/*
 * JMSQueueBridge.cls - Alchemy JMS <-> Queue Fabric bridge v0.1-dev7-fb1
 *
 * Core bridge logic is deliberately Java-neutral.  The live BSF4ooRexx/JMS
 * binding lives in JMSQueueBridgeBSF.cls so Queue Fabric remains independent
 * of Java, JMS vendor libraries, and BSF4ooRexx.
 */

::class JMSQueueBridgeBuild public
::constant VERSION "0.1-dev7-fb1"
::constant API "alchemy.jms.queue.bridge/0.1"

::class JMSBridgeState public
::constant STOPPED "STOPPED"
::constant RUNNING "RUNNING"
::constant QUIESCED "QUIESCED"
::constant FAILED "FAILED"

::class JMSBridgeDirection public
::constant INBOUND "JMS_TO_QUEUE"
::constant OUTBOUND "QUEUE_TO_JMS"

/* JMS session policy is explicit.  FAA/SCDS monitoring uses AUTO_ACKNOWLEDGE,
 * while CLIENT_ACKNOWLEDGE is available when post-persistence acknowledgement
 * is required without a transaction-capable broker profile. */
::class JMSBridgeSessionMode public
::constant AUTO_ACKNOWLEDGE "AUTO_ACKNOWLEDGE"
::constant CLIENT_ACKNOWLEDGE "CLIENT_ACKNOWLEDGE"
::constant TRANSACTED "TRANSACTED"

/* Transport policy is an adapter concern. ADMINISTERED leaves the JNDI
 * ConnectionFactory unchanged. SOLACE providers may explicitly override its
 * Direct Transport bit for diagnostics or a deployment-specific requirement. */
::class JMSBridgeTransportMode public
::constant ADMINISTERED "ADMINISTERED"
::constant DIRECT "DIRECT"
::constant GUARANTEED "GUARANTEED"

::class JMSBridgeBodyType public
::constant TEXT "TEXT"
::constant BYTES "BYTES"
::constant MAP "MAP"
::constant UNSUPPORTED "UNSUPPORTED"

/* Operational readiness is deliberately separate from the lifecycle state.
 * A bridge may be correctly configured locally while an external broker or
 * client profile refuses to activate its consumer flow. */
::class JMSBridgeOperationalDisposition public
::constant READY "READY"
::constant EXTERNAL_BLOCKED "EXTERNAL_BLOCKED"
::constant UNRESOLVED "UNRESOLVED"
::constant NO_EVIDENCE "NO_EVIDENCE"

::class JMSBridgeResult public
::attribute ok get
::attribute code get
::attribute value get
::attribute detail get

::method init
  expose ok code value detail
  use arg ok = .false, code = "FAILED", value = .nil, detail = ""
  ok = ok
  code = code~string
  value = value
  detail = detail~string

::method success class
  use arg value = .nil, code = "OK", detail = ""
  return self~new(.true, code, value, detail)

::method failure class
  use arg code, detail = "", value = .nil
  return self~new(.false, code, value, detail)

/* One non-consuming flow-activation attempt.  This is diagnostic evidence, not
 * a JMS delivery and is never placed on Queue Fabric. */
::class JMSBridgeFlowProbeEvidence public
::attribute sessionMode get
::attribute transportMode get
::attribute ok get
::attribute code get
::attribute detail get

::method init
  expose sessionMode transportMode ok code detail
  use strict arg sessionMode, transportMode, outcome
  sessionMode = sessionMode~string~translate
  transportMode = transportMode~string~translate
  ok = outcome~ok
  code = outcome~code
  detail = outcome~detail

/* Java-neutral interpretation of a bounded JMS flow capability matrix.  The
 * preferred path is CLIENT_ACKNOWLEDGE + GUARANTEED because it allows local
 * Queue Fabric persistence before acknowledgement without requiring XA. */
::class JMSBridgeFlowCapabilityReport public
::attribute evidence get

::method init
  expose evidence
  evidence = .array~new

::method record
  expose evidence
  use strict arg sessionMode, transportMode, outcome
  row = .JMSBridgeFlowProbeEvidence~new(sessionMode, transportMode, outcome)
  evidence~append(row)
  return row

