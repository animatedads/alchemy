/*
 * Brand Intervention Effectiveness v0.2
 *
 * Comparative evidence layer for interventions.  It asks whether outcomes
 * differ between eligible journeys where an intervention was applied and
 * comparable eligible journeys where it was not.  It preserves denominators,
 * time/release scope, uncertainty, counterevidence and guardrail outcomes.
 * It never promotes an observed association to causation by itself.
 */

::class BrandInterventionEffectivenessBuild public
::constant VERSION "0.2"
::constant API_VERSION "brand.intervention.effectiveness/0.2"
::constant PRODUCT "ooRexx Brand Intervention Effectiveness"

::class BrandInterventionEffectivenessAlchemySupport public
::method metadata class
  use arg purposeArg
  d=.directory~new
  d["purpose"]=purposeArg~string
  d["package_version"]=.BrandInterventionEffectivenessBuild~VERSION
  d["api_version"]=.BrandInterventionEffectivenessBuild~API_VERSION
  d["component"]="BRAND_INTERVENTION_EFFECTIVENESS"
  return d

::class BrandInterventionEffectivenessConstant public
::constant DIRECTION_INCREASE "INCREASE"
::constant DIRECTION_DECREASE "DECREASE"
::constant ROLE_PRIMARY "PRIMARY"
::constant ROLE_GUARDRAIL "GUARDRAIL"
::constant STATUS_INSUFFICIENT "INSUFFICIENT"
::constant STATUS_NO_CLEAR "NO_CLEAR_ASSOCIATION"
::constant STATUS_PROMISING "PROMISING_ASSOCIATION"
::constant STATUS_ADVERSE "ADVERSE_ASSOCIATION"
::constant STATUS_MIXED "MIXED_EFFECTS"
::constant STATUS_REVIEW "REVIEW_REQUIRED"
::constant ASSIGNMENT_OBSERVATIONAL "OBSERVATIONAL"
::constant ASSIGNMENT_RANDOMIZED "RANDOMIZED"
::constant ASSIGNMENT_QUASI "QUASI_EXPERIMENTAL"
::constant CAUSAL_ASSOCIATION_ONLY "ASSOCIATION_ONLY"
::constant CONFIDENCE_95 "WILSON_95"

::class BrandInterventionEffectivenessResult public
::attribute ok get
::attribute value get
::attribute code get
::attribute detail get
::method init
  expose ok value code detail
  use arg okArg, valueArg=.nil, codeArg="", detailArg=""
  ok=okArg; value=valueArg; code=codeArg; detail=detailArg
::method success class
  use arg value=.nil, detail=""
  return self~new(.true,value,"OK",detail)
::method failure class
  use arg codeArg, detailArg=""
  return self~new(.false,.nil,codeArg,detailArg)

::class BrandInterventionEffectivenessCanonical public
::method token class
  use arg value
  if value==.nil then return ""
  t=value~string~strip~translate
  t=changestr(" ",t,"_")
  return t
::method copyArray class
  use arg source
  out=.array~new
  if source==.nil then return out
  do x over source; out~append(x); end
  return out
::method contains class
  use arg values,wanted
  if values==.nil then return .false
  do x over values
    if x~string==wanted~string then return .true
  end
  return .false
::method field class
  use arg name,value
  return name~string || "=" || value~string || '0a'x
::method join class
  use arg name,values
  out=""
  if values==.nil then return out
  do x over values; out||=self~field(name,x); end
  return out
::method safePoint class
  use arg value
  if value==.nil then return .false
  p=value~string~strip
  if p="" then return .false
  if p~pos(" ")>0 | p~pos('09'x)>0 | p~pos('0a'x)>0 | p~pos('0d'x)>0 then return .false
  if p~caselessPos("BRAND_INTERVENTION:")=1 then return .true
  if p~caselessPos("BRAND_JOURNEY:")=1 then return .true
  if p~caselessPos("BRAND_INTERACTION:")=1 then return .true
  if p~caselessPos("INTERACTION_EVENT:")=1 then return .true
  if p~caselessPos("STRUCTURED_UTTERANCE:")=1 then return .true
  return .false

/* One outcome comparison among intervention-eligible journeys.  The control
   denominator is NOT "everyone else"; it is journeys where the same
   intervention was eligible/proposed but not applied. */
