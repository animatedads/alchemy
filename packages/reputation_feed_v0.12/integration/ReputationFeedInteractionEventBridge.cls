/* Reputation Feed v0.12 - Interaction Event v0.3 acquisition bridge.
 * Always uses Interaction Event's DEIDENTIFIED_ANALYTIC projection.
 */
::class ReputationFeedInteractionEventBridge subclass ReputationFeedAlchemyObject public
::method init
  use arg alchemyContextArg = .nil
  self~initDomainAlchemy("ReputationFeedInteractionEventBridge", alchemyContextArg)
  self~registerExternalRequirement("library", "interaction_event", "0.3", .true)
  self~registerMethodContract("EVIDENCEFROMLIBRARY", "Project one captured Interaction Event through DEIDENTIFIED_ANALYTIC and preserve it as Feed evidence", .array~of("PACKET_ID", "SOURCE_ID", "CAPTURE_LIBRARY", "EVENT_ID"), "REPUTATIONINTERACTIONEVIDENCEPACKET", .false)

::method evidenceFromLibrary
  use arg packetIdArg, sourceIdArg, captureLibrary, eventIdArg, observedGeographyArg = "", alchemyContextArg = .nil
  if captureLibrary == .nil then raise syntax 88.900 array("Interaction Event bridge requires capture library")
  event = captureLibrary~event(eventIdArg)
  if event == .nil then raise syntax 88.900 array("Interaction Event bridge event not found")
  if \event~sealed then raise syntax 88.900 array("Interaction Event bridge requires sealed event")
  projectedResult = captureLibrary~projectEvent(event~eventId, .InteractionProjectionPolicy~deidentified)
  if \projectedResult~ok then raise syntax 88.900 array("Interaction Event de-identified projection failed: " || projectedResult~code)
  projected = projectedResult~value
  packet = .ReputationInteractionEvidencePacket~new(packetIdArg, "INTERACTION_EVENT", sourceIdArg, event~eventId, event~pointId, event~surface, event~accessPointId, event~direction, event~occurredAt, event~observedAt, observedGeographyArg, "DEIDENTIFIED_ANALYTIC", alchemyContextArg)

  actor = projected~actorRef
  if actor \== .nil then packet~addContentItem(.ReputationInteractionEvidenceItem~new(event~eventId || ":ACTOR", "ACTOR_REFERENCE", actor~value, actor~sourcePrivacyClass, actor~projectionKind, "INTERACTION_REFERENCE", 100, event~pointId, alchemyContextArg))
  subject = projected~subjectRef
  if subject \== .nil then packet~addContentItem(.ReputationInteractionEvidenceItem~new(event~eventId || ":SUBJECT", "SUBJECT_REFERENCE", subject~value, subject~sourcePrivacyClass, subject~projectionKind, "INTERACTION_REFERENCE", 100, event~pointId, alchemyContextArg))
  do element over projected~content
    item = .ReputationInteractionEvidenceItem~new(element~elementId, element~semanticType, element~value, element~sourcePrivacyClass, element~projectionKind, element~originKind, element~confidence, event~pointId, alchemyContextArg)
    packet~addContentItem(item)
  end

  do assessment over projected~assessments
    ae = .ReputationInteractionAssessmentEvidence~new(assessment~assessmentId, assessment~assessmentType, assessment~value, assessment~assessorKind, assessment~assessorId, assessment~modelId, assessment~confidence, alchemyContextArg)
    dims = assessment~dimensions
    do key over dims; ae~putDimension(key, dims[key]); end
    do detail over assessment~details
      ae~addDetail(.ReputationInteractionEvidenceItem~new(detail~elementId, detail~semanticType, detail~value, detail~sourcePrivacyClass, detail~projectionKind, detail~originKind, detail~confidence, event~pointId, alchemyContextArg))
    end
    packet~addAssessment(ae)
  end

  do tag over projected~tags; packet~addSemanticToken("INTERACTION_TAG/" || tag); end
  do correlation over projected~correlations; packet~addCorrelation(correlation); end
  do anchor over event~evidence
    packet~addSourceEvidenceRef(anchor~sourceKind || ":" || anchor~sourceId || "@" || anchor~locator)
  end
  do link over captureLibrary~linksFrom(event~eventId)
    packet~addRelationship(.ReputationInteractionRelationshipEvidence~new(link~linkId, link~linkKind, "INTERACTION_EVENT:" || link~fromEventId, "INTERACTION_EVENT:" || link~toEventId, link~causalStatus, link~confidence, link~createdBy, alchemyContextArg))
  end
  do link over captureLibrary~linksTo(event~eventId)
    packet~addRelationship(.ReputationInteractionRelationshipEvidence~new(link~linkId, link~linkKind, "INTERACTION_EVENT:" || link~fromEventId, "INTERACTION_EVENT:" || link~toEventId, link~causalStatus, link~confidence, link~createdBy, alchemyContextArg))
  end
  packet~seal
  return packet

::requires 'ReputationFeedInteractionEvidence.cls'
::requires 'InteractionEvent.cls'