::method preferredEvidence
  expose evidence
  preferred = .array~new
  preferred~append(.array~of(.JMSBridgeSessionMode~CLIENT_ACKNOWLEDGE, .JMSBridgeTransportMode~GUARANTEED))
  preferred~append(.array~of(.JMSBridgeSessionMode~CLIENT_ACKNOWLEDGE, .JMSBridgeTransportMode~ADMINISTERED))
  preferred~append(.array~of(.JMSBridgeSessionMode~AUTO_ACKNOWLEDGE, .JMSBridgeTransportMode~GUARANTEED))
  preferred~append(.array~of(.JMSBridgeSessionMode~AUTO_ACKNOWLEDGE, .JMSBridgeTransportMode~ADMINISTERED))
  do choice over preferred
    do row over evidence
      if row~ok & row~sessionMode = choice[1] & row~transportMode = choice[2] then return row
    end
  end
  do row over evidence
    if row~ok then return row
  end
  return .nil

::method classification
  expose evidence
  if evidence~items = 0 then return "NO_EVIDENCE"
  if self~preferredEvidence \== .nil then return "FLOW_READY"
  allStartBlocked = .true
  do row over evidence
    if row~ok then allStartBlocked = .false
    if row~code~pos("FLOW_CONNECTION_START") = 0 then allStartBlocked = .false
  end
  if allStartBlocked then return "BROKER_FLOW_ACTIVATION_BLOCKED"
  return "FLOW_CAPABILITY_MIXED_FAILURE"

::method preferredSessionMode
  preferred = self~preferredEvidence
  if preferred == .nil then return ""
  return preferred~sessionMode

::method preferredTransportMode
  preferred = self~preferredEvidence
  if preferred == .nil then return ""
  return preferred~transportMode

::method operationalDisposition
  classification = self~classification
  select
    when classification = "NO_EVIDENCE" then return .JMSBridgeOperationalDisposition~NO_EVIDENCE
    when classification = "FLOW_READY" then return .JMSBridgeOperationalDisposition~READY
    when classification = "BROKER_FLOW_ACTIVATION_BLOCKED" then return .JMSBridgeOperationalDisposition~EXTERNAL_BLOCKED
    otherwise return .JMSBridgeOperationalDisposition~UNRESOLVED
  end

::method operatorAction
  disposition = self~operationalDisposition
  select
    when disposition = .JMSBridgeOperationalDisposition~READY then return "NONE"
    when disposition = .JMSBridgeOperationalDisposition~EXTERNAL_BLOCKED then return "BROKER_OR_CLIENT_PROFILE_FLOW_ACTIVATION_REVIEW_REQUIRED"
    when disposition = .JMSBridgeOperationalDisposition~NO_EVIDENCE then return "RUN_BOUNDED_FLOW_CAPABILITY_PROBE"
    otherwise return "REVIEW_CAPABILITY_EVIDENCE"
  end

/* Persistable, Java-free representation of one JMS message.  It intentionally
 * carries protocol data, not a BSF Java proxy, across the Queue Fabric durable
 * boundary. Bytes are represented as an even-length hexadecimal string. */
::class JMSBridgeMessage public
::constant PERSISTENT_TYPE "alchemy.jms.message/0.1"

::attribute messageId get
::attribute bodyType get
::attribute body get
::attribute headers get
::attribute properties get
::attribute provider get
::attribute source get
::attribute receivedAt get

::method init
  expose messageId bodyType body headers properties provider source receivedAt
  use arg messageId = "", bodyType = "TEXT", body = "", headers = .nil, properties = .nil, provider = "", source = "", receivedAt = ""
  messageId = messageId~string
  bodyType = bodyType~string~translate
  body = body
  if headers == .nil then headers = .directory~new
  if properties == .nil then properties = .directory~new
  headers = headers
  properties = properties
  provider = provider~string
  source = source~string
  if receivedAt = "" then receivedAt = .DateTime~new~string
  receivedAt = receivedAt~string

::method queuePersistentType
  return self~PERSISTENT_TYPE

::method queuePersistentState
  expose messageId bodyType body headers properties provider source receivedAt
  d = .directory~new
  d["messageId"] = messageId
  d["bodyType"] = bodyType
  d["body"] = body
  d["headers"] = headers
  d["properties"] = properties
  d["provider"] = provider
  d["source"] = source
  d["receivedAt"] = receivedAt
  return d