::class BrandInterventionEffectivenessAggregate subclass AlchemyObject public
::attribute aggregateId get
::attribute interventionKind get
::attribute outcomeKind get
::attribute desiredDirection get
::attribute outcomeRole get
::attribute classification get
::attribute fromAt get
::attribute toAt get
::attribute observationDays get
::attribute eligibleCount get
::attribute appliedCount get
::attribute appliedOutcomeCount get
::attribute notAppliedCount get
::attribute notAppliedOutcomeCount get
::attribute outcomeWindowSeconds get
::attribute assignmentMethod get
::attribute assignmentAuthorityId get
::attribute classifierId get
::attribute taxonomyVersion get
::attribute processVersion get
::attribute modelVersion get
::attribute sealed get
::method init
  expose aggregateId interventionKind outcomeKind desiredDirection outcomeRole classification fromAt toAt observationDays eligibleCount appliedCount appliedOutcomeCount notAppliedCount notAppliedOutcomeCount outcomeWindowSeconds assignmentMethod assignmentAuthorityId classifierId taxonomyVersion processVersion modelVersion supportPoints counterPoints sealed
  use arg idArg, interventionKindArg, outcomeKindArg, desiredDirectionArg, roleArg, classificationArg, fromAtArg, toAtArg, observationDaysArg, eligibleArg, appliedArg, appliedOutcomeArg, notAppliedArg, notAppliedOutcomeArg, outcomeWindowSecondsArg=0, assignmentMethodArg="OBSERVATIONAL", assignmentAuthorityArg="UNSPECIFIED", classifierArg="UNSPECIFIED", taxonomyArg="UNSPECIFIED", processArg="UNSPECIFIED", modelArg="UNSPECIFIED", alchemySealerArg=.nil, alchemyAuthorityArg=.nil
  aggregateId=idArg~string
  interventionKind=.BrandInterventionEffectivenessCanonical~token(interventionKindArg)
  outcomeKind=.BrandInterventionEffectivenessCanonical~token(outcomeKindArg)
  desiredDirection=.BrandInterventionEffectivenessCanonical~token(desiredDirectionArg)
  outcomeRole=.BrandInterventionEffectivenessCanonical~token(roleArg)
  classification=.BrandInterventionEffectivenessCanonical~token(classificationArg)
  fromAt=fromAtArg~string; toAt=toAtArg~string; observationDays=observationDaysArg+0
  eligibleCount=eligibleArg+0; appliedCount=appliedArg+0; appliedOutcomeCount=appliedOutcomeArg+0; notAppliedCount=notAppliedArg+0; notAppliedOutcomeCount=notAppliedOutcomeArg+0
  outcomeWindowSeconds=outcomeWindowSecondsArg+0
  assignmentMethod=.BrandInterventionEffectivenessCanonical~token(assignmentMethodArg)
  assignmentAuthorityId=.BrandInterventionEffectivenessCanonical~token(assignmentAuthorityArg)
  classifierId=.BrandInterventionEffectivenessCanonical~token(classifierArg)
  taxonomyVersion=.BrandInterventionEffectivenessCanonical~token(taxonomyArg)
  processVersion=.BrandInterventionEffectivenessCanonical~token(processArg)
  modelVersion=.BrandInterventionEffectivenessCanonical~token(modelArg)
  supportPoints=.array~new; counterPoints=.array~new; sealed=.false
  if aggregateId="" | interventionKind="" | outcomeKind="" | classification="" | fromAt="" | toAt="" then raise syntax 88.971 array("effectiveness aggregate requires id/intervention/outcome/classification/time")
  self~initAlchemy(.BrandInterventionEffectivenessAlchemySupport~metadata("time-scoped applied versus eligible-not-applied intervention outcome counts"),alchemySealerArg,alchemyAuthorityArg)
  self~registerStateVariable("aggregateId","CUSTOMER","aggregate identifier")
  self~registerStateVariable("interventionKind","CUSTOMER","intervention under study")
  self~registerStateVariable("outcomeKind","CUSTOMER","outcome under study")
  self~registerStateVariable("desiredDirection","CUSTOMER","whether intervention ideally increases or decreases this outcome")
  self~registerStateVariable("outcomeRole","CUSTOMER","PRIMARY or GUARDRAIL")
  self~registerStateVariable("classification","CUSTOMER","eligible journey classification")
  self~registerStateVariable("fromAt","CUSTOMER","inclusive study start")
  self~registerStateVariable("toAt","CUSTOMER","inclusive study end")
  self~registerStateVariable("observationDays","CUSTOMER","study duration")
  self~registerStateVariable("eligibleCount","CUSTOMER","intervention-eligible denominator")
  self~registerStateVariable("appliedCount","CUSTOMER","eligible journeys where intervention was applied")
  self~registerStateVariable("appliedOutcomeCount","CUSTOMER","outcomes among applied journeys")
  self~registerStateVariable("notAppliedCount","CUSTOMER","eligible journeys where intervention was not applied")
  self~registerStateVariable("notAppliedOutcomeCount","CUSTOMER","outcomes among eligible not-applied journeys")
  self~registerStateVariable("outcomeWindowSeconds","CUSTOMER","allowed outcome lag")
  self~registerStateVariable("assignmentMethod","CUSTOMER","OBSERVATIONAL/RANDOMIZED/QUASI_EXPERIMENTAL study assignment provenance")
  self~registerStateVariable("assignmentAuthorityId","INTERNAL","authority/source describing assignment; not causal authority")
  self~registerStateVariable("classifierId","CUSTOMER","frozen classifier provenance")
  self~registerStateVariable("taxonomyVersion","CUSTOMER","frozen taxonomy provenance")
  self~registerStateVariable("processVersion","CUSTOMER","process/release cohort")
  self~registerStateVariable("modelVersion","CUSTOMER","agent/model release cohort")
  self~registerStateVariable("supportPoints","INTERNAL","privacy-safe supporting evidence points")
  self~registerStateVariable("counterPoints","INTERNAL","privacy-safe counterexample evidence points")
  self~registerStateVariable("sealed","CUSTOMER","aggregate immutability")
  self~registerInstrumentationPoint("BRAND.INTERVENTION.EFFECTIVENESS.AGGREGATE.SEALED","effectiveness aggregate sealed",.true,"ALL","INTERNAL")
::method addSupportPoint
  expose supportPoints sealed; use arg p
  if sealed | \.BrandInterventionEffectivenessCanonical~safePoint(p) then return .false
  if \.BrandInterventionEffectivenessCanonical~contains(supportPoints,p~string) then supportPoints~append(p~string)
  return .true
::method addCounterPoint
  expose counterPoints sealed; use arg p
  if sealed | \.BrandInterventionEffectivenessCanonical~safePoint(p) then return .false
  if \.BrandInterventionEffectivenessCanonical~contains(counterPoints,p~string) then counterPoints~append(p~string)
  return .true
::method supportPoints
  expose supportPoints; return .BrandInterventionEffectivenessCanonical~copyArray(supportPoints)
::method counterPoints
  expose counterPoints; return .BrandInterventionEffectivenessCanonical~copyArray(counterPoints)
::method appliedOutcomeRate
  expose appliedCount appliedOutcomeCount
  if appliedCount<=0 then return 0
  return 100*appliedOutcomeCount/appliedCount
::method notAppliedOutcomeRate
  expose notAppliedCount notAppliedOutcomeCount
  if notAppliedCount<=0 then return 0
  return 100*notAppliedOutcomeCount/notAppliedCount
::method observedRateDelta
  return self~appliedOutcomeRate-self~notAppliedOutcomeRate
