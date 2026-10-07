ring = .WLUFastMacKeyRing~new
ignore = ring~addKey("active", "00112233445566778899aabbccddeeff")
authority = .WLUAuthority~new(ring)
account = .WLUAccount~new("broker-heartbeat", 0)
ignore = authority~addAccount(account)
ignore = authority~bindAccount("broker-H", "queue/heartbeat/*", "broker-heartbeat")

managerA = .ObjectQueueManager~new("", .QueueGraphPayloadCodec~new, "admin")
call ok managerA~createQueue("XMIT", "TEMPORARY", "OPS", 0, "admin"), "create xmit"
transport = .ProbeInProcessTransport~new
fabricA = .QueueChannelFabric~new("A", managerA, transport, "admin")
call ok fabricA~defineSenderChannel("OUT", "XMIT", "B", "IN", "admin", "wire", 0, "TEMPORARY", "admin"), "sender"
call ok fabricA~startSenderChannel("OUT", "admin"), "start sender"
policy = .QueueBrokerWLUAdmission~new(authority, "broker-H", "queue", 100, 100, 0, 30, 10, 10, 0)
service = .QueueBrokerService~new("broker-H", fabricA, .nil, policy, "admin", 0, 0.01, 0.1, 1)

first = service~heartbeatCycle
call assert first~denied = 1, "heartbeat WLU denial reported"
call assert first~attempted = 0, "denied heartbeat performs no probe"
call assert transport~probeCount = 0, "WLU denial is before network side effect"
call assert account~spentMicroWlu = 0, "denied heartbeat spends no WLU"
ignore = account~grant(100)
second = service~heartbeatCycle
call assert second~healthy = 1, "admitted heartbeat healthy"
call assert second~attempted = 1, "admitted heartbeat attempted"
call assert transport~probeCount = 1, "probe performed after admission"
call assert account~spentMicroWlu = 10, "heartbeat WLU settled separately"
call assert service~heartbeatCount = 1, "service heartbeat success counted"
call assert service~heartbeatDenialCount = 1, "service heartbeat denial counted"
say "OBJECT QUEUE FABRIC V0.9 WLU HEARTBEAT ADMISSION: OK"
exit 0

ok: procedure
  use arg result, label
  if result == .nil | \result~ok then do
    say "ASSERT FAILED:" label
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

::class ProbeInProcessTransport subclass QueueInProcessTransport
::attribute probeCount get
::method init
  expose probeCount
  self~init:super
  probeCount = 0
::method probe
  expose probeCount
  use strict arg sourceManager, remoteManager, remoteChannel, principal
  probeCount += 1
  return .QueueOperationResult~success(.nil, "probe-ok")

::requires "ObjectQueueWLU.cls"
