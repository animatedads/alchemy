/*
 * WLURouteAdvisory v0.1
 *
 * Non-authoritative evidence-weighted route advice over a verified analytics
 * snapshot.  Advice cannot grant entitlement, reserve capacity, mutate a job,
 * promote standby work, or invoke a provider.  Policy gates and ranking are
 * deliberately explicit rather than collapsed into an opaque weighted score.
 */

::options digits 30

::class WLURouteAdvisoryBuild public
::constant VERSION "0.1"
::constant API_VERSION "work.load.units.route-advisory/0.1"

::class WLURouteAdvisoryStatus public
::constant RECOMMENDATION_AVAILABLE "RECOMMENDATION_AVAILABLE"
::constant NO_EVIDENCE_ELIGIBLE_ROUTE "NO_EVIDENCE_ELIGIBLE_ROUTE"
::constant EVIDENCE_ELIGIBLE "EVIDENCE_ELIGIBLE"
::constant INSUFFICIENT_SAMPLE "INSUFFICIENT_SAMPLE"
::constant POLICY_NOT_MET "POLICY_NOT_MET"

::class WLURouteAdvisoryPolicy public
::attribute minimumSamples get
::attribute minimumSuccessLower95BasisPoints get
::attribute maximumOverExpectedUpper95BasisPoints get
::attribute maximumAverageActualMicroWlu get

::method init
  expose minimumSamples minimumSuccessLower95BasisPoints maximumOverExpectedUpper95BasisPoints maximumAverageActualMicroWlu
  use strict arg minimumSamples = 30, minimumSuccessLower95BasisPoints = 5000, maximumOverExpectedUpper95BasisPoints = 5000, maximumAverageActualMicroWlu = 0
  if \datatype(minimumSamples, "W") | minimumSamples < 1 then raise syntax 88.900 array("route advisory minimum samples must be a positive whole number")
  if \datatype(minimumSuccessLower95BasisPoints, "W") | minimumSuccessLower95BasisPoints < 0 | minimumSuccessLower95BasisPoints > 10000 then raise syntax 88.900 array("route advisory success lower bound must be 0..10000 basis points")
  if \datatype(maximumOverExpectedUpper95BasisPoints, "W") | maximumOverExpectedUpper95BasisPoints < 0 | maximumOverExpectedUpper95BasisPoints > 10000 then raise syntax 88.900 array("route advisory over-expected upper bound must be 0..10000 basis points")
  if \datatype(maximumAverageActualMicroWlu, "W") | maximumAverageActualMicroWlu < 0 then raise syntax 88.900 array("route advisory average WLU cap must be a non-negative whole micro-WLU value")

::method canonicalText
  expose minimumSamples minimumSuccessLower95BasisPoints maximumOverExpectedUpper95BasisPoints maximumAverageActualMicroWlu
  text = "WLU-ROUTE-ADVISORY-POLICY/1" || '0a'x
  text ||= "MINIMUM_SAMPLES=" || minimumSamples || '0a'x
  text ||= "MIN_SUCCESS_LOWER95_BP=" || minimumSuccessLower95BasisPoints || '0a'x
  text ||= "MAX_OVER_EXPECTED_UPPER95_BP=" || maximumOverExpectedUpper95BasisPoints || '0a'x
  text ||= "MAX_AVERAGE_ACTUAL_MICROWLU=" || maximumAverageActualMicroWlu || '0a'x
  return text

::class WLURouteCandidateAssessment public
::attribute stageId get
::attribute plannedExpectedMicroWlu get
::attribute statistics get
::attribute decisionEligible get
::attribute status get
::attribute reasons get
::attribute successObservedBasisPoints get
::attribute successLower95BasisPoints get
::attribute successUpper95BasisPoints get
::attribute overExpectedObservedBasisPoints get
::attribute overExpectedLower95BasisPoints get
::attribute overExpectedUpper95BasisPoints get
::attribute averageActualMicroWlu get
::attribute averageKnownHandoffMicroWlu get

::method init
  expose stageId plannedExpectedMicroWlu statistics decisionEligible status reasons successObservedBasisPoints successLower95BasisPoints successUpper95BasisPoints overExpectedObservedBasisPoints overExpectedLower95BasisPoints overExpectedUpper95BasisPoints averageActualMicroWlu averageKnownHandoffMicroWlu
  use strict arg stageId, plannedExpectedMicroWlu, statistics, decisionEligible, status, reasons, successObservedBasisPoints, successLower95BasisPoints, successUpper95BasisPoints, overExpectedObservedBasisPoints, overExpectedLower95BasisPoints, overExpectedUpper95BasisPoints, averageActualMicroWlu, averageKnownHandoffMicroWlu

