/*
 * JMSQueueBridgeBSF.cls - BSF4ooRexx/JMS transport binding v0.1-dev7-fb1.
 *
 * This file is the deliberate Java boundary. It is separately packaged from
 * Queue Fabric and requires BSF4ooRexx plus the chosen JMS provider JARs.
 */

::class JMSBSFProvider public
::attribute connected get
::attribute lastStage get

::method init
  expose config credentials connected context connection session inboundDestination outboundDestination consumer producer lastJavaError lastStage
  use strict arg config, credentials
  connected = .false
  context = .nil
  connection = .nil
  session = .nil
  inboundDestination = .nil
  outboundDestination = .nil
  consumer = .nil
  producer = .nil
  lastJavaError = ""
  lastStage = "INITIALIZED"

::method connect
  expose config credentials connected context connection session inboundDestination outboundDestination consumer producer lastJavaError lastStage
  if connected then return .JMSBridgeResult~success(.nil, "ALREADY_CONNECTED")

  credentialLease = .nil
  signal on syntax name javaFailure
  lastStage = "CREDENTIALS"
  credentialOutcome = self~acquireCredentialLease
  if \credentialOutcome~ok then do
    signal off syntax
    return credentialOutcome
  end
  credentialLease = credentialOutcome~value
  username = credentialLease~username
  password = credentialLease~password
  env = self~jndiEnvironment(username, password)

  lastStage = "JNDI_CONTEXT"
  InitialContext = bsf.importClass("javax.naming.InitialContext")
  context = InitialContext~new(env)
  lastStage = "CONNECTION_FACTORY"
  factory = context~lookup(config~connectionFactory)
  lastStage = "TRANSPORT_POLICY"
  transport = self~applyTransportPolicy(factory)
  transportDetail = transport~detail
  if \transport~ok then do
    signal off syntax
    if context \== .nil then self~safeJavaClose(context)
    context = .nil
    username = ""
    password = ""
    if credentialLease \== .nil then ignore = credentialLease~retire
    return transport
  end
  lastStage = "DATA_CONNECTION"
  if username \= "" | password \= "" then connection = factory~createConnection(username, password)
  else connection = factory~createConnection
  lastStage = "SESSION"
  session = self~createSession(connection)

  if config~inboundDestination \= "" then do
    lastStage = "INBOUND_DESTINATION"
    inboundDestination = context~lookup(config~inboundDestination)
    lastStage = "INBOUND_CONSUMER"
    consumer = session~createConsumer(inboundDestination)
  end
  if config~outboundDestination \= "" then do
    lastStage = "OUTBOUND_DESTINATION"
    outboundDestination = context~lookup(config~outboundDestination)
    lastStage = "OUTBOUND_PRODUCER"
    producer = session~createProducer(outboundDestination)
  end
  lastStage = "CONNECTION_START"
  connection~bsf.invoke("start")
  username = ""
  password = ""
  ignore = credentialLease~retire
  credentialLease = .nil
  connected = .true
  lastStage = "CONNECTED"
  signal off syntax
  return .JMSBridgeResult~success(.nil, "CONNECTED", config~sessionMode || "/" || config~transportMode)

javaFailure:
  signal off syntax
  lastJavaError = self~javaCondition
  if consumer \== .nil then self~safeJavaClose(consumer)
  if producer \== .nil then self~safeJavaClose(producer)
  if session \== .nil then self~safeJavaClose(session)
  if connection \== .nil then self~safeJavaClose(connection)
  if context \== .nil then self~safeJavaClose(context)
  consumer = .nil
  producer = .nil
  session = .nil
  connection = .nil
  context = .nil
  connected = .false
  username = ""
  password = ""
  if credentialLease \== .nil then ignore = credentialLease~retire
  return .JMSBridgeResult~failure("JMS_CONNECT_FAILED_AT_" || lastStage, lastJavaError)

/* Probe establishes the JNDI and JMS data connection and resolves configured
 * destinations, but deliberately creates no consumer/producer and receives no
 * message.  This is the bounded live-readiness operation for deployment tests. */
