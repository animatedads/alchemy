/* Reputation Feed v0.12 - Structured Utterance v0.3 acquisition bridge.
 * This bridge intentionally remains independent of StructuredUtteranceInteractionBridge.
 * The current API closure (Structured Utterance v0.3 + Interaction Event v0.3) has a
 * compatible native bridge, but Feed consumes each source domain independently so
 * representation lineage and assertion ancestry remain explicit.
 */
::class ReputationFeedStructuredUtteranceBridge subclass ReputationFeedAlchemyObject public
::method init
  use arg alchemyContextArg = .nil
  self~initDomainAlchemy("ReputationFeedStructuredUtteranceBridge", alchemyContextArg)
  self~registerExternalRequirement("library", "structured_utterance", "0.3", .true)
  self~registerMethodContract("EVIDENCEFROMUTTERANCE", "Project one sealed Structured Utterance through DEIDENTIFIED_ANALYTIC and preserve structured evidence", .array~of("PACKET_ID", "SOURCE_ID", "UTTERANCE"), "REPUTATIONINTERACTIONEVIDENCEPACKET", .false)

::method evidenceFromUtterance
  use arg packetIdArg, sourceIdArg, utterance, observedAtArg = .nil, observedGeographyArg = "", alchemyContextArg = .nil
  if utterance == .nil | \utterance~sealed then raise syntax 88.900 array("Structured Utterance bridge requires sealed utterance")
  if observedAtArg == .nil then observedAt = utterance~createdAt; else observedAt = observedAtArg
  packet = .ReputationInteractionEvidencePacket~new(packetIdArg, "STRUCTURED_UTTERANCE", sourceIdArg, utterance~utteranceId, utterance~pointId, utterance~surface, "", "OUTBOUND", utterance~createdAt, observedAt, observedGeographyArg, "DEIDENTIFIED_ANALYTIC", alchemyContextArg)
  policy = .UtteranceProjectionPolicy~deidentified
  do segment over utterance~segments
    projectedText = policy~projectText(segment)
    projection = "RAW"
    if projectedText \= segment~text then projection = "ABSTRACTED_OR_REDACTED"
    item = .ReputationInteractionEvidenceItem~new(segment~segmentId, "UTTERANCE_SEGMENT/" || segment~primaryPurpose, projectedText, segment~privacyClass, projection, "STRUCTURED_UTTERANCE", segment~confidence, utterance~pointId || "/SEGMENT/" || segment~segmentId, alchemyContextArg)
    packet~addContentItem(item)
    packet~addSemanticToken("PURPOSE/" || segment~primaryPurpose)
    packet~addSemanticToken("DATA_ROLE/" || segment~dataRole)
    do role over segment~roles; packet~addSemanticToken("ROLE/" || role); end
    do edge over segment~lineage
      packet~addSemanticToken("LINEAGE_KIND/" || edge~lineageKind)
      packet~addSemanticToken("LINEAGE_PRIVACY/" || edge~sourcePrivacyClass)
    end
  end
  do speechAct over utterance~speechActs; packet~addSemanticToken("SPEECH_ACT/" || speechAct); end
  do tag over utterance~contextTags; packet~addSemanticToken("CONTEXT/" || tag); end
  do domain over utterance~brandContext~domains; packet~addSemanticToken("BRAND_DOMAIN/" || domain); end
  do f over utterance~brandContext~functions; packet~addSemanticToken("BRAND_FUNCTION/" || f); end
  do opp over utterance~brandContext~opportunities; packet~addSemanticToken("BRAND_OPPORTUNITY/" || opp); end
  do act over utterance~acts; packet~addSemanticToken("COMMUNICATIVE_ACT/" || act~kind); end
  do ue over utterance~informationUses
    act = utterance~actById(ue~targetActId)
    if act \== .nil then do
      effective = .StructuredUtteranceAnalyzer~effectiveUse(act~kind, ue~relationRole)
      packet~addSemanticToken("INFORMATION_USE/" || effective)
    end
  end
  do intent over utterance~generationIntents
    packet~addSemanticToken("GENERATION_INTENT/" || intent~intendedAct)
    packet~addSourceEvidenceRef(utterance~pointId || "/INTENT/" || intent~intentId)
  end
  do finding over utterance~analysisFindings
    packet~addSemanticToken("STRUCTURED_FINDING/" || finding~code)
    packet~addSourceEvidenceRef(finding~pointId)
  end
  do correlation over utterance~correlations; packet~addCorrelation(correlation); end
  packet~addSourceEvidenceRef(utterance~pointId)
  packet~seal
  return packet

::requires 'ReputationFeedInteractionEvidence.cls'
::requires 'StructuredUtterance.cls'
