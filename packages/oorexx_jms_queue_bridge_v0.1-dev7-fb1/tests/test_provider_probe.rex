qm = .ObjectQueueManager~new
call assert qm~createQueue("IN", "TEMPORARY", "DEFAULT", 0, "bridge")~ok, "queue create"
provider = .FakeJMSProvider~new("AUTO_ACKNOWLEDGE")
config = .JMSBridgeConfig~new("probe", "GENERIC", "", "", "remote", "", "", "", "", "IN", "", "bridge", .false)
bridge = .JMSQueueBridgeService~new(qm, provider, config)

probe = bridge~probeProvider
call assert probe~ok, "stopped provider probe succeeds"
call assert probe~code = "JMS_PROBE_OK", "probe result"
call assert provider~probes = 1, "provider probed once"
call assert bridge~state = .JMSBridgeState~STOPPED, "probe does not start bridge"

flow = bridge~probeInboundFlow
call assert flow~ok, "inbound flow probe succeeds"
call assert flow~code = "JMS_INBOUND_FLOW_READY", "flow probe result"
call assert provider~flowProbes = 1, "flow probed once"
call assert bridge~state = .JMSBridgeState~STOPPED, "flow probe does not start bridge"

call assert bridge~start~ok, "start"
blocked = bridge~probeProvider
call assert \blocked~ok, "running probe rejected"
call assert blocked~code = "PROBE_REQUIRES_STOPPED", "running probe result"
blockedFlow = bridge~probeInboundFlow
call assert \blockedFlow~ok, "running flow probe rejected"
call assert provider~probes = 1, "running probe performs no provider work"
call assert provider~flowProbes = 1, "running flow probe performs no provider work"
call assert bridge~stop~ok, "stop"

say "JMS BRIDGE PROVIDER/FLOW PROBE PASS 15"
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