::method probe
  expose config connected lastJavaError lastStage
  if connected then return .JMSBridgeResult~failure("JMS_PROBE_REQUIRES_DISCONNECTED")

  credentialLease = .nil
  probeContext = .nil
  probeConnection = .nil
  signal on syntax name javaFailure

  credentialOutcome = self~acquireCredentialLease
  if \credentialOutcome~ok then do
    signal off syntax
    return credentialOutcome
  end
  credentialLease = credentialOutcome~value
  username = credentialLease~username
  password = credentialLease~password
  env = self~jndiEnvironment(username, password)

  lastStage = "PROBE_JNDI_CONTEXT"
  InitialContext = bsf.importClass("javax.naming.InitialContext")
  probeContext = InitialContext~new(env)
  lastStage = "PROBE_CONNECTION_FACTORY"
  factory = probeContext~lookup(config~connectionFactory)
  lastStage = "PROBE_TRANSPORT_POLICY"
  transport = self~applyTransportPolicy(factory)
  transportDetail = transport~detail
  if \transport~ok then do
    signal off syntax
    if probeContext \== .nil then self~safeJavaClose(probeContext)
    probeContext = .nil
    username = ""
    password = ""
    if credentialLease \== .nil then ignore = credentialLease~retire
    return transport
  end
  if config~inboundDestination \= "" then ignore = probeContext~lookup(config~inboundDestination)
  if config~outboundDestination \= "" then ignore = probeContext~lookup(config~outboundDestination)
  lastStage = "PROBE_DATA_CONNECTION"
  if username \= "" | password \= "" then probeConnection = factory~createConnection(username, password)
  else probeConnection = factory~createConnection
  lastStage = "PROBE_CONNECTION_START"
  probeConnection~bsf.invoke("start")
  probeConnection~close
  probeConnection = .nil
  probeContext~close
  probeContext = .nil
  username = ""
  password = ""
  ignore = credentialLease~retire
  credentialLease = .nil
  signal off syntax
  return .JMSBridgeResult~success(.nil, "JMS_PROBE_OK", config~transportMode)

javaFailure:
  signal off syntax
  lastJavaError = self~javaCondition
  if probeConnection \== .nil then self~safeJavaClose(probeConnection)
  if probeContext \== .nil then self~safeJavaClose(probeContext)
  username = ""
  password = ""
  if credentialLease \== .nil then ignore = credentialLease~retire
  return .JMSBridgeResult~failure("JMS_PROBE_FAILED_AT_" || lastStage, lastJavaError)

/* Probe the exact inbound activation seam without receiving a message.
 * It creates a session and consumer, starts the connection, then closes all
 * resources. This codifies the FAA/SCDS diagnostic boundary. */
::method probeInboundFlow
  expose config connected lastJavaError lastStage
  if connected then return .JMSBridgeResult~failure("JMS_PROBE_REQUIRES_DISCONNECTED")
  if config~inboundDestination = "" then return .JMSBridgeResult~failure("JMS_INBOUND_DISABLED")

  credentialLease = .nil
  probeContext = .nil
  probeConnection = .nil
  probeSession = .nil
  probeConsumer = .nil
  transportDetail = ""
  signal on syntax name javaFailure

  lastStage = "FLOW_CREDENTIALS"
  credentialOutcome = self~acquireCredentialLease
  if \credentialOutcome~ok then do
    signal off syntax
    return credentialOutcome
  end
  credentialLease = credentialOutcome~value
  username = credentialLease~username
  password = credentialLease~password
  env = self~jndiEnvironment(username, password)

  lastStage = "FLOW_JNDI_CONTEXT"
  InitialContext = bsf.importClass("javax.naming.InitialContext")
  probeContext = InitialContext~new(env)
  lastStage = "FLOW_CONNECTION_FACTORY"
  factory = probeContext~lookup(config~connectionFactory)
  lastStage = "FLOW_TRANSPORT_POLICY"
  transport = self~applyTransportPolicy(factory)
  transportDetail = transport~detail
  if \transport~ok then do
    signal off syntax
    if probeContext \== .nil then self~safeJavaClose(probeContext)
    probeContext = .nil
    username = ""
    password = ""
    if credentialLease \== .nil then ignore = credentialLease~retire
    return transport
  end
  lastStage = "FLOW_DATA_CONNECTION"
  if username \= "" | password \= "" then probeConnection = factory~createConnection(username, password)
  else probeConnection = factory~createConnection
  lastStage = "FLOW_SESSION"
  probeSession = self~createSession(probeConnection)
  lastStage = "FLOW_DESTINATION"
  destination = probeContext~lookup(config~inboundDestination)
  lastStage = "FLOW_CONSUMER"
  probeConsumer = probeSession~createConsumer(destination)
  lastStage = "FLOW_CONNECTION_START"
  probeConnection~bsf.invoke("start")

  self~safeJavaClose(probeConsumer)
  self~safeJavaClose(probeSession)
  self~safeJavaClose(probeConnection)
  self~safeJavaClose(probeContext)
  probeConsumer = .nil
  probeSession = .nil
  probeConnection = .nil
  probeContext = .nil
  username = ""
  password = ""
  ignore = credentialLease~retire
  credentialLease = .nil
  lastStage = "FLOW_READY"
  signal off syntax
  detail = config~sessionMode || "/" || config~transportMode
  if transportDetail \= "" then detail = detail || " | " || transportDetail
  return .JMSBridgeResult~success(.nil, "JMS_INBOUND_FLOW_READY", detail)

