/* Put one live-method patch onto the runner's permanent Object Queue Fabric. */
parse arg storeRoot methodName sourceFile rewind
if rewind = "" then rewind = 5

if storeRoot = "" | methodName = "" | sourceFile = "" then do
  say "usage: rexx send_patch.rex storeRoot methodName sourceFile [rewind]"
  exit 2
end
if \datatype(rewind, "W") | rewind < 0 then do
  say "invalid rewind:" rewind
  exit 2
end

/* ooRexx setMethod accepts an Array of source lines. Queue Fabric carries that
 * Array as part of the object graph, preserving normal multi-line Rexx source. */
source = readMethodSource(sourceFile)
if source == .nil then do
  say "cannot read method source:" sourceFile
  exit 3
end

manager = .ObjectQueueManager~new(storeRoot, .QueueGraphPayloadCodec~new, "admin")
if manager~queue("PATCH.INBOX") == .nil then do
  say "PATCH.INBOX does not exist in" storeRoot
  say "start runner.rex once before sending patches"
  exit 4
end

payload = .directory~new
payload["kind"] = "LIVE_METHOD_PATCH"
payload["methodName"] = methodName
payload["source"] = source
payload["rewind"] = rewind
payload["sourceFile"] = sourceFile
payload["submittedAt"] = .DateTime~new~string

options = .table~new
options["persistent"] = .true
options["securityDomain"] = "LIVEPATCH"
options["correlationId"] = "live-patch-" || .DateTime~new~microseconds
headers = .table~new
headers["submitted-by"] = "send_patch.rex"
options["headers"] = headers

putResult = manager~put("PATCH.INBOX", payload, options, "patch-tool")
call must putResult, "queue patch"

say "PATCH QUEUED"
say "  store  :" storeRoot
say "  package:" putResult~value~packageId
say "  method :" methodName
say "  source :" sourceFile
say "  rewind :" rewind
exit 0

readMethodSource: procedure
  use arg path
  stream = .Stream~new(path)
  if stream~query("exists") = "" then return .nil
  if stream~open("read") \= "READY:" then return .nil
  lines = .array~new
  do while stream~lines > 0
    lines~append(stream~lineIn)
  end
  ignore = stream~close
  return lines

must: procedure
  use arg result, label
  if result == .nil | \result~ok then do
    if result == .nil then say "FAILED:" label "nil result"
    else say "FAILED:" label result~code result~detail
    exit 10
  end
  return

::requires "ObjectQueueFabric.cls"