::method desiredEffectPct
  expose desiredDirection
  if desiredDirection=.BrandInterventionEffectivenessConstant~DIRECTION_DECREASE then return self~notAppliedOutcomeRate-self~appliedOutcomeRate
  return self~appliedOutcomeRate-self~notAppliedOutcomeRate
::method seal
  expose desiredDirection outcomeRole fromAt toAt observationDays eligibleCount appliedCount appliedOutcomeCount notAppliedCount notAppliedOutcomeCount outcomeWindowSeconds assignmentMethod sealed
  if desiredDirection<>.BrandInterventionEffectivenessConstant~DIRECTION_INCREASE & desiredDirection<>.BrandInterventionEffectivenessConstant~DIRECTION_DECREASE then return .BrandInterventionEffectivenessResult~failure("DIRECTION_INVALID")
  if outcomeRole<>.BrandInterventionEffectivenessConstant~ROLE_PRIMARY & outcomeRole<>.BrandInterventionEffectivenessConstant~ROLE_GUARDRAIL then return .BrandInterventionEffectivenessResult~failure("OUTCOME_ROLE_INVALID")
  if assignmentMethod<>.BrandInterventionEffectivenessConstant~ASSIGNMENT_OBSERVATIONAL & assignmentMethod<>.BrandInterventionEffectivenessConstant~ASSIGNMENT_RANDOMIZED & assignmentMethod<>.BrandInterventionEffectivenessConstant~ASSIGNMENT_QUASI then return .BrandInterventionEffectivenessResult~failure("ASSIGNMENT_METHOD_INVALID")
  if observationDays<=0 | fromAt>toAt then return .BrandInterventionEffectivenessResult~failure("TIME_SCOPE_INVALID")
  if eligibleCount<0 | appliedCount<0 | notAppliedCount<0 | appliedOutcomeCount<0 | notAppliedOutcomeCount<0 | outcomeWindowSeconds<0 then return .BrandInterventionEffectivenessResult~failure("COUNT_OR_WINDOW_INVALID")
  if eligibleCount<>appliedCount+notAppliedCount then return .BrandInterventionEffectivenessResult~failure("ELIGIBLE_DENOMINATOR_MISMATCH")
  if appliedOutcomeCount>appliedCount | notAppliedOutcomeCount>notAppliedCount then return .BrandInterventionEffectivenessResult~failure("OUTCOME_COUNT_EXCEEDS_DENOMINATOR")
  sealed=.true; self~alchemyTouch("EFFECTIVENESS_AGGREGATE_SEAL"); self~alchemyInstrument("BRAND.INTERVENTION.EFFECTIVENESS.AGGREGATE.SEALED",self~pointId)
  return .BrandInterventionEffectivenessResult~success(self)
::method pointId
  expose aggregateId; return "BRAND_INTERVENTION:EFFECTIVENESS_AGGREGATE:"||aggregateId
::method canonicalText
  expose aggregateId interventionKind outcomeKind desiredDirection outcomeRole classification fromAt toAt observationDays eligibleCount appliedCount appliedOutcomeCount notAppliedCount notAppliedOutcomeCount outcomeWindowSeconds assignmentMethod assignmentAuthorityId classifierId taxonomyVersion processVersion modelVersion sealed
  if \sealed then raise syntax 93.971 additional("BrandInterventionEffectivenessAggregate must be sealed")
  out=.BrandInterventionEffectivenessCanonical~field("EFFECTIVENESS_AGGREGATE",aggregateId)
  out||=.BrandInterventionEffectivenessCanonical~field("INTERVENTION_KIND",interventionKind)
  out||=.BrandInterventionEffectivenessCanonical~field("OUTCOME_KIND",outcomeKind)
  out||=.BrandInterventionEffectivenessCanonical~field("DESIRED_DIRECTION",desiredDirection)
  out||=.BrandInterventionEffectivenessCanonical~field("OUTCOME_ROLE",outcomeRole)
  out||=.BrandInterventionEffectivenessCanonical~field("CLASSIFICATION",classification)
  out||=.BrandInterventionEffectivenessCanonical~field("FROM",fromAt)
  out||=.BrandInterventionEffectivenessCanonical~field("TO",toAt)
  out||=.BrandInterventionEffectivenessCanonical~field("OBSERVATION_DAYS",observationDays)
  out||=.BrandInterventionEffectivenessCanonical~field("ELIGIBLE_COUNT",eligibleCount)
  out||=.BrandInterventionEffectivenessCanonical~field("APPLIED_COUNT",appliedCount)
  out||=.BrandInterventionEffectivenessCanonical~field("APPLIED_OUTCOME_COUNT",appliedOutcomeCount)
  out||=.BrandInterventionEffectivenessCanonical~field("NOT_APPLIED_COUNT",notAppliedCount)
  out||=.BrandInterventionEffectivenessCanonical~field("NOT_APPLIED_OUTCOME_COUNT",notAppliedOutcomeCount)
  out||=.BrandInterventionEffectivenessCanonical~field("APPLIED_OUTCOME_RATE_PCT",self~appliedOutcomeRate)
  out||=.BrandInterventionEffectivenessCanonical~field("NOT_APPLIED_OUTCOME_RATE_PCT",self~notAppliedOutcomeRate)
  out||=.BrandInterventionEffectivenessCanonical~field("OBSERVED_RATE_DELTA_PCT",self~observedRateDelta)
  out||=.BrandInterventionEffectivenessCanonical~field("DESIRED_EFFECT_PCT",self~desiredEffectPct)
  out||=.BrandInterventionEffectivenessCanonical~field("OUTCOME_WINDOW_SECONDS",outcomeWindowSeconds)
  out||=.BrandInterventionEffectivenessCanonical~field("ASSIGNMENT_METHOD",assignmentMethod)
  out||=.BrandInterventionEffectivenessCanonical~field("ASSIGNMENT_AUTHORITY_ID",assignmentAuthorityId)
  out||=.BrandInterventionEffectivenessCanonical~field("CLASSIFIER_ID",classifierId)
  out||=.BrandInterventionEffectivenessCanonical~field("TAXONOMY_VERSION",taxonomyVersion)
  out||=.BrandInterventionEffectivenessCanonical~field("PROCESS_VERSION",processVersion)
  out||=.BrandInterventionEffectivenessCanonical~field("MODEL_VERSION",modelVersion)
  return out