javaFailure:
  signal off syntax
  lastJavaError = self~javaCondition
  if probeConsumer \== .nil then self~safeJavaClose(probeConsumer)
  if probeSession \== .nil then self~safeJavaClose(probeSession)
  if probeConnection \== .nil then self~safeJavaClose(probeConnection)
  if probeContext \== .nil then self~safeJavaClose(probeContext)
  username = ""
  password = ""
  if credentialLease \== .nil then ignore = credentialLease~retire
  detail = lastJavaError
  if transportDetail \= "" then detail = transportDetail || " | " || detail
  return .JMSBridgeResult~failure("JMS_FLOW_PROBE_FAILED_AT_" || lastStage, detail)

/* Compare the useful non-transacted activation combinations without receiving
 * a message.  TRANSACTED is intentionally excluded from this matrix; it is a
 * deployment capability, not a prerequisite for the monitoring bridge. */
::method probeInboundCapabilities
  expose config credentials connected
  use arg includeDirect = .false
  if connected then return .JMSBridgeResult~failure("JMS_PROBE_REQUIRES_DISCONNECTED")
  if config~inboundDestination = "" then return .JMSBridgeResult~failure("JMS_INBOUND_DISABLED")

  report = .JMSBridgeFlowCapabilityReport~new
  sessions = .array~of(.JMSBridgeSessionMode~AUTO_ACKNOWLEDGE, .JMSBridgeSessionMode~CLIENT_ACKNOWLEDGE)
  transports = .array~of(.JMSBridgeTransportMode~ADMINISTERED, .JMSBridgeTransportMode~GUARANTEED)
  if includeDirect then transports~append(.JMSBridgeTransportMode~DIRECT)

  do sessionMode over sessions
    do transportMode over transports
      candidateConfig = config~copyWithSessionPolicy(sessionMode, transportMode)
      candidate = .JMSBSFProvider~new(candidateConfig, credentials)
      outcome = candidate~probeInboundFlow
      ignore = report~record(sessionMode, transportMode, outcome)
    end
  end

  return .JMSBridgeResult~success(report, "JMS_FLOW_CAPABILITY_PROBE_COMPLETE", report~classification)

::method close
  expose connected context connection session consumer producer lastJavaError
  if \connected then return .JMSBridgeResult~success(.nil, "ALREADY_CLOSED")
  signal on syntax name javaFailure
  if consumer \== .nil then consumer~close
  if producer \== .nil then producer~close
  if session \== .nil then session~close
  if connection \== .nil then connection~close
  if context \== .nil then context~close
  connected = .false
  consumer = .nil
  producer = .nil
  session = .nil
  connection = .nil
  context = .nil
  signal off syntax
  return .JMSBridgeResult~success(.nil, "CLOSED")
javaFailure:
  signal off syntax
  lastJavaError = self~javaCondition
  connected = .false
  return .JMSBridgeResult~failure("JMS_CLOSE_FAILED", lastJavaError)

