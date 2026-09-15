/* Reputation Feed v0.12 - rich interaction evidence substrate.
 *
 * These classes preserve privacy-projected interaction evidence without
 * granting Feed authority over communication semantics.  An explicit claim
 * specification is required before evidence can become a Feed claim.
 */

::class ReputationInteractionEvidenceItem subclass ReputationFeedAlchemyObject public
::attribute itemId get
::attribute itemKind get
::attribute value get
::attribute sourcePrivacyClass get
::attribute projectionKind get
::attribute originKind get
::attribute confidence get
::attribute sourcePointId get

::method init
  expose itemId itemKind value sourcePrivacyClass projectionKind originKind confidence sourcePointId
  use arg itemIdArg, itemKindArg, valueArg = "", sourcePrivacyClassArg = "", projectionKindArg = "", originKindArg = "", confidenceArg = 100, sourcePointIdArg = "", alchemyContextArg = .nil
  self~initDomainAlchemy("ReputationInteractionEvidenceItem", alchemyContextArg)
  itemId = itemIdArg~string~upper~strip
  itemKind = itemKindArg~string~upper~strip
  value = valueArg~string
  sourcePrivacyClass = sourcePrivacyClassArg~string~upper~strip
  projectionKind = projectionKindArg~string~upper~strip
  originKind = originKindArg~string~upper~strip
  confidence = .ReputationFeedCanonical~clamp(confidenceArg)
  sourcePointId = sourcePointIdArg~string
  if itemId = "" | itemKind = "" then raise syntax 88.900 array("ReputationInteractionEvidenceItem requires id and kind")

::method canonicalText
  expose itemId itemKind value sourcePrivacyClass projectionKind originKind confidence sourcePointId
  text = .ReputationFeedCanonical~field("ITEM", itemId)
  text ||= .ReputationFeedCanonical~field("KIND", itemKind)
  text ||= .ReputationFeedCanonical~field("VALUE", value)
  text ||= .ReputationFeedCanonical~field("SOURCE_PRIVACY", sourcePrivacyClass)
  text ||= .ReputationFeedCanonical~field("PROJECTION", projectionKind)
  text ||= .ReputationFeedCanonical~field("ORIGIN", originKind)
  text ||= .ReputationFeedCanonical~field("CONFIDENCE", confidence)
  text ||= .ReputationFeedCanonical~field("SOURCE_POINT", sourcePointId)
  return text


::class ReputationInteractionAssessmentEvidence subclass ReputationFeedAlchemyObject public
::attribute assessmentId get
::attribute assessmentType get
::attribute value get
::attribute assessorKind get
::attribute assessorId get
::attribute modelId get
::attribute confidence get

::method init
  expose assessmentId assessmentType value assessorKind assessorId modelId confidence dimensions details
  use arg assessmentIdArg, assessmentTypeArg, valueArg = "", assessorKindArg = "", assessorIdArg = "", modelIdArg = "", confidenceArg = 50, alchemyContextArg = .nil
  self~initDomainAlchemy("ReputationInteractionAssessmentEvidence", alchemyContextArg)
  assessmentId = assessmentIdArg~string~upper~strip
  assessmentType = assessmentTypeArg~string~upper~strip
  value = valueArg~string~upper~strip
  assessorKind = assessorKindArg~string~upper~strip
  assessorId = assessorIdArg~string
  modelId = modelIdArg~string
  confidence = .ReputationFeedCanonical~clamp(confidenceArg)
  dimensions = .table~new
  details = .array~new
  if assessmentId = "" | assessmentType = "" then raise syntax 88.900 array("ReputationInteractionAssessmentEvidence requires id and type")

::method putDimension
  expose dimensions
  use arg nameArg, valueArg
  name = nameArg~string~upper~strip
  if name = "" then return .false
  dimensions[name] = valueArg~string
  return .true

::method addDetail
  expose details
  use arg item
  if item == .nil then return .false
  details~append(item)
  return .true

