parse source . . here
root = filespec("L", here)
call directory root

store = "tmp_inbound_store"
call sysFileTree store, found., "DO"
if found.0 > 0 then "rm -rf" store

qm = .ObjectQueueManager~new(store)
created = qm~createQueue("SWIM.IN", "PERMANENT", "FAA", 0, "bridge")
call assert created~ok, "queue create"

/* CLIENT_ACKNOWLEDGE is non-transacted but deliberately defers the JMS ACK
 * until after Queue Fabric has durably accepted the transfer. */
config = .JMSBridgeConfig~new("faa-test", "SOLACE", "", "", "remote.in", "", "", "", "", "SWIM.IN", "", "bridge", .true, 1000, "REJECT", "com.solacesystems.jndi.SolJNDIInitialContextFactory", "CLIENT_ACKNOWLEDGE")
provider = .FakeJMSProvider~new("CLIENT_ACKNOWLEDGE")
service = .JMSQueueBridgeService~new(qm, provider, config)
call assert service~start~ok, "service start"

h = .directory~new
h["JMSMESSAGEID"] = "ID:42"
h["JMSPRIORITY"] = "4"
m1 = .JMSBridgeMessage~new("ID:42", "TEXT", "<notam id='42'/>", h, .directory~new, "SOLACE", "remote.in")
d1 = .JMSBridgeInboundDelivery~new("jms:faa-test:ID:42", m1)
provider~enqueue(d1)
r1 = service~pumpInbound(0)
call assert r1~ok, "first delivery accepted"
call assert qm~depth("SWIM.IN", "bridge")~value["ready"] = 1, "depth after first"

/* Simulate redelivery after local durable accept but before/without JMS ACK. */
m2 = .JMSBridgeMessage~new("ID:42", "TEXT", "<notam id='42'/>", h, .directory~new, "SOLACE", "remote.in")
d2 = .JMSBridgeInboundDelivery~new("jms:faa-test:ID:42", m2)
provider~enqueue(d2)
r2 = service~pumpInbound(0)
call assert r2~ok, "redelivery handled"
call assert qm~depth("SWIM.IN", "bridge")~value["ready"] = 1, "duplicate suppressed"
call assert service~inboundAccepted = 1, "accepted count"
call assert service~inboundDuplicates = 1, "duplicate count"
call assert provider~accepts = 2, "both deliveries acknowledged"

say "JMS INBOUND CLIENT-ACK IDEMPOTENCY PASS 8"
call directory ".."
"rm -rf" root || "/" || store
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
