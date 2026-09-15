/*
 * Brand Interaction Effect v0.6 - statistical / temporal / cohort provenance evidence layer.
 *
 * A tone or appropriateness finding is not useful to a reasoning model if it
 * arrives as a naked label.  This file carries the denominator, joint counts,
 * time scope, classifier provenance, thresholds, materiality, supporting and
 * counter evidence, and explicit limits on interpretation.
 */

::class BrandEvidenceConstant public
::constant STATUS_INSUFFICIENT "INSUFFICIENT"
::constant STATUS_MATERIAL_INVESTIGATION "MATERIAL_INVESTIGATION"
::constant STATUS_WEAK "WEAK_SIGNAL"
::constant STATUS_SUPPORTED "SUPPORTED"
::constant STATUS_STRONG "STRONG"
::constant ROLE_CURRENT "CURRENT"
::constant ROLE_PREVIOUS "PREVIOUS"
::constant ROLE_BASELINE "LONG_BASELINE"
::constant CAUSAL_ASSOCIATION_ONLY "ASSOCIATION_ONLY"

::class BrandEvidenceFrame public
::attribute frameId get
::attribute role get
::attribute classification get
::attribute fromAt get
::attribute toAt get
::attribute observationDays get
::attribute populationCount get
::attribute outcomeKind get
::attribute outcomeCount get
::attribute featureDimension get
::attribute featureClass get
::attribute exposedCount get
::attribute exposedOutcomeCount get
::attribute classifierId get
::attribute taxonomyVersion get
::attribute outcomeWindowSeconds get
::attribute materialityScore get
::attribute materialOutcomeCount get
::attribute commercialValueAtRisk get
::attribute cohortProvenance get
::attribute sealed get
::method init
  expose frameId role classification fromAt toAt observationDays populationCount outcomeKind outcomeCount featureDimension featureClass exposedCount exposedOutcomeCount classifierId taxonomyVersion outcomeWindowSeconds materialityScore materialOutcomeCount commercialValueAtRisk supportPoints counterPoints cohortProvenance sealed
  use arg frameIdArg, roleArg, classificationArg, fromAtArg, toAtArg, observationDaysArg, populationCountArg, outcomeKindArg, outcomeCountArg, featureDimensionArg, featureClassArg, exposedCountArg, exposedOutcomeCountArg, classifierIdArg = "UNSPECIFIED", taxonomyVersionArg = "UNSPECIFIED", outcomeWindowSecondsArg = 0
  frameId = frameIdArg~string
  role = .BrandInteractionCanonical~token(roleArg)
  classification = .BrandInteractionCanonical~token(classificationArg)
  fromAt = fromAtArg~string
  toAt = toAtArg~string
  observationDays = observationDaysArg + 0
  populationCount = populationCountArg + 0
  outcomeKind = .BrandInteractionCanonical~token(outcomeKindArg)
  outcomeCount = outcomeCountArg + 0
  featureDimension = .BrandInteractionCanonical~token(featureDimensionArg)
  featureClass = .BrandInteractionCanonical~token(featureClassArg)
  exposedCount = exposedCountArg + 0
  exposedOutcomeCount = exposedOutcomeCountArg + 0
  classifierId = .BrandInteractionCanonical~token(classifierIdArg)
  taxonomyVersion = .BrandInteractionCanonical~token(taxonomyVersionArg)
  outcomeWindowSeconds = outcomeWindowSecondsArg + 0
  materialityScore = 0
  materialOutcomeCount = 0
  commercialValueAtRisk = 0
  supportPoints = .array~new
  counterPoints = .array~new
  cohortProvenance = .nil
  sealed = .false
  if frameId = "" | role = "" | classification = "" | fromAt = "" | toAt = "" | outcomeKind = "" | featureDimension = "" | featureClass = "" then raise syntax 88.991 array("BrandEvidenceFrame requires ids, time scope, classification, outcome and feature")
::method setMateriality
  expose sealed materialityScore materialOutcomeCount commercialValueAtRisk
  use arg scoreArg, materialOutcomeCountArg = 0, commercialValueAtRiskArg = 0
  if sealed then return .false
  materialityScore = .BrandInteractionCanonical~clamp(scoreArg)
  if datatype(materialOutcomeCountArg,"W") & materialOutcomeCountArg >= 0 then materialOutcomeCount = materialOutcomeCountArg
  if datatype(commercialValueAtRiskArg,"N") & commercialValueAtRiskArg >= 0 then commercialValueAtRisk = commercialValueAtRiskArg + 0
  return .true
::method addSupportPoint
  expose supportPoints sealed
  use arg point
  if sealed | point~string = "" then return .false
  if \.BrandInteractionCanonical~contains(supportPoints, point~string) then supportPoints~append(point~string)
  return .true
::method addCounterPoint
  expose counterPoints sealed
  use arg point
  if sealed | point~string = "" then return .false
  if \.BrandInteractionCanonical~contains(counterPoints, point~string) then counterPoints~append(point~string)
  return .true
::method supportPoints
  expose supportPoints
  return .BrandInteractionCanonical~copyArray(supportPoints)
::method counterPoints
  expose counterPoints
  return .BrandInteractionCanonical~copyArray(counterPoints)
::method unexposedCount
  expose populationCount exposedCount
  return populationCount - exposedCount
::method unexposedOutcomeCount
  expose outcomeCount exposedOutcomeCount
  return outcomeCount - exposedOutcomeCount
::method populationOutcomeRate
  expose populationCount outcomeCount
  if populationCount <= 0 then return 0
  return 100 * outcomeCount / populationCount
::method exposedOutcomeRate
  expose exposedCount exposedOutcomeCount
  if exposedCount <= 0 then return 0
  return 100 * exposedOutcomeCount / exposedCount
::method unexposedOutcomeRate
  n = self~unexposedCount
  if n <= 0 then return 0
  return 100 * self~unexposedOutcomeCount / n
::method featurePrevalence
  expose populationCount exposedCount
  if populationCount <= 0 then return 0
  return 100 * exposedCount / populationCount
::method absoluteRiskDifference
  return self~exposedOutcomeRate - self~unexposedOutcomeRate
::method relativeRisk
  base = self~unexposedOutcomeRate
  if base <= 0 then do
    if self~exposedOutcomeRate <= 0 then return 0
    return -1  /* undefined / infinite: consumer must not pretend precision */
  end
  return self~exposedOutcomeRate / base
::method attachCohortProvenance
  expose cohortProvenance sealed
  use arg provenance
  if sealed then return .BrandInteractionResult~failure("EVIDENCE_FRAME_ALREADY_SEALED")
  if provenance == .nil then return .BrandInteractionResult~failure("COHORT_PROVENANCE_REQUIRED")
  if \provenance~sealed then return .BrandInteractionResult~failure("COHORT_PROVENANCE_NOT_SEALED")
  cohortProvenance = provenance
  return .BrandInteractionResult~success(self)
::method seal
  expose observationDays populationCount outcomeCount exposedCount exposedOutcomeCount outcomeWindowSeconds cohortProvenance sealed
  if observationDays <= 0 then return .BrandInteractionResult~failure("EVIDENCE_TIME_SCOPE_REQUIRED")
  if populationCount < 0 | outcomeCount < 0 | exposedCount < 0 | exposedOutcomeCount < 0 then return .BrandInteractionResult~failure("EVIDENCE_NEGATIVE_COUNT")
  if outcomeCount > populationCount then return .BrandInteractionResult~failure("OUTCOME_EXCEEDS_POPULATION")
  if exposedCount > populationCount then return .BrandInteractionResult~failure("EXPOSURE_EXCEEDS_POPULATION")
  if exposedOutcomeCount > exposedCount | exposedOutcomeCount > outcomeCount then return .BrandInteractionResult~failure("JOINT_COUNT_INVALID")
  if self~unexposedOutcomeCount < 0 | self~unexposedOutcomeCount > self~unexposedCount then return .BrandInteractionResult~failure("COMPARISON_COUNT_INVALID")
  if outcomeWindowSeconds < 0 then return .BrandInteractionResult~failure("OUTCOME_WINDOW_INVALID")
  if cohortProvenance \== .nil then do
    if \cohortProvenance~sealed then return .BrandInteractionResult~failure("COHORT_PROVENANCE_NOT_SEALED")
    if cohortProvenance~analyzableCount \= populationCount then return .BrandInteractionResult~failure("COHORT_PROVENANCE_POPULATION_MISMATCH")
  end
  sealed = .true
  return .BrandInteractionResult~success(self)
::method pointId
  expose frameId
  return "BRAND_INTERACTION:EVIDENCE_FRAME:" || frameId