::class BrandInterventionEffectivenessThreshold subclass AlchemyObject public
::attribute thresholdId get
::attribute minEligible get
::attribute minApplied get
::attribute minNotApplied get
::attribute minAppliedOutcomes get
::attribute minNotAppliedOutcomes get
::attribute minObservationDays get
::attribute minAbsoluteEffectPct get
::attribute minTotalOutcomes get
::attribute requireIntervalSeparation get
::method init
  expose thresholdId minEligible minApplied minNotApplied minAppliedOutcomes minNotAppliedOutcomes minObservationDays minAbsoluteEffectPct minTotalOutcomes requireIntervalSeparation
  use arg idArg="INTERVENTION-EFFECTIVENESS-V2", eligibleArg=1000, appliedArg=25, notAppliedArg=25, appliedOutcomeArg=0, notAppliedOutcomeArg=0, daysArg=14, effectArg=1, totalOutcomeArg=20, requireIntervalSeparationArg=.true
  thresholdId=idArg~string; minEligible=eligibleArg+0; minApplied=appliedArg+0; minNotApplied=notAppliedArg+0; minAppliedOutcomes=appliedOutcomeArg+0; minNotAppliedOutcomes=notAppliedOutcomeArg+0; minObservationDays=daysArg+0; minAbsoluteEffectPct=effectArg+0; minTotalOutcomes=totalOutcomeArg+0; requireIntervalSeparation=requireIntervalSeparationArg
  self~initAlchemy(.BrandInterventionEffectivenessAlchemySupport~metadata("explicit minimum evidence threshold for intervention outcome comparison"))
  self~registerStateVariable("thresholdId","CUSTOMER","threshold id")
  self~registerStateVariable("minEligible","CUSTOMER","minimum eligible journeys")
  self~registerStateVariable("minApplied","CUSTOMER","minimum applied journeys")
  self~registerStateVariable("minNotApplied","CUSTOMER","minimum eligible-not-applied controls")
  self~registerStateVariable("minAppliedOutcomes","CUSTOMER","minimum outcomes in applied arm")
  self~registerStateVariable("minNotAppliedOutcomes","CUSTOMER","minimum outcomes in control arm")
  self~registerStateVariable("minObservationDays","CUSTOMER","minimum time coverage")
  self~registerStateVariable("minAbsoluteEffectPct","CUSTOMER","minimum absolute percentage-point effect to call directional")
  self~registerStateVariable("minTotalOutcomes","CUSTOMER","minimum total outcome events across applied and eligible-not-applied arms")
  self~registerStateVariable("requireIntervalSeparation","CUSTOMER","whether directional association requires non-overlapping 95 percent Wilson intervals")
::method canonicalText
  expose thresholdId minEligible minApplied minNotApplied minAppliedOutcomes minNotAppliedOutcomes minObservationDays minAbsoluteEffectPct minTotalOutcomes requireIntervalSeparation
  out=.BrandInterventionEffectivenessCanonical~field("EFFECTIVENESS_THRESHOLD",thresholdId)
  out||=.BrandInterventionEffectivenessCanonical~field("MIN_ELIGIBLE",minEligible)
  out||=.BrandInterventionEffectivenessCanonical~field("MIN_APPLIED",minApplied)
  out||=.BrandInterventionEffectivenessCanonical~field("MIN_NOT_APPLIED",minNotApplied)
  out||=.BrandInterventionEffectivenessCanonical~field("MIN_APPLIED_OUTCOMES",minAppliedOutcomes)
  out||=.BrandInterventionEffectivenessCanonical~field("MIN_NOT_APPLIED_OUTCOMES",minNotAppliedOutcomes)
  out||=.BrandInterventionEffectivenessCanonical~field("MIN_OBSERVATION_DAYS",minObservationDays)
  out||=.BrandInterventionEffectivenessCanonical~field("MIN_ABSOLUTE_EFFECT_PCT",minAbsoluteEffectPct)
  out||=.BrandInterventionEffectivenessCanonical~field("MIN_TOTAL_OUTCOMES",minTotalOutcomes)
  out||=.BrandInterventionEffectivenessCanonical~field("REQUIRE_INTERVAL_SEPARATION",requireIntervalSeparation)
  return out

::class BrandInterventionEffectivenessUncertainty subclass AlchemyObject public
::attribute evidenceId get
::attribute appliedLower95 get
::attribute appliedUpper95 get
::attribute notAppliedLower95 get
::attribute notAppliedUpper95 get
::attribute intervalSeparation get
::attribute confidenceMethod get
::method init
  expose evidenceId appliedLower95 appliedUpper95 notAppliedLower95 notAppliedUpper95 intervalSeparation confidenceMethod
  use arg idArg, appliedN, appliedOutcome, notAppliedN, notAppliedOutcome
  evidenceId=idArg~string; a=self~wilson(appliedN,appliedOutcome); n=self~wilson(notAppliedN,notAppliedOutcome)
  appliedLower95=a[1]; appliedUpper95=a[2]; notAppliedLower95=n[1]; notAppliedUpper95=n[2]
  intervalSeparation=.false
  if appliedLower95>notAppliedUpper95 | notAppliedLower95>appliedUpper95 then intervalSeparation=.true
  confidenceMethod=.BrandInterventionEffectivenessConstant~CONFIDENCE_95
  self~initAlchemy(.BrandInterventionEffectivenessAlchemySupport~metadata("95 percent Wilson uncertainty around applied and eligible-not-applied outcome rates"))
  self~registerStateVariable("evidenceId","CUSTOMER","uncertainty evidence id")
  self~registerStateVariable("appliedLower95","CUSTOMER","applied outcome rate lower Wilson bound")
  self~registerStateVariable("appliedUpper95","CUSTOMER","applied outcome rate upper Wilson bound")
  self~registerStateVariable("notAppliedLower95","CUSTOMER","not-applied outcome rate lower Wilson bound")
  self~registerStateVariable("notAppliedUpper95","CUSTOMER","not-applied outcome rate upper Wilson bound")
  self~registerStateVariable("intervalSeparation","CUSTOMER","whether the 95 percent intervals are non-overlapping")
  self~registerStateVariable("confidenceMethod","CUSTOMER","uncertainty method")
