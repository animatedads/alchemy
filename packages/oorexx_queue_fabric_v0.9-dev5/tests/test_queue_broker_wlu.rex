ring = .WLUFastMacKeyRing~new
ignore = ring~addKey("active", "00112233445566778899aabbccddeeff")
authority = .WLUAuthority~new(ring)
account = .WLUAccount~new("broker-account", 0)
ignore = authority~addAccount(account)
ignore = authority~bindAccount("broker-A", "queue/*", "broker-account")

managerA = .ObjectQueueManager~new("", .QueueGraphPayloadCodec~new, "admin")
managerB = .ObjectQueueManager~new("", .QueueGraphPayloadCodec~new, "admin")
call ok managerA~createQueue("XMIT", "TEMPORARY", "OPS", 0, "admin"), "create xmit"
call ok managerB~createQueue("WORK", "TEMPORARY", "OPS", 0, "admin"), "create work"
call ok managerB~grant("WORK", "wire", .QueueAccess~PUT, "admin"), "grant wire put"
call ok managerB~grant("WORK", "wire", .QueueAccess~BROWSE, "admin"), "grant wire browse"
call ok managerB~grant("WORK", "wire", .QueueAccess~GET, "admin"), "grant wire get"
transport = .QueueInProcessTransport~new
fabricA = .QueueChannelFabric~new("A", managerA, transport, "admin")
fabricB = .QueueChannelFabric~new("B", managerB, transport, "admin")
ignore = transport~registerEndpoint("B", fabricB)
call ok fabricA~defineSenderChannel("OUT", "XMIT", "B", "IN", "admin", "wire", 0, "TEMPORARY", "admin"), "sender"
call ok fabricB~defineReceiverChannel("IN", "A", "wire", "TEMPORARY", "admin"), "receiver"
call ok fabricA~startSenderChannel("OUT", "admin"), "start sender"
call ok fabricB~startReceiverChannel("IN", "admin"), "start receiver"
call ok fabricA~defineRemoteQueue("REMOTE", "WORK", "B", "XMIT", "OUT", "OPS", "TEMPORARY", "admin", "admin"), "remote"
call ok fabricA~grantRemotePut("REMOTE", "app", "admin"), "grant"
call ok fabricA~put("REMOTE", "payload", .nil, "app"), "queue"

policy = .QueueBrokerWLUAdmission~new(authority, "broker-A", "queue", 100, 100)
service = .QueueBrokerService~new("broker-A", fabricA, .nil, policy, "admin", 0, 0.01, 0.1)
first = service~pumpCycle
call assert first~denied = 1, "WLU denies before pump"
call assert first~attempted = 0, "denied work is not pumped"
package = managerA~browse("XMIT", "admin")~value
call assert package~deliveryCount = 0, "WLU denial does not claim transmission package"
call assert package~backoutCount = 0, "WLU denial does not alter backout count"
call assert managerB~depth("WORK", "wire")~value["ready"] = 0, "no remote side effect on denial"

ignore = account~grant(1000)
call SysSleep 0.26
second = service~pumpCycle
call assert second~sent = 1, "admitted work transfers"
call assert managerB~depth("WORK", "wire")~value["ready"] = 1, "destination receives admitted work"
call assert account~spentMicroWlu = 100, "actual WLU settled"
say "OBJECT QUEUE FABRIC V0.9 WLU ADMISSION: OK"
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

::requires "ObjectQueueWLU.cls"
