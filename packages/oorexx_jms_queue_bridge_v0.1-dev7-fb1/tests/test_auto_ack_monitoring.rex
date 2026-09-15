qm = .ObjectQueueManager~new
call assert qm~createQueue("MON", "TEMPORARY", "DEFAULT", 1, "bridge")~ok, "queue create"
call assert qm~put("MON", "already-full", .nil, "bridge")~ok, "fill queue"
config = .JMSBridgeConfig~new("monitor", "SOLACE", "", "", "remote", "", "", "", "", "MON", "", "bridge", .false, 1000, "REJECT", "com.solacesystems.jndi.SolJNDIInitialContextFactory", "AUTO_ACKNOWLEDGE")
provider = .FakeJMSProvider~new("AUTO_ACKNOWLEDGE")
service = .JMSQueueBridgeService~new(qm, provider, config)
call assert service~start~ok, "start"
msg = .JMSBridgeMessage~new("ID:auto", "TEXT", "monitoring")
provider~enqueue(.JMSBridgeInboundDelivery~new("jms:monitor:ID:auto", msg))
r = service~pumpInbound(0)
call assert \r~ok, "local failure reported"
call assert r~code = "LOCAL_ACCEPT_FAILED_AFTER_AUTO_ACK", "loss-window code explicit"
call assert provider~rejects = 1, "settlement hook invoked"
call assert qm~depth("MON", "bridge")~value["ready"] = 1, "queue remains full"
call assert service~inboundFailures = 1, "failure counted"
say "JMS AUTO-ACK MONITORING SEMANTICS PASS 7"
exit 0

assert: procedure
  use arg ok, label
  if \ok then do
    say "FAIL:" label
    exit 1
  end
return

::requires "JMSQueueBridge.cls"
::requires "FakeJMSProvider.cls"