::method dimensions
  expose dimensions
  out = .table~new
  do key over dimensions; out[key] = dimensions[key]; end
  return out

::method details
  expose details
  return .ReputationFeedCanonical~copyArray(details)

::method canonicalText
  expose assessmentId assessmentType value assessorKind assessorId modelId confidence dimensions details
  text = .ReputationFeedCanonical~field("ASSESSMENT", assessmentId)
  text ||= .ReputationFeedCanonical~field("TYPE", assessmentType)
  text ||= .ReputationFeedCanonical~field("VALUE", value)
  text ||= .ReputationFeedCanonical~field("ASSESSOR_KIND", assessorKind)
  text ||= .ReputationFeedCanonical~field("ASSESSOR_ID", assessorId)
  text ||= .ReputationFeedCanonical~field("MODEL_ID", modelId)
  text ||= .ReputationFeedCanonical~field("CONFIDENCE", confidence)
  pairs = .array~new
  do key over dimensions; pairs~append(key || "=" || dimensions[key]~string); end
  text ||= .ReputationFeedCanonical~join("DIMENSION", pairs)
  detailTexts = .array~new
  do detail over details; detailTexts~append(detail~canonicalText); end
  text ||= .ReputationFeedCanonical~join("DETAIL", detailTexts)
  return text


::class ReputationInteractionRelationshipEvidence subclass ReputationFeedAlchemyObject public
::attribute relationshipId get
::attribute relationshipKind get
::attribute fromPointId get
::attribute toPointId get
::attribute causalStatus get
::attribute confidence get
::attribute createdBy get

::method init
  expose relationshipId relationshipKind fromPointId toPointId causalStatus confidence createdBy
  use arg relationshipIdArg, relationshipKindArg, fromPointIdArg = "", toPointIdArg = "", causalStatusArg = "NONE", confidenceArg = 50, createdByArg = "", alchemyContextArg = .nil
  self~initDomainAlchemy("ReputationInteractionRelationshipEvidence", alchemyContextArg)
  relationshipId = relationshipIdArg~string~upper~strip
  relationshipKind = relationshipKindArg~string~upper~strip
  fromPointId = fromPointIdArg~string
  toPointId = toPointIdArg~string
  causalStatus = causalStatusArg~string~upper~strip
  confidence = .ReputationFeedCanonical~clamp(confidenceArg)
  createdBy = createdByArg~string
  if relationshipId = "" | relationshipKind = "" then raise syntax 88.900 array("ReputationInteractionRelationshipEvidence requires id and kind")

::method canonicalText
  expose relationshipId relationshipKind fromPointId toPointId causalStatus confidence createdBy
  text = .ReputationFeedCanonical~field("RELATIONSHIP", relationshipId)
  text ||= .ReputationFeedCanonical~field("KIND", relationshipKind)
  text ||= .ReputationFeedCanonical~field("FROM", fromPointId)
  text ||= .ReputationFeedCanonical~field("TO", toPointId)
  text ||= .ReputationFeedCanonical~field("CAUSAL_STATUS", causalStatus)
  text ||= .ReputationFeedCanonical~field("CONFIDENCE", confidence)
  text ||= .ReputationFeedCanonical~field("CREATED_BY", createdBy)
  return text


::class ReputationInteractionEvidencePacket subclass ReputationFeedAlchemyObject public
::attribute packetId get
::attribute sourceKind get
::attribute sourceId get
::attribute sourceObjectId get
::attribute sourcePointId get
::attribute surface get
::attribute accessPointId get
::attribute direction get
::attribute occurredAt get
::attribute observedAt get
::attribute observedGeographyId get
::attribute privacyProjectionMode get
::attribute sealed get

