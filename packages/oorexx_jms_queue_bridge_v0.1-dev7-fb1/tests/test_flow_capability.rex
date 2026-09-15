report = .JMSBridgeFlowCapabilityReport~new
call assert report~classification = "NO_EVIDENCE", "empty report"

r1 = .JMSBridgeResult~failure("JMS_FLOW_PROBE_FAILED_AT_FLOW_CONNECTION_START", "admin blocked")
r2 = .JMSBridgeResult~failure("JMS_FLOW_PROBE_FAILED_AT_FLOW_CONNECTION_START", "guaranteed blocked")
r3 = .JMSBridgeResult~failure("JMS_FLOW_PROBE_FAILED_AT_FLOW_CONNECTION_START", "client admin blocked")
r4 = .JMSBridgeResult~failure("JMS_FLOW_PROBE_FAILED_AT_FLOW_CONNECTION_START", "client guaranteed blocked")
ignore = report~record("AUTO_ACKNOWLEDGE", "ADMINISTERED", r1)
ignore = report~record("AUTO_ACKNOWLEDGE", "GUARANTEED", r2)
ignore = report~record("CLIENT_ACKNOWLEDGE", "ADMINISTERED", r3)
ignore = report~record("CLIENT_ACKNOWLEDGE", "GUARANTEED", r4)
call assert report~classification = "BROKER_FLOW_ACTIVATION_BLOCKED", "all connection start failures classified"
call assert report~preferredEvidence == .nil, "no preferred path while blocked"
call assert report~operationalDisposition = .JMSBridgeOperationalDisposition~EXTERNAL_BLOCKED, "blocked operational disposition"
call assert report~operatorAction = "BROKER_OR_CLIENT_PROFILE_FLOW_ACTIVATION_REVIEW_REQUIRED", "blocked operator action"

ready = .JMSBridgeFlowCapabilityReport~new
ignore = ready~record("AUTO_ACKNOWLEDGE", "ADMINISTERED", r1)
ignore = ready~record("AUTO_ACKNOWLEDGE", "GUARANTEED", .JMSBridgeResult~success(.nil, "JMS_INBOUND_FLOW_READY"))
ignore = ready~record("CLIENT_ACKNOWLEDGE", "ADMINISTERED", .JMSBridgeResult~success(.nil, "JMS_INBOUND_FLOW_READY"))
ignore = ready~record("CLIENT_ACKNOWLEDGE", "GUARANTEED", .JMSBridgeResult~success(.nil, "JMS_INBOUND_FLOW_READY"))
call assert ready~classification = "FLOW_READY", "ready classified"
call assert ready~preferredSessionMode = "CLIENT_ACKNOWLEDGE", "client acknowledgement preferred"
call assert ready~preferredTransportMode = "GUARANTEED", "guaranteed preferred"
call assert ready~operationalDisposition = .JMSBridgeOperationalDisposition~READY, "ready operational disposition"
call assert ready~operatorAction = "NONE", "ready operator action"

config = .JMSBridgeConfig~new("cap", "SOLACE", "tcps://example:55443", "CF", "Q", "", "VPN", "", "", "IN", "", "bridge", .true, 1000, "REJECT", "com.solacesystems.jndi.SolJNDIInitialContextFactory", "AUTO_ACKNOWLEDGE", "ADMINISTERED")
copy = config~copyWithSessionPolicy("CLIENT_ACKNOWLEDGE", "GUARANTEED")
call assert copy~bridgeId = config~bridgeId, "clone bridge id"
call assert copy~providerUrl = config~providerUrl, "clone provider url"
call assert copy~inboundDestination = config~inboundDestination, "clone destination"
call assert copy~sessionMode = "CLIENT_ACKNOWLEDGE", "clone session override"
call assert copy~transportMode = "GUARANTEED", "clone transport override"
call assert config~sessionMode = "AUTO_ACKNOWLEDGE", "source config unchanged"
call assert config~transportMode = "ADMINISTERED", "source transport unchanged"

say "JMS FLOW CAPABILITY MODEL PASS 17"
exit 0

assert: procedure
  use arg ok, label
  if \ok then do
    say "FAIL:" label
    exit 1
  end
return

::requires "JMSQueueBridge.cls"