::method queueRestoreState
  expose messageId bodyType body headers properties provider source receivedAt
  use arg d
  messageId = d["messageId"]
  bodyType = d["bodyType"]
  body = d["body"]
  headers = d["headers"]
  properties = d["properties"]
  provider = d["provider"]
  source = d["source"]
  receivedAt = d["receivedAt"]
  return self

::method newBlank class
  return self~new

::class JMSBridgeMessageFactory public
::method newBlank
  return .JMSBridgeMessage~newBlank

::class JMSBridgeQueueCodecFactory public
::method newCodec class
  codec = .QueueGraphPayloadCodec~new
  ignore = codec~typeRegistry~register(.JMSBridgeMessage~PERSISTENT_TYPE, .JMSBridgeMessageFactory~new)
  return codec

/* A delivery is ephemeral. JMS acknowledgement/recovery stays owned by the provider. */
::class JMSBridgeInboundDelivery public
::attribute transferId get
::attribute message get
::attribute providerDelivery get

::method init
  expose transferId message providerDelivery
  use strict arg transferId, message, providerDelivery = .nil
  transferId = transferId~string
  message = message
  providerDelivery = providerDelivery

/* Configuration contains no password.  Credential sources are separate and
 * are consulted only by the Java/JMS provider when establishing a session. */
::class JMSBridgeConfig public
::attribute bridgeId get
::attribute providerKind get
::attribute providerUrl get
::attribute connectionFactory get
::attribute inboundDestination get
::attribute outboundDestination get
::attribute messageVpn get
::attribute trustStore get
::attribute trustStoreFormat get
::attribute localInboundQueue get
::attribute localOutboundQueue get
::attribute principal get
::attribute persistentInbound get
::attribute receiveTimeoutMs get
::attribute missingMessageIdPolicy get
::attribute initialContextFactory get
::attribute sessionMode get
::attribute transportMode get

::method init
  expose bridgeId providerKind providerUrl connectionFactory inboundDestination outboundDestination messageVpn trustStore trustStoreFormat localInboundQueue localOutboundQueue principal persistentInbound receiveTimeoutMs missingMessageIdPolicy initialContextFactory sessionMode transportMode
  use arg bridgeId = "jms-bridge", providerKind = "GENERIC", providerUrl = "", connectionFactory = "", inboundDestination = "", outboundDestination = "", messageVpn = "", trustStore = "", trustStoreFormat = "", localInboundQueue = "", localOutboundQueue = "", principal = "queue-admin", persistentInbound = .true, receiveTimeoutMs = 1000, missingMessageIdPolicy = "REJECT", initialContextFactory = "com.solacesystems.jndi.SolJNDIInitialContextFactory", sessionMode = "AUTO_ACKNOWLEDGE", transportMode = "ADMINISTERED"
  bridgeId = bridgeId~string
  providerKind = providerKind~string~translate
  providerUrl = providerUrl~string
  connectionFactory = connectionFactory~string
  inboundDestination = inboundDestination~string
  outboundDestination = outboundDestination~string
  messageVpn = messageVpn~string
  trustStore = trustStore~string
  trustStoreFormat = trustStoreFormat~string
  localInboundQueue = localInboundQueue~string
  localOutboundQueue = localOutboundQueue~string
  principal = principal~string
  persistentInbound = persistentInbound
  receiveTimeoutMs = receiveTimeoutMs
  missingMessageIdPolicy = missingMessageIdPolicy~string~translate
  initialContextFactory = initialContextFactory~string
  sessionMode = sessionMode~string~translate
  transportMode = transportMode~string~translate
  if sessionMode <> .JMSBridgeSessionMode~AUTO_ACKNOWLEDGE & sessionMode <> .JMSBridgeSessionMode~CLIENT_ACKNOWLEDGE & sessionMode <> .JMSBridgeSessionMode~TRANSACTED then raise syntax 88.900 array("Unsupported JMS session mode: " || sessionMode)
  if transportMode <> .JMSBridgeTransportMode~ADMINISTERED & transportMode <> .JMSBridgeTransportMode~DIRECT & transportMode <> .JMSBridgeTransportMode~GUARANTEED then raise syntax 88.900 array("Unsupported JMS transport mode: " || transportMode)