::method reasonCount
  expose reasons
  return reasons~items

::method canonicalText
  expose stageId plannedExpectedMicroWlu statistics decisionEligible status reasons successObservedBasisPoints successLower95BasisPoints successUpper95BasisPoints overExpectedObservedBasisPoints overExpectedLower95BasisPoints overExpectedUpper95BasisPoints averageActualMicroWlu averageKnownHandoffMicroWlu
  text = "WLU-ROUTE-CANDIDATE-ASSESSMENT/1" || '0a'x
  text ||= "STAGE=" || stageId || '0a'x
  text ||= "PLANNED_EXPECTED_MICROWLU=" || plannedExpectedMicroWlu || '0a'x
  text ||= "SAMPLE_COUNT=" || statistics~sampleCount || '0a'x
  text ||= "MINIMUM_SAMPLES=" || statistics~minimumSamples || '0a'x
  text ||= "DECISION_ELIGIBLE=" || decisionEligible || '0a'x
  text ||= "STATUS=" || status || '0a'x
  text ||= "SUCCESS_OBSERVED_BP=" || successObservedBasisPoints || '0a'x
  text ||= "SUCCESS_LOWER95_BP=" || successLower95BasisPoints || '0a'x
  text ||= "SUCCESS_UPPER95_BP=" || successUpper95BasisPoints || '0a'x
  text ||= "OVER_EXPECTED_OBSERVED_BP=" || overExpectedObservedBasisPoints || '0a'x
  text ||= "OVER_EXPECTED_LOWER95_BP=" || overExpectedLower95BasisPoints || '0a'x
  text ||= "OVER_EXPECTED_UPPER95_BP=" || overExpectedUpper95BasisPoints || '0a'x
  text ||= "AVERAGE_ACTUAL_MICROWLU=" || averageActualMicroWlu || '0a'x
  text ||= "AVERAGE_HANDOFF_MICROWLU=" || averageKnownHandoffMicroWlu || '0a'x
  text ||= "REASON_COUNT=" || reasons~items || '0a'x
  do reason over reasons
    text ||= "REASON=" || reason || '0a'x
  end
  return text

::class WLURouteAdvisoryResult public
::attribute status get
::attribute recommendedStageId get
::attribute recommendedAssessment get
::attribute assessments get
::attribute sourceSequence get
::attribute sourceTag get
::attribute policy get
::attribute proof get

::method init
  expose status recommendedStageId recommendedAssessment assessments sourceSequence sourceTag policy proof
  use strict arg status, recommendedStageId, recommendedAssessment, assessments, sourceSequence, sourceTag, policy, proof = .nil

::method hasRecommendation
  expose recommendedAssessment
  return recommendedAssessment \== .nil

::method canonicalText
  expose status recommendedStageId assessments sourceSequence sourceTag policy
  text = "WLU-ROUTE-ADVISORY-RESULT/1" || '0a'x
  text ||= "STATUS=" || status || '0a'x
  text ||= "RECOMMENDED_STAGE=" || recommendedStageId || '0a'x
  text ||= "SOURCE_SEQUENCE=" || sourceSequence || '0a'x
  text ||= "SOURCE_TAG=" || sourceTag || '0a'x
  text ||= policy~canonicalText
  text ||= "ASSESSMENT_COUNT=" || assessments~items || '0a'x
  do assessment over assessments
    text ||= assessment~canonicalText
  end
  return text

::method withProof
  expose status recommendedStageId recommendedAssessment assessments sourceSequence sourceTag policy
  use strict arg proofArg
  return .WLURouteAdvisoryResult~new(status, recommendedStageId, recommendedAssessment, assessments, sourceSequence, sourceTag, policy, proofArg)

::method verify
  expose proof
  use strict arg keyRing
  if proof == .nil then return .false
  return keyRing~verify(self~canonicalText, proof)

::method assessmentFor
  expose assessments
  use strict arg stageId
  stageId = stageId~string~strip~translate
  do item over assessments
    if item~stageId~translate = stageId then return item
  end
  return .nil

