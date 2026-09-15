/*
 * Reputation Feed v0.12 optional Queue Fabric bridge.
 *
 * This bridge publishes sealed Feed evidence objects through a pre-existing
 * QueueTopicFabric. It deliberately does not define topics, queues,
 * subscriptions, ACLs, persistence, or transport. Those remain Queue Fabric
 * wiring authority. Payloads remain ooRexx object graphs.
 */

::class ReputationFeedQueueContract public
::constant TOPIC_NAME "REPUTATION_FEED"
::constant TOPIC_ROOT "reputation/feed"
::constant RAW_PREFIX "raw"
::constant CLAIM_PREFIX "claims"
::constant HYPOTHESIS_PREFIX "hypotheses"
::constant CORRECTION_PREFIX "corrections"
::constant ALERT_PREFIX "alerts"
::constant INTERACTION_PREFIX "interactions"
::constant DECISION_PREFIX "decisions"
::constant HEADER_API "reputation.feed.api"
::constant HEADER_KIND "reputation.feed.kind"
::constant HEADER_CLASS "reputation.feed.object_class"
::constant HEADER_OBJECT_ID "reputation.feed.object_id"
::constant HEADER_BOUNDARY "reputation.feed.authority_boundary"
::constant HEADER_ENCODING "reputation.feed.payload_encoding"


::class ReputationFeedQueueBridge subclass ReputationFeedAlchemyObject public
::attribute topicName get
::attribute principal get

::method init
  expose topicFabric topicName principal
  use arg topicFabricArg, topicNameArg = "REPUTATION_FEED", principalArg = "", alchemyContextArg = .nil
  self~initDomainAlchemy("ReputationFeedQueueBridge", alchemyContextArg)
  topicFabric = topicFabricArg
  topicName = topicNameArg~string~strip
  principal = principalArg~string
  if topicFabric \== .nil then do
    if topicFabric~hasMethod("QUEUEMANAGER") then do
      manager = topicFabric~queueManager
      if manager \== .nil & manager~hasMethod("PAYLOADCODEC") then ignore = .ReputationFeedQueuePersistenceSupport~registerTypes(manager~payloadCodec, alchemyContextArg)
    end
  end
  self~registerExternalRequirement("library", "oorexx_queue_fabric", "0.9", .false)
  self~registerStateVariable("topicName", "PUBLIC", "Pre-existing Queue Fabric topic name used for reputation feed transport")
  self~registerStateVariable("principal", "INTERNAL", "Queue Fabric principal supplied by the caller")
  self~registerMethodContract("PUBLISHRAW", "Publish one sealed raw acquisition envelope without flattening", .array~of("ENVELOPE", "OPTIONS"), "QUEUEOPERATIONRESULT", .false)
  self~registerMethodContract("PUBLISHCLAIM", "Publish one sealed feed claim without promoting it to fact", .array~of("CLAIM", "OPTIONS"), "QUEUEOPERATIONRESULT", .false)
  self~registerMethodContract("PUBLISHHYPOTHESIS", "Publish one sealed event hypothesis explicitly as non-authoritative hypothesis evidence", .array~of("HYPOTHESIS", "OPTIONS"), "QUEUEOPERATIONRESULT", .false)
  self~registerMethodContract("PUBLISHCORRECTION", "Publish one sealed correction/retraction record", .array~of("CORRECTION", "OPTIONS"), "QUEUEOPERATIONRESULT", .false)
  self~registerMethodContract("PUBLISHWATCHMATCH", "Publish one watch-match alert without turning it into a reputational disposition", .array~of("MATCH", "OPTIONS"), "QUEUEOPERATIONRESULT", .false)
  self~registerMethodContract("PUBLISHINTERACTIONEVIDENCE", "Publish one sealed privacy-projected interaction evidence packet without promoting it to a claim or fact", .array~of("PACKET", "OPTIONS"), "QUEUEOPERATIONRESULT", .false)
  self~registerMethodContract("PUBLISHDECISIONTRACE", "Publish one sealed governed decision trace as audit evidence, never as a reputational disposition", .array~of("TRACE", "OPTIONS"), "QUEUEOPERATIONRESULT", .false)

::method validateTopology
  expose topicFabric topicName
  if topicFabric == .nil then return .QueueOperationResult~failure("REPUTATION_FEED_TOPIC_FABRIC_MISSING")
  if \topicFabric~hasMethod("TOPIC") | \topicFabric~hasMethod("PUBLISH") then return .QueueOperationResult~failure("REPUTATION_FEED_TOPIC_FABRIC_INVALID")
  topic = topicFabric~topic(topicName)
  if topic == .nil then return .QueueOperationResult~failure("REPUTATION_FEED_TOPIC_NOT_FOUND", topicName)
  if topic~topicString \= .ReputationFeedQueueContract~TOPIC_ROOT then return .QueueOperationResult~failure("REPUTATION_FEED_TOPIC_CONTRACT_MISMATCH", topic~topicString || " != " || .ReputationFeedQueueContract~TOPIC_ROOT)
  return .QueueOperationResult~success(topic)