::method copyWithSessionPolicy
  expose bridgeId providerKind providerUrl connectionFactory inboundDestination outboundDestination messageVpn trustStore trustStoreFormat localInboundQueue localOutboundQueue principal persistentInbound receiveTimeoutMs missingMessageIdPolicy initialContextFactory
  use strict arg sessionMode, transportMode
  return .JMSBridgeConfig~new(bridgeId, providerKind, providerUrl, connectionFactory, inboundDestination, outboundDestination, messageVpn, trustStore, trustStoreFormat, localInboundQueue, localOutboundQueue, principal, persistentInbound, receiveTimeoutMs, missingMessageIdPolicy, initialContextFactory, sessionMode, transportMode)

/* Ephemeral credential material.  This object must never cross the Queue Fabric
 * durable boundary.  retire() clears the ooRexx references as soon as the JMS
 * provider has established or rejected the connection. */
::class JMSBridgeCredentialLease public
::attribute active get

::method init
  expose usernameValue passwordValue active
  use arg usernameValue = "", passwordValue = ""
  usernameValue = usernameValue~string
  passwordValue = passwordValue~string
  active = .true

::method username
  expose usernameValue active
  if \active then return ""
  return usernameValue

::method password
  expose passwordValue active
  if \active then return ""
  return passwordValue

::method retire
  expose usernameValue passwordValue active
  usernameValue = ""
  passwordValue = ""
  active = .false
  return .true

/* Reads secrets lazily from environment variables and stores only their names. */
::class JMSBridgeEnvironmentCredentials public
::attribute usernameVariable get
::attribute passwordVariable get

::method init
  expose usernameVariable passwordVariable
  use arg usernameVariable = "JMS_USERNAME", passwordVariable = "JMS_PASSWORD"
  usernameVariable = usernameVariable~string
  passwordVariable = passwordVariable~string

::method username
  expose usernameVariable
  return value(usernameVariable, , "ENVIRONMENT")

::method password
  expose passwordVariable
  return value(passwordVariable, , "ENVIRONMENT")

::method acquire
  expose usernameVariable passwordVariable
  username = value(usernameVariable, , "ENVIRONMENT")
  password = value(passwordVariable, , "ENVIRONMENT")
  lease = .JMSBridgeCredentialLease~new(username, password)
  return .JMSBridgeResult~success(lease, "CREDENTIALS_ACQUIRED")

/*
 * JMSQueueBridgeService owns bridge semantics, but not Java.  A provider object
 * implements connect/close/receive plus accept/reject settlement for inbound
 * and send/complete/abort settlement for outbound. dev1-dev4 commit/rollback
 * aliases remain accepted for compatibility. This is intentionally duck-typed so live
 * BSF4ooRexx binding and deterministic test providers can coexist.
 */
::class JMSQueueBridgeService subclass AlchemyObject public
::attribute state get
::attribute inboundAccepted get
::attribute inboundDuplicates get
::attribute inboundFailures get
::attribute outboundCommitted get
::attribute outboundFailures get
::attribute lastResult get