/* Long-lived read-only advisory surface.  It consumes verified evidence and
 * returns recommendation material only; no WLU authority object is accepted. */
::class WLUJobRouteAdvisor subclass AlchemyObject public
::attribute keyRing get
::attribute analytics get

::method init
  expose keyRing analytics
  use strict arg keyRing
  if keyRing == .nil | \keyRing~isA(.WLUFastMacKeyRing) then raise syntax 88.900 array("WLU route advisor requires WLUFastMacKeyRing")
  analytics = .WLUJobRouteAnalytics~new(keyRing)
  alchemyConstruction = .WLUAlchemySupport~construction(keyRing, "WLUJobRouteAdvisor", "Non-authoritative evidence-weighted route advice over verified route analytics")
  self~init:super(alchemyConstruction[1], alchemyConstruction[2], alchemyConstruction[3])
  ignore = .WLUAlchemySupport~finishConstruction(self)
  self~registerMethodContract("ASSESSSTAGE", "Assess one declared WLU job stage against explicit statistical evidence gates", .array~of("SOURCE", "STAGE", "POLICY", "WINDOWSTARTTICK", "WINDOWENDTICK", "JOBIDS"), "WLURESULT", .false, "AUTO", "CUSTOMER", "NORMAL", "READ", "NONE")
  self~registerMethodContract("ADVISE", "Rank only evidence-eligible candidate stages without granting workload authority", .array~of("SOURCE", "STAGES", "POLICY", "WINDOWSTARTTICK", "WINDOWENDTICK", "JOBIDS"), "WLURESULT", .false, "AUTO", "CUSTOMER", "SENSITIVE", "READ", "NONE")
  self~registerInstrumentationPoint("WLU.JOB.ROUTE.ADVISORY", "read-only evidence-weighted route recommendation boundary", .true, "ALL", "INTERNAL")

::method assessStage
  expose analytics
  use strict arg source, stage, policy = .nil, windowStartTick = 0, windowEndTick = 0, jobIds = .nil
  guard on
  if policy == .nil then policy = .WLURouteAdvisoryPolicy~new
  valid = self~validatePolicyAndStage(policy, stage)
  if \valid~ok then return valid
  snapshotResult = self~resolveSnapshot(source)
  if \snapshotResult~ok then return snapshotResult
  return self~assessmentFromSnapshot(snapshotResult~value, stage, policy, windowStartTick, windowEndTick, jobIds)

::method advise
  expose analytics keyRing
  use strict arg source, stages, policy = .nil, windowStartTick = 0, windowEndTick = 0, jobIds = .nil
  guard on
  if policy == .nil then policy = .WLURouteAdvisoryPolicy~new
  if \policy~isA(.WLURouteAdvisoryPolicy) then return .WLUResult~failure("WLU_ROUTE_ADVISORY_POLICY_REQUIRED", "WLURouteAdvisoryPolicy required")
  if stages == .nil | \stages~isA(.Collection) then return .WLUResult~failure("WLU_ROUTE_ADVISORY_STAGES_REQUIRED", "candidate stages must be a collection")
  if stages~items < 1 then return .WLUResult~failure("WLU_ROUTE_ADVISORY_STAGES_REQUIRED", "at least one candidate stage required")
  snapshotResult = self~resolveSnapshot(source)
  if \snapshotResult~ok then return snapshotResult
  snapshot = snapshotResult~value
  assessments = .array~new
  best = .nil
  do stage over stages
    valid = self~validatePolicyAndStage(policy, stage)
    if \valid~ok then return valid
    one = self~assessmentFromSnapshot(snapshot, stage, policy, windowStartTick, windowEndTick, jobIds)
    if \one~ok then return one
    assessment = one~value
    assessments~append(assessment)
    if assessment~decisionEligible then do
      if best == .nil then best = assessment
      else if self~better(assessment, best) then best = assessment
    end
  end
  if best == .nil then do
    status = .WLURouteAdvisoryStatus~NO_EVIDENCE_ELIGIBLE_ROUTE
    recommendedId = ""
  end
  else do
    status = .WLURouteAdvisoryStatus~RECOMMENDATION_AVAILABLE
    recommendedId = best~stageId
  end
  report = .WLURouteAdvisoryResult~new(status, recommendedId, best, assessments, snapshot~sourceSequence, snapshot~sourceTag, policy)
  report = report~withProof(keyRing~sign(report~canonicalText))
  meta = .directory~new
  meta["candidate_count"] = assessments~items
  meta["status"] = status
  meta["recommended_stage_id"] = recommendedId
  meta["source_sequence"] = snapshot~sourceSequence
  self~alchemyInstrument("WLU.JOB.ROUTE.ADVISORY", meta)
  return .WLUResult~success(report)