::method publishRaw
  use arg envelope, options = .nil
  if envelope == .nil | \envelope~isA(.ReputationRawEnvelope) then return .QueueOperationResult~failure("REPUTATION_FEED_PAYLOAD_INVALID", "raw envelope required")
  if \envelope~sealed then return .QueueOperationResult~failure("REPUTATION_FEED_PAYLOAD_UNSEALED", envelope~envelopeId)
  source = envelope~sourceIdentity
  tail = self~safeSegment(source~sourceKind) || "/" || self~safeSegment(source~sourceId) || "/" || self~safeSegment(envelope~envelopeId)
  return self~publishObject("RAW", .ReputationFeedQueueContract~RAW_PREFIX, tail, envelope, envelope~envelopeId, "RAW_EVIDENCE_ONLY", options)

::method publishClaim
  use arg claim, options = .nil
  if claim == .nil | \claim~isA(.ReputationFeedClaim) then return .QueueOperationResult~failure("REPUTATION_FEED_PAYLOAD_INVALID", "feed claim required")
  if \claim~sealed then return .QueueOperationResult~failure("REPUTATION_FEED_PAYLOAD_UNSEALED", claim~claimId)
  tail = self~safeSegment(claim~sourceId) || "/" || self~safeSegment(claim~claimId)
  return self~publishObject("CLAIM", .ReputationFeedQueueContract~CLAIM_PREFIX, tail, claim, claim~claimId, "CLAIM_NOT_FACT", options)

::method publishHypothesis
  use arg hypothesis, options = .nil
  if hypothesis == .nil | \hypothesis~isA(.ReputationEventHypothesis) then return .QueueOperationResult~failure("REPUTATION_FEED_PAYLOAD_INVALID", "event hypothesis required")
  if \hypothesis~sealed then return .QueueOperationResult~failure("REPUTATION_FEED_PAYLOAD_UNSEALED", hypothesis~hypothesisId)
  tail = self~safeSegment(hypothesis~eventType) || "/" || self~safeSegment(hypothesis~hypothesisId)
  return self~publishObject("HYPOTHESIS", .ReputationFeedQueueContract~HYPOTHESIS_PREFIX, tail, hypothesis, hypothesis~hypothesisId, "HYPOTHESIS_NOT_EVENT", options)

::method publishCorrection
  use arg correction, options = .nil
  if correction == .nil | \correction~isA(.ReputationFeedCorrection) then return .QueueOperationResult~failure("REPUTATION_FEED_PAYLOAD_INVALID", "feed correction required")
  if \correction~sealed then return .QueueOperationResult~failure("REPUTATION_FEED_PAYLOAD_UNSEALED", correction~correctionId)
  tail = self~safeSegment(correction~correctionType) || "/" || self~safeSegment(correction~targetClaimId) || "/" || self~safeSegment(correction~correctionId)
  return self~publishObject("CORRECTION", .ReputationFeedQueueContract~CORRECTION_PREFIX, tail, correction, correction~correctionId, "HISTORY_SUPERSESSION_EVIDENCE", options)

::method publishInteractionEvidence
  use arg packet, options = .nil
  if packet == .nil | \packet~isA(.ReputationInteractionEvidencePacket) then return .QueueOperationResult~failure("REPUTATION_FEED_PAYLOAD_INVALID", "interaction evidence packet required")
  if \packet~sealed then return .QueueOperationResult~failure("REPUTATION_FEED_PAYLOAD_UNSEALED", packet~packetId)
  tail = self~safeSegment(packet~sourceKind) || "/" || self~safeSegment(packet~sourceId) || "/" || self~safeSegment(packet~packetId)
  return self~publishObject("INTERACTION_EVIDENCE", .ReputationFeedQueueContract~INTERACTION_PREFIX, tail, packet, packet~packetId, "PRIVACY_PROJECTED_INTERACTION_EVIDENCE_NOT_DISPOSITION", options)

::method publishWatchMatch
  use arg match, options = .nil
  if match == .nil | \match~isA(.ReputationWatchMatch) then return .QueueOperationResult~failure("REPUTATION_FEED_PAYLOAD_INVALID", "watch match required")
  tail = self~safeSegment(match~watchSetId) || "/" || self~safeSegment(match~hypothesisId)
  identity = match~watchSetId || ":" || match~hypothesisId
  return self~publishObject("ALERT", .ReputationFeedQueueContract~ALERT_PREFIX, tail, match, identity, "WATCH_SIGNAL_NOT_DISPOSITION", options)

