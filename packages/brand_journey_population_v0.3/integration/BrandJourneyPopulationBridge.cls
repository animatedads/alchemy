/*
 * One-way bridge from sealed BrandJourney + BrandJourneyAssessment into a
 * privacy-minimised population observation.  relationshipRef/raw customer data
 * is intentionally never copied.
 */
::class BrandJourneyPopulationBridge public
::method fromJourney class
  use arg observationId, journey, assessment, occurredAt, classification, outcomeKind="", outcomeLagSeconds=0, classifierId="UNSPECIFIED", taxonomyVersion="UNSPECIFIED", processVersion="UNSPECIFIED", modelVersion="UNSPECIFIED"
  if journey==.nil | assessment==.nil then return .BrandJourneyPopulationResult~failure("JOURNEY_ASSESSMENT_REQUIRED")
  if \journey~sealed | \assessment~sealed then return .BrandJourneyPopulationResult~failure("JOURNEY_ASSESSMENT_NOT_SEALED")
  kind=.BrandJourneyPopulationCanonical~token(outcomeKind)
  occurred=.false
  if kind="" then do
    tps=journey~touchpoints
    if tps~items=0 then return .BrandJourneyPopulationResult~failure("JOURNEY_TOUCHPOINT_REQUIRED")
    last=tps[tps~items]
    select
      when last~stateAfter=.BrandJourneyConstant~STATE_ABANDONED then do; kind=.BrandJourneyPopulationConstant~OUTCOME_ABANDONMENT; occurred=.true; end
      when last~stateAfter=.BrandJourneyConstant~STATE_COMMERCIAL_EXIT then do; kind=.BrandJourneyPopulationConstant~OUTCOME_COMMERCIAL_EXIT; occurred=.true; end
      otherwise do; kind=.BrandJourneyPopulationConstant~OUTCOME_RELATIONSHIP_PRESERVED; occurred=assessment~containsFinding(.BrandJourneyConstant~FIND_RELATIONSHIP_PRESERVED); end
    end
  end
  else do
    tps=journey~touchpoints
    if tps~items>0 then do
      last=tps[tps~items]
      if kind=.BrandJourneyPopulationConstant~OUTCOME_ABANDONMENT then occurred=last~stateAfter=.BrandJourneyConstant~STATE_ABANDONED
      else if kind=.BrandJourneyPopulationConstant~OUTCOME_COMMERCIAL_EXIT then occurred=last~stateAfter=.BrandJourneyConstant~STATE_COMMERCIAL_EXIT
      else if kind=.BrandJourneyPopulationConstant~OUTCOME_RELATIONSHIP_PRESERVED then occurred=assessment~containsFinding(.BrandJourneyConstant~FIND_RELATIONSHIP_PRESERVED)
    end
  end
  o=.BrandJourneyPopulationObservation~new(observationId,journey~pointId,occurredAt,classification,kind,occurred,outcomeLagSeconds,classifierId,taxonomyVersion,processVersion,modelVersion)
  do f over assessment~findings
    select
      when f=.BrandJourneyConstant~FIND_CONTEXT_LOSS then o~addExposure(f)
      when f=.BrandJourneyConstant~FIND_REPEAT_BURDEN then o~addExposure(f)
      when f=.BrandJourneyConstant~FIND_UNRESOLVED_CARRY then o~addExposure(f)
      when f=.BrandJourneyConstant~FIND_COMMERCIAL_WHILE_UNRESOLVED then o~addExposure(f)
      when f=.BrandJourneyConstant~FIND_RECOVERY_ACROSS_DOMAIN then o~addModifier(.BrandJourneyPopulationConstant~MOD_RECOVERY_ACROSS_DOMAIN)
      when f=.BrandJourneyConstant~FIND_RELATIONSHIP_PRESERVED then o~addModifier(.BrandJourneyPopulationConstant~MOD_RELATIONSHIP_PRESERVED)
      otherwise nop
    end
  end
  o~addEvidencePoint(journey~pointId)
  o~addEvidencePoint(assessment~pointId)
  do ep over assessment~evidencePoints; o~addEvidencePoint(ep); end
  sr=o~seal
  if \sr~ok then return .BrandJourneyPopulationResult~failure(sr~code,sr~detail)
  return .BrandJourneyPopulationResult~success(o)
::requires "BrandJourneyPopulation.cls"