::method canonicalText
  expose frameId role classification fromAt toAt observationDays populationCount outcomeKind outcomeCount featureDimension featureClass exposedCount exposedOutcomeCount classifierId taxonomyVersion outcomeWindowSeconds materialityScore materialOutcomeCount commercialValueAtRisk supportPoints counterPoints cohortProvenance sealed
  if \sealed then raise syntax 93.991 additional("BrandEvidenceFrame must be sealed")
  out = .BrandInteractionCanonical~field("EVIDENCE_FRAME",frameId)
  out ||= .BrandInteractionCanonical~field("ROLE",role)
  out ||= .BrandInteractionCanonical~field("CLASSIFICATION",classification)
  out ||= .BrandInteractionCanonical~field("FROM",fromAt)
  out ||= .BrandInteractionCanonical~field("TO",toAt)
  out ||= .BrandInteractionCanonical~field("OBSERVATION_DAYS",observationDays)
  out ||= .BrandInteractionCanonical~field("POPULATION",populationCount)
  out ||= .BrandInteractionCanonical~field("OUTCOME_KIND",outcomeKind)
  out ||= .BrandInteractionCanonical~field("OUTCOME_COUNT",outcomeCount)
  out ||= .BrandInteractionCanonical~field("FEATURE_DIMENSION",featureDimension)
  out ||= .BrandInteractionCanonical~field("FEATURE_CLASS",featureClass)
  out ||= .BrandInteractionCanonical~field("EXPOSED_COUNT",exposedCount)
  out ||= .BrandInteractionCanonical~field("EXPOSED_OUTCOME_COUNT",exposedOutcomeCount)
  out ||= .BrandInteractionCanonical~field("UNEXPOSED_COUNT",self~unexposedCount)
  out ||= .BrandInteractionCanonical~field("UNEXPOSED_OUTCOME_COUNT",self~unexposedOutcomeCount)
  out ||= .BrandInteractionCanonical~field("POPULATION_OUTCOME_RATE_PCT",self~populationOutcomeRate)
  out ||= .BrandInteractionCanonical~field("FEATURE_PREVALENCE_PCT",self~featurePrevalence)
  out ||= .BrandInteractionCanonical~field("EXPOSED_OUTCOME_RATE_PCT",self~exposedOutcomeRate)
  out ||= .BrandInteractionCanonical~field("UNEXPOSED_OUTCOME_RATE_PCT",self~unexposedOutcomeRate)
  out ||= .BrandInteractionCanonical~field("ABSOLUTE_RISK_DIFFERENCE_PCT",self~absoluteRiskDifference)
  out ||= .BrandInteractionCanonical~field("RELATIVE_RISK",self~relativeRisk)
  out ||= .BrandInteractionCanonical~field("CLASSIFIER_ID",classifierId)
  out ||= .BrandInteractionCanonical~field("TAXONOMY_VERSION",taxonomyVersion)
  out ||= .BrandInteractionCanonical~field("OUTCOME_WINDOW_SECONDS",outcomeWindowSeconds)
  out ||= .BrandInteractionCanonical~field("MATERIALITY_SCORE",materialityScore)
  out ||= .BrandInteractionCanonical~field("MATERIAL_OUTCOME_COUNT",materialOutcomeCount)
  out ||= .BrandInteractionCanonical~field("COMMERCIAL_VALUE_AT_RISK",commercialValueAtRisk)
  if cohortProvenance \== .nil then out ||= cohortProvenance~canonicalText
  out ||= .BrandInteractionCanonical~join("SUPPORT_POINT",supportPoints)
  out ||= .BrandInteractionCanonical~join("COUNTER_POINT",counterPoints)
  return out

/*
 * Cohort provenance is selection evidence, not customer data.  It records how
 * a candidate population became the analyzable 2x2 frame: source, sampling,
 * selection policy, deduplication, missingness and outcome ascertainment.
 * Opaque unit identifiers never travel into this object.
 */
::class BrandEvidenceCohortProvenance public
::attribute provenanceId get
::attribute sourceKind get
::attribute sourceSystem get
::attribute unitKind get
::attribute selectionRuleId get
::attribute samplingMethod get
::attribute inclusionPolicyId get
::attribute exclusionPolicyId get
::attribute deduplicationMethod get
::attribute dedupKeyKind get
::attribute featureClassifierId get
::attribute taxonomyVersion get
::attribute outcomeAscertainmentId get
::attribute sourceCandidateCount get
::attribute selectedCount get
::attribute analyzableCount get
::attribute excludedCount get
::attribute selectionUnknownCount get
::attribute incompleteSelectedCount get
::attribute missingExposureCount get
::attribute missingOutcomeCount get
::attribute duplicateCount get
::attribute sealed get
::method init
  expose provenanceId sourceKind sourceSystem unitKind selectionRuleId samplingMethod inclusionPolicyId exclusionPolicyId deduplicationMethod dedupKeyKind featureClassifierId taxonomyVersion outcomeAscertainmentId sourceCandidateCount selectedCount analyzableCount excludedCount selectionUnknownCount incompleteSelectedCount missingExposureCount missingOutcomeCount duplicateCount exclusionReasonCounts exclusionReasonOrder unknownReasonCounts unknownReasonOrder limitations sealed
  use arg provenanceIdArg, sourceKindArg, sourceSystemArg, unitKindArg, selectionRuleIdArg, samplingMethodArg, inclusionPolicyIdArg="UNSPECIFIED", exclusionPolicyIdArg="UNSPECIFIED", deduplicationMethodArg="OPAQUE_UNIT_KEY", dedupKeyKindArg="INTERACTION_KEY", featureClassifierIdArg="UNSPECIFIED", taxonomyVersionArg="UNSPECIFIED", outcomeAscertainmentIdArg="UNSPECIFIED"
  provenanceId=provenanceIdArg~string
  sourceKind=.BrandInteractionCanonical~token(sourceKindArg)
  sourceSystem=.BrandInteractionCanonical~token(sourceSystemArg)
  unitKind=.BrandInteractionCanonical~token(unitKindArg)
  selectionRuleId=.BrandInteractionCanonical~token(selectionRuleIdArg)
  samplingMethod=.BrandInteractionCanonical~token(samplingMethodArg)
  inclusionPolicyId=.BrandInteractionCanonical~token(inclusionPolicyIdArg)
  exclusionPolicyId=.BrandInteractionCanonical~token(exclusionPolicyIdArg)
  deduplicationMethod=.BrandInteractionCanonical~token(deduplicationMethodArg)
  dedupKeyKind=.BrandInteractionCanonical~token(dedupKeyKindArg)
  featureClassifierId=.BrandInteractionCanonical~token(featureClassifierIdArg)
  taxonomyVersion=.BrandInteractionCanonical~token(taxonomyVersionArg)
  outcomeAscertainmentId=.BrandInteractionCanonical~token(outcomeAscertainmentIdArg)
  if provenanceId="" | sourceKind="" | sourceSystem="" | unitKind="" | selectionRuleId="" | samplingMethod="" | inclusionPolicyId="" | exclusionPolicyId="" | deduplicationMethod="" | dedupKeyKind="" | featureClassifierId="" | taxonomyVersion="" | outcomeAscertainmentId="" then raise syntax 88.996 array("BrandEvidenceCohortProvenance requires controlled selection lineage")
  sourceCandidateCount=0; selectedCount=0; analyzableCount=0; excludedCount=0; selectionUnknownCount=0; incompleteSelectedCount=0; missingExposureCount=0; missingOutcomeCount=0; duplicateCount=0
  exclusionReasonCounts=.table~new; exclusionReasonOrder=.array~new
  unknownReasonCounts=.table~new; unknownReasonOrder=.array~new
  limitations=.array~new; sealed=.false
::method setCounts
  expose sourceCandidateCount selectedCount analyzableCount excludedCount selectionUnknownCount incompleteSelectedCount missingExposureCount missingOutcomeCount duplicateCount sealed
  use arg candidatesArg, selectedArg, analyzableArg, excludedArg, selectionUnknownArg, incompleteArg, missingExposureArg, missingOutcomeArg, duplicateArg
  if sealed then return .false
  sourceCandidateCount=candidatesArg+0; selectedCount=selectedArg+0; analyzableCount=analyzableArg+0; excludedCount=excludedArg+0; selectionUnknownCount=selectionUnknownArg+0; incompleteSelectedCount=incompleteArg+0; missingExposureCount=missingExposureArg+0; missingOutcomeCount=missingOutcomeArg+0; duplicateCount=duplicateArg+0
  return .true
::method addExclusionReason
  expose exclusionReasonCounts exclusionReasonOrder sealed
  use arg reasonArg, countArg=1
  if sealed then return .false
  r=.BrandInteractionCanonical~token(reasonArg); if r="" | \datatype(countArg,"W") | countArg<0 then return .false
  if \exclusionReasonCounts~hasIndex(r) then do; exclusionReasonCounts[r]=0; exclusionReasonOrder~append(r); end
  exclusionReasonCounts[r]+=countArg
  return .true