::method receive
  expose connected consumer config lastJavaError
  use arg timeoutMs = 1000
  if \connected then return .JMSBridgeResult~failure("JMS_NOT_CONNECTED")
  if consumer == .nil then return .JMSBridgeResult~failure("JMS_INBOUND_DISABLED")
  signal on syntax name javaFailure
  javaMessage = consumer~receive(timeoutMs)
  if javaMessage == .nil then do
    signal off syntax
    return .JMSBridgeResult~success(.nil, "NO_MESSAGE")
  end
  decoded = self~decode(javaMessage)
  if \decoded~ok then do
    signal off syntax
    return decoded
  end
  message = decoded~value
  if message~messageId = "" & config~missingMessageIdPolicy = "REJECT" then do
    signal off syntax
    return .JMSBridgeResult~failure("MISSING_JMS_MESSAGE_ID")
  end
  transferId = "jms:" || config~bridgeId || ":" || message~messageId
  delivery = .JMSBridgeInboundDelivery~new(transferId, message, javaMessage)
  signal off syntax
  return .JMSBridgeResult~success(delivery, "RECEIVED")
javaFailure:
  signal off syntax
  lastJavaError = self~javaCondition
  return .JMSBridgeResult~failure("JMS_RECEIVE_FAILED", lastJavaError)

::method acceptInbound
  expose config session lastJavaError
  use arg delivery
  select
    when config~sessionMode = .JMSBridgeSessionMode~AUTO_ACKNOWLEDGE then return .JMSBridgeResult~success(delivery, "JMS_AUTO_ACK_ALREADY_SETTLED")
    when config~sessionMode = .JMSBridgeSessionMode~CLIENT_ACKNOWLEDGE then do
      signal on syntax name javaFailure
      delivery~providerDelivery~acknowledge
      signal off syntax
      return .JMSBridgeResult~success(delivery, "JMS_CLIENT_ACKNOWLEDGED")
    end
    when config~sessionMode = .JMSBridgeSessionMode~TRANSACTED then do
      signal on syntax name javaFailure
      session~commit
      signal off syntax
      return .JMSBridgeResult~success(delivery, "JMS_TRANSACTION_COMMITTED")
    end
    otherwise return .JMSBridgeResult~failure("JMS_SESSION_MODE_INVALID", config~sessionMode)
  end
javaFailure:
  signal off syntax
  lastJavaError = self~javaCondition
  return .JMSBridgeResult~failure("JMS_INBOUND_SETTLEMENT_FAILED", lastJavaError)

::method rejectInbound
  expose config session lastJavaError
  use arg delivery
  select
    when config~sessionMode = .JMSBridgeSessionMode~AUTO_ACKNOWLEDGE then return .JMSBridgeResult~success(delivery, "JMS_AUTO_ACK_CANNOT_RECOVER")
    when config~sessionMode = .JMSBridgeSessionMode~CLIENT_ACKNOWLEDGE then do
      signal on syntax name javaFailure
      session~recover
      signal off syntax
      return .JMSBridgeResult~success(delivery, "JMS_CLIENT_RECOVER_REQUESTED")
    end
    when config~sessionMode = .JMSBridgeSessionMode~TRANSACTED then do
      signal on syntax name javaFailure
      session~rollback
      signal off syntax
      return .JMSBridgeResult~success(delivery, "JMS_TRANSACTION_ROLLED_BACK")
    end
    otherwise return .JMSBridgeResult~failure("JMS_SESSION_MODE_INVALID", config~sessionMode)
  end
javaFailure:
  signal off syntax
  lastJavaError = self~javaCondition
  return .JMSBridgeResult~failure("JMS_INBOUND_RECOVERY_FAILED", lastJavaError)

/* Compatibility aliases for dev1-dev3 provider contract. */
::method commitInbound
  forward message "ACCEPTINBOUND"

::method rollbackInbound
  forward message "REJECTINBOUND"

