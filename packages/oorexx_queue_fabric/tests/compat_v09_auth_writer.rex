/* v0.9 authenticated writer for exact v0.8.2 reverse compatibility evidence. */
parse arg root keyHex
if root = "" | keyHex = "" then exit 2
protector = .QueueHmacSha512RecordProtector~new("compat-auth", keyHex, .nil, 64)
manager = .ObjectQueueManager~new(root, .QueueGraphPayloadCodec~new, "admin", .nil, protector)
call must manager~createQueue("COMPAT.AUTH", "PERMANENT", "OPS", 10, "admin"), "create authenticated permanent queue"
payload = .directory~new
payload["writer"] = "V09-AUTH"
payload["nested"] = .array~of("nine", .directory~new)
payload["nested"][2]["value"] = 9009
options = .table~new
options["persistent"] = .true
options["priority"] = 10
options["correlationId"] = "compat-auth-v09"
call must manager~put("COMPAT.AUTH", payload, options, "admin"), "persist authenticated nested object graph"
say "V09 AUTHENTICATED WRITER: OK"
exit 0

must: procedure
  use arg outcome, label
  if outcome == .nil | \outcome~ok then do
    if outcome == .nil then say "ASSERT FAILED:" label "nil outcome"
    else say "ASSERT FAILED:" label outcome~code outcome~detail
    exit 1
  end
  return

::requires "ObjectQueueFabric.cls"
::requires "ObjectQueueCrypto.cls"