::method wilson private
  use arg nArg,kArg
  out=.array~new; n=nArg+0; k=kArg+0
  if n<=0 then do; out~append(0); out~append(0); return out; end
  p=k/n; z=1.96; z2=z*z; den=1+z2/n; centre=(p+z2/(2*n))/den; variance=p*(1-p)/n+z2/(4*n*n); rad=z*self~sqrtNumber(variance)/den
  lo=100*(centre-rad); hi=100*(centre+rad); if lo<0 then lo=0; if hi>100 then hi=100
  out~append(lo); out~append(hi); return out
::method sqrtNumber private
  use arg value
  if value<=0 then return 0
  x=value; if x<1 then x=1
  do 20; x=(x+value/x)/2; end
  return x
::method canonicalText
  expose evidenceId appliedLower95 appliedUpper95 notAppliedLower95 notAppliedUpper95 intervalSeparation confidenceMethod
  out=.BrandInterventionEffectivenessCanonical~field("EFFECTIVENESS_UNCERTAINTY",evidenceId)
  out||=.BrandInterventionEffectivenessCanonical~field("CONFIDENCE_METHOD",confidenceMethod)
  out||=.BrandInterventionEffectivenessCanonical~field("APPLIED_OUTCOME_RATE_LOWER_95_PCT",appliedLower95)
  out||=.BrandInterventionEffectivenessCanonical~field("APPLIED_OUTCOME_RATE_UPPER_95_PCT",appliedUpper95)
  out||=.BrandInterventionEffectivenessCanonical~field("NOT_APPLIED_OUTCOME_RATE_LOWER_95_PCT",notAppliedLower95)
  out||=.BrandInterventionEffectivenessCanonical~field("NOT_APPLIED_OUTCOME_RATE_UPPER_95_PCT",notAppliedUpper95)
  out||=.BrandInterventionEffectivenessCanonical~field("INTERVAL_SEPARATION",intervalSeparation)
  return out

::class BrandInterventionEffectivenessAnalysis subclass AlchemyObject public
::attribute analysisId get
::attribute aggregate get
::attribute threshold get
::attribute uncertainty get
::attribute statisticalSufficient get
::attribute effectMaterial get
::attribute confidenceGate get
::attribute status get
::attribute causalStatus get
::method init
  expose analysisId aggregate threshold uncertainty statisticalSufficient effectMaterial confidenceGate status causalStatus reasons
  use arg idArg, aggregateArg, thresholdArg, uncertaintyArg, sufficientArg, materialArg, statusArg, confidenceArg=.true
  analysisId=idArg~string; aggregate=aggregateArg; threshold=thresholdArg; uncertainty=uncertaintyArg; statisticalSufficient=sufficientArg; effectMaterial=materialArg; confidenceGate=confidenceArg; status=.BrandInterventionEffectivenessCanonical~token(statusArg); causalStatus=.BrandInterventionEffectivenessConstant~CAUSAL_ASSOCIATION_ONLY; reasons=.array~new
  self~initAlchemy(.BrandInterventionEffectivenessAlchemySupport~metadata("bounded intervention effectiveness association analysis"))
  self~registerStateVariable("analysisId","CUSTOMER","analysis id")
  self~registerStateVariable("aggregate","INTERNAL","raw time-scoped aggregate")
  self~registerStateVariable("threshold","INTERNAL","evidence threshold")
  self~registerStateVariable("uncertainty","INTERNAL","rate uncertainty")
  self~registerStateVariable("statisticalSufficient","CUSTOMER","whether minimum denominators/events/time were met")
  self~registerStateVariable("effectMaterial","CUSTOMER","whether observed absolute effect met configured magnitude")
  self~registerStateVariable("confidenceGate","CUSTOMER","whether configured uncertainty gate permits directional association")
  self~registerStateVariable("status","CUSTOMER","directional association status")
  self~registerStateVariable("reasons","CUSTOMER","controlled evidence-gate reason codes")
  self~registerStateVariable("causalStatus","CUSTOMER","always association-only in this library")
  self~recordRelationship("USES",aggregate,"time-scoped intervention aggregate","INTERNAL")
  self~recordRelationship("GOVERNED_BY",threshold,"effectiveness evidence threshold","INTERNAL")
  self~recordRelationship("USES",uncertainty,"rate uncertainty evidence","INTERNAL")
::method addReason
  expose reasons
  use arg value
  t=.BrandInterventionEffectivenessCanonical~token(value); if t<>"" & \.BrandInterventionEffectivenessCanonical~contains(reasons,t) then reasons~append(t)
  return self
::method reasons
  expose reasons; return .BrandInterventionEffectivenessCanonical~copyArray(reasons)
::method canonicalText
  expose analysisId aggregate threshold uncertainty statisticalSufficient effectMaterial confidenceGate status causalStatus reasons
  out=.BrandInterventionEffectivenessCanonical~field("EFFECTIVENESS_ANALYSIS",analysisId)
  out||=.BrandInterventionEffectivenessCanonical~field("STATUS",status)
  out||=.BrandInterventionEffectivenessCanonical~field("STATISTICAL_SUFFICIENT",statisticalSufficient)
  out||=.BrandInterventionEffectivenessCanonical~field("EFFECT_MATERIAL",effectMaterial)
  out||=.BrandInterventionEffectivenessCanonical~field("CONFIDENCE_GATE",confidenceGate)
  out||=.BrandInterventionEffectivenessCanonical~field("CAUSAL_STATUS",causalStatus)
  out||=.BrandInterventionEffectivenessCanonical~join("REASON",reasons)
  out||=aggregate~canonicalText
  out||=threshold~canonicalText
  out||=uncertainty~canonicalText
  return out

