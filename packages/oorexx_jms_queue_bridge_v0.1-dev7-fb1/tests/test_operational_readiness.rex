qm = .ObjectQueueManager~new
call assert qm~createQueue("IN", "TEMPORARY", "DEFAULT", 0, "bridge")~ok, "queue create"
provider = .FakeJMSProvider~new("AUTO_ACKNOWLEDGE")
config = .JMSBridgeConfig~new("ready", "GENERIC", "", "", "remote", "", "", "", "", "IN", "", "bridge", .false)
bridge = .JMSQueueBridgeService~new(qm, provider, config)

ready = bridge~assessInboundReadiness
call assert ready~ok, "ready assessment succeeds"
call assert ready~code = "JMS_INBOUND_READY", "ready code"
call assert ready~value~operationalDisposition = .JMSBridgeOperationalDisposition~READY, "ready disposition"
call assert ready~value~operatorAction = "NONE", "ready action"
call assert ready~detail = "CLIENT_ACKNOWLEDGE/GUARANTEED", "ready preferred policy"

provider~capabilityMode = "BLOCKED"
blocked = bridge~assessInboundReadiness
call assert \blocked~ok, "external block is not readiness"
call assert blocked~code = "JMS_INBOUND_EXTERNAL_BLOCKER", "external blocker code"
call assert blocked~value~classification = "BROKER_FLOW_ACTIVATION_BLOCKED", "blocked classification retained"
call assert blocked~value~operationalDisposition = .JMSBridgeOperationalDisposition~EXTERNAL_BLOCKED, "blocked disposition"
call assert blocked~detail = "BROKER_OR_CLIENT_PROFILE_FLOW_ACTIVATION_REVIEW_REQUIRED", "blocked action"

provider~capabilityMode = "MIXED"
mixed = bridge~assessInboundReadiness
call assert \mixed~ok, "mixed evidence unresolved"
call assert mixed~code = "JMS_INBOUND_READINESS_UNRESOLVED", "mixed code"
call assert mixed~value~operationalDisposition = .JMSBridgeOperationalDisposition~UNRESOLVED, "mixed disposition"
call assert mixed~detail = "REVIEW_CAPABILITY_EVIDENCE", "mixed action"

call assert provider~capabilityProbes = 3, "three capability probes"
call assert bridge~state = .JMSBridgeState~STOPPED, "readiness never starts bridge"

call assert bridge~start~ok, "start"
running = bridge~assessInboundReadiness
call assert \running~ok, "running readiness rejected"
call assert running~code = "READINESS_REQUIRES_STOPPED", "running code"
call assert provider~capabilityProbes = 3, "running assessment performs no probe"
call assert bridge~stop~ok, "stop"

say "JMS BRIDGE OPERATIONAL READINESS PASS 18"
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
