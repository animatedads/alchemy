managerA = .ObjectQueueManager~new("", .QueueGraphPayloadCodec~new, "admin")
managerB = .ObjectQueueManager~new("", .QueueGraphPayloadCodec~new, "admin")
call must managerA~createQueue("XMIT.B", "TEMPORARY", "OPS", 0, "admin"), "create xmit"
call must managerB~createQueue("WORK", "TEMPORARY", "OPS", 0, "admin"), "create work"
call must managerB~grant("WORK", "wire", .QueueAccess~PUT, "admin"), "grant wire put"
call must managerB~grant("WORK", "wire", .QueueAccess~BROWSE, "admin"), "grant wire browse"
call must managerB~grant("WORK", "wire", .QueueAccess~GET, "admin"), "grant wire get"

transport = .QueueInProcessTransport~new
fabricA = .QueueChannelFabric~new("A", managerA, transport, "admin")
fabricB = .QueueChannelFabric~new("B", managerB, transport, "admin")
ignore = transport~registerEndpoint("B", fabricB)
call must fabricA~defineSenderChannel("A.TO.B", "XMIT.B", "B", "B.FROM.A", "admin", "wire", 4, "TEMPORARY", "admin"), "define sender"
call must fabricB~defineReceiverChannel("B.FROM.A", "A", "wire", "TEMPORARY", "admin"), "define receiver"
call must fabricA~startSenderChannel("A.TO.B", "admin"), "start sender"
call must fabricB~startReceiverChannel("B.FROM.A", "admin"), "start receiver"
call must fabricA~defineRemoteQueue("REMOTE.WORK", "WORK", "B", "XMIT.B", "A.TO.B", "OPS", "TEMPORARY", "admin", "admin"), "define remote"
call must fabricA~grantRemotePut("REMOTE.WORK", "app", "admin"), "grant app"

/* First prove drain can flush real queued work. */
payload = .directory~new
payload["kind"] = "DRAIN"
call must fabricA~put("REMOTE.WORK", payload, .nil, "app"), "queue remote work"
service = .QueueBrokerService~new("drain-real-work", fabricA, .nil, .nil, "admin", 0.005, 0.02, 0.08)
call assert service~start~ok, "service start"
call assert service~quiesce(.true)~ok, "request draining quiesce"
service~waitForStop(.false)
call assert service~state = .QueueBrokerServiceState~QUIESCED, "queued work drains to QUIESCED"
depthDest = managerB~depth("WORK", "wire")
call must depthDest, "destination depth"
call assert depthDest~value["total"] = 1, "queued work delivered before quiesce"
call assert service~stop~ok, "stop first service"

/* Empty RUNNING sender channels are still attempted.  They must not hold a
 * drain open forever merely because attempted > 0 on QUEUE_EMPTY. */
emptyService = .QueueBrokerService~new("drain-empty-channel", fabricA, .nil, .nil, "admin", 0.005, 0.02, 0.08)
call assert emptyService~start~ok, "empty service start"
call SysSleep 0.01
call assert emptyService~quiesce(.true)~ok, "empty channel drain"
emptyService~waitForStop(.false)
call assert emptyService~state = .QueueBrokerServiceState~QUIESCED, "empty RUNNING channel reaches QUIESCED"
call assert emptyService~cycles > 0, "empty channel was actually pumped"
call assert emptyService~stop~ok, "stop empty service"

say "OBJECT QUEUE FABRIC V0.9 BROKER DRAIN: OK"
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

::requires "ObjectQueueBrokerService.cls"