::class BrandInterventionEffectivenessEngine public
::method analyze
  use arg aggregate, threshold=.nil
  if aggregate==.nil | \aggregate~sealed then return .BrandInterventionEffectivenessResult~failure("AGGREGATE_NOT_SEALED")
  if threshold==.nil then threshold=.BrandInterventionEffectivenessThreshold~new
  sufficient=.true
  if aggregate~eligibleCount<threshold~minEligible then sufficient=.false
  if aggregate~appliedCount<threshold~minApplied then sufficient=.false
  if aggregate~notAppliedCount<threshold~minNotApplied then sufficient=.false
  if aggregate~appliedOutcomeCount<threshold~minAppliedOutcomes then sufficient=.false
  if aggregate~notAppliedOutcomeCount<threshold~minNotAppliedOutcomes then sufficient=.false
  if aggregate~appliedOutcomeCount+aggregate~notAppliedOutcomeCount<threshold~minTotalOutcomes then sufficient=.false
  if aggregate~observationDays<threshold~minObservationDays then sufficient=.false
  material=.false
  if abs(aggregate~desiredEffectPct)>=threshold~minAbsoluteEffectPct then material=.true
  u=.BrandInterventionEffectivenessUncertainty~new("UNCERTAINTY-"||aggregate~aggregateId,aggregate~appliedCount,aggregate~appliedOutcomeCount,aggregate~notAppliedCount,aggregate~notAppliedOutcomeCount)
  confidence=.true
  if threshold~requireIntervalSeparation then confidence=u~intervalSeparation
  if \sufficient then status=.BrandInterventionEffectivenessConstant~STATUS_INSUFFICIENT
  else if \material then status=.BrandInterventionEffectivenessConstant~STATUS_NO_CLEAR
  else if \confidence then status=.BrandInterventionEffectivenessConstant~STATUS_NO_CLEAR
  else if aggregate~desiredEffectPct>0 then status=.BrandInterventionEffectivenessConstant~STATUS_PROMISING
  else status=.BrandInterventionEffectivenessConstant~STATUS_ADVERSE
  a=.BrandInterventionEffectivenessAnalysis~new("ANALYSIS-"||aggregate~aggregateId,aggregate,threshold,u,sufficient,material,status,confidence)
  if \sufficient then a~addReason("STATISTICAL_THRESHOLD_NOT_MET")
  if \material then a~addReason("EFFECT_BELOW_MATERIAL_THRESHOLD")
  if threshold~requireIntervalSeparation & \confidence then a~addReason("CONFIDENCE_INTERVALS_OVERLAP")
  return .BrandInterventionEffectivenessResult~success(a)

::class BrandInterventionEffectivenessStudy subclass AlchemyObject public
::attribute studyId get
::attribute primaryAnalysis get
::attribute status get
::attribute causalStatus get
::attribute sealed get
::method init
  expose studyId primaryAnalysis guardrailAnalyses status causalStatus supportPoints counterPoints confounders scopeExclusions permitted prohibited sealed
  use arg idArg, primaryArg
  studyId=idArg~string; primaryAnalysis=primaryArg; guardrailAnalyses=.array~new; supportPoints=.array~new; counterPoints=.array~new; confounders=.array~new; scopeExclusions=.array~new; permitted=.array~new; prohibited=.array~new; status=.BrandInterventionEffectivenessConstant~STATUS_REVIEW; causalStatus=.BrandInterventionEffectivenessConstant~CAUSAL_ASSOCIATION_ONLY; sealed=.false
  if studyId="" | primaryAnalysis==.nil then raise syntax 88.972 array("effectiveness study requires id and primary analysis")
  self~initAlchemy(.BrandInterventionEffectivenessAlchemySupport~metadata("multi-outcome intervention effectiveness study with guardrail outcomes and anti-overclaim bounds"))
  self~registerStateVariable("studyId","CUSTOMER","study id")
  self~registerStateVariable("primaryAnalysis","INTERNAL","primary target outcome analysis")
  self~registerStateVariable("guardrailAnalyses","INTERNAL","secondary outcomes that prevent one-metric optimisation")
  self~registerStateVariable("status","CUSTOMER","overall study status")
  self~registerStateVariable("causalStatus","CUSTOMER","association-only causal status")
  self~registerStateVariable("supportPoints","INTERNAL","supporting evidence points")
  self~registerStateVariable("counterPoints","INTERNAL","counterexample evidence points")
  self~registerStateVariable("confounders","CUSTOMER","controlled plausible confounder codes")
  self~registerStateVariable("scopeExclusions","CUSTOMER","where result must not be generalised")
  self~registerStateVariable("permitted","CUSTOMER","bounded interpretations supported by this study")
  self~registerStateVariable("prohibited","CUSTOMER","explicit overinterpretations")
  self~registerStateVariable("sealed","CUSTOMER","study immutability")
  self~recordRelationship("USES",primaryAnalysis,"primary intervention outcome analysis","INTERNAL")
::method addGuardrail
  expose guardrailAnalyses sealed; use arg analysis
  if sealed | analysis==.nil then return .false
  guardrailAnalyses~append(analysis); self~recordRelationship("GUARDRAIL",analysis,"guardrail outcome analysis","INTERNAL"); return .true
::method guardrails
  expose guardrailAnalyses; return .BrandInterventionEffectivenessCanonical~copyArray(guardrailAnalyses)
::method addSupportPoint
  expose supportPoints sealed; use arg p
  if sealed | \.BrandInterventionEffectivenessCanonical~safePoint(p) then return .false
  if \.BrandInterventionEffectivenessCanonical~contains(supportPoints,p~string) then supportPoints~append(p~string)
  return .true
