/* Convert a post-intervention observation into a privacy-minimised population
   observation so intervention outcomes can later be compared statistically.
   This bridge records exposure; it never asserts that intervention caused the
   outcome. */
::class BrandInterventionPopulationBridge public
::method toPopulationObservation
  use arg populationObservationId, interventionOutcome, classification, classifierId="UNSPECIFIED", taxonomyVersion="UNSPECIFIED", processVersion="UNSPECIFIED", modelVersion="UNSPECIFIED"
  if interventionOutcome==.nil | \interventionOutcome~sealed then return .BrandInterventionResult~failure("INTERVENTION_OUTCOME_NOT_SEALED")
  o=.BrandJourneyPopulationObservation~new(populationObservationId,interventionOutcome~sourceJourneyPoint,interventionOutcome~observedAt,classification,interventionOutcome~outcomeKind,interventionOutcome~outcomeOccurred,interventionOutcome~outcomeLagSeconds,classifierId,taxonomyVersion,processVersion,modelVersion)
  if interventionOutcome~interventionApplied then o~addExposure("INTERVENTION_"||interventionOutcome~interventionKind)
  else o~addExposure("INTERVENTION_NOT_APPLIED_"||interventionOutcome~interventionKind)
  o~addModifier("INTERVENTION_MEASUREMENT")
  do p over interventionOutcome~evidencePoints
    /* Upstream population object accepts only its existing safe point families;
       intervention-specific points are intentionally not smuggled through. */
    if p~caselessPos("BRAND_JOURNEY:")=1 | p~caselessPos("BRAND_INTERACTION:")=1 | p~caselessPos("INTERACTION_EVENT:")=1 | p~caselessPos("STRUCTURED_UTTERANCE:")=1 then o~addEvidencePoint(p)
  end
  sr=o~seal; if \sr~ok then return .BrandInterventionResult~failure(sr~code,sr~detail)
  return .BrandInterventionResult~success(o)
::requires "BrandIntervention.cls"