::method init
  expose queueManager provider config state inboundAccepted inboundDuplicates inboundFailures outboundCommitted outboundFailures lastResult
  use strict arg queueManager, provider, config

  meta = .directory~new
  meta["purpose"] = "Bridge JMS sessions to Alchemy Queue Fabric without coupling Queue Fabric to Java"
  meta["package_version"] = .JMSQueueBridgeBuild~VERSION
  meta["authorship"] = "Alchemy ooRexx project"
  meta["standards"] = .array~of(.JMSQueueBridgeBuild~API, "queue.fabric/0.9", "ALCHEMY-HOUSE-OBJECT-0.8")
  meta["design_limitations"] = .array~of("No distributed XA", "AUTO_ACKNOWLEDGE can acknowledge before local Queue Fabric persistence", "CLIENT_ACKNOWLEDGE provides post-persistence acknowledgement with one synchronous consumer per session", "Outbound may duplicate after remote JMS send succeeds and before local ACK", "Live Java/JMS binding remains a separate BSF4ooRexx boundary")
  self~init:super(meta)

  queueManager = queueManager
  provider = provider
  config = config
  state = .JMSBridgeState~STOPPED
  inboundAccepted = 0
  inboundDuplicates = 0
  inboundFailures = 0
  outboundCommitted = 0
  outboundFailures = 0
  lastResult = .JMSBridgeResult~success(.nil, "INITIALIZED")

  self~registerStateVariable("state", "INTERNAL", "bridge lifecycle state")
  self~registerStateVariable("inboundAccepted", "INTERNAL", "locally accepted JMS deliveries")
  self~registerStateVariable("inboundDuplicates", "INTERNAL", "duplicate JMS redeliveries suppressed by transfer receipt")
  self~registerStateVariable("inboundFailures", "INTERNAL", "failed inbound bridge attempts")
  self~registerStateVariable("outboundCommitted", "INTERNAL", "remote JMS send completions followed by local ACK")
  self~registerStateVariable("outboundFailures", "INTERNAL", "failed outbound bridge attempts")
  self~registerMethodContract("START", "Connect provider and activate bridge", .array~new, "JMSBRIDGERESULT", .false)
  self~registerMethodContract("PROBEPROVIDER", "Verify JMS endpoint/JNDI reachability without consuming a message", .array~new, "JMSBRIDGERESULT", .false)
  self~registerMethodContract("PROBEINBOUNDFLOW", "Activate the configured inbound JMS consumer without receiving a message", .array~new, "JMSBRIDGERESULT", .false)
  self~registerMethodContract("PROBEINBOUNDCAPABILITIES", "Compare non-transacted JMS session/transport flow activation without receiving a message", .array~of("INCLUDE_DIRECT"), "JMSBRIDGERESULT", .false)
  self~registerMethodContract("PUMPINBOUND", "Consume one JMS delivery into Queue Fabric", .array~of("TIMEOUT_MS"), "JMSBRIDGERESULT", .false)
  self~registerMethodContract("PUMPOUTBOUND", "Send one claimed Queue Fabric package to JMS", .array~new, "JMSBRIDGERESULT", .false)
  self~registerMethodContract("STOP", "Close provider and stop bridge", .array~new, "JMSBRIDGERESULT", .false)
  self~registerMethodContract("RUNTIMEPREPARE", "Runtime Registry prepare lifecycle", .array~new, "JMSBRIDGERESULT", .false)
  self~registerMethodContract("RUNTIMESELFTEST", "Runtime Registry self-test lifecycle", .array~new, "JMSBRIDGERESULT", .false)
  self~registerMethodContract("RUNTIMESTART", "Runtime Registry start lifecycle", .array~new, "JMSBRIDGERESULT", .false)
  self~registerMethodContract("RUNTIMEQUIESCE", "Runtime Registry quiesce lifecycle", .array~new, "JMSBRIDGERESULT", .false)
  self~registerMethodContract("RUNTIMESTOP", "Runtime Registry stop lifecycle", .array~new, "JMSBRIDGERESULT", .false)
  self~describeMethodPolicy("START", "FALSE", "INTERNAL", "SENSITIVE", "MUTATE", "NONE")
  self~describeMethodPolicy("PROBEPROVIDER", "FALSE", "INTERNAL", "SENSITIVE", "READ", "NONE")
  self~describeMethodPolicy("PROBEINBOUNDFLOW", "FALSE", "INTERNAL", "SENSITIVE", "READ", "NONE")
  self~describeMethodPolicy("PROBEINBOUNDCAPABILITIES", "FALSE", "INTERNAL", "SENSITIVE", "READ", "NONE")
  self~describeMethodPolicy("PUMPINBOUND", "FALSE", "CUSTOMER", "SENSITIVE", "MUTATE", "NONE")
  self~describeMethodPolicy("PUMPOUTBOUND", "FALSE", "CUSTOMER", "SENSITIVE", "MUTATE", "NONE")
  self~describeMethodPolicy("STOP", "FALSE", "INTERNAL", "SENSITIVE", "MUTATE", "NONE")
  self~recordRelationship("QUEUE_MANAGER", queueManager, "local queue authority", "INTERNAL")
  self~recordRelationship("JMS_PROVIDER", provider, "external JMS session authority", "INTERNAL")
  self~registerExternalRequirement("library", "oorexx_queue_fabric", "queue.fabric/0.9", .true)
  self~registerExternalRequirement("library", "alchemy_objects", "v0.8", .true)
  self~declareHouseCompliance(95)

  /* Register the bridge message type with the manager's graph codec. */
  if queueManager~hasMethod("PAYLOADCODEC") then do
    codec = queueManager~payloadCodec
    if codec \== .nil then if codec~hasMethod("TYPEREGISTRY") then do
      ignore = codec~typeRegistry~register(.JMSBridgeMessage~PERSISTENT_TYPE, .JMSBridgeMessageFactory~new)
    end
  end

