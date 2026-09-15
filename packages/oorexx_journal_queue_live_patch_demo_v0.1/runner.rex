/*
 * JournalPointedState + Object Queue Fabric live-patch/rewind demonstration.
 *
 * The runner and patch sender are separate OS processes. They communicate only
 * through one PERMANENT Queue Fabric queue. The runner deliberately constructs
 * a fresh ObjectQueueManager for each poll, replaying the queue journal so it
 * sees work appended by another process after the previous poll.
 */
parse arg storeRoot delay limit
if storeRoot = "" then storeRoot = "./livepatch-queue-store"
if delay = "" then delay = 1
if limit = "" then limit = 100

if \datatype(delay, "N") | delay < 0 then do
  say "invalid delay:" delay
  exit 2
end
if \datatype(limit, "W") | limit < 1 then do
  say "invalid limit:" limit
  exit 2
end

/* Bootstrap the permanent control queue if this is a new store. */
manager = .ObjectQueueManager~new(storeRoot, .QueueGraphPayloadCodec~new, "admin")
if manager~queue("PATCH.INBOX") == .nil then do
  call must manager~createQueue("PATCH.INBOX", "PERMANENT", "LIVEPATCH", 100, "admin"), "create PATCH.INBOX"
  call must manager~grant("PATCH.INBOX", "patch-tool", .QueueAccess~PUT, "admin"), "grant patch-tool PUT"
  call must manager~grant("PATCH.INBOX", "runner", .QueueAccess~GET, "admin"), "grant runner GET"
end
manager = .nil

/* Journalled testbed state. NEXT is the next X(i) that must run. */
initial = .directory~new
initial["NEXT"] = 1
state = .JournalPointedState~new(initial, "demo-runner-state")
controller = .StateOfNationController~new
controller~register("runner", state)
worker = .DemoWorker~new

/* Pointer-only freeze immediately before each X(i). */
checkpoints = .directory~new
checkpoints[1] = controller~checkpoint("before-X-1", "ITERATION")
abandoned = .array~new
patchGeneration = 0

say "LIVE PATCH RUNNER READY"
say "  queue store :" storeRoot
say "  queue       : PATCH.INBOX (PERMANENT)"
say "  initial X   : X.v1(i) = i*10"
say "  range       : 1.." || limit
say "  command     : rexx send_patch.rex" storeRoot "X X_v2.method 5"
say

do while state~at("NEXT") <= limit
  /* Reopen/recover Queue Fabric state. This is the cross-process visibility
   * boundary; no private mailbox, socket or signal is used. */
  manager = .ObjectQueueManager~new(storeRoot, .QueueGraphPayloadCodec~new, "admin")

  do forever
    got = manager~get("PATCH.INBOX", "runner")
    if \got~ok then do
      if got~code = "QUEUE_EMPTY" then leave
      say "PATCH QUEUE ERROR:" got~code got~detail
      exit 4
    end

    payload = got~value~payload
    if \payload~isA(.Directory) then do
      say "PATCH REJECTED: payload is not a Directory"
      iterate
    end
    if \payload~hasIndex("kind") | payload["kind"] \= "LIVE_METHOD_PATCH" then do
      say "PATCH REJECTED: unsupported kind"
      iterate
    end
    if \payload~hasIndex("methodName") | \payload~hasIndex("source") then do
      say "PATCH REJECTED: methodName/source required"
      iterate
    end

    methodName = payload["methodName"]~string
    source = payload["source"]
    rewind = 0
    if payload~hasIndex("rewind") then rewind = payload["rewind"]
    if \datatype(rewind, "W") | rewind < 0 then do
      say "PATCH REJECTED: rewind must be a non-negative whole number"
      iterate
    end

    currentNext = state~at("NEXT")
    if rewind >= currentNext then targetNext = 1
    else targetNext = currentNext - rewind

    /* Keep a pointer to the future we are about to abandon. */
    oldFuturePoint = state~journalPoint
    oldFutureNext = currentNext

    /* Code moves forward ... */
    worker~installLiveMethod(methodName, source)
    patchGeneration += 1

    /* ... while data can move backward. */
    if rewind > 0 then do
      if \checkpoints~hasIndex(targetNext) then do
        say "PATCH ERROR: checkpoint before X(" || targetNext || ") not retained"
        exit 5
      end
      abandoned~append(oldFuturePoint)
      cp = checkpoints[targetNext]
      controller~restore(cp)
      say "*** PATCH" patchGeneration "INSTALLED:" methodName || " rewind=" || rewind
      say "*** abandoned branch" oldFuturePoint~string "had NEXT=" || oldFutureNext
      say "*** restored" cp~checkpointId "=> NEXT=" || state~at("NEXT")
      say "*** replaying" targetNext "through" (oldFutureNext - 1) "with new code"
    end
    else say "*** PATCH" patchGeneration "INSTALLED:" methodName || " no rewind"
  end
  manager = .nil

  i = state~at("NEXT")
  checkpoints[i] = controller~checkpoint("before-X-" || i, "ITERATION")

  result = worker~X(i)
  say right(i, 3) "|" result "| state-head=" || state~journalPoint~nodeId

  metadata = .directory~new
  metadata["completed"] = i
  metadata["result"] = result
  state~put("NEXT", i + 1, "X-COMPLETE", metadata)
  controller~noteProgress("runner", i, metadata)

  if delay > 0 then call SysSleep delay
end

say
say "RUN COMPLETE"
say "  NEXT=" || state~at("NEXT")
say "  retained journal nodes=" || state~retainedNodeCount
say "  abandoned branch pointers=" || abandoned~items
do p over abandoned
  oldState = state~reconstruct(p)
  say "    " || p~string || " reconstructs NEXT=" || oldState["NEXT"]
end
exit 0

must: procedure
  use arg result, label
  if result == .nil | \result~ok then do
    if result == .nil then say "FAILED:" label "nil result"
    else say "FAILED:" label result~code result~detail
    exit 10
  end
  return

::class DemoWorker public inherit LiveMethodPatchable
::method X
  use strict arg i
  return "X.v1(" || i || ")=" || (i * 10)

::requires "JournalPointedState.cls"
::requires "ObjectQueueFabric.cls"