::method addCounterPoint
  expose counterPoints sealed; use arg p
  if sealed | \.BrandInterventionEffectivenessCanonical~safePoint(p) then return .false
  if \.BrandInterventionEffectivenessCanonical~contains(counterPoints,p~string) then counterPoints~append(p~string)
  return .true
::method addConfounder
  expose confounders sealed; use arg v; if sealed then return .false
  t=.BrandInterventionEffectivenessCanonical~token(v); if t<>"" & \.BrandInterventionEffectivenessCanonical~contains(confounders,t) then confounders~append(t)
  return .true
::method addScopeExclusion
  expose scopeExclusions sealed; use arg v; if sealed then return .false
  t=.BrandInterventionEffectivenessCanonical~token(v); if t<>"" & \.BrandInterventionEffectivenessCanonical~contains(scopeExclusions,t) then scopeExclusions~append(t)
  return .true
::method permitInterpretation
  expose permitted sealed; use arg v; if sealed then return .false
  t=.BrandInterventionEffectivenessCanonical~token(v); if t<>"" & \.BrandInterventionEffectivenessCanonical~contains(permitted,t) then permitted~append(t)
  return .true
::method prohibitInterpretation
  expose prohibited sealed; use arg v; if sealed then return .false
  t=.BrandInterventionEffectivenessCanonical~token(v); if t<>"" & \.BrandInterventionEffectivenessCanonical~contains(prohibited,t) then prohibited~append(t)
  return .true
::method confounders
  expose confounders; return .BrandInterventionEffectivenessCanonical~copyArray(confounders)
::method seal
  expose primaryAnalysis guardrailAnalyses status supportPoints counterPoints confounders scopeExclusions permitted prohibited sealed
  if primaryAnalysis~aggregate~outcomeRole<>.BrandInterventionEffectivenessConstant~ROLE_PRIMARY then return .BrandInterventionEffectivenessResult~failure("PRIMARY_ROLE_REQUIRED")
  status=primaryAnalysis~status
  incompleteGuardrail=.false; adverseGuardrail=.false
  do g over guardrailAnalyses
    if g~aggregate~outcomeRole<>.BrandInterventionEffectivenessConstant~ROLE_GUARDRAIL then return .BrandInterventionEffectivenessResult~failure("GUARDRAIL_ROLE_REQUIRED")
    if g~status=.BrandInterventionEffectivenessConstant~STATUS_INSUFFICIENT then incompleteGuardrail=.true
    if g~status=.BrandInterventionEffectivenessConstant~STATUS_ADVERSE then adverseGuardrail=.true
  end
  if primaryAnalysis~status=.BrandInterventionEffectivenessConstant~STATUS_INSUFFICIENT then status=.BrandInterventionEffectivenessConstant~STATUS_INSUFFICIENT
  else if adverseGuardrail then do
    if primaryAnalysis~status=.BrandInterventionEffectivenessConstant~STATUS_PROMISING then status=.BrandInterventionEffectivenessConstant~STATUS_MIXED
    else status=.BrandInterventionEffectivenessConstant~STATUS_ADVERSE
  end
  else if incompleteGuardrail & primaryAnalysis~status=.BrandInterventionEffectivenessConstant~STATUS_PROMISING then status=.BrandInterventionEffectivenessConstant~STATUS_REVIEW
  if prohibited~items=0 then do
    prohibited~append("TREAT_OBSERVED_DIFFERENCE_AS_CAUSATION")
    prohibited~append("GENERALISE_BEYOND_ELIGIBLE_SCOPED_COHORT")
  end
  if permitted~items=0 then permitted~append("REASON_ABOUT_ASSOCIATION_WITHIN_DECLARED_COHORT_AND_TIME")
  if scopeExclusions~items=0 then scopeExclusions~append("JOURNEYS_WHERE_INTERVENTION_WAS_NOT_ELIGIBLE")
  if primaryAnalysis~aggregate~assignmentMethod=.BrandInterventionEffectivenessConstant~ASSIGNMENT_OBSERVATIONAL then do
    if \.BrandInterventionEffectivenessCanonical~contains(confounders,"INTERVENTION_SELECTION_BIAS") then confounders~append("INTERVENTION_SELECTION_BIAS")
  end
  sealed=.true
  return .BrandInterventionEffectivenessResult~success(self)
::method pointId
  expose studyId; return "BRAND_INTERVENTION:EFFECTIVENESS_STUDY:"||studyId
::method reasoningMaterial
  expose studyId primaryAnalysis guardrailAnalyses status causalStatus supportPoints counterPoints confounders scopeExclusions permitted prohibited sealed
  if \sealed then raise syntax 93.972 additional("BrandInterventionEffectivenessStudy must be sealed")
  out=.BrandInterventionEffectivenessCanonical~field("BRAND_INTERVENTION_EFFECTIVENESS_STUDY",studyId)
  out||=.BrandInterventionEffectivenessCanonical~field("STUDY_STATUS",status)
  out||=.BrandInterventionEffectivenessCanonical~field("CAUSAL_STATUS",causalStatus)
  out||=.BrandInterventionEffectivenessCanonical~field("PRIMARY_BEGIN",1)
  out||=primaryAnalysis~canonicalText
  out||=.BrandInterventionEffectivenessCanonical~field("PRIMARY_END",1)
  do g over guardrailAnalyses
    out||=.BrandInterventionEffectivenessCanonical~field("GUARDRAIL_BEGIN",g~analysisId)
    out||=g~canonicalText
    out||=.BrandInterventionEffectivenessCanonical~field("GUARDRAIL_END",g~analysisId)
  end
  out||=.BrandInterventionEffectivenessCanonical~join("SUPPORT_POINT",supportPoints)
  out||=.BrandInterventionEffectivenessCanonical~join("COUNTER_POINT",counterPoints)
  out||=.BrandInterventionEffectivenessCanonical~join("PLAUSIBLE_CONFOUNDER",confounders)
  out||=.BrandInterventionEffectivenessCanonical~join("SCOPE_EXCLUSION",scopeExclusions)
  out||=.BrandInterventionEffectivenessCanonical~join("PERMITTED_INTERPRETATION",permitted)
  out||=.BrandInterventionEffectivenessCanonical~join("PROHIBITED_INTERPRETATION",prohibited)
  return out