::method init
  expose packetId sourceKind sourceId sourceObjectId sourcePointId surface accessPointId direction occurredAt observedAt observedGeographyId privacyProjectionMode contentItems assessments relationships semanticTokens correlations sourceEvidenceRefs sealed
  use arg packetIdArg, sourceKindArg, sourceIdArg, sourceObjectIdArg, sourcePointIdArg, surfaceArg = "", accessPointIdArg = "", directionArg = "", occurredAtArg = .nil, observedAtArg = .nil, observedGeographyArg = "", privacyProjectionModeArg = "DEIDENTIFIED_ANALYTIC", alchemyContextArg = .nil
  self~initDomainAlchemy("ReputationInteractionEvidencePacket", alchemyContextArg)
  packetId = packetIdArg~string~upper~strip
  sourceKind = sourceKindArg~string~upper~strip
  sourceId = sourceIdArg~string~upper~strip
  sourceObjectId = sourceObjectIdArg~string
  sourcePointId = sourcePointIdArg~string
  surface = surfaceArg~string~upper~strip
  accessPointId = accessPointIdArg~string
  direction = directionArg~string~upper~strip
  if occurredAtArg == .nil then occurredAt = .DateTime~new; else occurredAt = occurredAtArg
  if observedAtArg == .nil then observedAt = occurredAt; else observedAt = observedAtArg
  observedGeographyId = observedGeographyArg~string~upper~strip
  privacyProjectionMode = privacyProjectionModeArg~string~upper~strip
  contentItems = .array~new
  assessments = .array~new
  relationships = .array~new
  semanticTokens = .array~new
  correlations = .array~new
  sourceEvidenceRefs = .array~new
  sealed = .false
  if packetId = "" | sourceKind = "" | sourceId = "" | sourceObjectId = "" | sourcePointId = "" then raise syntax 88.900 array("ReputationInteractionEvidencePacket requires packet/source/object/point identities")
  if privacyProjectionMode <> "DEIDENTIFIED_ANALYTIC" then raise syntax 88.900 array("Reputation Feed interaction evidence accepts de-identified analytical projections only")

::method addContentItem
  expose contentItems sealed
  use arg item
  if sealed | item == .nil then return .false
  contentItems~append(item)
  return .true

::method addAssessment
  expose assessments sealed
  use arg assessment
  if sealed | assessment == .nil then return .false
  assessments~append(assessment)
  return .true

::method addRelationship
  expose relationships sealed
  use arg relationship
  if sealed | relationship == .nil then return .false
  relationships~append(relationship)
  return .true

::method addSemanticToken
  expose semanticTokens sealed
  use arg valueArg
  if sealed then return .false
  value = valueArg~string~upper~strip
  if value = "" then return .false
  if .ReputationFeedCanonical~containsString(semanticTokens, value) then return .false
  semanticTokens~append(value)
  return .true

::method addCorrelation
  expose correlations sealed
  use arg valueArg
  if sealed then return .false
  value = valueArg~string
  if value = "" then return .false
  if .ReputationFeedCanonical~containsString(correlations, value) then return .false
  correlations~append(value)
  return .true

::method addSourceEvidenceRef
  expose sourceEvidenceRefs sealed
  use arg valueArg
  if sealed then return .false
  value = valueArg~string
  if value = "" then return .false
  if .ReputationFeedCanonical~containsString(sourceEvidenceRefs, value) then return .false
  sourceEvidenceRefs~append(value)
  return .true

::method contentItems
  expose contentItems
  return .ReputationFeedCanonical~copyArray(contentItems)
::method assessments
  expose assessments
  return .ReputationFeedCanonical~copyArray(assessments)
::method relationships
  expose relationships
  return .ReputationFeedCanonical~copyArray(relationships)
::method semanticTokens
  expose semanticTokens
  return .ReputationFeedCanonical~copyArray(semanticTokens)
::method correlations
  expose correlations
  return .ReputationFeedCanonical~copyArray(correlations)
::method sourceEvidenceRefs
  expose sourceEvidenceRefs
  return .ReputationFeedCanonical~copyArray(sourceEvidenceRefs)