::method addSelectionUnknownReason
  expose unknownReasonCounts unknownReasonOrder sealed
  use arg reasonArg, countArg=1
  if sealed then return .false
  r=.BrandInteractionCanonical~token(reasonArg); if r="" | \datatype(countArg,"W") | countArg<0 then return .false
  if \unknownReasonCounts~hasIndex(r) then do; unknownReasonCounts[r]=0; unknownReasonOrder~append(r); end
  unknownReasonCounts[r]+=countArg
  return .true
::method addLimitation
  expose limitations sealed
  use arg value
  if sealed then return .false
  t=.BrandInteractionCanonical~token(value); if t="" then return .false
  if \.BrandInteractionCanonical~contains(limitations,t) then limitations~append(t)
  return .true
::method limitations
  expose limitations
  return .BrandInteractionCanonical~copyArray(limitations)
::method analysisCoveragePct
  expose sourceCandidateCount analyzableCount
  if sourceCandidateCount<=0 then return 0
  return 100*analyzableCount/sourceCandidateCount
::method selectedAnalysisCoveragePct
  expose selectedCount analyzableCount
  if selectedCount<=0 then return 0
  return 100*analyzableCount/selectedCount
::method incompleteSelectedPct
  expose selectedCount incompleteSelectedCount
  if selectedCount<=0 then return 0
  return 100*incompleteSelectedCount/selectedCount
::method selectionUnknownPct
  expose sourceCandidateCount selectionUnknownCount
  if sourceCandidateCount<=0 then return 0
  return 100*selectionUnknownCount/sourceCandidateCount
::method selectedPct
  expose sourceCandidateCount selectedCount
  if sourceCandidateCount<=0 then return 0
  return 100*selectedCount/sourceCandidateCount
::method seal
  expose sourceCandidateCount selectedCount analyzableCount excludedCount selectionUnknownCount incompleteSelectedCount missingExposureCount missingOutcomeCount duplicateCount sealed
  vals=.array~of(sourceCandidateCount,selectedCount,analyzableCount,excludedCount,selectionUnknownCount,incompleteSelectedCount,missingExposureCount,missingOutcomeCount,duplicateCount)
  do v over vals
    if \datatype(v,"W") | v<0 then return .BrandInteractionResult~failure("COHORT_PROVENANCE_COUNT_INVALID")
  end
  if sourceCandidateCount \= selectedCount+excludedCount+selectionUnknownCount then return .BrandInteractionResult~failure("COHORT_SELECTION_ACCOUNTING_MISMATCH")
  if analyzableCount>selectedCount then return .BrandInteractionResult~failure("COHORT_ANALYZABLE_EXCEEDS_SELECTED")
  if incompleteSelectedCount \= selectedCount-analyzableCount then return .BrandInteractionResult~failure("COHORT_INCOMPLETE_ACCOUNTING_MISMATCH")
  if missingExposureCount>incompleteSelectedCount | missingOutcomeCount>incompleteSelectedCount then return .BrandInteractionResult~failure("COHORT_MISSINGNESS_ACCOUNTING_INVALID")
  sealed=.true
  return .BrandInteractionResult~success(self)
::method pointId
  expose provenanceId
  return "BRAND_INTERACTION:EVIDENCE_COHORT_PROVENANCE:"||provenanceId
::method canonicalText
  expose provenanceId sourceKind sourceSystem unitKind selectionRuleId samplingMethod inclusionPolicyId exclusionPolicyId deduplicationMethod dedupKeyKind featureClassifierId taxonomyVersion outcomeAscertainmentId sourceCandidateCount selectedCount analyzableCount excludedCount selectionUnknownCount incompleteSelectedCount missingExposureCount missingOutcomeCount duplicateCount exclusionReasonCounts exclusionReasonOrder unknownReasonCounts unknownReasonOrder limitations sealed
  if \sealed then raise syntax 93.996 additional("BrandEvidenceCohortProvenance must be sealed")
  out=.BrandInteractionCanonical~field("COHORT_PROVENANCE",provenanceId)
  out||=.BrandInteractionCanonical~field("SOURCE_KIND",sourceKind)
  out||=.BrandInteractionCanonical~field("SOURCE_SYSTEM",sourceSystem)
  out||=.BrandInteractionCanonical~field("UNIT_KIND",unitKind)
  out||=.BrandInteractionCanonical~field("SELECTION_RULE_ID",selectionRuleId)
  out||=.BrandInteractionCanonical~field("SAMPLING_METHOD",samplingMethod)
  out||=.BrandInteractionCanonical~field("INCLUSION_POLICY_ID",inclusionPolicyId)
  out||=.BrandInteractionCanonical~field("EXCLUSION_POLICY_ID",exclusionPolicyId)
  out||=.BrandInteractionCanonical~field("DEDUPLICATION_METHOD",deduplicationMethod)
  out||=.BrandInteractionCanonical~field("DEDUP_KEY_KIND",dedupKeyKind)
  out||=.BrandInteractionCanonical~field("FEATURE_CLASSIFIER_ID",featureClassifierId)
  out||=.BrandInteractionCanonical~field("COHORT_TAXONOMY_VERSION",taxonomyVersion)
  out||=.BrandInteractionCanonical~field("OUTCOME_ASCERTAINMENT_ID",outcomeAscertainmentId)
  out||=.BrandInteractionCanonical~field("SOURCE_CANDIDATES",sourceCandidateCount)
  out||=.BrandInteractionCanonical~field("SELECTED",selectedCount)
  out||=.BrandInteractionCanonical~field("ANALYZABLE",analyzableCount)
  out||=.BrandInteractionCanonical~field("EXCLUDED",excludedCount)
  out||=.BrandInteractionCanonical~field("SELECTION_UNKNOWN",selectionUnknownCount)
  out||=.BrandInteractionCanonical~field("INCOMPLETE_SELECTED",incompleteSelectedCount)
  out||=.BrandInteractionCanonical~field("MISSING_EXPOSURE",missingExposureCount)
  out||=.BrandInteractionCanonical~field("MISSING_OUTCOME",missingOutcomeCount)
  out||=.BrandInteractionCanonical~field("DUPLICATE_ATTEMPTS",duplicateCount)
  out||=.BrandInteractionCanonical~field("SELECTED_PCT",self~selectedPct)
  out||=.BrandInteractionCanonical~field("ANALYSIS_COVERAGE_PCT",self~analysisCoveragePct)
  out||=.BrandInteractionCanonical~field("SELECTED_ANALYSIS_COVERAGE_PCT",self~selectedAnalysisCoveragePct)
  out||=.BrandInteractionCanonical~field("INCOMPLETE_SELECTED_PCT",self~incompleteSelectedPct)
  out||=.BrandInteractionCanonical~field("SELECTION_UNKNOWN_PCT",self~selectionUnknownPct)
  do r over exclusionReasonOrder; out||=.BrandInteractionCanonical~field("EXCLUSION_REASON",r||":"||exclusionReasonCounts[r]); end
  do r over unknownReasonOrder; out||=.BrandInteractionCanonical~field("SELECTION_UNKNOWN_REASON",r||":"||unknownReasonCounts[r]); end
  out||=.BrandInteractionCanonical~join("COHORT_LIMITATION",limitations)
  return out

::class BrandEvidenceThreshold public
::attribute thresholdId get
::attribute minPopulationCount get
::attribute minExposedCount get
::attribute minOutcomeCount get
::attribute minJointCount get
::attribute minObservationDays get
::attribute minAbsoluteRiskDifference get
::attribute minRelativeRisk get
::attribute minMaterialityScore get
::attribute minConfidenceLevel get
::attribute requireConfidenceExcludesNull get
::attribute requireCohortProvenance get
::attribute minSelectedAnalysisCoveragePct get
::attribute maxIncompleteSelectedPct get
::attribute maxSelectionUnknownPct get
::attribute requireExplicitSelectionRule get
::method init
  expose thresholdId minPopulationCount minExposedCount minOutcomeCount minJointCount minObservationDays minAbsoluteRiskDifference minRelativeRisk minMaterialityScore minConfidenceLevel requireConfidenceExcludesNull requireCohortProvenance minSelectedAnalysisCoveragePct maxIncompleteSelectedPct maxSelectionUnknownPct requireExplicitSelectionRule
  use arg thresholdIdArg = "DEFAULT", minPopulationArg = 1000, minExposedArg = 25, minOutcomeArg = 20, minJointArg = 5, minDaysArg = 14, minAbsRiskDiffArg = 1, minRelativeRiskArg = 1.25, minMaterialityArg = 80, minConfidenceLevelArg = 95, requireConfidenceExcludesNullArg = .true, requireCohortProvenanceArg = .false, minSelectedAnalysisCoveragePctArg = 0, maxIncompleteSelectedPctArg = 100, maxSelectionUnknownPctArg = 100, requireExplicitSelectionRuleArg = .false
  thresholdId = .BrandInteractionCanonical~token(thresholdIdArg)
  minPopulationCount = minPopulationArg + 0
  minExposedCount = minExposedArg + 0
  minOutcomeCount = minOutcomeArg + 0
  minJointCount = minJointArg + 0
  minObservationDays = minDaysArg + 0
  minAbsoluteRiskDifference = minAbsRiskDiffArg + 0
  minRelativeRisk = minRelativeRiskArg + 0
  minMaterialityScore = .BrandInteractionCanonical~clamp(minMaterialityArg)
  minConfidenceLevel = minConfidenceLevelArg + 0
  requireConfidenceExcludesNull = requireConfidenceExcludesNullArg
  requireCohortProvenance = requireCohortProvenanceArg
  minSelectedAnalysisCoveragePct = .BrandInteractionCanonical~clamp(minSelectedAnalysisCoveragePctArg)
  maxIncompleteSelectedPct = .BrandInteractionCanonical~clamp(maxIncompleteSelectedPctArg)
  maxSelectionUnknownPct = .BrandInteractionCanonical~clamp(maxSelectionUnknownPctArg)
  requireExplicitSelectionRule = requireExplicitSelectionRuleArg