::method send
  expose connected producer session lastJavaError config
  use arg package
  if \connected then return .JMSBridgeResult~failure("JMS_NOT_CONNECTED")
  if producer == .nil then return .JMSBridgeResult~failure("JMS_OUTBOUND_DISABLED")
  signal on syntax name javaFailure

  payload = package~payload
  if payload~isA(.JMSBridgeMessage) then bridgeMessage = payload
  else bridgeMessage = .JMSBridgeMessage~new("", "TEXT", payload~string)

  select
    when bridgeMessage~bodyType = .JMSBridgeBodyType~TEXT then javaMessage = session~createTextMessage(bridgeMessage~body~string)
    when bridgeMessage~bodyType = .JMSBridgeBodyType~MAP then do
      if bridgeMessage~body == .nil | \bridgeMessage~body~hasMethod("ALLINDEXES") then do
        signal off syntax
        return .JMSBridgeResult~failure("INVALID_OUTBOUND_MAP_BODY")
      end
      javaMessage = session~createMapMessage
      do mapName over bridgeMessage~body~allIndexes
        javaMessage~setString(mapName~string, bridgeMessage~body[mapName]~string)
      end
    end
    otherwise do
      signal off syntax
      return .JMSBridgeResult~failure("UNSUPPORTED_OUTBOUND_BODY_TYPE", bridgeMessage~bodyType)
    end
  end

  /* Preserve application-owned JMS metadata across the Java-free durable
   * envelope. The bridge's own transfer/queue properties are reserved and
   * written last so an application cannot spoof Queue Fabric settlement
   * identity. FederationBank/IJCIB properties are intentionally strings. */
  if bridgeMessage~properties \== .nil & bridgeMessage~properties~hasMethod("ALLINDEXES") then do
    do propertyName over bridgeMessage~properties~allIndexes
      upperName = propertyName~string~translate
      if upperName \= "ALCHEMYTRANSFERID" & upperName \= "ALCHEMYQUEUE" then
        javaMessage~setStringProperty(propertyName~string, bridgeMessage~properties[propertyName]~string)
    end
  end

  correlationId = package~correlationId
  if correlationId = "" & bridgeMessage~headers \== .nil & bridgeMessage~headers~hasMethod("HASINDEX") then do
    if bridgeMessage~headers~hasIndex("JMSCORRELATIONID") then correlationId = bridgeMessage~headers["JMSCORRELATIONID"]~string
  end
  if correlationId \= "" then javaMessage~setJMSCorrelationID(correlationId)
  if bridgeMessage~headers \== .nil & bridgeMessage~headers~hasMethod("HASINDEX") then do
    if bridgeMessage~headers~hasIndex("JMSTYPE") then do
      if bridgeMessage~headers["JMSTYPE"]~string \= "" then javaMessage~setJMSType(bridgeMessage~headers["JMSTYPE"]~string)
    end
  end

  javaMessage~setStringProperty("AlchemyTransferId", package~packageId)
  javaMessage~setStringProperty("AlchemyQueue", package~currentQueue)

  producer~bsf.invoke("send", javaMessage)
  signal off syntax
  if config~sessionMode = .JMSBridgeSessionMode~TRANSACTED then code = "JMS_SENT_PENDING_COMMIT"
  else code = "JMS_SEND_RETURNED"
  return .JMSBridgeResult~success(javaMessage, code)
javaFailure:
  signal off syntax
  lastJavaError = self~javaCondition
  return .JMSBridgeResult~failure("JMS_SEND_FAILED", lastJavaError)

::method completeOutbound
  expose config session lastJavaError
  use arg package
  if config~sessionMode \= .JMSBridgeSessionMode~TRANSACTED then return .JMSBridgeResult~success(package, "JMS_NONTRANSACTED_SEND_COMPLETE")
  signal on syntax name javaFailure
  session~commit
  signal off syntax
  return .JMSBridgeResult~success(package, "JMS_TRANSACTION_COMMITTED")
javaFailure:
  signal off syntax
  lastJavaError = self~javaCondition
  return .JMSBridgeResult~failure("JMS_OUTBOUND_COMPLETION_FAILED", lastJavaError)

::method abortOutbound
  expose config session lastJavaError
  use arg package
  if config~sessionMode \= .JMSBridgeSessionMode~TRANSACTED then return .JMSBridgeResult~success(package, "JMS_NONTRANSACTED_NO_ROLLBACK")
  signal on syntax name javaFailure
  session~rollback
  signal off syntax
  return .JMSBridgeResult~success(package, "JMS_TRANSACTION_ROLLED_BACK")
