/*
 * CivicQueueIngress.cls - CivicPort v0.14 Queue Fabric/JMS bridge seam.
 *
 * This is the only CivicPort source file that knows the Java-neutral JMS bridge
 * durable message type.  It never loads the live BSF/provider bridge and therefore
 * contains no Java, JNDI, broker connection, or credential implementation.
 */

::class CivicQueueIngressBuild public
::constant RELEASE "0.14"
::constant QUEUE_FABRIC_VERSION "0.9-dev4"
::constant JMS_QUEUE_BRIDGE_VERSION "0.1-dev7-fb1"


::class CivicQueueBuildResult subclass CivicAlchemyObject public
::attribute ok get
::attribute document get
::attribute errorCode get
::attribute message get

::method success class
  use arg document
  return self~new(.true, document, "", "")

::method failure class
  use arg code, message = ""
  return self~new(.false, .nil, code, message)

::method init
  expose ok document errorCode message
  use arg okArg, documentArg, codeArg, messageArg
  ignore = self~initCivicAlchemy
  ok = okArg
  document = documentArg
  errorCode = codeArg~string
  message = messageArg~string


::class CivicJmsQueueDocumentFactory subclass CivicAlchemyObject public
::method init
  expose digestPort
  use arg digestPortArg = .nil
  ignore = self~initCivicAlchemy
  if digestPortArg == .nil then digestPort = .CivicDigestPort~new
  else digestPort = digestPortArg
  self~registerExternalRequirement("library", "oorexx_jms_queue_bridge", .CivicQueueIngressBuild~JMS_QUEUE_BRIDGE_VERSION, .true)

::method fromPackage
  expose digestPort
  use arg queueName, package, useClassification = ""
  if package == .nil then return .CivicQueueBuildResult~failure("QUEUE_PACKAGE_REQUIRED")
  payload = package~payload
  if payload == .nil | \payload~isA(.JMSBridgeMessage) then -
    return .CivicQueueBuildResult~failure("UNSUPPORTED_QUEUE_PAYLOAD", "Expected JMSBridgeMessage")
  if payload~bodyType \= .JMSBridgeBodyType~TEXT then -
    return .CivicQueueBuildResult~failure("UNSUPPORTED_JMS_BODY_TYPE", payload~bodyType)
  if payload~messageId = "" then return .CivicQueueBuildResult~failure("JMS_MESSAGE_ID_REQUIRED")

  bodyDigest = digestPort~sha512Bytes(payload~body)
  headerBytes = .CivicQueueMapCodec~encode(payload~headers)
  propertyBytes = .CivicQueueMapCodec~encode(payload~properties)
  headerDigest = digestPort~sha512Bytes(headerBytes)
  propertyDigest = digestPort~sha512Bytes(propertyBytes)
  if bodyDigest~left(10) = "HASH_ERROR" | headerDigest~left(10) = "HASH_ERROR" | propertyDigest~left(10) = "HASH_ERROR" then -
    return .CivicQueueBuildResult~failure("QUEUE_EVIDENCE_DIGEST_FAILED")

  sourceIdentity = "JMS:" || c2x(payload~provider) || ":" || c2x(payload~source) || ":" || c2x(payload~messageId)
  document = .CivicQueueDocument~new(sourceIdentity, queueName, package~packageId, payload~messageId, payload~provider, payload~source, -
    payload~bodyType, payload~body, bodyDigest, payload~headers, payload~properties, headerDigest, propertyDigest, payload~receivedAt, -
    .DateTime~new~utcIsoDate, package~createdAt, package~correlationId, package~replyTo, package~priority, useClassification)
  return .CivicQueueBuildResult~success(document)


::class CivicQueueIngestResult subclass CivicAlchemyObject public
::attribute ok get
::attribute code get
::attribute record get
::attribute duplicate get
::attribute packageId get
::attribute message get

::method success class
  use arg code, record = .nil, duplicate = .false, packageId = "", message = ""
  return self~new(.true, code, record, duplicate, packageId, message)

::method failure class
  use arg code, packageId = "", message = ""
  return self~new(.false, code, .nil, .false, packageId, message)