::method canonicalText
  expose thresholdId minPopulationCount minExposedCount minOutcomeCount minJointCount minObservationDays minAbsoluteRiskDifference minRelativeRisk minMaterialityScore minConfidenceLevel requireConfidenceExcludesNull requireCohortProvenance minSelectedAnalysisCoveragePct maxIncompleteSelectedPct maxSelectionUnknownPct requireExplicitSelectionRule
  out = .BrandInteractionCanonical~field("THRESHOLD",thresholdId)
  out ||= .BrandInteractionCanonical~field("MIN_POPULATION",minPopulationCount)
  out ||= .BrandInteractionCanonical~field("MIN_EXPOSED",minExposedCount)
  out ||= .BrandInteractionCanonical~field("MIN_OUTCOMES",minOutcomeCount)
  out ||= .BrandInteractionCanonical~field("MIN_JOINT",minJointCount)
  out ||= .BrandInteractionCanonical~field("MIN_OBSERVATION_DAYS",minObservationDays)
  out ||= .BrandInteractionCanonical~field("MIN_ABS_RISK_DIFF_PCT",minAbsoluteRiskDifference)
  out ||= .BrandInteractionCanonical~field("MIN_RELATIVE_RISK",minRelativeRisk)
  out ||= .BrandInteractionCanonical~field("MIN_MATERIALITY",minMaterialityScore)
  out ||= .BrandInteractionCanonical~field("MIN_CONFIDENCE_LEVEL_PCT",minConfidenceLevel)
  out ||= .BrandInteractionCanonical~field("REQUIRE_CONFIDENCE_EXCLUDES_NULL",requireConfidenceExcludesNull)
  out ||= .BrandInteractionCanonical~field("REQUIRE_COHORT_PROVENANCE",requireCohortProvenance)
  out ||= .BrandInteractionCanonical~field("MIN_SELECTED_ANALYSIS_COVERAGE_PCT",minSelectedAnalysisCoveragePct)
  out ||= .BrandInteractionCanonical~field("MAX_INCOMPLETE_SELECTED_PCT",maxIncompleteSelectedPct)
  out ||= .BrandInteractionCanonical~field("MAX_SELECTION_UNKNOWN_PCT",maxSelectionUnknownPct)
  out ||= .BrandInteractionCanonical~field("REQUIRE_EXPLICIT_SELECTION_RULE",requireExplicitSelectionRule)
  return out

/*
 * Approximate association uncertainty for the sealed 2x2 evidence frame.
 * This is deliberately labelled approximate statistical evidence, not causal
 * proof.  Relative-risk bounds use the log method; zero cells use a recorded
 * Haldane-Anscombe 0.5 correction.  Absolute-risk-difference bounds are built
 * from Wilson score intervals for the two risks and are therefore conservative.
 */
::class BrandStatisticalEvidence public
::attribute confidenceLevel get
::attribute method get
::attribute continuityCorrectionApplied get
::attribute exposedOutcomeCount get
::attribute exposedNonOutcomeCount get
::attribute unexposedOutcomeCount get
::attribute unexposedNonOutcomeCount get
::attribute exposedRiskPct get
::attribute unexposedRiskPct get
::attribute relativeRisk get
::attribute relativeRiskLow get
::attribute relativeRiskHigh get
::attribute riskDifferencePct get
::attribute riskDifferenceLowPct get
::attribute riskDifferenceHighPct get
::attribute confidenceExcludesRelativeRiskNull get
::attribute confidenceExcludesRiskDifferenceNull get
::attribute confidenceExcludesNull get
::attribute direction get
::method init
  expose confidenceLevel method continuityCorrectionApplied exposedOutcomeCount exposedNonOutcomeCount unexposedOutcomeCount unexposedNonOutcomeCount exposedRiskPct unexposedRiskPct relativeRisk relativeRiskLow relativeRiskHigh riskDifferencePct riskDifferenceLowPct riskDifferenceHighPct confidenceExcludesRelativeRiskNull confidenceExcludesRiskDifferenceNull confidenceExcludesNull direction
  use arg frame, confidenceLevelArg, z
  confidenceLevel=confidenceLevelArg+0
  method="LOG_RR_PLUS_WILSON_RISK_DIFFERENCE_APPROXIMATION"
  a=frame~exposedOutcomeCount+0
  b=frame~exposedCount-frame~exposedOutcomeCount
  c=frame~unexposedOutcomeCount+0
  d=frame~unexposedCount-frame~unexposedOutcomeCount
  exposedOutcomeCount=a; exposedNonOutcomeCount=b; unexposedOutcomeCount=c; unexposedNonOutcomeCount=d
  n1=a+b; n0=c+d
  if n1>0 then p1=a/n1; else p1=0
  if n0>0 then p0=c/n0; else p0=0
  exposedRiskPct=100*p1; unexposedRiskPct=100*p0
  riskDifferencePct=100*(p1-p0)

  continuityCorrectionApplied=.false
  aa=a; bb=b; cc=c; dd=d
  if aa=0 | bb=0 | cc=0 | dd=0 then do
    continuityCorrectionApplied=.true
    aa=aa+0.5; bb=bb+0.5; cc=cc+0.5; dd=dd+0.5
  end
  nn1=aa+bb; nn0=cc+dd
  cp1=aa/nn1; cp0=cc/nn0
  if cp0<=0 then relativeRisk=0; else relativeRisk=cp1/cp0
  if relativeRisk>0 then do
    se2=(1/aa)-(1/nn1)+(1/cc)-(1/nn0)
    if se2<0 then se2=0
    se=RxCalcSqrt(se2)
    lr=RxCalcLog(relativeRisk)
    relativeRiskLow=RxCalcExp(lr-z*se)
    relativeRiskHigh=RxCalcExp(lr+z*se)
  end
  else do
    relativeRiskLow=0; relativeRiskHigh=0
  end

  w1=self~wilson(p1,n1,z); w0=self~wilson(p0,n0,z)
  riskDifferenceLowPct=100*(w1[1]-w0[2])
  riskDifferenceHighPct=100*(w1[2]-w0[1])
  if riskDifferencePct>0 then direction="INCREASED_OUTCOME"
  else if riskDifferencePct<0 then direction="DECREASED_OUTCOME"
  else direction="NO_DIRECTION"
  confidenceExcludesRelativeRiskNull=.false
  confidenceExcludesRiskDifferenceNull=.false
  if direction="INCREASED_OUTCOME" then do
    confidenceExcludesRelativeRiskNull=relativeRiskLow>1
    confidenceExcludesRiskDifferenceNull=riskDifferenceLowPct>0
  end
  else if direction="DECREASED_OUTCOME" then do
    confidenceExcludesRelativeRiskNull=relativeRiskHigh<1
    confidenceExcludesRiskDifferenceNull=riskDifferenceHighPct<0
  end
  confidenceExcludesNull=confidenceExcludesRelativeRiskNull & confidenceExcludesRiskDifferenceNull
::method wilson private
  use arg p,n,z
  out=.array~new
  if n<=0 then do; out~append(0); out~append(1); return out; end
  z2=z*z
  den=1+z2/n
  center=(p+z2/(2*n))/den
  under=p*(1-p)/n+z2/(4*n*n)
  if under<0 then under=0
  half=(z/den)*RxCalcSqrt(under)
  low=max(0,center-half); high=min(1,center+half)
  out~append(low); out~append(high); return out
