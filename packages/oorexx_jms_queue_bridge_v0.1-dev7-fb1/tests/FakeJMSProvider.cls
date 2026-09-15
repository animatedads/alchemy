::class FakeJMSProvider public
::attribute accepts get
::attribute rejects get
::attribute sends get
::attribute completes get
::attribute aborts get
::attribute connected get
::attribute probes get
::attribute flowProbes get
::attribute capabilityProbes get
::attribute capabilityMode set
::attribute failSend set
::attribute failAcceptInbound set
::attribute failCompleteOutbound set
::attribute sessionMode get

::method init
  expose inbound accepts rejects sends completes aborts connected probes flowProbes capabilityProbes capabilityMode failSend failAcceptInbound failCompleteOutbound sessionMode
  use arg sessionMode = "AUTO_ACKNOWLEDGE"
  inbound = .queue~new
  accepts = 0
  rejects = 0
  sends = 0
  completes = 0
  aborts = 0
  connected = .false
  probes = 0
  flowProbes = 0
  capabilityProbes = 0
  capabilityMode = "READY"
  failSend = .false
  failAcceptInbound = .false
  failCompleteOutbound = .false
  sessionMode = sessionMode~string~translate

::method enqueue
  expose inbound
  use arg delivery
  inbound~queue(delivery)
  return delivery

::method probe
  expose probes connected
  if connected then return .JMSBridgeResult~failure("JMS_PROBE_REQUIRES_DISCONNECTED")
  probes += 1
  return .JMSBridgeResult~success(.nil, "JMS_PROBE_OK")

::method probeInboundFlow
  expose flowProbes connected sessionMode
  if connected then return .JMSBridgeResult~failure("JMS_PROBE_REQUIRES_DISCONNECTED")
  flowProbes += 1
  return .JMSBridgeResult~success(.nil, "JMS_INBOUND_FLOW_READY", sessionMode)

::method probeInboundCapabilities
  expose capabilityProbes connected capabilityMode
  use arg includeDirect = .false
  if connected then return .JMSBridgeResult~failure("JMS_PROBE_REQUIRES_DISCONNECTED")
  capabilityProbes += 1
  report = .JMSBridgeFlowCapabilityReport~new
  if capabilityMode = "BLOCKED" then do
    fail = .JMSBridgeResult~failure("JMS_FLOW_PROBE_FAILED_AT_FLOW_CONNECTION_START", "injected external block")
    ignore = report~record("AUTO_ACKNOWLEDGE", "ADMINISTERED", fail)
    ignore = report~record("AUTO_ACKNOWLEDGE", "GUARANTEED", fail)
    ignore = report~record("CLIENT_ACKNOWLEDGE", "ADMINISTERED", fail)
    ignore = report~record("CLIENT_ACKNOWLEDGE", "GUARANTEED", fail)
  end
  else if capabilityMode = "MIXED" then do
    ignore = report~record("AUTO_ACKNOWLEDGE", "ADMINISTERED", .JMSBridgeResult~failure("JMS_FLOW_PROBE_FAILED_AT_FLOW_SESSION", "injected mixed failure"))
    ignore = report~record("AUTO_ACKNOWLEDGE", "GUARANTEED", .JMSBridgeResult~failure("JMS_FLOW_PROBE_FAILED_AT_FLOW_CONNECTION_START", "injected mixed failure"))
  end
  else do
    ignore = report~record("CLIENT_ACKNOWLEDGE", "GUARANTEED", .JMSBridgeResult~success(.nil, "JMS_INBOUND_FLOW_READY"))
  end
  return .JMSBridgeResult~success(report, "JMS_FLOW_CAPABILITY_PROBE_COMPLETE", report~classification)

::method connect
  expose connected
  connected = .true
  return .JMSBridgeResult~success(.nil, "CONNECTED")

::method close
  expose connected
  connected = .false
  return .JMSBridgeResult~success(.nil, "CLOSED")

::method receive
  expose inbound connected
  use arg timeoutMs = 0
  if \connected then return .JMSBridgeResult~failure("JMS_NOT_CONNECTED")
  if inbound~items = 0 then return .JMSBridgeResult~success(.nil, "NO_MESSAGE")
  return .JMSBridgeResult~success(inbound~pull, "RECEIVED")

::method acceptInbound
  expose accepts failAcceptInbound sessionMode
  use arg delivery
  if failAcceptInbound then return .JMSBridgeResult~failure("JMS_INBOUND_SETTLEMENT_FAILED", "injected")
  accepts += 1
  select
    when sessionMode = "AUTO_ACKNOWLEDGE" then code = "JMS_AUTO_ACK_ALREADY_SETTLED"
    when sessionMode = "CLIENT_ACKNOWLEDGE" then code = "JMS_CLIENT_ACKNOWLEDGED"
    otherwise code = "JMS_TRANSACTION_COMMITTED"
  end
  return .JMSBridgeResult~success(delivery, code)

::method rejectInbound
  expose rejects sessionMode
  use arg delivery
  rejects += 1
  select
    when sessionMode = "AUTO_ACKNOWLEDGE" then code = "JMS_AUTO_ACK_CANNOT_RECOVER"
    when sessionMode = "CLIENT_ACKNOWLEDGE" then code = "JMS_CLIENT_RECOVER_REQUESTED"
    otherwise code = "JMS_TRANSACTION_ROLLED_BACK"
  end
  return .JMSBridgeResult~success(delivery, code)

::method send
  expose sends failSend
  use arg package
  if failSend then return .JMSBridgeResult~failure("JMS_SEND_FAILED", "injected")
  sends += 1
  return .JMSBridgeResult~success(package, "JMS_SEND_RETURNED")

::method completeOutbound
  expose completes failCompleteOutbound sessionMode
  use arg package
  if failCompleteOutbound then return .JMSBridgeResult~failure("JMS_OUTBOUND_COMPLETION_FAILED", "injected")
  completes += 1
  if sessionMode = "TRANSACTED" then code = "JMS_TRANSACTION_COMMITTED"
  else code = "JMS_NONTRANSACTED_SEND_COMPLETE"
  return .JMSBridgeResult~success(package, code)

::method abortOutbound
  expose aborts sessionMode
  use arg package
  aborts += 1
  if sessionMode = "TRANSACTED" then code = "JMS_TRANSACTION_ROLLED_BACK"
  else code = "JMS_NONTRANSACTED_NO_ROLLBACK"
  return .JMSBridgeResult~success(package, code)

/* dev1-dev3 provider aliases */
::method commitInbound
  use arg delivery
  return self~acceptInbound(delivery)

::method rollbackInbound
  use arg delivery
  return self~rejectInbound(delivery)

::method commitOutbound
  use arg package
  return self~completeOutbound(package)

::method rollbackOutbound
  use arg package
  return self~abortOutbound(package)

::requires "JMSQueueBridge.cls"