::method runtimePrepare
  expose queueManager provider config
  use arg context = .nil
  if queueManager == .nil then return .JMSBridgeResult~failure("QUEUE_MANAGER_MISSING")
  if provider == .nil then return .JMSBridgeResult~failure("JMS_PROVIDER_MISSING")
  if config == .nil then return .JMSBridgeResult~failure("CONFIG_MISSING")
  return .JMSBridgeResult~success(self, "PREPARED")

::method runtimeSelfTest
  expose queueManager provider config
  if \provider~hasMethod("CONNECT") | \provider~hasMethod("CLOSE") then return .JMSBridgeResult~failure("INVALID_JMS_PROVIDER")
  if config~localInboundQueue \= "" then do
    if \provider~hasMethod("RECEIVE") then return .JMSBridgeResult~failure("INVALID_INBOUND_JMS_PROVIDER")
    if \provider~hasMethod("ACCEPTINBOUND") & \provider~hasMethod("COMMITINBOUND") then return .JMSBridgeResult~failure("INVALID_INBOUND_JMS_PROVIDER")
    if \provider~hasMethod("REJECTINBOUND") & \provider~hasMethod("ROLLBACKINBOUND") then return .JMSBridgeResult~failure("INVALID_INBOUND_JMS_PROVIDER")
    if queueManager~queue(config~localInboundQueue) == .nil then return .JMSBridgeResult~failure("INBOUND_QUEUE_MISSING", config~localInboundQueue)
  end
  if config~localOutboundQueue \= "" then do
    if \provider~hasMethod("SEND") then return .JMSBridgeResult~failure("INVALID_OUTBOUND_JMS_PROVIDER")
    if \provider~hasMethod("COMPLETEOUTBOUND") & \provider~hasMethod("COMMITOUTBOUND") then return .JMSBridgeResult~failure("INVALID_OUTBOUND_JMS_PROVIDER")
    if \provider~hasMethod("ABORTOUTBOUND") & \provider~hasMethod("ROLLBACKOUTBOUND") then return .JMSBridgeResult~failure("INVALID_OUTBOUND_JMS_PROVIDER")
    if queueManager~queue(config~localOutboundQueue) == .nil then return .JMSBridgeResult~failure("OUTBOUND_QUEUE_MISSING", config~localOutboundQueue)
  end
  return .JMSBridgeResult~success(self, "SELF_TEST_OK")

::method runtimeStart
  return self~start

::method runtimeQuiesce
  return self~quiesce

::method runtimeStop
  return self~stop

::method probeProvider
  expose provider state lastResult
  if state \= .JMSBridgeState~STOPPED then return .JMSBridgeResult~failure("PROBE_REQUIRES_STOPPED", state)
  if \provider~hasMethod("PROBE") then return .JMSBridgeResult~failure("JMS_PROVIDER_PROBE_UNSUPPORTED")
  r = provider~probe
  lastResult = r
  return r

::method probeInboundFlow
  expose provider state lastResult
  if state \= .JMSBridgeState~STOPPED then return .JMSBridgeResult~failure("PROBE_REQUIRES_STOPPED", state)
  if \provider~hasMethod("PROBEINBOUNDFLOW") then return .JMSBridgeResult~failure("JMS_PROVIDER_FLOW_PROBE_UNSUPPORTED")
  r = provider~probeInboundFlow
  lastResult = r
  return r

::method probeInboundCapabilities
  expose provider state lastResult
  use arg includeDirect = .false
  if state \= .JMSBridgeState~STOPPED then return .JMSBridgeResult~failure("PROBE_REQUIRES_STOPPED", state)
  if \provider~hasMethod("PROBEINBOUNDCAPABILITIES") then return .JMSBridgeResult~failure("JMS_PROVIDER_CAPABILITY_PROBE_UNSUPPORTED")
  r = provider~probeInboundCapabilities(includeDirect)
  lastResult = r
  return r

/* Convert diagnostic capability evidence into an operational deployment
 * disposition. This remains a no-receive operation and does not mutate Queue
 * Fabric or start the long-running bridge. */