::method seal
  expose contentItems sealed
  if contentItems~items = 0 then raise syntax 88.900 array("ReputationInteractionEvidencePacket requires retained privacy-projected content")
  sealed = .true
  return self

::method canonicalText
  expose packetId sourceKind sourceId sourceObjectId sourcePointId surface accessPointId direction occurredAt observedAt observedGeographyId privacyProjectionMode contentItems assessments relationships semanticTokens correlations sourceEvidenceRefs sealed
  if \sealed then raise syntax 93.900 additional("ReputationInteractionEvidencePacket must be sealed before canonicalisation")
  text = .ReputationFeedCanonical~field("PACKET", packetId)
  text ||= .ReputationFeedCanonical~field("SOURCE_KIND", sourceKind)
  text ||= .ReputationFeedCanonical~field("SOURCE_ID", sourceId)
  text ||= .ReputationFeedCanonical~field("SOURCE_OBJECT", sourceObjectId)
  text ||= .ReputationFeedCanonical~field("SOURCE_POINT", sourcePointId)
  text ||= .ReputationFeedCanonical~field("SURFACE", surface)
  text ||= .ReputationFeedCanonical~field("ACCESS_POINT", accessPointId)
  text ||= .ReputationFeedCanonical~field("DIRECTION", direction)
  text ||= .ReputationFeedCanonical~field("OCCURRED", occurredAt)
  text ||= .ReputationFeedCanonical~field("OBSERVED", observedAt)
  text ||= .ReputationFeedCanonical~field("OBSERVED_GEO", observedGeographyId)
  text ||= .ReputationFeedCanonical~field("PRIVACY_PROJECTION", privacyProjectionMode)
  itemTexts = .array~new
  do item over contentItems; itemTexts~append(item~canonicalText); end
  text ||= .ReputationFeedCanonical~join("CONTENT", itemTexts)
  assessmentTexts = .array~new
  do assessment over assessments; assessmentTexts~append(assessment~canonicalText); end
  text ||= .ReputationFeedCanonical~join("ASSESSMENT", assessmentTexts)
  relationshipTexts = .array~new
  do relationship over relationships; relationshipTexts~append(relationship~canonicalText); end
  text ||= .ReputationFeedCanonical~join("RELATIONSHIP", relationshipTexts)
  text ||= .ReputationFeedCanonical~join("SEMANTIC", semanticTokens)
  text ||= .ReputationFeedCanonical~join("CORRELATION", correlations)
  text ||= .ReputationFeedCanonical~join("SOURCE_EVIDENCE", sourceEvidenceRefs)
  return text


::method queuePersistentType
  return "reputation.feed.interaction-evidence/1"