::class BrandInterventionEffectivenessTemporalReport subclass AlchemyObject public
::attribute reportId get
::attribute currentStudy get
::attribute previousStudy get
::attribute baselineStudy get
::attribute causalStatus get
::method init
  expose reportId currentStudy previousStudy baselineStudy causalStatus
  use arg idArg,currentArg,previousArg,baselineArg
  reportId=idArg~string; currentStudy=currentArg; previousStudy=previousArg; baselineStudy=baselineArg; causalStatus=.BrandInterventionEffectivenessConstant~CAUSAL_ASSOCIATION_ONLY
  self~initAlchemy(.BrandInterventionEffectivenessAlchemySupport~metadata("current/previous/baseline intervention effectiveness evidence preserving separate denominators and releases"))
  self~registerStateVariable("reportId","CUSTOMER","temporal effectiveness report id")
  self~registerStateVariable("currentStudy","INTERNAL","current time-scoped study")
  self~registerStateVariable("previousStudy","INTERNAL","previous comparable study")
  self~registerStateVariable("baselineStudy","INTERNAL","longer baseline study")
  self~registerStateVariable("causalStatus","CUSTOMER","association-only status")
  self~recordRelationship("USES",currentStudy,"current effectiveness study","INTERNAL")
  self~recordRelationship("COMPARES",previousStudy,"previous effectiveness study","INTERNAL")
  self~recordRelationship("COMPARES",baselineStudy,"baseline effectiveness study","INTERNAL")
::method primaryDesiredEffectDeltaCurrentPrevious
  expose currentStudy previousStudy
  return currentStudy~primaryAnalysis~aggregate~desiredEffectPct-previousStudy~primaryAnalysis~aggregate~desiredEffectPct
::method primaryDesiredEffectDeltaCurrentBaseline
  expose currentStudy baselineStudy
  return currentStudy~primaryAnalysis~aggregate~desiredEffectPct-baselineStudy~primaryAnalysis~aggregate~desiredEffectPct
::method reasoningMaterial
  expose reportId currentStudy previousStudy baselineStudy causalStatus
  out=.BrandInterventionEffectivenessCanonical~field("BRAND_INTERVENTION_EFFECTIVENESS_TEMPORAL_REPORT",reportId)
  out||=.BrandInterventionEffectivenessCanonical~field("CAUSAL_STATUS",causalStatus)
  out||=.BrandInterventionEffectivenessCanonical~field("CURRENT_BEGIN",1)||currentStudy~reasoningMaterial||.BrandInterventionEffectivenessCanonical~field("CURRENT_END",1)
  out||=.BrandInterventionEffectivenessCanonical~field("PREVIOUS_BEGIN",1)||previousStudy~reasoningMaterial||.BrandInterventionEffectivenessCanonical~field("PREVIOUS_END",1)
  out||=.BrandInterventionEffectivenessCanonical~field("LONG_BASELINE_BEGIN",1)||baselineStudy~reasoningMaterial||.BrandInterventionEffectivenessCanonical~field("LONG_BASELINE_END",1)
  out||=.BrandInterventionEffectivenessCanonical~field("CURRENT_V_PREVIOUS_PRIMARY_DESIRED_EFFECT_DELTA_PCT",self~primaryDesiredEffectDeltaCurrentPrevious)
  out||=.BrandInterventionEffectivenessCanonical~field("CURRENT_V_BASELINE_PRIMARY_DESIRED_EFFECT_DELTA_PCT",self~primaryDesiredEffectDeltaCurrentBaseline)
  out||=.BrandInterventionEffectivenessCanonical~field("PROHIBITED_INTERPRETATION","TEMPORAL_CHANGE_PROVES_INTERVENTION_CAUSATION")
  return out

::class BrandInterventionEffectivenessLibrary subclass AlchemyObject public
::method init
  expose studies temporalReports
  studies=.directory~new; temporalReports=.directory~new
  self~initAlchemy(.BrandInterventionEffectivenessAlchemySupport~metadata("registry of sealed privacy-minimised intervention effectiveness evidence"))
  self~registerStateVariable("studies","INTERNAL","effectiveness studies")
  self~registerStateVariable("temporalReports","INTERNAL","temporal effectiveness reports")
::method registerStudy
  expose studies; use arg s
  if s==.nil | \s~sealed then return .BrandInterventionEffectivenessResult~failure("STUDY_NOT_SEALED")
  if studies~hasIndex(s~studyId) then return .BrandInterventionEffectivenessResult~failure("STUDY_ALREADY_REGISTERED")
  studies[s~studyId]=s; self~recordRelationship("CONTAINS",s,"intervention effectiveness study","INTERNAL"); return .BrandInterventionEffectivenessResult~success(s)
::method registerTemporalReport
  expose temporalReports; use arg r
  if r==.nil then return .BrandInterventionEffectivenessResult~failure("TEMPORAL_REPORT_REQUIRED")
  if temporalReports~hasIndex(r~reportId) then return .BrandInterventionEffectivenessResult~failure("TEMPORAL_REPORT_ALREADY_REGISTERED")
  temporalReports[r~reportId]=r; self~recordRelationship("CONTAINS",r,"temporal intervention effectiveness report","INTERNAL"); return .BrandInterventionEffectivenessResult~success(r)
::method study
  expose studies; use arg idArg; return studies~at(idArg~string)
::method temporalReport
  expose temporalReports; use arg idArg; return temporalReports~at(idArg~string)

::requires "BrandIntervention.cls"
