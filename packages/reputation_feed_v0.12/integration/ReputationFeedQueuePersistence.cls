/*
 * Reputation Feed v0.12 Queue Fabric persistence registration.
 *
 * Persistence formats are independently versioned from the Feed API. The
 * factory holds caller-supplied Alchemy context; authority/sealer objects are
 * never serialized into Queue Fabric journals.
 */

::class ReputationFeedQueuePersistentType public
::constant RAW_ENVELOPE "reputation.feed.raw-envelope/1"
::constant CLAIM "reputation.feed.claim/1"
::constant EVENT_HYPOTHESIS "reputation.feed.event-hypothesis/1"
::constant CORRECTION "reputation.feed.correction/1"
::constant WATCH_MATCH "reputation.feed.watch-match/1"
::constant INTERACTION_EVIDENCE "reputation.feed.interaction-evidence/1"
::constant DECISION_TRACE "reputation.feed.decision-trace/1"

::class ReputationFeedQueuePayloadFactory subclass ReputationFeedAlchemyObject public
::attribute payloadKind get

::method init
  expose payloadKind restoreContext
  use arg payloadKindArg, alchemyContextArg = .nil
  self~initDomainAlchemy("ReputationFeedQueuePayloadFactory", alchemyContextArg)
  payloadKind = payloadKindArg~string~upper~strip
  restoreContext = alchemyContextArg

::method newBlank
  expose payloadKind restoreContext
  select
    when payloadKind = "RAW" then return .ReputationRawEnvelope~new("", .nil, .nil, .nil, "TEXT/PLAIN", "", "", "", restoreContext)
    when payloadKind = "CLAIM" then return .ReputationFeedClaim~new("", "", "", "", "", .nil, .nil, "", 0, "ASSERTS", "ACTIVE", "", "", restoreContext)
    when payloadKind = "HYPOTHESIS" then return .ReputationEventHypothesis~new("", "", restoreContext)
    when payloadKind = "CORRECTION" then return .ReputationFeedCorrection~new("", "", "RETRACTION", "", .nil, "", 0, "", restoreContext)
    when payloadKind = "WATCH_MATCH" then return .ReputationWatchMatch~new("", "", .false, 0, .false, 0, 0, 0, restoreContext)
    when payloadKind = "INTERACTION_EVIDENCE" then return .ReputationInteractionEvidencePacket~new("RESTORE", "RESTORE", "RESTORE", "RESTORE", "RESTORE", "", "", "", .nil, .nil, "", "DEIDENTIFIED_ANALYTIC", restoreContext)
    when payloadKind = "DECISION_TRACE" then return .ReputationFeedDecisionTrace~new("RESTORE", .nil, "", "", restoreContext)
    otherwise raise syntax 88.900 array("Unsupported Reputation Feed Queue persistence factory kind " || payloadKind)
  end


::class ReputationFeedQueuePersistenceSupport public
::method registerTypes class
  use arg payloadCodec, alchemyContextArg = .nil
  if payloadCodec == .nil | \payloadCodec~hasMethod("TYPEREGISTRY") then return .false
  registry = payloadCodec~typeRegistry
  ignore = registry~register(.ReputationFeedQueuePersistentType~RAW_ENVELOPE, .ReputationFeedQueuePayloadFactory~new("RAW", alchemyContextArg))
  ignore = registry~register(.ReputationFeedQueuePersistentType~CLAIM, .ReputationFeedQueuePayloadFactory~new("CLAIM", alchemyContextArg))
  ignore = registry~register(.ReputationFeedQueuePersistentType~EVENT_HYPOTHESIS, .ReputationFeedQueuePayloadFactory~new("HYPOTHESIS", alchemyContextArg))
  ignore = registry~register(.ReputationFeedQueuePersistentType~CORRECTION, .ReputationFeedQueuePayloadFactory~new("CORRECTION", alchemyContextArg))
  ignore = registry~register(.ReputationFeedQueuePersistentType~WATCH_MATCH, .ReputationFeedQueuePayloadFactory~new("WATCH_MATCH", alchemyContextArg))
  ignore = registry~register(.ReputationFeedQueuePersistentType~INTERACTION_EVIDENCE, .ReputationFeedQueuePayloadFactory~new("INTERACTION_EVIDENCE", alchemyContextArg))
  ignore = registry~register(.ReputationFeedQueuePersistentType~DECISION_TRACE, .ReputationFeedQueuePayloadFactory~new("DECISION_TRACE", alchemyContextArg))
  return .true

::method newCodec class
  use arg alchemyContextArg = .nil
  codec = .QueueGraphPayloadCodec~new
  ignore = self~registerTypes(codec, alchemyContextArg)
  return codec

::requires "ReputationAcquisition.cls"
::requires "ReputationFeedInteractionEvidence.cls"
::requires "ReputationDecisionAudit.cls"
::requires "ReputationFeed.cls"
::requires "ObjectQueueFabric.cls"