::method queuePersistentState
  expose packetId sourceKind sourceId sourceObjectId sourcePointId surface accessPointId direction occurredAt observedAt observedGeographyId privacyProjectionMode contentItems assessments relationships semanticTokens correlations sourceEvidenceRefs sealed
  if \sealed then raise syntax 88.900 array("Unsealed ReputationInteractionEvidencePacket cannot cross the durable Queue Fabric boundary")
  state = .table~new
  state["packetId"] = packetId
  state["sourceKind"] = sourceKind
  state["sourceId"] = sourceId
  state["sourceObjectId"] = sourceObjectId
  state["sourcePointId"] = sourcePointId
  state["surface"] = surface
  state["accessPointId"] = accessPointId
  state["direction"] = direction
  state["occurredAt"] = .ReputationFeedQueuePersistenceValue~dateText(occurredAt)
  state["observedAt"] = .ReputationFeedQueuePersistenceValue~dateText(observedAt)
  state["observedGeographyId"] = observedGeographyId
  state["privacyProjectionMode"] = privacyProjectionMode
  contentRows = .array~new
  do item over contentItems
    row = .table~new
    row["itemId"] = item~itemId
    row["itemKind"] = item~itemKind
    row["value"] = item~value
    row["sourcePrivacyClass"] = item~sourcePrivacyClass
    row["projectionKind"] = item~projectionKind
    row["originKind"] = item~originKind
    row["confidence"] = item~confidence~string
    row["sourcePointId"] = item~sourcePointId
    contentRows~append(row)
  end
  state["contentItems"] = contentRows
  assessmentRows = .array~new
  do assessment over assessments
    row = .table~new
    row["assessmentId"] = assessment~assessmentId
    row["assessmentType"] = assessment~assessmentType
    row["value"] = assessment~value
    row["assessorKind"] = assessment~assessorKind
    row["assessorId"] = assessment~assessorId
    row["modelId"] = assessment~modelId
    row["confidence"] = assessment~confidence~string
    row["dimensions"] = assessment~dimensions
    detailRows = .array~new
    do detail over assessment~details
      detailRow = .table~new
      detailRow["itemId"] = detail~itemId
      detailRow["itemKind"] = detail~itemKind
      detailRow["value"] = detail~value
      detailRow["sourcePrivacyClass"] = detail~sourcePrivacyClass
      detailRow["projectionKind"] = detail~projectionKind
      detailRow["originKind"] = detail~originKind
      detailRow["confidence"] = detail~confidence~string
      detailRow["sourcePointId"] = detail~sourcePointId
      detailRows~append(detailRow)
    end
    row["details"] = detailRows
    assessmentRows~append(row)
  end
  state["assessments"] = assessmentRows
  relationshipRows = .array~new
  do relationship over relationships
    row = .table~new
    row["relationshipId"] = relationship~relationshipId
    row["relationshipKind"] = relationship~relationshipKind
    row["fromPointId"] = relationship~fromPointId
    row["toPointId"] = relationship~toPointId
    row["causalStatus"] = relationship~causalStatus
    row["confidence"] = relationship~confidence~string
    row["createdBy"] = relationship~createdBy
    relationshipRows~append(row)
  end
  state["relationships"] = relationshipRows
  state["semanticTokens"] = .ReputationFeedCanonical~copyArray(semanticTokens)
  state["correlations"] = .ReputationFeedCanonical~copyArray(correlations)
  state["sourceEvidenceRefs"] = .ReputationFeedCanonical~copyArray(sourceEvidenceRefs)
  return state

::method queueRestoreState
  expose packetId sourceKind sourceId sourceObjectId sourcePointId surface accessPointId direction occurredAt observedAt observedGeographyId privacyProjectionMode contentItems assessments relationships semanticTokens correlations sourceEvidenceRefs sealed
  use arg state
  packetId = state["packetId"]~string
  sourceKind = state["sourceKind"]~string
  sourceId = state["sourceId"]~string
  sourceObjectId = state["sourceObjectId"]~string
  sourcePointId = state["sourcePointId"]~string
  surface = state["surface"]~string
  accessPointId = state["accessPointId"]~string
  direction = state["direction"]~string
  occurredAt = .ReputationFeedQueuePersistenceValue~dateValue(state["occurredAt"])
  observedAt = .ReputationFeedQueuePersistenceValue~dateValue(state["observedAt"])
  observedGeographyId = state["observedGeographyId"]~string
  privacyProjectionMode = state["privacyProjectionMode"]~string
  contentItems = .array~new
  do row over state["contentItems"]
    contentItems~append(.ReputationInteractionEvidenceItem~new(row["itemId"], row["itemKind"], row["value"], row["sourcePrivacyClass"], row["projectionKind"], row["originKind"], row["confidence"], row["sourcePointId"], self~domainAlchemyContext))
  end
  assessments = .array~new
  do row over state["assessments"]
    assessment = .ReputationInteractionAssessmentEvidence~new(row["assessmentId"], row["assessmentType"], row["value"], row["assessorKind"], row["assessorId"], row["modelId"], row["confidence"], self~domainAlchemyContext)
    dims = row["dimensions"]
    do key over dims; assessment~putDimension(key, dims[key]); end
    do detailRow over row["details"]
      assessment~addDetail(.ReputationInteractionEvidenceItem~new(detailRow["itemId"], detailRow["itemKind"], detailRow["value"], detailRow["sourcePrivacyClass"], detailRow["projectionKind"], detailRow["originKind"], detailRow["confidence"], detailRow["sourcePointId"], self~domainAlchemyContext))
    end
    assessments~append(assessment)
  end
  relationships = .array~new
  do row over state["relationships"]
    relationships~append(.ReputationInteractionRelationshipEvidence~new(row["relationshipId"], row["relationshipKind"], row["fromPointId"], row["toPointId"], row["causalStatus"], row["confidence"], row["createdBy"], self~domainAlchemyContext))
  end
  semanticTokens = .ReputationFeedCanonical~copyArray(state["semanticTokens"])
  correlations = .ReputationFeedCanonical~copyArray(state["correlations"])
  sourceEvidenceRefs = .ReputationFeedCanonical~copyArray(state["sourceEvidenceRefs"])
  sealed = .true
  return self


