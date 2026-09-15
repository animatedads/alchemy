parse arg root
if root = "" then root = directory()

say "RUNTIME REGISTRY V0.1 CONCURRENCY START"

verifier = .RuntimePinnedSourceVerifier~new
kernel = .RuntimeKernel~new(verifier)
registry = kernel~registry

f1 = .RuntimeArtifactFactory~fromFile("stress.capability", "CAPABILITY", "1.0.0", "fixture:stress:v1", "DemoCapability", root || "/fixtures/modules/DemoCapability_v1.cls")
f2 = .RuntimeArtifactFactory~fromFile("stress.capability", "CAPABILITY", "2.0.0", "fixture:stress:v2", "DemoCapability", root || "/fixtures/modules/DemoCapability_v2.cls")
call assert f1~ok, "load v1 fixture"
call assert f2~ok, "load v2 fixture"
v1 = f1~value
v2 = f2~value
pinResult = verifier~pin(v1~artifactId, v1~sourceLines)
pinResult = verifier~pin(v2~artifactId, v2~sourceLines)

s1 = kernel~stage("stress", v1)
s2 = kernel~stage("stress", v2)
call assert s1~ok, "stage v1"
call assert s2~ok, "stage v2"
g1 = s1~value
g2 = s2~value
ar = kernel~activate("stress", "stress.capability", g1~generationId)
call assert ar~ok, "activate v1"

gate = .RegistryStartGate~new
messages = .array~new
do workerNo = 1 to 8
  worker = .RegistryLeaseWorker~new(registry, "stress", "stress.capability", 500, gate)
  msg = .Message~new(worker, "RUN")
  msg~start
  messages~append(msg)
end

/* Every worker first acquires and holds a v1 lease.  Only then do we publish
 * v2, proving activation works while multiple independent activities are
 * actively pinned to the previous generation.
 */
readyResult = gate~awaitReady(8)
call assert (g1~leaseCount = 8), "all workers hold v1 leases before activation"
ar = kernel~activate("stress", "stress.capability", g2~generationId)
call assert ar~ok, "activate v2 with eight in-flight v1 leases"
call assert (g1~state = "DRAINING"), "v1 is draining while held by workers"
call assert (g1~leaseCount = 8), "activation does not disturb held leases"
openResult = gate~open

heldOneCount = 0
oneCount = 0
twoCount = 0
errorCount = 0
do msg over messages
  msg~wait
  call assert (msg~errorCondition == .nil), "worker activity completes without condition"
  resultRow = msg~result
  heldOneCount = heldOneCount + resultRow["HELD_ONE"]
  oneCount = oneCount + resultRow["ONE"]
  twoCount = twoCount + resultRow["TWO"]
  errorCount = errorCount + resultRow["ERROR"]
end

call assert (heldOneCount = 8), "every in-flight lease continued to execute v1"
call assert (oneCount + twoCount = 4000), "all post-publication acquisitions resolved to a complete generation"
call assert (twoCount = 4000), "all new acquisitions after publication resolve to v2"
call assert (errorCount = 0), "no acquisition or release errors during activation"
call assert (registry~activeGenerationId("stress", "stress.capability") = g2~generationId), "v2 remains active"
collectResult = kernel~collectRetired
call assert (g1~state = "RETIRED"), "v1 drains after concurrent workers"

say "  held_v1_leases=" || heldOneCount
say "  post_publish_v1=" || oneCount
say "  post_publish_v2=" || twoCount
say "  errors=" || errorCount
say "RUNTIME REGISTRY V0.1 CONCURRENCY: OK"
exit 0

assert: procedure
  use arg condition, label
  if \condition then do
    say "ASSERTION FAILED:" label
    exit 1
  end
return

::class RegistryStartGate
::method init
  expose ready isOpen
  ready = 0
  isOpen = .false

::method held
  expose ready
  guard on
  ready = ready + 1
  return ready

::method awaitReady
  expose ready
  use arg required
  guard on when ready >= required
  return ready

::method awaitOpen
  expose isOpen
  guard on when isOpen
  return .true

::method open
  expose isOpen
  guard on
  isOpen = .true
  return .true

::class RegistryLeaseWorker
::method init
  expose registry environment moduleId loops gate
  use arg registry, environment, moduleId, loops, gate

::method run
  expose registry environment moduleId loops gate
  counts = .directory~new
  counts["HELD_ONE"] = 0
  counts["ONE"] = 0
  counts["TWO"] = 0
  counts["ERROR"] = 0

  heldResult = registry~acquire(environment, moduleId)
  if \heldResult~ok then do
    counts["ERROR"] = counts["ERROR"] + 1
    return counts
  end
  heldLease = heldResult~value
  ready = gate~held
  gateResult = gate~awaitOpen
  if heldLease~module~version = "ONE" then counts["HELD_ONE"] = 1
  else counts["ERROR"] = counts["ERROR"] + 1
  releaseResult = heldLease~release
  if \releaseResult~ok then counts["ERROR"] = counts["ERROR"] + 1

  do i = 1 to loops
    acquireResult = registry~acquire(environment, moduleId)
    if \acquireResult~ok then do
      counts["ERROR"] = counts["ERROR"] + 1
      iterate
    end

    lease = acquireResult~value
    module = lease~module
    if module == .nil then counts["ERROR"] = counts["ERROR"] + 1
    else do
      version = module~version
      if version = "ONE" then counts["ONE"] = counts["ONE"] + 1
      else if version = "TWO" then counts["TWO"] = counts["TWO"] + 1
      else counts["ERROR"] = counts["ERROR"] + 1
    end

    releaseResult = lease~release
    if \releaseResult~ok then counts["ERROR"] = counts["ERROR"] + 1
  end

  return counts

::requires "src/RuntimeRegistry.cls"
