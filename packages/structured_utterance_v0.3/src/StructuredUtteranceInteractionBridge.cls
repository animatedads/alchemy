/* Bridge from Structured Utterance v0.3 into Interaction Event v0.2.
 *
 * v0.3 promotes generation-time intent, information-use relationships and
 * derived use findings into native Interaction Event evidence objects.  The
 * existing controlled tags/segment metadata remain for compatibility and
 * cheap routing, but they are no longer the only copy of the pre-flattening
 * evidence.
 */
::class StructuredUtteranceInteractionBridge public
::method toEvent class
  use arg utterance, eventIdArg, accessPointIdArg = "", actorRefArg = .nil, subjectRefArg = .nil
  if utterance == .nil | \utterance~sealed then return .StructuredUtteranceResult~failure("UTTERANCE_NOT_SEALED")
  eventId = eventIdArg~string
  if eventId = "" then return .StructuredUtteranceResult~failure("EVENT_ID_REQUIRED")
  event = .InteractionEvent~new(eventId, "AGENT_UTTERANCE", actorRefArg, utterance~surface, accessPointIdArg, "OUTBOUND", .nil, .nil, subjectRefArg)
  do correlation over utterance~correlations
    event~addCorrelation(correlation)
  end
  event~addTag("STRUCTURED_UTTERANCE")
  do tag over utterance~contextTags; event~addTag("CONTEXT/" || tag); end
  do domain over utterance~brandContext~domains; event~addTag("BRAND_DOMAIN/" || domain); end
  do f over utterance~brandContext~functions; event~addTag("BRAND_FUNCTION/" || f); end
  do opp over utterance~brandContext~opportunities; event~addTag("BRAND_OPPORTUNITY/" || opp); end
  if utterance~hasExplicitSalesProposition then event~addTag("EXPLICIT_SALES_PROPOSITION")
  else event~addTag("NO_EXPLICIT_SALES_PROPOSITION")

  event~addEvidence(.InteractionEvidenceAnchor~new(utterance~utteranceId, "STRUCTURED_UTTERANCE", utterance~pointId, .nil, 100))

  /* Native information-use evidence.  Only controlled ids/tokens cross this
     boundary; raw source/customer wording remains in Structured Utterance. */
  do ue over utterance~informationUses
    segment = utterance~segmentById(ue~segmentId)
    act = utterance~actById(ue~targetActId)
    lineage = utterance~lineageEdgeById(ue~segmentId, ue~lineageEdgeId)
    if segment == .nil | act == .nil | lineage == .nil then iterate
    if \self~interactionTokenCompatible(ue~useEdgeId) then return .StructuredUtteranceResult~failure("INTERACTION_NATIVE_TOKEN_INCOMPATIBLE", "USE_EDGE_ID:" || ue~useEdgeId)
    if \self~interactionTokenCompatible(segment~segmentId) then return .StructuredUtteranceResult~failure("INTERACTION_NATIVE_TOKEN_INCOMPATIBLE", "SEGMENT_ID:" || segment~segmentId)
    if \self~interactionTokenCompatible(lineage~sourceRef, .true) then return .StructuredUtteranceResult~failure("INTERACTION_NATIVE_TOKEN_INCOMPATIBLE", "SOURCE_REF:" || lineage~sourceRef)
    if \self~interactionTokenCompatible(act~actId) then return .StructuredUtteranceResult~failure("INTERACTION_NATIVE_TOKEN_INCOMPATIBLE", "ACT_ID:" || act~actId)
    if \self~interactionTokenCompatible(ue~authorityId, .true) then return .StructuredUtteranceResult~failure("INTERACTION_NATIVE_TOKEN_INCOMPATIBLE", "USE_AUTHORITY_ID:" || ue~authorityId)
    effective = .StructuredUtteranceAnalyzer~effectiveUse(act~kind, ue~relationRole)
    nativeUse = .InteractionInformationUseEvidence~new(ue~useEdgeId, segment~segmentId, lineage~sourceRef, lineage~lineageKind, lineage~sourcePrivacyClass, act~actId, act~kind, ue~relationRole, ue~declaredUse, effective, ue~authorityKind, ue~authorityId, min(ue~confidence, lineage~confidence))
    event~addInformationUse(nativeUse)
  end

  do intent over utterance~generationIntents
    if \self~interactionTokenCompatible(intent~intentId) then return .StructuredUtteranceResult~failure("INTERACTION_NATIVE_TOKEN_INCOMPATIBLE", "INTENT_ID:" || intent~intentId)
    if \self~interactionTokenCompatible(intent~targetActId) then return .StructuredUtteranceResult~failure("INTERACTION_NATIVE_TOKEN_INCOMPATIBLE", "INTENT_ACT_ID:" || intent~targetActId)
    if \self~interactionTokenCompatible(intent~authorityId, .true) then return .StructuredUtteranceResult~failure("INTERACTION_NATIVE_TOKEN_INCOMPATIBLE", "INTENT_AUTHORITY_ID:" || intent~authorityId)
    event~addTag("STRUCTURED_INTENT/" || intent~intendedAct)
    event~addEvidence(.InteractionEvidenceAnchor~new(intent~intentId, "STRUCTURED_GENERATION_INTENT", utterance~pointId || "/INTENT/" || intent~intentId, .nil, intent~confidence))
    nativeIntent = .InteractionGenerationIntentEvidence~new(intent~intentId, intent~targetActId, intent~intendedAct, intent~intendedRegister, intent~intendedOutcome, intent~authorityKind, intent~authorityId, "", intent~confidence)
    do useId over intent~informationUseIds; nativeIntent~addInformationUseRef(useId); end
    event~addGenerationIntent(nativeIntent)
  end

  do finding over utterance~analysisFindings
    event~addTag("STRUCTURED_FINDING/" || finding~code)
    event~addEvidence(.InteractionEvidenceAnchor~new(finding~findingId, "STRUCTURED_USE_FINDING", finding~pointId, .nil, finding~confidence))
    nativeFinding = .InteractionDerivedFinding~new(finding~findingId, finding~code, "STRUCTURED_UTTERANCE", "STRUCTURED_UTTERANCE_ANALYZER", finding~confidence)
    /* A finding can be reconstructed from the use edge(s); retain controlled
       ids only and do not copy the sensitive source wording. */
    do ue over utterance~informationUses
      if ue~segmentId = finding~segmentId & ue~targetActId = finding~actId then nativeFinding~addEvidenceRef(ue~useEdgeId)
    end
    event~addDerivedFinding(nativeFinding)
  end

  do segment over utterance~segments
    meta = .table~new
    meta["STRUCTURED_UTTERANCE_ID"] = utterance~utteranceId
    meta["PRIMARY_PURPOSE"] = segment~primaryPurpose
    meta["DATA_ROLE"] = segment~dataRole
    roleText = ""
    do role over segment~roles
      if roleText <> "" then roleText ||= ","
      roleText ||= role
    end
    meta["ROLES"] = roleText
    lineageText = ""
    do edge over segment~lineage
      if lineageText <> "" then lineageText ||= ","
      lineageText ||= edge~lineageKind || "@" || edge~sourceRef
    end
    meta["LINEAGE"] = lineageText
    useText = ""
    do ue over utterance~informationUses
      if ue~segmentId = segment~segmentId then do
        act = utterance~actById(ue~targetActId)
        effective = "UNKNOWN"
        if act \== .nil then effective = .StructuredUtteranceAnalyzer~effectiveUse(act~kind, ue~relationRole)
        if useText <> "" then useText ||= ","
        useText ||= ue~useEdgeId || "@" || ue~targetActId || ":" || ue~relationRole || ":DECLARED=" || ue~declaredUse || ":EFFECTIVE=" || effective
      end
    end
    meta["INFORMATION_USES"] = useText
    intentText = ""
    do intent over utterance~generationIntents
      act = utterance~actById(intent~targetActId)
      if act \== .nil then do sid over act~segmentIds
        if sid = segment~segmentId then do
          if intentText <> "" then intentText ||= ","
          intentText ||= intent~intentId || "@" || intent~intendedAct || ":REGISTER=" || intent~intendedRegister
        end
      end
    end
    meta["GENERATION_INTENTS"] = intentText
    ce = .InteractionContentElement~new(eventId || ":" || segment~segmentId, "UTTERANCE_SEGMENT", segment~text, segment~privacyClass, segment~abstractText, segment~retentionClass, .InteractionConstant~ORIGIN_AGENT, utterance~pointId || "/SEGMENT/" || segment~segmentId, "", segment~confidence, meta)
    event~addContent(ce)
  end
  event~seal
  return .StructuredUtteranceResult~success(event)

::method interactionTokenCompatible class private
  use arg value, allowEmpty = .false
  s = value~string~strip
  if s = "" then return allowEmpty
  return .InteractionCanonical~token(s) <> ""
::requires 'StructuredUtterance.cls'
::requires 'InteractionEvent.cls'