::class ReputationInteractionClaimSpec subclass ReputationFeedAlchemyObject public
::attribute claimId get
::attribute familyId get
::attribute eventType get
::attribute title get
::attribute eventKey get
::attribute confidence get
::attribute stance get
::attribute claimState get
::attribute assertionRootId get
::attribute assertionRelationship get
::attribute assertionDetail get
::attribute sealed get

::method init
  expose claimId familyId eventType title eventKey confidence stance claimState assertionRootId assertionRelationship assertionDetail subjects concepts affectedGeographies sealed
  use arg claimIdArg, familyIdArg, eventTypeArg, assertionRootIdArg, titleArg = "", eventKeyArg = "", confidenceArg = 50, stanceArg = "ASSERTS", claimStateArg = "ACTIVE", assertionRelationshipArg = "DIRECT_INTERACTION_EVIDENCE", assertionDetailArg = "", alchemyContextArg = .nil
  self~initDomainAlchemy("ReputationInteractionClaimSpec", alchemyContextArg)
  claimId = claimIdArg~string~upper~strip
  familyId = familyIdArg~string~upper~strip
  eventType = eventTypeArg~string~upper~strip
  assertionRootId = assertionRootIdArg~string~upper~strip
  title = titleArg~string
  eventKey = eventKeyArg~string~upper~strip
  confidence = .ReputationFeedCanonical~clamp(confidenceArg)
  stance = stanceArg~string~upper~strip
  claimState = claimStateArg~string~upper~strip
  assertionRelationship = assertionRelationshipArg~string~upper~strip
  assertionDetail = assertionDetailArg~string
  subjects = .array~new
  concepts = .array~new
  affectedGeographies = .array~new
  sealed = .false

::method addSubject
  expose subjects sealed
  use arg kindArg, idArg, strengthArg = 100
  if sealed then return .false
  subjects~append(.ReputationFeedSubjectLink~new(kindArg, idArg, strengthArg, self~domainAlchemyContext))
  return .true
::method addConcept
  expose concepts sealed
  use arg valueArg
  if sealed then return .false
  value = valueArg~string~upper~strip
  if value = "" | .ReputationFeedCanonical~containsString(concepts, value) then return .false
  concepts~append(value)
  return .true
::method addAffectedGeography
  expose affectedGeographies sealed
  use arg valueArg
  if sealed then return .false
  value = valueArg~string~upper~strip
  if value = "" | .ReputationFeedCanonical~containsString(affectedGeographies, value) then return .false
  affectedGeographies~append(value)
  return .true
::method subjects
  expose subjects
  return .ReputationFeedCanonical~copyArray(subjects)
::method concepts
  expose concepts
  return .ReputationFeedCanonical~copyArray(concepts)
