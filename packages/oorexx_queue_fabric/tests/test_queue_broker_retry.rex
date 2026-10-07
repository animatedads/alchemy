manager = .ObjectQueueManager~new("", .QueueGraphPayloadCodec~new, "admin")
call ok manager~createQueue("XMIT", "TEMPORARY", "OPS", 0, "admin"), "create xmit"
transport = .QueueInProcessTransport~new
fabric = .QueueChannelFabric~new("A", manager, transport, "admin")
call ok fabric~defineSenderChannel("OUT", "XMIT", "MISSING", "IN", "admin", "wire", 0, "TEMPORARY", "admin"), "define sender"
call ok fabric~startSenderChannel("OUT", "admin"), "start sender"
call ok fabric~defineRemoteQueue("REMOTE", "WORK", "MISSING", "XMIT", "OUT", "OPS", "TEMPORARY", "admin", "admin"), "define remote"
call ok fabric~grantRemotePut("REMOTE", "app", "admin"), "grant"
call ok fabric~put("REMOTE", "payload", .nil, "app"), "queue"
service = .QueueBrokerService~new("retry-broker", fabric, .nil, .nil, "admin", 0, 0.05, 0.2)
first = service~pumpCycle
call assert first~attempted = 1, "first attempt performed"
call assert first~failures = 1, "first attempt fails"
channel = fabric~senderChannel("OUT")
call assert channel~state = .QueueChannelState~RETRYING, "channel enters retrying"
second = service~pumpCycle
call assert second~attempted = 0, "retry deadline prevents immediate re-attempt"
call assert second~deferred = 1, "channel deferred"
call SysSleep 0.06
third = service~pumpCycle
call assert third~attempted = 1, "retry occurs after deadline"
package = manager~browse("XMIT", "admin")~value
call assert package~deliveryCount = 2, "two actual claims recorded"
call assert package~backoutCount = 0, "transport retry never increments application backout"
say "OBJECT QUEUE FABRIC V0.9 BROKER RETRY: OK"
exit 0

ok: procedure
  use arg result, label
  if result == .nil | \result~ok then do
    if result == .nil then say "ASSERT FAILED:" label "nil result"
    else say "ASSERT FAILED:" label result~code result~detail
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

::requires "ObjectQueueBrokerService.cls"