::method assessmentFromSnapshot private
  expose analytics
  use strict arg snapshot, stage, policy, windowStartTick, windowEndTick, jobIds
  statsResult = analytics~stageStatistics(snapshot, stage~stageId, windowStartTick, windowEndTick, policy~minimumSamples, jobIds)
  if \statsResult~ok then return statsResult
  stats = statsResult~value
  successCI = stats~declaredSuccessWilson95
  overCI = stats~overExpectedWilson95
  reasons = .array~new
  if \stats~sufficientSample then reasons~append("INSUFFICIENT_SAMPLE")
  if stats~sufficientSample then do
    if successCI[1] < policy~minimumSuccessLower95BasisPoints then reasons~append("SUCCESS_LOWER_BOUND_BELOW_FLOOR")
    if overCI[2] > policy~maximumOverExpectedUpper95BasisPoints then reasons~append("OVER_EXPECTED_UPPER_BOUND_ABOVE_LIMIT")
    if policy~maximumAverageActualMicroWlu > 0 then do
      if stats~averageActualMicroWlu > policy~maximumAverageActualMicroWlu then reasons~append("AVERAGE_ACTUAL_WLU_ABOVE_LIMIT")
    end
  end
  eligible = reasons~items = 0
  if eligible then status = .WLURouteAdvisoryStatus~EVIDENCE_ELIGIBLE
  else if \stats~sufficientSample then status = .WLURouteAdvisoryStatus~INSUFFICIENT_SAMPLE
  else status = .WLURouteAdvisoryStatus~POLICY_NOT_MET
  assessment = .WLURouteCandidateAssessment~new(stage~stageId, stage~expectedMicroWlu, stats, eligible, status, reasons, stats~declaredSuccessBasisPoints, successCI[1], successCI[2], stats~overExpectedBasisPoints, overCI[1], overCI[2], stats~averageActualMicroWlu, stats~averageKnownHandoffMicroWlu)
  return .WLUResult~success(assessment)

::method validatePolicyAndStage private
  use strict arg policy, stage
  if policy == .nil | \policy~isA(.WLURouteAdvisoryPolicy) then return .WLUResult~failure("WLU_ROUTE_ADVISORY_POLICY_REQUIRED", "WLURouteAdvisoryPolicy required")
  if stage == .nil | \stage~isA(.WLUJobStage) then return .WLUResult~failure("WLU_ROUTE_ADVISORY_STAGE_REQUIRED", "WLUJobStage candidate required")
  return .WLUResult~success

::method resolveSnapshot private
  expose analytics
  use strict arg source
  if source == .nil then return .WLUResult~failure("WLU_ROUTE_ADVISORY_SOURCE_REQUIRED", "verified journal or analytics snapshot required")
  if source~isA(.WLURouteAnalyticsSnapshot) then return .WLUResult~success(source)
  if \source~isA(.WLUJobRouteFileJournal) then return .WLUResult~failure("WLU_ROUTE_ADVISORY_SOURCE_REQUIRED", "verified journal or analytics snapshot required")
  return analytics~verifiedSnapshot(source)

/* Explicit lexicographic ranking: stronger conservative success evidence,
 * lower conservative overrun risk, lower observed actual WLU, then lower
 * declared expected WLU. Exact ties preserve caller candidate order. */
::method better private
  use strict arg candidate, incumbent
  if candidate~successLower95BasisPoints > incumbent~successLower95BasisPoints then return .true
  if candidate~successLower95BasisPoints < incumbent~successLower95BasisPoints then return .false
  if candidate~overExpectedUpper95BasisPoints < incumbent~overExpectedUpper95BasisPoints then return .true
  if candidate~overExpectedUpper95BasisPoints > incumbent~overExpectedUpper95BasisPoints then return .false
  if candidate~averageActualMicroWlu < incumbent~averageActualMicroWlu then return .true
  if candidate~averageActualMicroWlu > incumbent~averageActualMicroWlu then return .false
  if candidate~plannedExpectedMicroWlu < incumbent~plannedExpectedMicroWlu then return .true
  return .false

::requires "WLURouteAnalytics.cls"
