/* v0.9-dev5 authenticated reader for exact v0.8.2 durable state. */
parse arg root keyHex
if root = "" | keyHex = "" then exit 2
protector = .QueueHmacSha512RecordProtector~new("compat-auth", keyHex, .nil, 64)
manager = .ObjectQueueManager~new(root, .QueueGraphPayloadCodec~new, "admin", .nil, protector)
call assert manager~isA(.AlchemyObject), "runtime queue manager adopts AlchemyObject"
depth = manager~depth("COMPAT.AUTH", "admin")
call must depth, "authenticated queue recovered"
call assert depth~value["ready"] = 1, "one authenticated package recovered"
browse = manager~browse("COMPAT.AUTH", "admin")
call must browse, "browse authenticated package"
package = browse~value
call assert \package~isA(.AlchemyObject), "durable QueueWorkPackage remains outside AlchemyObject graph boundary"
call assert package~priority = 9, "priority recovered"
call assert package~correlationId = "compat-auth-v082", "correlation recovered"
call assert package~payload~isA(.Directory), "payload remains Directory"
call assert package~payload["writer"] = "V082-AUTH", "writer identity recovered"
call assert package~payload["nested"]~isA(.Array), "nested Array recovered"
call assert package~payload["nested"][2]~isA(.Directory), "nested Directory recovered"
call assert package~payload["nested"][2]["value"] = 8209, "nested value recovered"
call assert protector~verifiedRecords >= 2, "authenticated v0.8.2 journal records verified"
say "OBJECT QUEUE FABRIC V0.8.2 -> V0.9-dev5 AUTHENTICATED REPLAY: OK"
exit 0

must: procedure
  use arg outcome, label
  if outcome == .nil | \outcome~ok then do
    if outcome == .nil then say "ASSERT FAILED:" label "nil outcome"
    else say "ASSERT FAILED:" label outcome~code outcome~detail
    exit 1
  end
  return

assert: procedure
  use arg condition, label
  if \condition then do
    say "ASSERT FAILED:" label
    exit 1
  end
  return

::requires "ObjectQueueFabric.cls"
::requires "ObjectQueueCrypto.cls"
