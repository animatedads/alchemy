/* Privacy-minimising bridge from Interaction Event v0.2.
 *
 * v0.4 treats native Interaction Event generation-intent / information-use /
 * derived-finding objects as the authoritative structured evidence surface.
 * Compatibility tags such as STRUCTURED_FINDING/... are deliberately ignored
 * when copied from the source event and are regenerated only from native
 * evidence objects.  A producer therefore cannot manufacture a brand finding
 * merely by attaching a convenient string tag.
 */
::class BrandInteractionEventBridge public
::method fromEvent class
  use arg event, assessments = .nil
  if event == .nil | \event~sealed then return .BrandInteractionResult~failure("EVENT_NOT_SEALED")
  o = .BrandInteractionObservation~new("OBS-" || event~eventId, event~eventId, event~eventKind, event~pointId, event~surface, event~direction, event~occurredAt)

  /* Copy ordinary event tags, but never accept structured finding/intent/use
     assertions merely because a producer placed them in the string tag bag. */
  do tag over event~tags
    if tag~left(19) = "STRUCTURED_FINDING/" then iterate
    if tag~left(18) = "STRUCTURED_INTENT/" then iterate
    if tag~left(25) = "STRUCTURED_EFFECTIVE_USE/" then iterate
    o~addTag(tag)
  end

  /* Native v0.2 evidence is token/scalar-only and carries no raw customer
     wording.  Regenerate controlled bridge tags and evidence points from it. */
  do finding over event~derivedFindings
    o~addTag("STRUCTURED_FINDING/" || finding~code)
    o~addEvidencePoint(finding~pointId)
    do ref over finding~evidenceRefs
      o~addEvidencePoint("INTERACTION_INFORMATION_USE:" || ref)
    end
  end
  do intent over event~generationIntents
    o~addTag("STRUCTURED_INTENT/" || intent~intendedAct)
    o~addEvidencePoint(intent~pointId)
  end
  do useEvidence over event~informationUses
    o~addTag("STRUCTURED_EFFECTIVE_USE/" || useEvidence~effectiveUse)
    o~addEvidencePoint(useEvidence~pointId)
    if useEvidence~sourcePrivacyClass = "CUSTOMER_SENSITIVE" then o~addTag("STRUCTURED_SOURCE_PRIVACY/CUSTOMER_SENSITIVE")
  end

  /* Extract only controlled purpose/role metadata from structured-utterance
     segments.  Raw element values and actor/subject references are ignored. */
  do element over event~content
    /* Transformation does not confer safety.  UNKNOWN privacy is fail-closed
       at this bridge just as it is in Interaction Event projections. */
    if element~semanticType = "UTTERANCE_SEGMENT" & element~privacyClass <> "UNKNOWN" then do
      m = element~metadata
      if m~hasIndex("PRIMARY_PURPOSE") then o~addPurpose(m["PRIMARY_PURPOSE"])
      if m~hasIndex("ROLES") then do
        roleText = m["ROLES"]
        do while roleText <> ""
          parse var roleText one "," roleText
          if one <> "" then o~addPurpose(one)
        end
      end
    end
  end
  if assessments \== .nil then do assessment over assessments
    o~putAssessment(assessment~assessmentType, assessment~value)
    ar=.BrandAssessmentRecord~new(assessment~assessmentId, assessment~assessmentType, assessment~value, assessment~assessorKind, assessment~assessorId, assessment~modelId, assessment~confidence)
    o~addAssessmentRecord(ar)
    dims = assessment~dimensions
    do k over dims
      if datatype(dims[k],"N") then o~putDimension(k,dims[k])
    end
    o~addEvidencePoint("INTERACTION_ASSESSMENT:" || assessment~assessmentId)
  end
  o~addEvidencePoint(event~pointId)
  o~seal
  return .BrandInteractionResult~success(o)

::method episodeFromCorrelation class
  use arg captureLibrary, correlationId, episodeIdArg = ""
  if captureLibrary == .nil then return .BrandInteractionResult~failure("CAPTURE_LIBRARY_REQUIRED")
  events = captureLibrary~eventsForCorrelation(correlationId)
  if events~items = 0 then return .BrandInteractionResult~failure("CORRELATION_EMPTY", correlationId)
  id = episodeIdArg~string; if id = "" then id = correlationId~string
  episode = .BrandInteractionEpisode~new(id)
  do event over events
    assessments = captureLibrary~assessmentsFor(event~eventId)
    result = self~fromEvent(event,assessments)
    if \result~ok then return result
    episode~addObservation(result~value)
    do tag over event~tags
      if tag~left(18) = "BRAND_OPPORTUNITY/" then episode~addOpportunity(tag~substr(19))
    end
  end
  return episode~seal
::requires 'BrandInteractionEffect.cls'
::requires 'InteractionEvent.cls'
