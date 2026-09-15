parse source . . here
root = filespec("L", here)
call directory root

qm = .ObjectQueueManager~new
created = qm~createQueue("IN", "TEMPORARY", "DEFAULT", 1, "bridge")
call assert created~ok, "queue create"
call assert qm~put("IN", "already-full", .nil, "bridge")~ok, "fill queue"
config = .JMSBridgeConfig~new("test", "GENERIC", "", "", "remote", "", "", "", "", "IN", "", "bridge", .false, 1000, "REJECT", "com.solacesystems.jndi.SolJNDIInitialContextFactory", "CLIENT_ACKNOWLEDGE")
provider = .FakeJMSProvider~new("CLIENT_ACKNOWLEDGE")
service = .JMSQueueBridgeService~new(qm, provider, config)
call assert service~start~ok, "start"
msg = .JMSBridgeMessage~new("ID:busy", "TEXT", "payload")
provider~enqueue(.JMSBridgeInboundDelivery~new("jms:test:ID:busy", msg))
r = service~pumpInbound(0)
call assert \r~ok, "local reject reported"
call assert r~code = "LOCAL_ACCEPT_FAILED", "local failure code"
call assert provider~rejects = 1, "JMS recovery requested"
call assert qm~depth("IN", "bridge")~value["ready"] = 1, "queue unchanged"
say "JMS INBOUND CLIENT-ACK RECOVERY PASS 7"
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