::method assessInboundReadiness
  expose state lastResult
  use arg includeDirect = .false
  if state \= .JMSBridgeState~STOPPED then return .JMSBridgeResult~failure("READINESS_REQUIRES_STOPPED", state)
  probed = self~probeInboundCapabilities(includeDirect)
  if \probed~ok then do
    lastResult = probed
    return probed
  end
  report = probed~value
  if report == .nil | \report~hasMethod("OPERATIONALDISPOSITION") then do
    lastResult = .JMSBridgeResult~failure("JMS_INBOUND_READINESS_INVALID_EVIDENCE", probed~code, report)
    return lastResult
  end
  disposition = report~operationalDisposition
  select
    when disposition = .JMSBridgeOperationalDisposition~READY then do
      detail = report~preferredSessionMode || "/" || report~preferredTransportMode
      lastResult = .JMSBridgeResult~success(report, "JMS_INBOUND_READY", detail)
    end
    when disposition = .JMSBridgeOperationalDisposition~EXTERNAL_BLOCKED then do
      lastResult = .JMSBridgeResult~failure("JMS_INBOUND_EXTERNAL_BLOCKER", report~operatorAction, report)
    end
    when disposition = .JMSBridgeOperationalDisposition~NO_EVIDENCE then do
      lastResult = .JMSBridgeResult~failure("JMS_INBOUND_READINESS_NO_EVIDENCE", report~operatorAction, report)
    end
    otherwise do
      lastResult = .JMSBridgeResult~failure("JMS_INBOUND_READINESS_UNRESOLVED", report~operatorAction, report)
    end
  end
  return lastResult

::method start
  expose provider state lastResult
  if state = .JMSBridgeState~RUNNING then return .JMSBridgeResult~success(.nil, "ALREADY_RUNNING")
  r = provider~connect
  if \r~ok then do
    state = .JMSBridgeState~FAILED
    lastResult = r
    return r
  end
  state = .JMSBridgeState~RUNNING
  lastResult = .JMSBridgeResult~success(.nil, "RUNNING")
  return lastResult

::method quiesce
  expose state lastResult
  if state = .JMSBridgeState~STOPPED then return .JMSBridgeResult~success(.nil, "ALREADY_STOPPED")
  state = .JMSBridgeState~QUIESCED
  lastResult = .JMSBridgeResult~success(.nil, "QUIESCED")
  return lastResult

::method stop
  expose provider state lastResult
  r = provider~close
  state = .JMSBridgeState~STOPPED
  if r~ok then lastResult = .JMSBridgeResult~success(.nil, "STOPPED")
  else lastResult = r
  return lastResult

::method pumpInbound
  expose queueManager provider config state inboundAccepted inboundDuplicates inboundFailures lastResult
  use arg timeoutMs = .nil
  if state \= .JMSBridgeState~RUNNING then return .JMSBridgeResult~failure("NOT_RUNNING", state)
  if config~localInboundQueue = "" then return .JMSBridgeResult~failure("INBOUND_DISABLED")
  if timeoutMs == .nil then timeoutMs = config~receiveTimeoutMs

  received = provider~receive(timeoutMs)
  if \received~ok then do
    inboundFailures += 1
    lastResult = received
    return received
  end
  delivery = received~value
  if delivery == .nil then do
    lastResult = .JMSBridgeResult~success(.nil, "NO_MESSAGE")
    return lastResult
  end

  transferId = delivery~transferId
  if transferId = "" then do
    ignore = self~rejectInbound(delivery)
    inboundFailures += 1
    lastResult = .JMSBridgeResult~failure("MISSING_JMS_MESSAGE_ID", "Inbound idempotency requires JMSMessageID")
    return lastResult
  end

  options = .table~new
  options["persistent"] = config~persistentInbound
  options["sourceManager"] = "JMS:" || config~bridgeId
  options["sourceQueue"] = config~inboundDestination
  options["correlationId"] = self~header(delivery~message~headers, "JMSCORRELATIONID", "")
  options["replyTo"] = self~header(delivery~message~headers, "JMSREPLYTO", "")
  options["priority"] = self~header(delivery~message~headers, "JMSPRIORITY", 0)
  options["headers"] = delivery~message~headers

  accepted = queueManager~acceptTransfer(transferId, config~localInboundQueue, delivery~message, options, config~principal)
  if \accepted~ok then do
    rejected = self~rejectInbound(delivery)
    inboundFailures += 1
    if config~sessionMode = .JMSBridgeSessionMode~AUTO_ACKNOWLEDGE then code = "LOCAL_ACCEPT_FAILED_AFTER_AUTO_ACK"
    else code = "LOCAL_ACCEPT_FAILED"
    detail = accepted~code || ":" || accepted~detail || " settlement=" || rejected~code
    lastResult = .JMSBridgeResult~failure(code, detail, accepted)
    return lastResult
  end

  committed = self~acceptInbound(delivery)
  if \committed~ok then do
    /* Do not undo the local durable accept. If the selected acknowledgement
       policy can redeliver, Queue Fabric suppresses the duplicate by transfer id. */
    inboundFailures += 1
    lastResult = .JMSBridgeResult~failure("JMS_SETTLEMENT_FAILED_AFTER_LOCAL_ACCEPT", committed~detail, accepted)
    return lastResult
  end

  if accepted~value~hasMethod("DUPLICATE") then do
    if accepted~value~duplicate then inboundDuplicates += 1
    else inboundAccepted += 1
  end
  else inboundAccepted += 1
  lastResult = .JMSBridgeResult~success(accepted~value, "INBOUND_SETTLED", committed~code)
  return lastResult