javaFailure:
  signal off syntax
  lastJavaError = self~javaCondition
  return .JMSBridgeResult~failure("JMS_OUTBOUND_ABORT_FAILED", lastJavaError)

::method commitOutbound
  forward message "COMPLETEOUTBOUND"

::method rollbackOutbound
  forward message "ABORTOUTBOUND"

::method safeJavaClose private
  use arg javaObject
  if javaObject == .nil then return .true
  signal on syntax name ignored
  javaObject~close
  signal off syntax
  return .true
ignored:
  signal off syntax
  return .false

::method createSession private
  expose config
  use arg connection
  select
    when config~sessionMode = .JMSBridgeSessionMode~AUTO_ACKNOWLEDGE then return connection~createSession(.false, 1)
    when config~sessionMode = .JMSBridgeSessionMode~CLIENT_ACKNOWLEDGE then return connection~createSession(.false, 2)
    when config~sessionMode = .JMSBridgeSessionMode~TRANSACTED then return connection~createSession(.true, 0)
    otherwise raise syntax 88.900 array("Unsupported JMS session mode: " || config~sessionMode)
  end

::method applyTransportPolicy private
  expose config
  use arg factory

  if config~providerKind \= "SOLACE" then do
    if config~transportMode = .JMSBridgeTransportMode~ADMINISTERED then return .JMSBridgeResult~success(.nil, "JMS_TRANSPORT_ADMINISTERED", "provider=" || config~providerKind)
    return .JMSBridgeResult~failure("JMS_TRANSPORT_OVERRIDE_UNSUPPORTED", config~providerKind)
  end

  signal on syntax name javaFailure
  if \factory~bsf.isA("com.solacesystems.jms.SolConnectionFactory") then do
    signal off syntax
    if config~transportMode = .JMSBridgeTransportMode~ADMINISTERED then return .JMSBridgeResult~success(.nil, "JMS_TRANSPORT_ADMINISTERED", "solace_factory_type=unverified")
    return .JMSBridgeResult~failure("JMS_SOLACE_CONNECTION_FACTORY_REQUIRED")
  end

  before = self~javaString(factory~getDirectTransport)
  if config~transportMode = .JMSBridgeTransportMode~DIRECT then factory~setDirectTransport(.true)
  if config~transportMode = .JMSBridgeTransportMode~GUARANTEED then factory~setDirectTransport(.false)
  after = self~javaString(factory~getDirectTransport)
  signal off syntax
  return .JMSBridgeResult~success(.nil, "JMS_TRANSPORT_" || config~transportMode, "solace_direct_before=" || before || " solace_direct_after=" || after)
javaFailure:
  signal off syntax
  return .JMSBridgeResult~failure("JMS_TRANSPORT_OVERRIDE_FAILED", self~javaCondition)

::method acquireCredentialLease private
  expose credentials
  if credentials == .nil then return .JMSBridgeResult~success(.JMSBridgeCredentialLease~new, "ANONYMOUS_CREDENTIALS")
  if credentials~hasMethod("ACQUIRE") then do
    outcome = credentials~acquire
    if outcome == .nil | \outcome~hasMethod("OK") then return .JMSBridgeResult~failure("JMS_CREDENTIAL_SOURCE_INVALID")
    if \outcome~ok then return .JMSBridgeResult~failure("JMS_CREDENTIAL_ACQUIRE_FAILED", outcome~code)
    lease = outcome~value
    if lease == .nil | \lease~hasMethod("USERNAME") | \lease~hasMethod("PASSWORD") | \lease~hasMethod("RETIRE") then return .JMSBridgeResult~failure("JMS_CREDENTIAL_LEASE_INVALID")
    return .JMSBridgeResult~success(lease, "JMS_CREDENTIAL_LEASE_ACQUIRED")
  end
  if \credentials~hasMethod("USERNAME") | \credentials~hasMethod("PASSWORD") then return .JMSBridgeResult~failure("JMS_CREDENTIAL_SOURCE_INVALID")
  return .JMSBridgeResult~success(.JMSBridgeCredentialLease~new(credentials~username, credentials~password), "LEGACY_CREDENTIALS_ACQUIRED")