::method publishDecisionTrace
  use arg trace, options = .nil
  if trace == .nil | \trace~isA(.ReputationFeedDecisionTrace) then return .QueueOperationResult~failure("REPUTATION_FEED_PAYLOAD_INVALID", "decision trace required")
  if \trace~sealed then return .QueueOperationResult~failure("REPUTATION_FEED_PAYLOAD_UNSEALED", trace~traceId)
  tail = self~safeSegment(trace~policyId) || "/" || self~safeSegment(trace~policyVersion) || "/" || self~safeSegment(trace~traceId)
  return self~publishObject("DECISION_TRACE", .ReputationFeedQueueContract~DECISION_PREFIX, tail, trace, trace~traceId, "GOVERNED_DECISION_AUDIT_NOT_DISPOSITION", options)

::method publishObject private
  expose topicFabric topicName principal
  use arg kind, prefix, tail, payload, objectId, boundary, callerOptions = .nil
  self~alchemyTouch("QUEUE_PUBLISH_" || kind)
  topology = self~validateTopology
  if \topology~ok then return topology

  if callerOptions == .nil then options = .table~new
  else do
    if \callerOptions~hasMethod("COPY") then return .QueueOperationResult~failure("REPUTATION_FEED_OPTIONS_INVALID", "options must support COPY")
    options = callerOptions~copy
  end

  persistentRequested = .false
  if options~hasIndex("persistent") then persistentRequested = self~truth(options["persistent"])
  retainRequested = .false
  if options~hasIndex("retain") then retainRequested = self~truth(options["retain"])
  if persistentRequested | retainRequested then do
    if \payload~hasMethod("QUEUEPERSISTENTTYPE") | \payload~hasMethod("QUEUEPERSISTENTSTATE") | \payload~hasMethod("QUEUERESTORESTATE") then return .QueueOperationResult~failure("REPUTATION_FEED_PERSISTENCE_ADAPTER_REQUIRED", payload~class~id || " has no explicit Queue Fabric restore contract")
    manager = topicFabric~queueManager
    if manager == .nil | \manager~hasMethod("PAYLOADCODEC") then return .QueueOperationResult~failure("REPUTATION_FEED_PERSISTENCE_CODEC_MISSING")
    if \manager~payloadCodec~canEncode(payload) then return .QueueOperationResult~failure("REPUTATION_FEED_PERSISTENCE_ENCODING_FAILED", payload~class~id)
  end

  if options~hasIndex("headers") then do
    callerHeaders = options["headers"]
    if callerHeaders == .nil then headers = .table~new
    else do
      if \callerHeaders~hasMethod("COPY") then return .QueueOperationResult~failure("REPUTATION_FEED_HEADERS_INVALID", "headers must support COPY")
      headers = callerHeaders~copy
    end
  end
  else headers = .table~new

  subtopic = prefix || "/" || tail
  options["subtopic"] = subtopic
  if \options~hasIndex("correlationId") | options["correlationId"] = "" then options["correlationId"] = objectId
  headers[.ReputationFeedQueueContract~HEADER_API] = .ReputationFeedBuild~API_VERSION
  headers[.ReputationFeedQueueContract~HEADER_KIND] = kind
  headers[.ReputationFeedQueueContract~HEADER_CLASS] = payload~class~id
  headers[.ReputationFeedQueueContract~HEADER_OBJECT_ID] = objectId
  headers[.ReputationFeedQueueContract~HEADER_BOUNDARY] = boundary
  headers[.ReputationFeedQueueContract~HEADER_ENCODING] = "OOREXX_OBJECT_GRAPH"
  options["headers"] = headers
  return topicFabric~publish(topicName, payload, options, principal)

::method safeSegment private
  use arg valueArg
  source = valueArg~string~lower~strip
  if source = "" then return "unknown"
  allowed = "abcdefghijklmnopqrstuvwxyz0123456789_.-"
  out = ""
  lastUnderscore = .false
  do i = 1 to source~length
    ch = source~substr(i, 1)
    if allowed~pos(ch) > 0 then do
      out ||= ch
      lastUnderscore = .false
    end
    else if \lastUnderscore then do
      out ||= "_"
      lastUnderscore = .true
    end
  end
  if out = "" then return "unknown"
  return out

::method truth private
  use arg value
  if value == .true then return .true
  if value == .false | value == .nil then return .false
  text = value~string~upper
  return text = "1" | text = "TRUE" | text = "YES" | text = "ON"

::requires "ReputationAcquisition.cls"
::requires "ReputationFeedInteractionEvidence.cls"
::requires "ReputationDecisionAudit.cls"
::requires "ReputationFeed.cls"
::requires "ReputationFeedQueuePersistence.cls"
::requires "ObjectQueueTopics.cls"