::method affectedGeographies
  expose affectedGeographies
  return .ReputationFeedCanonical~copyArray(affectedGeographies)
::method seal
  expose claimId familyId eventType assertionRootId sealed
  if claimId = "" | familyId = "" | eventType = "" | assertionRootId = "" then raise syntax 88.900 array("ReputationInteractionClaimSpec requires claimId, familyId, eventType and explicit assertionRootId")
  sealed = .true
  return self
::method canonicalText
  expose claimId familyId eventType title eventKey confidence stance claimState assertionRootId assertionRelationship assertionDetail subjects concepts affectedGeographies sealed
  if \sealed then raise syntax 93.900 additional("ReputationInteractionClaimSpec must be sealed before canonicalisation")
  text = .ReputationFeedCanonical~field("CLAIM", claimId)
  text ||= .ReputationFeedCanonical~field("FAMILY", familyId)
  text ||= .ReputationFeedCanonical~field("EVENT_TYPE", eventType)
  text ||= .ReputationFeedCanonical~field("TITLE", title)
  text ||= .ReputationFeedCanonical~field("EVENT_KEY", eventKey)
  text ||= .ReputationFeedCanonical~field("CONFIDENCE", confidence)
  text ||= .ReputationFeedCanonical~field("STANCE", stance)
  text ||= .ReputationFeedCanonical~field("STATE", claimState)
  text ||= .ReputationFeedCanonical~field("ASSERTION_ROOT", assertionRootId)
  text ||= .ReputationFeedCanonical~field("ASSERTION_RELATIONSHIP", assertionRelationship)
  text ||= .ReputationFeedCanonical~field("ASSERTION_DETAIL", assertionDetail)
  subjectTexts = .array~new
  do subject over subjects; subjectTexts~append(subject~canonicalText); end
  text ||= .ReputationFeedCanonical~join("SUBJECT", subjectTexts)
  text ||= .ReputationFeedCanonical~join("CONCEPT", concepts)
  text ||= .ReputationFeedCanonical~join("AFFECTED_GEO", affectedGeographies)
  return text


::class ReputationFeedInteractionClaimBridge subclass ReputationFeedAlchemyObject public
::method init
  use arg alchemyContextArg = .nil
  self~initDomainAlchemy("ReputationFeedInteractionClaimBridge", alchemyContextArg)
  self~registerMethodContract("CLAIMFROMEVIDENCE", "Create one Feed claim from a sealed interaction packet under an explicit caller-supplied claim specification", .array~of("SPEC", "PACKET"), "REPUTATIONFEEDCLAIM", .false)
::method claimFromEvidence
  use arg spec, packet
  self~alchemyTouch("CLAIM_FROM_INTERACTION_EVIDENCE")
  if spec == .nil | \spec~sealed then raise syntax 88.900 array("Interaction claim bridge requires sealed claim specification")
  if packet == .nil | \packet~sealed then raise syntax 88.900 array("Interaction claim bridge requires sealed evidence packet")
  claim = .ReputationFeedClaim~new(spec~claimId, packet~sourceObjectId, spec~familyId, spec~eventType, spec~title, packet~occurredAt, packet~observedAt, packet~observedGeographyId, spec~confidence, spec~stance, spec~claimState, packet~sourceId, packet~sourcePointId, self~domainAlchemyContext)
  if spec~eventKey <> "" then claim~setEventKey(spec~eventKey)
  claim~addAssertionOrigin(spec~assertionRootId, packet~sourceId, spec~assertionRelationship, packet~packetId, spec~assertionDetail)
  do subject over spec~subjects; claim~addSubject(subject~subjectKind, subject~subjectId, subject~strength); end
  do concept over spec~concepts; claim~addConcept(concept); end
  do geography over spec~affectedGeographies; claim~addAffectedGeography(geography); end
  claim~seal
  return claim

::requires 'ReputationFeed.cls'