::method fromFrame class
  use arg frame, confidenceLevelArg=95
  if frame==.nil | \frame~sealed then return .BrandInteractionResult~failure("STATISTICAL_FRAME_NOT_SEALED")
  if frame~exposedCount<=0 | frame~unexposedCount<=0 then return .BrandInteractionResult~failure("STATISTICAL_COMPARISON_GROUP_REQUIRED")
  z=self~zFor(confidenceLevelArg)
  if z<=0 then return .BrandInteractionResult~failure("UNSUPPORTED_CONFIDENCE_LEVEL",confidenceLevelArg)
  return .BrandInteractionResult~success(self~new(frame,confidenceLevelArg,z))
::method zFor class
  use arg level
  level=level+0
  if level=80 then return 1.2815515655446
  if level=90 then return 1.6448536269515
  if level=95 then return 1.95996398454005
  if level=98 then return 2.32634787404084
  if level=99 then return 2.5758293035489
  return 0
::method canonicalText
  expose confidenceLevel method continuityCorrectionApplied exposedOutcomeCount exposedNonOutcomeCount unexposedOutcomeCount unexposedNonOutcomeCount exposedRiskPct unexposedRiskPct relativeRisk relativeRiskLow relativeRiskHigh riskDifferencePct riskDifferenceLowPct riskDifferenceHighPct confidenceExcludesRelativeRiskNull confidenceExcludesRiskDifferenceNull confidenceExcludesNull direction
  out=.BrandInteractionCanonical~field("STATISTICAL_METHOD",method)
  out||=.BrandInteractionCanonical~field("CONFIDENCE_LEVEL_PCT",confidenceLevel)
  out||=.BrandInteractionCanonical~field("EXPOSED_OUTCOME_A",exposedOutcomeCount)
  out||=.BrandInteractionCanonical~field("EXPOSED_NONOUTCOME_B",exposedNonOutcomeCount)
  out||=.BrandInteractionCanonical~field("UNEXPOSED_OUTCOME_C",unexposedOutcomeCount)
  out||=.BrandInteractionCanonical~field("UNEXPOSED_NONOUTCOME_D",unexposedNonOutcomeCount)
  out||=.BrandInteractionCanonical~field("CONTINUITY_CORRECTION_APPLIED",continuityCorrectionApplied)
  out||=.BrandInteractionCanonical~field("EXPOSED_RISK_PCT",exposedRiskPct)
  out||=.BrandInteractionCanonical~field("UNEXPOSED_RISK_PCT",unexposedRiskPct)
  out||=.BrandInteractionCanonical~field("RELATIVE_RISK_ESTIMATE",relativeRisk)
  out||=.BrandInteractionCanonical~field("RELATIVE_RISK_CI_LOW",relativeRiskLow)
  out||=.BrandInteractionCanonical~field("RELATIVE_RISK_CI_HIGH",relativeRiskHigh)
  out||=.BrandInteractionCanonical~field("RISK_DIFFERENCE_PCT",riskDifferencePct)
  out||=.BrandInteractionCanonical~field("RISK_DIFFERENCE_CI_LOW_PCT",riskDifferenceLowPct)
  out||=.BrandInteractionCanonical~field("RISK_DIFFERENCE_CI_HIGH_PCT",riskDifferenceHighPct)
  out||=.BrandInteractionCanonical~field("ASSOCIATION_DIRECTION",direction)
  out||=.BrandInteractionCanonical~field("RR_CI_EXCLUDES_NULL",confidenceExcludesRelativeRiskNull)
  out||=.BrandInteractionCanonical~field("RD_CI_EXCLUDES_NULL",confidenceExcludesRiskDifferenceNull)
  out||=.BrandInteractionCanonical~field("CONFIDENCE_EXCLUDES_NULL",confidenceExcludesNull)
  return out

::class BrandEvidenceAssessment public
::attribute status get
::attribute thresholdCoveragePct get
::attribute statisticalSufficient get
::attribute materialInvestigation get
::attribute effectGate get
::attribute confidenceGate get
::attribute cohortQualityGate get
::attribute statisticalEvidence get
::attribute causalStatus get
::method init
  expose status thresholdCoveragePct statisticalSufficient materialInvestigation effectGate confidenceGate cohortQualityGate statisticalEvidence causalStatus reasons
  use arg statusArg, coverageArg, statisticalArg, materialArg, effectArg, confidenceArg=.false, statisticalEvidenceArg=.nil, cohortQualityArg=.true
  status = .BrandInteractionCanonical~token(statusArg)
  thresholdCoveragePct = .BrandInteractionCanonical~clamp(coverageArg)
  statisticalSufficient = statisticalArg
  materialInvestigation = materialArg
  effectGate = effectArg
  confidenceGate = confidenceArg
  cohortQualityGate = cohortQualityArg
  statisticalEvidence = statisticalEvidenceArg
  causalStatus = .BrandEvidenceConstant~CAUSAL_ASSOCIATION_ONLY
  reasons = .array~new
::method addReason
  expose reasons
  use arg value
  t=.BrandInteractionCanonical~token(value); if t<>"" & \.BrandInteractionCanonical~contains(reasons,t) then reasons~append(t)
  return self
::method reasons
  expose reasons
  return .BrandInteractionCanonical~copyArray(reasons)
::method canonicalText
  expose status thresholdCoveragePct statisticalSufficient materialInvestigation effectGate confidenceGate cohortQualityGate statisticalEvidence causalStatus reasons
  out=.BrandInteractionCanonical~field("EVIDENCE_STATUS",status)
  out||=.BrandInteractionCanonical~field("THRESHOLD_COVERAGE_PCT",thresholdCoveragePct)
  out||=.BrandInteractionCanonical~field("STATISTICAL_SUFFICIENT",statisticalSufficient)
  out||=.BrandInteractionCanonical~field("MATERIAL_INVESTIGATION",materialInvestigation)
  out||=.BrandInteractionCanonical~field("EFFECT_GATE",effectGate)
  out||=.BrandInteractionCanonical~field("CONFIDENCE_GATE",confidenceGate)
  out||=.BrandInteractionCanonical~field("COHORT_QUALITY_GATE",cohortQualityGate)
  out||=.BrandInteractionCanonical~field("CAUSAL_STATUS",causalStatus)
  if statisticalEvidence\==.nil then out||=statisticalEvidence~canonicalText
  out||=.BrandInteractionCanonical~join("REASON",reasons)
  return out

::class BrandEvidenceEngine subclass AlchemyObject public
::method init
  meta=.directory~new
  meta["purpose"]="Evaluate scoped aggregate brand-effect evidence with explicit size, effect and uncertainty gates"
  meta["package_version"]=.BrandInteractionBuild~VERSION
  meta["api_version"]=.BrandInteractionBuild~API_VERSION
  self~initAlchemy(meta)
  self~registerMethodContract("EVALUATE", "evaluate sealed evidence frame against explicit statistical/material thresholds", .array~of("FRAME","THRESHOLD"), "BRANDINTERACTIONRESULT", .false, "AUTO", "INTERNAL", "NORMAL", "READ", "NONE")
  self~registerExternalRequirement("library","alchemy_objects","0.4.3",.true)
  self~registerInstrumentationPoint("BRAND_INTERACTION.EVIDENCE.EVALUATE", "aggregate evidence evaluation requested", .true, "ALL", "INTERNAL")
