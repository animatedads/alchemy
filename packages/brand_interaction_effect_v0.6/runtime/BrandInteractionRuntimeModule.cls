/* Runtime Registry entry point for Brand Interaction Effect v0.6. */
::class BrandInteractionRuntimeModule public
::attribute starts get
::attribute quiesces get
::attribute stops get
::method init
  expose starts quiesces stops
  starts = 0; quiesces = 0; stops = 0
::method runtimeStart
  expose starts
  starts += 1; return .true
::method runtimeQuiesce
  expose quiesces
  quiesces += 1; return .true
::method runtimeStop
  expose stops
  stops += 1; return .true
::method generationLabel
  return "BRAND-INTERACTION-EFFECT-V0.6"
::method apiVersion
  return .BrandInteractionBuild~API_VERSION
::method newEngine
  return .BrandInteractionEngine~new
::method newPolicy
  return .BrandInteractionPolicy~new
::method newEvidenceEngine
  return .BrandEvidenceEngine~new
::method newEvidenceThreshold
  return .BrandEvidenceThreshold~new
::method newStatisticalEvidence
  use arg frame, confidenceLevel = 95
  return .BrandStatisticalEvidence~fromFrame(frame, confidenceLevel)
::method newCohortAccumulator
  use arg accumulatorId, classification, fromAt, toAt, observationDays, outcomeKind, featureDimension, featureClass, classifierId = "UNSPECIFIED", taxonomyVersion = "UNSPECIFIED", outcomeWindowSeconds = 0
  return .BrandEvidenceCohortAccumulator~new(accumulatorId, classification, fromAt, toAt, observationDays, outcomeKind, featureDimension, featureClass, classifierId, taxonomyVersion, outcomeWindowSeconds)
::method newCohortProvenance
  use arg provenanceId, sourceKind, sourceSystem, unitKind, selectionRuleId, samplingMethod, inclusionPolicyId = "UNSPECIFIED", exclusionPolicyId = "UNSPECIFIED", deduplicationMethod = "OPAQUE_UNIT_KEY", dedupKeyKind = "INTERACTION_KEY", featureClassifierId = "UNSPECIFIED", taxonomyVersion = "UNSPECIFIED", outcomeAscertainmentId = "UNSPECIFIED"
  return .BrandEvidenceCohortProvenance~new(provenanceId, sourceKind, sourceSystem, unitKind, selectionRuleId, samplingMethod, inclusionPolicyId, exclusionPolicyId, deduplicationMethod, dedupKeyKind, featureClassifierId, taxonomyVersion, outcomeAscertainmentId)
::requires 'BrandInteractionEffect.cls'
::requires 'BrandEffectEvidence.cls'
