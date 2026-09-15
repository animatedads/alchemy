parse source . . here
root = filespec("L", here)
call directory root

qm = .ObjectQueueManager~new
call assert qm~createQueue("OUT", "TEMPORARY", "DEFAULT", 0, "bridge")~ok, "queue create"
config = .JMSBridgeConfig~new("test", "GENERIC", "", "", "", "remote.out", "", "", "", "", "OUT", "bridge", .false, 1000, "REJECT", "com.solacesystems.jndi.SolJNDIInitialContextFactory", "AUTO_ACKNOWLEDGE")
provider = .FakeJMSProvider~new("AUTO_ACKNOWLEDGE")
service = .JMSQueueBridgeService~new(qm, provider, config)
call assert service~start~ok, "start"

call assert qm~put("OUT", "hello", .nil, "bridge")~ok, "put"
r1 = service~pumpOutbound
call assert r1~ok, "outbound success"
call assert provider~sends = 1, "send count"
call assert provider~completes = 1, "non-transacted completion"
call assert qm~depth("OUT", "bridge")~value["total"] = 0, "acked after JMS send returns"

call assert qm~put("OUT", "again", .nil, "bridge")~ok, "put retry"
provider~failSend = .true
r2 = service~pumpOutbound
call assert \r2~ok, "send failure reported"
call assert provider~aborts = 1, "non-transacted abort hook"
call assert qm~depth("OUT", "bridge")~value["ready"] = 1, "queue package released not lost"
p = qm~browse("OUT", "bridge")~value
call assert p~backoutCount = 0, "transport failure does not increment backout"
say "JMS NON-TRANSACTED OUTBOUND SEMANTICS PASS 11"
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
