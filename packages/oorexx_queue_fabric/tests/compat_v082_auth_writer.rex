/* Exact v0.8.2 authenticated durable writer for v0.9 compatibility evidence. */
parse arg root keyHex
if root = "" | keyHex = "" then exit 2
protector = .QueueHmacSha512RecordProtector~new("compat-auth", keyHex, .nil, 64)
manager = .ObjectQueueManager~new(root, .QueueGraphPayloadCodec~new, "admin", .nil, protector)
call must manager~createQueue("COMPAT.AUTH", "PERMANENT", "OPS", 10, "admin"), "create authenticated permanent queue"
payload = .directory~new
payload["writer"] = "V082-AUTH"
payload["nested"] = .array~of("alpha", .directory~new)
payload["nested"][2]["value"] = 8209
options = .table~new
options["persistent"] = .true
options["priority"] = 9
options["correlationId"] = "compat-auth-v082"
call must manager~put("COMPAT.AUTH", payload, options, "admin"), "persist authenticated nested object graph"
say "V082 AUTHENTICATED WRITER: OK"
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