::method evaluate
  self~alchemyTouch("EVALUATE")
  self~alchemyInstrument("BRAND_INTERACTION.EVIDENCE.EVALUATE")
  use arg frame, threshold = .nil
  if frame == .nil then return .BrandInteractionResult~failure("EVIDENCE_FRAME_NOT_SEALED")
  if \frame~sealed then return .BrandInteractionResult~failure("EVIDENCE_FRAME_NOT_SEALED")
  if threshold == .nil then threshold = .BrandEvidenceThreshold~new
  ratios=.array~new
  ratios~append(self~ratio(frame~populationCount,threshold~minPopulationCount))
  ratios~append(self~ratio(frame~exposedCount,threshold~minExposedCount))
  ratios~append(self~ratio(frame~outcomeCount,threshold~minOutcomeCount))
  ratios~append(self~ratio(frame~exposedOutcomeCount,threshold~minJointCount))
  ratios~append(self~ratio(frame~observationDays,threshold~minObservationDays))
  coverage=100
  do r over ratios; coverage=min(coverage,r); end
  statistical = coverage >= 100
  statsResult=.BrandStatisticalEvidence~fromFrame(frame,threshold~minConfidenceLevel)
  if \statsResult~ok then return statsResult
  stats=statsResult~value
  rr=frame~relativeRisk
  effect = abs(frame~absoluteRiskDifference) >= threshold~minAbsoluteRiskDifference
  if rr >= threshold~minRelativeRisk then effect=.true
  if threshold~requireConfidenceExcludesNull then confidence=stats~confidenceExcludesNull
  else confidence=.true
  material = frame~materialityScore >= threshold~minMaterialityScore & frame~materialOutcomeCount > 0
  provenance=frame~cohortProvenance
  cohortQuality=.true
  if threshold~requireCohortProvenance & provenance==.nil then cohortQuality=.false
  if provenance\==.nil then do
    if provenance~selectedAnalysisCoveragePct < threshold~minSelectedAnalysisCoveragePct then cohortQuality=.false
    if provenance~incompleteSelectedPct > threshold~maxIncompleteSelectedPct then cohortQuality=.false
    if provenance~selectionUnknownPct > threshold~maxSelectionUnknownPct then cohortQuality=.false
    if threshold~requireExplicitSelectionRule & provenance~selectionRuleId="UNSPECIFIED" then cohortQuality=.false
  end
  if statistical then do
    if effect & confidence & cohortQuality then do
      strong = frame~populationCount >= threshold~minPopulationCount*2 & frame~exposedCount >= threshold~minExposedCount*2 & frame~outcomeCount >= threshold~minOutcomeCount*2 & frame~exposedOutcomeCount >= threshold~minJointCount*2 & frame~observationDays >= threshold~minObservationDays*2
      if strong then status=.BrandEvidenceConstant~STATUS_STRONG
      else status=.BrandEvidenceConstant~STATUS_SUPPORTED
    end
    else status=.BrandEvidenceConstant~STATUS_WEAK
  end
  else if material then status=.BrandEvidenceConstant~STATUS_MATERIAL_INVESTIGATION
  else status=.BrandEvidenceConstant~STATUS_INSUFFICIENT
  a=.BrandEvidenceAssessment~new(status,coverage,statistical,material,effect,confidence,stats,cohortQuality)
  if frame~populationCount < threshold~minPopulationCount then a~addReason("POPULATION_BELOW_THRESHOLD")
  if frame~exposedCount < threshold~minExposedCount then a~addReason("EXPOSED_BELOW_THRESHOLD")
  if frame~outcomeCount < threshold~minOutcomeCount then a~addReason("OUTCOMES_BELOW_THRESHOLD")
  if frame~exposedOutcomeCount < threshold~minJointCount then a~addReason("JOINT_BELOW_THRESHOLD")
  if frame~observationDays < threshold~minObservationDays then a~addReason("TIME_WINDOW_BELOW_THRESHOLD")
  if \effect then a~addReason("EFFECT_SIZE_BELOW_THRESHOLD")
  if threshold~requireConfidenceExcludesNull & \confidence then a~addReason("CONFIDENCE_INTERVAL_CROSSES_NULL")
  if threshold~requireCohortProvenance & provenance==.nil then a~addReason("COHORT_PROVENANCE_REQUIRED")
  if provenance\==.nil then do
    if provenance~selectedAnalysisCoveragePct < threshold~minSelectedAnalysisCoveragePct then a~addReason("COHORT_SELECTED_ANALYSIS_COVERAGE_BELOW_THRESHOLD")
    if provenance~incompleteSelectedPct > threshold~maxIncompleteSelectedPct then a~addReason("COHORT_INCOMPLETE_SELECTED_ABOVE_THRESHOLD")
    if provenance~selectionUnknownPct > threshold~maxSelectionUnknownPct then a~addReason("COHORT_SELECTION_UNKNOWN_ABOVE_THRESHOLD")
    if threshold~requireExplicitSelectionRule & provenance~selectionRuleId="UNSPECIFIED" then a~addReason("COHORT_SELECTION_RULE_REQUIRED")
  end
  if material then a~addReason("HIGH_MATERIALITY_REQUIRES_INVESTIGATION")
  return .BrandInteractionResult~success(a)
::method ratio private
  use arg actual, required
  if required <= 0 then return 100
  return min(100,100*actual/required)

/*
 * Privacy-minimised population accumulator.  It counts one declared analysis
 * unit once, rather than asking callers to hand-enter 2x2 totals.  The unit id
 * is an opaque deduplication key; no customer prose is retained.
 */
::class BrandEvidenceCohortAccumulator subclass AlchemyObject public
::attribute accumulatorId get
::attribute populationCount get
::attribute outcomeCount get
::attribute exposedCount get
::attribute exposedOutcomeCount get
::attribute duplicateCount get
::attribute sourceCandidateCount get
::attribute selectedCount get
::attribute excludedCount get
::attribute selectionUnknownCount get
::attribute incompleteSelectedCount get
::attribute missingExposureCount get
::attribute missingOutcomeCount get
::method init
  expose accumulatorId classification fromAt toAt observationDays outcomeKind featureDimension featureClass classifierId taxonomyVersion outcomeWindowSeconds units populationCount outcomeCount exposedCount exposedOutcomeCount duplicateCount sourceCandidateCount selectedCount excludedCount selectionUnknownCount incompleteSelectedCount missingExposureCount missingOutcomeCount evidencePoints provenanceSpec exclusionReasonCounts exclusionReasonOrder unknownReasonCounts unknownReasonOrder provenanceLimitations
  use arg accumulatorIdArg, classificationArg, fromAtArg, toAtArg, observationDaysArg, outcomeKindArg, featureDimensionArg, featureClassArg, classifierIdArg="UNSPECIFIED", taxonomyVersionArg="UNSPECIFIED", outcomeWindowSecondsArg=0
  accumulatorId=accumulatorIdArg~string
  classification=.BrandInteractionCanonical~token(classificationArg)
  fromAt=fromAtArg~string; toAt=toAtArg~string; observationDays=observationDaysArg+0
  outcomeKind=.BrandInteractionCanonical~token(outcomeKindArg)
  featureDimension=.BrandInteractionCanonical~token(featureDimensionArg)
  featureClass=.BrandInteractionCanonical~token(featureClassArg)
  classifierId=.BrandInteractionCanonical~token(classifierIdArg)
  taxonomyVersion=.BrandInteractionCanonical~token(taxonomyVersionArg)
  outcomeWindowSeconds=outcomeWindowSecondsArg+0
  if accumulatorId="" | classification="" | fromAt="" | toAt="" | observationDays<=0 | outcomeKind="" | featureDimension="" | featureClass="" then raise syntax 88.995 array("BrandEvidenceCohortAccumulator requires id, scope, outcome and feature")
  units=.table~new; populationCount=0; outcomeCount=0; exposedCount=0; exposedOutcomeCount=0; duplicateCount=0
  sourceCandidateCount=0; selectedCount=0; excludedCount=0; selectionUnknownCount=0; incompleteSelectedCount=0; missingExposureCount=0; missingOutcomeCount=0
  evidencePoints=.array~new; provenanceSpec=.nil
  exclusionReasonCounts=.table~new; exclusionReasonOrder=.array~new; unknownReasonCounts=.table~new; unknownReasonOrder=.array~new; provenanceLimitations=.array~new
  meta=.directory~new
  meta["purpose"]="Accumulate privacy-minimised interaction candidates into a deduplicated brand evidence frame with explicit selection provenance"
  meta["package_version"]=.BrandInteractionBuild~VERSION
  meta["api_version"]=.BrandInteractionBuild~API_VERSION
  self~initAlchemy(meta)
  self~registerMethodContract("OBSERVE", "count one included opaque analysis unit once", .array~of("UNIT_ID","EXPOSED","OUTCOME"), "BRANDINTERACTIONRESULT", .false, "AUTO", "INTERNAL", "NORMAL", "MUTATE", "NONE")
  self~registerMethodContract("CONSIDER", "record one source candidate with selection and missingness state", .array~of("UNIT_ID","SELECTION_STATE","EXPOSURE_STATE","OUTCOME_STATE"), "BRANDINTERACTIONRESULT", .false, "AUTO", "INTERNAL", "NORMAL", "MUTATE", "NONE")
  self~registerMethodContract("CONFIGUREPROVENANCE", "declare cohort source, selection, sampling and ascertainment lineage", .array~of("PROVENANCE_ID","SOURCE_KIND","SOURCE_SYSTEM","UNIT_KIND","SELECTION_RULE_ID","SAMPLING_METHOD"), "BRANDINTERACTIONRESULT", .false, "AUTO", "INTERNAL", "NORMAL", "MUTATE", "NONE")
  self~registerMethodContract("BUILDFRAME", "seal accumulated counts and cohort provenance into a BrandEvidenceFrame", .array~of("FRAME_ID","ROLE"), "BRANDINTERACTIONRESULT", .false, "AUTO", "INTERNAL", "NORMAL", "READ", "NONE")
  self~registerExternalRequirement("library","alchemy_objects","0.4.3",.true)
  self~registerInstrumentationPoint("BRAND_INTERACTION.EVIDENCE.OBSERVE", "cohort unit observed", .true, "ALL", "INTERNAL")
  self~registerInstrumentationPoint("BRAND_INTERACTION.EVIDENCE.CONSIDER", "cohort source candidate considered", .true, "ALL", "INTERNAL")