::method jndiEnvironment private
  expose config
  use strict arg username, password
  Hashtable = bsf.importClass("java.util.Hashtable")
  env = Hashtable~new
  env~put("java.naming.factory.initial", config~initialContextFactory)
  env~put("java.naming.provider.url", config~providerUrl)
  if username \= "" then env~put("java.naming.security.principal", username)
  if password \= "" then env~put("java.naming.security.credentials", password)
  if config~messageVpn \= "" then env~put("Solace_JMS_VPN", config~messageVpn)
  if config~trustStore \= "" then env~put("Solace_JMS_SSL_TrustStore", config~trustStore)
  if config~trustStoreFormat \= "" then env~put("Solace_JMS_SSL_TrustStoreFormat", config~trustStoreFormat)
  return env

::method decode private
  expose config
  use arg javaMessage
  headers = .directory~new
  properties = .directory~new

  headers["JMSMESSAGEID"] = self~javaString(javaMessage~getJMSMessageID)
  headers["JMSTIMESTAMP"] = javaMessage~getJMSTimestamp~string
  headers["JMSCORRELATIONID"] = self~javaString(javaMessage~getJMSCorrelationID)
  headers["JMSREPLYTO"] = self~javaString(javaMessage~getJMSReplyTo)
  headers["JMSDESTINATION"] = self~javaString(javaMessage~getJMSDestination)
  headers["JMSDELIVERYMODE"] = javaMessage~getJMSDeliveryMode~string
  headers["JMSREDELIVERED"] = javaMessage~getJMSRedelivered~string
  headers["JMSTYPE"] = self~javaString(javaMessage~getJMSType)
  headers["JMSEXPIRATION"] = javaMessage~getJMSExpiration~string
  headers["JMSPRIORITY"] = javaMessage~getJMSPriority~string

  names = javaMessage~getPropertyNames
  do while names~hasMoreElements
    name = self~javaString(names~nextElement)
    value = javaMessage~getObjectProperty(name)
    properties[name] = self~javaString(value)
  end

  if javaMessage~bsf.isA("javax.jms.TextMessage") then do
    bodyType = .JMSBridgeBodyType~TEXT
    body = self~javaString(javaMessage~getText)
  end
  else if javaMessage~bsf.isA("javax.jms.MapMessage") then do
    bodyType = .JMSBridgeBodyType~MAP
    body = .directory~new
    mapNames = javaMessage~getMapNames
    do while mapNames~hasMoreElements
      mapName = self~javaString(mapNames~nextElement)
      body[mapName] = self~javaString(javaMessage~getObject(mapName))
    end
  end
  else do
    /* Keep unsupported Java objects out of Queue Fabric persistence. */
    return .JMSBridgeResult~failure("UNSUPPORTED_JMS_MESSAGE_TYPE", self~javaString(javaMessage~getClass~getName))
  end

  message = .JMSBridgeMessage~new(headers["JMSMESSAGEID"], bodyType, body, headers, properties, config~providerKind, config~inboundDestination)
  return .JMSBridgeResult~success(message, "DECODED")

::method javaString private
  use arg value
  if value == .nil then return ""
  if value~class == .String then return value
  signal on syntax name fallback
  return unbox(value)~string
fallback:
  signal off syntax
  return value~toString

::method javaCondition private
  c = condition("O")
  detail = condition("D")
  /* BSF.CLS removes BSF_ERROR_MESSAGE when there is no Java-side detail.
   * Referencing .BSF_ERROR_MESSAGE directly in that state yields the literal
   * symbol name, which used to hide the useful ooRexx condition. */
  if .local~hasIndex("BSF_ERROR_MESSAGE") then do
    bsfDetail = .local["BSF_ERROR_MESSAGE"]~string
    if bsfDetail \= "" then detail = detail || " | " || bsfDetail
  end
  if c \== .nil then do
    if c~hasIndex("DESCRIPTION") then if c["DESCRIPTION"]~string \= "" then detail = detail || " | " || c["DESCRIPTION"]
    if c~hasIndex("MESSAGE") then if c["MESSAGE"]~string \= "" then detail = detail || " | " || c["MESSAGE"]
  end
  return detail

::requires "JMSQueueBridge.cls"
::requires "BSF.CLS"
