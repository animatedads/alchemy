managerA = .ObjectQueueManager~new("", .QueueGraphPayloadCodec~new, "admin")
managerB = .ObjectQueueManager~new("", .QueueGraphPayloadCodec~new, "admin")
call ok managerA~createQueue("XMIT.B", "TEMPORARY", "OPS", 0, "admin"), "create xmit"
call ok managerB~createQueue("WORK", "TEMPORARY", "OPS", 0, "admin"), "create work"
call ok managerB~grant("WORK", "wire", .QueueAccess~PUT, "admin"), "grant wire put"
call ok managerB~grant("WORK", "wire", .QueueAccess~BROWSE, "admin"), "grant wire browse"
call ok managerB~grant("WORK", "wire", .QueueAccess~GET, "admin"), "grant wire get"

transport = .QueueInProcessTransport~new
fabricA = .QueueChannelFabric~new("A", managerA, transport, "admin")
fabricB = .QueueChannelFabric~new("B", managerB, transport, "admin")
ignore = transport~registerEndpoint("B", fabricB)
call ok fabricA~defineSenderChannel("A.TO.B", "XMIT.B", "B", "B.FROM.A", "admin", "wire", 4, "TEMPORARY", "admin"), "define sender"
call ok fabricB~defineReceiverChannel("B.FROM.A", "A", "wire", "TEMPORARY", "admin"), "define receiver"
call ok fabricA~startSenderChannel("A.TO.B", "admin"), "start sender"
call ok fabricB~startReceiverChannel("B.FROM.A", "admin"), "start receiver"
call ok fabricA~defineRemoteQueue("REMOTE.WORK", "WORK", "B", "XMIT.B", "A.TO.B", "OPS", "TEMPORARY", "admin", "admin"), "define remote"
call ok fabricA~grantRemotePut("REMOTE.WORK", "app", "admin"), "grant app"
call ok fabricA~put("REMOTE.WORK", .array~of("rich", .directory~new), .nil, "app"), "queue remote object"

service = .QueueBrokerService~new("broker-A", fabricA)
call assert service~isA(.AlchemyObject), "broker service inherits AlchemyObject"
call assert service~runtimePrepare(.nil), "runtime prepare"
call assert service~runtimeSelfTest, "runtime self test"
cycle = service~pumpCycle
call assert cycle~attempted = 1, "one sender attempted"
call assert cycle~sent = 1, "one package sent"
call assert cycle~failures = 0, "no pump failures"
depth = managerB~depth("WORK", "wire")
call ok depth, "destination depth"
call assert depth~value["ready"] = 1, "destination received package"
getResult = managerB~get("WORK", "wire")
call ok getResult, "get remote payload"
call assert getResult~value~payload~isA(.Array), "rich payload remains array"
call assert getResult~value~payload[2]~isA(.Directory), "nested object remains directory"
say "OBJECT QUEUE FABRIC V0.9 BROKER SERVICE: OK"
say "attempted=" || cycle~attempted "sent=" || cycle~sent
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