::method init
  expose ok code record duplicate packageId message
  use arg okArg, codeArg, recordArg, duplicateArg, packageIdArg, messageArg
  ignore = self~initCivicAlchemy
  ok = okArg
  code = codeArg~string
  record = recordArg
  duplicate = duplicateArg
  packageId = packageIdArg~string
  message = messageArg~string


::class CivicQueueIngestor subclass CivicAlchemyObject public
::attribute queueName get
::attribute principal get
::attribute useClassification get

::method init
  expose queueManager journal queueName principal useClassification factory
  use arg queueManagerArg, journalArg, queueNameArg, principalArg = "civicport", useClassificationArg = "", factoryArg = .nil
  ignore = self~initCivicAlchemy
  queueManager = queueManagerArg
  journal = journalArg
  queueName = queueNameArg~string
  principal = principalArg~string
  useClassification = useClassificationArg~string~translate
  if factoryArg == .nil then factory = .CivicJmsQueueDocumentFactory~new
  else factory = factoryArg
  if queueManager == .nil then raise syntax 93.900 additional("CivicQueueIngestor requires a Queue Fabric manager")
  if journal == .nil then raise syntax 93.900 additional("CivicQueueIngestor requires a CivicQueueJournal")
  if queueName = "" then raise syntax 93.900 additional("CivicQueueIngestor requires a queue name")
  self~registerExternalRequirement("library", "oorexx_queue_fabric", .CivicQueueIngressBuild~QUEUE_FABRIC_VERSION, .true)
  self~registerExternalRequirement("library", "oorexx_jms_queue_bridge", .CivicQueueIngressBuild~JMS_QUEUE_BRIDGE_VERSION, .true)

::method pumpOne
  expose queueManager journal queueName principal useClassification factory
  claimed = queueManager~claim(queueName, principal)
  if \claimed~ok then do
    if claimed~code = "QUEUE_EMPTY" then return .CivicQueueIngestResult~success("NO_MESSAGE")
    return .CivicQueueIngestResult~failure("QUEUE_CLAIM_FAILED", "", claimed~code || ":" || claimed~detail)
  end
  package = claimed~value
  built = factory~fromPackage(queueName, package, useClassification)
  if \built~ok then do
    rejected = queueManager~nack(queueName, package~packageId, package~claimToken, principal)
    detail = built~errorCode || ":" || built~message
    if \rejected~ok then detail = detail || ";NACK=" || rejected~code || ":" || rejected~detail
    return .CivicQueueIngestResult~failure(built~errorCode, package~packageId, detail)
  end

  signal on syntax name journalFailure
  appended = journal~append(built~document)
  signal off syntax
  if \appended~ok then do
    rejected = queueManager~nack(queueName, package~packageId, package~claimToken, principal)
    detail = appended~errorCode || ":" || appended~message
    if \rejected~ok then detail = detail || ";NACK=" || rejected~code || ":" || rejected~detail
    return .CivicQueueIngestResult~failure(appended~errorCode, package~packageId, detail)
  end

  acked = queueManager~ack(queueName, package~packageId, package~claimToken, principal)
  if \acked~ok then return .CivicQueueIngestResult~failure("QUEUE_ACK_FAILED_AFTER_JOURNAL", package~packageId, acked~code || ":" || acked~detail)
  if appended~duplicate then return .CivicQueueIngestResult~success("DUPLICATE_ACKED", appended~record, .true, package~packageId)
  return .CivicQueueIngestResult~success("JOURNALLED_ACKED", appended~record, .false, package~packageId)

journalFailure:
  signal off syntax
  detail = condition("D")
  released = queueManager~release(queueName, package~packageId, package~claimToken, principal, "Civic queue journal failure")
  if \released~ok then detail = detail || ";RELEASE=" || released~code || ":" || released~detail
  return .CivicQueueIngestResult~failure("QUEUE_JOURNAL_FAILED", package~packageId, detail)

::requires "CivicQueueEvidence.cls"
::requires "JMSQueueBridge.cls"