::method configureProvenance
  expose provenanceSpec
  self~alchemyTouch("CONFIGUREPROVENANCE")
  use arg provenanceIdArg, sourceKindArg, sourceSystemArg, unitKindArg, selectionRuleIdArg, samplingMethodArg, inclusionPolicyIdArg="UNSPECIFIED", exclusionPolicyIdArg="UNSPECIFIED", deduplicationMethodArg="OPAQUE_UNIT_KEY", dedupKeyKindArg="INTERACTION_KEY", outcomeAscertainmentIdArg="UNSPECIFIED"
  p=.BrandEvidenceCohortProvenance~new(provenanceIdArg,sourceKindArg,sourceSystemArg,unitKindArg,selectionRuleIdArg,samplingMethodArg,inclusionPolicyIdArg,exclusionPolicyIdArg,deduplicationMethodArg,dedupKeyKindArg,"UNSPECIFIED","UNSPECIFIED",outcomeAscertainmentIdArg)
  provenanceSpec=p
  return .BrandInteractionResult~success(self)
::method addProvenanceLimitation
  expose provenanceLimitations
  use arg value
  t=.BrandInteractionCanonical~token(value); if t="" then return .false
  if \.BrandInteractionCanonical~contains(provenanceLimitations,t) then provenanceLimitations~append(t)
  return .true
::method observe
  expose duplicateCount
  self~alchemyTouch("OBSERVE"); self~alchemyInstrument("BRAND_INTERACTION.EVIDENCE.OBSERVE")
  use arg unitIdArg, exposedArg, outcomeArg, evidencePointArg=""
  return self~consider(unitIdArg,"INCLUDE",exposedArg,outcomeArg,evidencePointArg,"")
::method consider
  expose units populationCount outcomeCount exposedCount exposedOutcomeCount duplicateCount sourceCandidateCount selectedCount excludedCount selectionUnknownCount incompleteSelectedCount missingExposureCount missingOutcomeCount evidencePoints exclusionReasonCounts exclusionReasonOrder unknownReasonCounts unknownReasonOrder
  self~alchemyTouch("CONSIDER"); self~alchemyInstrument("BRAND_INTERACTION.EVIDENCE.CONSIDER")
  use arg unitIdArg, selectionStateArg, exposureStateArg="UNKNOWN", outcomeStateArg="UNKNOWN", evidencePointArg="", reasonArg="UNSPECIFIED"
  unitId=unitIdArg~string
  if unitId="" then return .BrandInteractionResult~failure("COHORT_UNIT_ID_REQUIRED")
  if units~hasIndex(unitId) then do; duplicateCount+=1; return .BrandInteractionResult~failure("COHORT_DUPLICATE_UNIT"); end
  selection=.BrandInteractionCanonical~token(selectionStateArg)
  if selection<>"INCLUDE" & selection<>"EXCLUDE" & selection<>"UNKNOWN" then return .BrandInteractionResult~failure("COHORT_SELECTION_STATE_INVALID")
  units[unitId]=1; sourceCandidateCount+=1
  reason=.BrandInteractionCanonical~token(reasonArg); if reason="" then reason="UNSPECIFIED"
  if selection="EXCLUDE" then do
    excludedCount+=1; ignore=self~incrementReason(exclusionReasonCounts,exclusionReasonOrder,reason)
    return .BrandInteractionResult~success(self)
  end
  if selection="UNKNOWN" then do
    selectionUnknownCount+=1; ignore=self~incrementReason(unknownReasonCounts,unknownReasonOrder,reason)
    return .BrandInteractionResult~success(self)
  end
  selectedCount+=1
  exposureKnown=self~isBoolean(exposureStateArg); outcomeKnown=self~isBoolean(outcomeStateArg)
  if \exposureKnown then missingExposureCount+=1
  if \outcomeKnown then missingOutcomeCount+=1
  if \exposureKnown | \outcomeKnown then do
    incompleteSelectedCount+=1
    return .BrandInteractionResult~success(self)
  end
  exposed=self~truth(exposureStateArg); outcome=self~truth(outcomeStateArg)
  populationCount+=1
  if exposed then exposedCount+=1
  if outcome then outcomeCount+=1
  if exposed & outcome then exposedOutcomeCount+=1
  if evidencePointArg~string<>"" & evidencePoints~items<32 then do
    if \.BrandInteractionCanonical~contains(evidencePoints,evidencePointArg~string) then evidencePoints~append(evidencePointArg~string)
  end
  return .BrandInteractionResult~success(self)
::method buildFrame
  expose classification fromAt toAt observationDays outcomeKind featureDimension featureClass classifierId taxonomyVersion outcomeWindowSeconds populationCount outcomeCount exposedCount exposedOutcomeCount evidencePoints provenanceSpec sourceCandidateCount selectedCount excludedCount selectionUnknownCount incompleteSelectedCount missingExposureCount missingOutcomeCount duplicateCount exclusionReasonCounts exclusionReasonOrder unknownReasonCounts unknownReasonOrder provenanceLimitations
  self~alchemyTouch("BUILDFRAME")
  use arg frameIdArg, roleArg="CURRENT"
  f=.BrandEvidenceFrame~new(frameIdArg,roleArg,classification,fromAt,toAt,observationDays,populationCount,outcomeKind,outcomeCount,featureDimension,featureClass,exposedCount,exposedOutcomeCount,classifierId,taxonomyVersion,outcomeWindowSeconds)
  do p over evidencePoints; f~addSupportPoint(p); end
  if provenanceSpec\==.nil then do
    prov=.BrandEvidenceCohortProvenance~new(provenanceSpec~provenanceId,provenanceSpec~sourceKind,provenanceSpec~sourceSystem,provenanceSpec~unitKind,provenanceSpec~selectionRuleId,provenanceSpec~samplingMethod,provenanceSpec~inclusionPolicyId,provenanceSpec~exclusionPolicyId,provenanceSpec~deduplicationMethod,provenanceSpec~dedupKeyKind,classifierId,taxonomyVersion,provenanceSpec~outcomeAscertainmentId)
    prov~setCounts(sourceCandidateCount,selectedCount,populationCount,excludedCount,selectionUnknownCount,incompleteSelectedCount,missingExposureCount,missingOutcomeCount,duplicateCount)
    do r over exclusionReasonOrder; prov~addExclusionReason(r,exclusionReasonCounts[r]); end
    do r over unknownReasonOrder; prov~addSelectionUnknownReason(r,unknownReasonCounts[r]); end
    do lim over provenanceLimitations; prov~addLimitation(lim); end
    pr=prov~seal; if \pr~ok then return pr
    ar=f~attachCohortProvenance(prov); if \ar~ok then return ar
  end
  r=f~seal
  if \r~ok then return r
  return .BrandInteractionResult~success(f)
::method pointId
  expose accumulatorId
  return "BRAND_INTERACTION:EVIDENCE_COHORT:"||accumulatorId
::method incrementReason private
  use arg counts, order, reason
  if \counts~hasIndex(reason) then do; counts[reason]=0; order~append(reason); end
  counts[reason]+=1
  return .true
::method isBoolean private
  use arg v
  if v==.true | v==.false then return .true
  if datatype(v,"W") & (v=0 | v=1) then return .true
  return .false
::method truth private
  use arg v
  if v==.true then return .true
  if v==.false then return .false
  return v=1

::class BrandTemporalEvidenceSeries public
::attribute seriesId get
::attribute sealed get
::method init
  expose seriesId frames sealed
  use arg idArg
  seriesId=idArg~string; frames=.array~new; sealed=.false
  if seriesId="" then raise syntax 88.992 array("BrandTemporalEvidenceSeries requires id")
::method addFrame
  expose frames sealed
  use arg frame
  if sealed then return .false
  if frame==.nil then return .false
  if \frame~sealed then return .false
  frames~append(frame); return .true
::method frames
  expose frames
  return .BrandInteractionCanonical~copyArray(frames)
::method seal
  expose frames sealed
  if frames~items < 1 then return .BrandInteractionResult~failure("TEMPORAL_SERIES_EMPTY")
  currentCount=0
  do f over frames; if f~role=.BrandEvidenceConstant~ROLE_CURRENT then currentCount+=1; end
  if currentCount<>1 then return .BrandInteractionResult~failure("TEMPORAL_SERIES_REQUIRES_ONE_CURRENT")
  sealed=.true; return .BrandInteractionResult~success(self)
::method currentFrame
  expose frames
  do f over frames; if f~role=.BrandEvidenceConstant~ROLE_CURRENT then return f; end
  return .nil