::method pumpOutbound
  expose queueManager provider config state outboundCommitted outboundFailures lastResult
  if state \= .JMSBridgeState~RUNNING then return .JMSBridgeResult~failure("NOT_RUNNING", state)
  if config~localOutboundQueue = "" then return .JMSBridgeResult~failure("OUTBOUND_DISABLED")

  claimed = queueManager~claim(config~localOutboundQueue, config~principal)
  if \claimed~ok then do
    if claimed~code = "QUEUE_EMPTY" then return .JMSBridgeResult~success(.nil, "NO_MESSAGE")
    outboundFailures += 1
    lastResult = .JMSBridgeResult~failure("LOCAL_CLAIM_FAILED", claimed~code || ":" || claimed~detail, claimed)
    return lastResult
  end

  package = claimed~value
  sent = provider~send(package)
  if \sent~ok then do
    ignore = self~abortOutbound(package)
    ignore = queueManager~release(config~localOutboundQueue, package~packageId, package~claimToken, config~principal, "JMS send failed")
    outboundFailures += 1
    lastResult = .JMSBridgeResult~failure("JMS_SEND_FAILED", sent~detail, sent)
    return lastResult
  end

  committed = self~completeOutbound(package)
  if \committed~ok then do
    /* Remote outcome may be ambiguous. Releasing locally gives at-least-once
       semantics; downstreams should use the emitted AlchemyTransferId. */
    ignore = queueManager~release(config~localOutboundQueue, package~packageId, package~claimToken, config~principal, "JMS send completion failed or ambiguous")
    outboundFailures += 1
    lastResult = .JMSBridgeResult~failure("JMS_SEND_COMPLETION_AMBIGUOUS", committed~detail, committed)
    return lastResult
  end

  acked = queueManager~ack(config~localOutboundQueue, package~packageId, package~claimToken, config~principal)
  if \acked~ok then do
    outboundFailures += 1
    lastResult = .JMSBridgeResult~failure("REMOTE_SETTLED_LOCAL_ACK_FAILED", acked~code || ":" || acked~detail, acked)
    return lastResult
  end

  outboundCommitted += 1
  lastResult = .JMSBridgeResult~success(package, "OUTBOUND_SETTLED", committed~code)
  return lastResult

::method acceptInbound private
  expose provider
  use arg delivery
  if provider~hasMethod("ACCEPTINBOUND") then return provider~acceptInbound(delivery)
  return provider~commitInbound(delivery)

::method rejectInbound private
  expose provider
  use arg delivery
  if provider~hasMethod("REJECTINBOUND") then return provider~rejectInbound(delivery)
  return provider~rollbackInbound(delivery)

::method completeOutbound private
  expose provider
  use arg package
  if provider~hasMethod("COMPLETEOUTBOUND") then return provider~completeOutbound(package)
  return provider~commitOutbound(package)

::method abortOutbound private
  expose provider
  use arg package
  if provider~hasMethod("ABORTOUTBOUND") then return provider~abortOutbound(package)
  return provider~rollbackOutbound(package)

::method header private
  use arg headers, name, fallback = ""
  if headers == .nil then return fallback
  v = headers[name]
  if v == .nil then return fallback
  return v

::requires "AlchemyObject.cls"
::requires "ObjectQueueFabric.cls"