::method frameByRole
  expose frames
  use arg roleArg
  role=.BrandInteractionCanonical~token(roleArg)
  do f over frames; if f~role=role then return f; end
  return .nil
::method exposedOutcomeRateDelta
  use arg otherRoleArg
  c=self~currentFrame; p=self~frameByRole(otherRoleArg)
  if c==.nil then return 0
  if p==.nil then return 0
  return c~exposedOutcomeRate-p~exposedOutcomeRate
::method featurePrevalenceDelta
  use arg otherRoleArg
  c=self~currentFrame; p=self~frameByRole(otherRoleArg)
  if c==.nil then return 0
  if p==.nil then return 0
  return c~featurePrevalence-p~featurePrevalence
::method canonicalText
  expose seriesId frames sealed
  if \sealed then raise syntax 93.992 additional("BrandTemporalEvidenceSeries must be sealed")
  out=.BrandInteractionCanonical~field("TEMPORAL_SERIES",seriesId)
  do f over frames; out||=.BrandInteractionCanonical~field("FRAME_POINT",f~pointId); end
  prev=self~frameByRole(.BrandEvidenceConstant~ROLE_PREVIOUS)
  base=self~frameByRole(.BrandEvidenceConstant~ROLE_BASELINE)
  if prev\==.nil then do
    out||=.BrandInteractionCanonical~field("CURRENT_V_PREVIOUS_EXPOSED_OUTCOME_RATE_DELTA_PCT",self~exposedOutcomeRateDelta(.BrandEvidenceConstant~ROLE_PREVIOUS))
    out||=.BrandInteractionCanonical~field("CURRENT_V_PREVIOUS_FEATURE_PREVALENCE_DELTA_PCT",self~featurePrevalenceDelta(.BrandEvidenceConstant~ROLE_PREVIOUS))
  end
  if base\==.nil then do
    out||=.BrandInteractionCanonical~field("CURRENT_V_BASELINE_EXPOSED_OUTCOME_RATE_DELTA_PCT",self~exposedOutcomeRateDelta(.BrandEvidenceConstant~ROLE_BASELINE))
    out||=.BrandInteractionCanonical~field("CURRENT_V_BASELINE_FEATURE_PREVALENCE_DELTA_PCT",self~featurePrevalenceDelta(.BrandEvidenceConstant~ROLE_BASELINE))
  end
  return out

::class BrandEffectEvidencePacket public
::attribute packetId get
::attribute claimCode get
::attribute dimension get
::attribute frame get
::attribute threshold get
::attribute assessment get
::attribute temporalSeries get
::attribute sealed get
::method init
  expose packetId claimCode dimension frame threshold assessment temporalSeries supportPoints counterPoints confounders scopeExclusions permittedInterpretations prohibitedInterpretations sealed
  use arg packetIdArg, claimCodeArg, dimensionArg, frameArg, thresholdArg, assessmentArg, temporalSeriesArg = .nil
  packetId=packetIdArg~string
  claimCode=.BrandInteractionCanonical~token(claimCodeArg)
  dimension=.BrandInteractionCanonical~token(dimensionArg)
  frame=frameArg; threshold=thresholdArg; assessment=assessmentArg; temporalSeries=temporalSeriesArg
  supportPoints=.array~new; counterPoints=.array~new; confounders=.array~new; scopeExclusions=.array~new; permittedInterpretations=.array~new; prohibitedInterpretations=.array~new; sealed=.false
  if packetId="" | claimCode="" | dimension="" then raise syntax 88.993 array("BrandEffectEvidencePacket requires id, claim and dimension")
::method addSupportPoint
  expose supportPoints sealed
  use arg p
  if sealed | p~string="" then return .false
  if \.BrandInteractionCanonical~contains(supportPoints,p~string) then supportPoints~append(p~string)
  return .true
::method addCounterPoint
  expose counterPoints sealed
  use arg p
  if sealed | p~string="" then return .false
  if \.BrandInteractionCanonical~contains(counterPoints,p~string) then counterPoints~append(p~string)
  return .true
::method addConfounder
  expose confounders sealed
  use arg v
  if sealed then return .false
  t=.BrandInteractionCanonical~token(v); if t="" then return .false
  if \.BrandInteractionCanonical~contains(confounders,t) then confounders~append(t)
  return .true
::method addScopeExclusion
  expose scopeExclusions sealed
  use arg v
  if sealed then return .false
  t=.BrandInteractionCanonical~token(v); if t="" then return .false
  if \.BrandInteractionCanonical~contains(scopeExclusions,t) then scopeExclusions~append(t)
  return .true
::method permitInterpretation
  expose permittedInterpretations sealed
  use arg v
  if sealed then return .false
  t=.BrandInteractionCanonical~token(v); if t="" then return .false
  if \.BrandInteractionCanonical~contains(permittedInterpretations,t) then permittedInterpretations~append(t)
  return .true
::method prohibitInterpretation
  expose prohibitedInterpretations sealed
  use arg v
  if sealed then return .false
  t=.BrandInteractionCanonical~token(v); if t="" then return .false
  if \.BrandInteractionCanonical~contains(prohibitedInterpretations,t) then prohibitedInterpretations~append(t)
  return .true
::method seal
  expose frame threshold assessment temporalSeries supportPoints counterPoints scopeExclusions permittedInterpretations prohibitedInterpretations sealed
  if frame==.nil then return .BrandInteractionResult~failure("PACKET_FRAME_REQUIRED")
  if \frame~sealed then return .BrandInteractionResult~failure("PACKET_FRAME_REQUIRED")
  if threshold==.nil | assessment==.nil then return .BrandInteractionResult~failure("PACKET_THRESHOLD_ASSESSMENT_REQUIRED")
  if temporalSeries\==.nil then do
    if \temporalSeries~sealed then return .BrandInteractionResult~failure("PACKET_TEMPORAL_SERIES_NOT_SEALED")
  end
  if supportPoints~items=0 then return .BrandInteractionResult~failure("SUPPORTING_EVIDENCE_REQUIRED")
  if assessment~status=.BrandEvidenceConstant~STATUS_SUPPORTED | assessment~status=.BrandEvidenceConstant~STATUS_STRONG then do
    if counterPoints~items=0 & scopeExclusions~items=0 then return .BrandInteractionResult~failure("COUNTER_OR_SCOPE_BOUNDARY_REQUIRED")
  end
  if permittedInterpretations~items=0 | prohibitedInterpretations~items=0 then return .BrandInteractionResult~failure("INTERPRETATION_BOUNDS_REQUIRED")
  sealed=.true; return .BrandInteractionResult~success(self)
::method pointId
  expose packetId
  return "BRAND_INTERACTION:EVIDENCE_PACKET:"||packetId
::method canonicalText
  expose packetId claimCode dimension frame threshold assessment temporalSeries supportPoints counterPoints confounders scopeExclusions permittedInterpretations prohibitedInterpretations sealed
  if \sealed then raise syntax 93.993 additional("BrandEffectEvidencePacket must be sealed")
  out=.BrandInteractionCanonical~field("EVIDENCE_PACKET",packetId)
  out||=.BrandInteractionCanonical~field("CLAIM_CANDIDATE",claimCode)
  out||=.BrandInteractionCanonical~field("DIMENSION",dimension)
  out||=frame~canonicalText
  out||=threshold~canonicalText
  out||=assessment~canonicalText
  if temporalSeries\==.nil then out||=temporalSeries~canonicalText
  out||=.BrandInteractionCanonical~join("SUPPORT_POINT",supportPoints)
  out||=.BrandInteractionCanonical~join("COUNTER_POINT",counterPoints)
  out||=.BrandInteractionCanonical~join("PLAUSIBLE_CONFOUNDER",confounders)
  out||=.BrandInteractionCanonical~join("SCOPE_EXCLUSION",scopeExclusions)
  out||=.BrandInteractionCanonical~join("PERMITTED_INTERPRETATION",permittedInterpretations)
  out||=.BrandInteractionCanonical~join("PROHIBITED_INTERPRETATION",prohibitedInterpretations)
  return out

::class BrandToneAppropriatenessReport public
::attribute reportId get
::attribute packet get
::method init
  expose reportId packet
  use arg reportIdArg, packetArg
  reportId=reportIdArg~string; packet=packetArg
  if reportId="" then raise syntax 88.994 array("BrandToneAppropriatenessReport requires sealed packet")
  if packet==.nil then raise syntax 88.994 array("BrandToneAppropriatenessReport requires sealed packet")
  if \packet~sealed then raise syntax 88.994 array("BrandToneAppropriatenessReport requires sealed packet")
::method reasoningMaterial
  expose reportId packet
  out=.BrandInteractionCanonical~field("TONE_APPROPRIATENESS_REPORT",reportId)
  out||=packet~canonicalText
  return out

::requires 'BrandInteractionEffect.cls'
::requires 'rxmath' LIBRARY
