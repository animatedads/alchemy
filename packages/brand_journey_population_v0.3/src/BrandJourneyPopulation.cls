/*
 * Brand Journey Population v0.3
 *
 * Privacy-minimised population / longitudinal evidence over Brand Journey.
 * This package deliberately analyses frozen journey residue, not raw customer
 * conversations and not CRM identity.  It gives a reasoning LLM denominators,
 * time scope, cohort selection, uncertainty, supporting/counter evidence and
 * explicit anti-overclaim boundaries.
 */

::class BrandJourneyPopulationBuild public
::constant VERSION "0.3"
::constant API_VERSION "brand.journey.population/0.3"
::constant PRODUCT "ooRexx Brand Journey Population"

::class BrandJourneyPopulationAlchemySupport public
::method metadata class
  use arg purposeArg
  d=.directory~new
  d["purpose"]=purposeArg~string
  d["package_version"]=.BrandJourneyPopulationBuild~VERSION
  d["api_version"]=.BrandJourneyPopulationBuild~API_VERSION
  d["component"]="BRAND_JOURNEY_POPULATION"
  return d

::class BrandJourneyPopulationConstant public
::constant ROLE_CURRENT "CURRENT"
::constant ROLE_PREVIOUS "PREVIOUS"
::constant ROLE_BASELINE "LONG_BASELINE"
::constant ANY "ANY"

::constant OUTCOME_ABANDONMENT "ABANDONMENT"
::constant OUTCOME_COMMERCIAL_EXIT "COMMERCIAL_EXIT"
::constant OUTCOME_RELATIONSHIP_PRESERVED "RELATIONSHIP_PRESERVED"

::constant MOD_RECOVERY_ACROSS_DOMAIN "SERVICE_RECOVERY_ACROSS_DOMAIN"
::constant MOD_RELATIONSHIP_PRESERVED "RELATIONSHIP_PRESERVED_ACROSS_TOUCHPOINTS"

::constant CONFIDENCE_95 "WILSON_95"
::constant CAUSAL_ASSOCIATION_ONLY "ASSOCIATION_ONLY"

::class BrandJourneyPopulationResult public
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

::class BrandJourneyPopulationCanonical public
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
  use arg values, wanted
  if values==.nil then return .false
  do x over values
    if x~string == wanted~string then return .true
  end
  return .false
::method field class
  use arg name,value
  return name~string || "=" || value~string || '0a'x
::method join class
  use arg name,values
  out=""
  if values==.nil then return out
  do x over values; out ||= self~field(name,x); end
  return out
::method clamp class
  use arg value
  n=value+0
  if n<0 then return 0
  if n>100 then return 100
  return n
::method inWindow class
  use arg atValue, fromValue, toValue
  /* Input timestamps are required to be sortable ISO-8601 strings. */
  a=atValue~string; f=fromValue~string; t=toValue~string
  if a="" | f="" | t="" then return .false
  return a>=f & a<=t
::method safePoint class
  use arg value
  if value==.nil then return .false
  p=value~string~strip
  if p="" then return .false
  if p~pos(" ")>0 | p~pos('09'x)>0 | p~pos('0a'x)>0 | p~pos('0d'x)>0 then return .false
  if p~caselessPos("BRAND_JOURNEY:")=1 then return .true
  if p~caselessPos("BRAND_INTERACTION:")=1 then return .true
  if p~caselessPos("INTERACTION_EVENT:")=1 then return .true
  if p~caselessPos("STRUCTURED_UTTERANCE:")=1 then return .true
  return .false

/* One privacy-minimised journey-level observation.  No raw transcript or
   customer identity is accepted.  The observation carries only controlled
   journey findings, outcome state, version provenance and evidence points. */
::class BrandJourneyPopulationObservation subclass AlchemyObject public
::attribute observationId get
::attribute journeyPoint get
::attribute occurredAt get
::attribute classification get
::attribute outcomeKind get
::attribute outcomeOccurred get
::attribute outcomeLagSeconds get
::attribute classifierId get
::attribute taxonomyVersion get
::attribute processVersion get
::attribute modelVersion get
::attribute materialityScore get
::attribute commercialValueAtRisk get
::attribute sealed get
::method init
  expose observationId journeyPoint occurredAt classification outcomeKind outcomeOccurred outcomeLagSeconds classifierId taxonomyVersion processVersion modelVersion materialityScore commercialValueAtRisk exposures modifiers evidencePoints sealed
  use arg idArg, journeyPointArg, occurredAtArg, classificationArg, outcomeKindArg, outcomeOccurredArg=.false, outcomeLagSecondsArg=0, classifierIdArg="UNSPECIFIED", taxonomyVersionArg="UNSPECIFIED", processVersionArg="UNSPECIFIED", modelVersionArg="UNSPECIFIED", alchemySealerArg=.nil, alchemyAuthorityArg=.nil
  observationId=idArg~string
  journeyPoint=journeyPointArg~string
  occurredAt=occurredAtArg~string
  classification=.BrandJourneyPopulationCanonical~token(classificationArg)
  outcomeKind=.BrandJourneyPopulationCanonical~token(outcomeKindArg)
  outcomeOccurred=outcomeOccurredArg
  outcomeLagSeconds=outcomeLagSecondsArg+0
  classifierId=.BrandJourneyPopulationCanonical~token(classifierIdArg)
  taxonomyVersion=.BrandJourneyPopulationCanonical~token(taxonomyVersionArg)
  processVersion=.BrandJourneyPopulationCanonical~token(processVersionArg)
  modelVersion=.BrandJourneyPopulationCanonical~token(modelVersionArg)
  materialityScore=0
  commercialValueAtRisk=0
  exposures=.array~new; modifiers=.array~new; evidencePoints=.array~new; sealed=.false
  if observationId="" | journeyPoint="" | occurredAt="" | classification="" | outcomeKind="" then raise syntax 88.980 array("BrandJourneyPopulationObservation requires id, journey point, time, classification and outcome kind")
  if \.BrandJourneyPopulationCanonical~safePoint(journeyPoint) then raise syntax 88.980 array("journeyPoint must be an opaque stable evidence point, not prose/customer data")
  self~initAlchemy(.BrandJourneyPopulationAlchemySupport~metadata("privacy-minimised journey observation for cohort/statistical reasoning"),alchemySealerArg,alchemyAuthorityArg)
  self~registerStateVariable("observationId","CUSTOMER","population-local observation id")
  self~registerStateVariable("journeyPoint","INTERNAL","upstream privacy-minimised journey evidence point")
  self~registerStateVariable("occurredAt","CUSTOMER","sortable ISO-8601 observation timestamp")
  self~registerStateVariable("classification","CUSTOMER","comparable journey classification")
  self~registerStateVariable("outcomeKind","CUSTOMER","controlled outcome kind")
  self~registerStateVariable("outcomeOccurred","CUSTOMER","whether measured outcome occurred")
  self~registerStateVariable("outcomeLagSeconds","CUSTOMER","time from journey exposure/reference point to outcome")
  self~registerStateVariable("classifierId","CUSTOMER","frozen classifier provenance")
  self~registerStateVariable("taxonomyVersion","CUSTOMER","frozen taxonomy provenance")
  self~registerStateVariable("processVersion","CUSTOMER","process/release cohort provenance")
  self~registerStateVariable("modelVersion","CUSTOMER","agent/model cohort provenance")
  self~registerStateVariable("exposures","CUSTOMER","controlled journey feature exposures")
  self~registerStateVariable("modifiers","CUSTOMER","controlled recovery/context modifiers")
  self~registerStateVariable("materialityScore","CUSTOMER","material significance independent of statistical support")
  self~registerStateVariable("commercialValueAtRisk","INTERNAL","bounded commercial value; never customer-safe")
  self~registerStateVariable("evidencePoints","INTERNAL","supporting privacy-minimised evidence points")
  self~registerStateVariable("sealed","CUSTOMER","observation immutability")
  self~registerInstrumentationPoint("BRAND.JOURNEY.POPULATION.OBSERVATION.SEALED","journey population observation sealed",.true,"ALL","INTERNAL")
  self~registerMethodContract("SEAL","validate and seal journey population observation",.array~new,"BRANDJOURNEYPOPULATIONRESULT",.false,"AUTO","CUSTOMER","NORMAL","MUTATE","NONE")
::method addExposure
  expose exposures sealed
  use arg value
  if sealed then return .false
  t=.BrandJourneyPopulationCanonical~token(value); if t="" then return .false
  if \.BrandJourneyPopulationCanonical~contains(exposures,t) then exposures~append(t)
  return .true
::method addModifier
  expose modifiers sealed
  use arg value
  if sealed then return .false
  t=.BrandJourneyPopulationCanonical~token(value); if t="" then return .false
  if \.BrandJourneyPopulationCanonical~contains(modifiers,t) then modifiers~append(t)
  return .true
::method addEvidencePoint
  expose evidencePoints sealed
  use arg value
  if sealed | value~string="" then return .false
  if \.BrandJourneyPopulationCanonical~safePoint(value) then return .false
  if \.BrandJourneyPopulationCanonical~contains(evidencePoints,value~string) then evidencePoints~append(value~string)
  return .true
::method setMateriality
  expose materialityScore commercialValueAtRisk sealed
  use arg scoreArg, commercialValueArg=0
  if sealed then return .false
  materialityScore=.BrandJourneyPopulationCanonical~clamp(scoreArg)
  if datatype(commercialValueArg,"N") & commercialValueArg>=0 then commercialValueAtRisk=commercialValueArg+0
  return .true
::method exposures
  expose exposures; return .BrandJourneyPopulationCanonical~copyArray(exposures)
::method modifiers
  expose modifiers; return .BrandJourneyPopulationCanonical~copyArray(modifiers)
::method evidencePoints
  expose evidencePoints; return .BrandJourneyPopulationCanonical~copyArray(evidencePoints)
::method hasExposure
  expose exposures; use arg value; return .BrandJourneyPopulationCanonical~contains(exposures,.BrandJourneyPopulationCanonical~token(value))
::method hasModifier
  expose modifiers; use arg value; return .BrandJourneyPopulationCanonical~contains(modifiers,.BrandJourneyPopulationCanonical~token(value))
::method seal
  expose outcomeOccurred outcomeLagSeconds sealed
  if outcomeLagSeconds<0 then return .BrandJourneyPopulationResult~failure("OUTCOME_LAG_INVALID")
  sealed=.true
  self~alchemyTouch("OBSERVATION_SEAL")
  self~alchemyInstrument("BRAND.JOURNEY.POPULATION.OBSERVATION.SEALED",self~pointId)
  return .BrandJourneyPopulationResult~success(self)
::method pointId
  expose observationId; return "BRAND_JOURNEY:POPULATION_OBSERVATION:"||observationId
::method canonicalText
  expose observationId journeyPoint occurredAt classification outcomeKind outcomeOccurred outcomeLagSeconds classifierId taxonomyVersion processVersion modelVersion materialityScore exposures modifiers sealed
  if \sealed then raise syntax 93.980 additional("BrandJourneyPopulationObservation must be sealed")
  out=.BrandJourneyPopulationCanonical~field("OBSERVATION",observationId)
  out||=.BrandJourneyPopulationCanonical~field("JOURNEY_POINT",journeyPoint)
  out||=.BrandJourneyPopulationCanonical~field("OCCURRED_AT",occurredAt)
  out||=.BrandJourneyPopulationCanonical~field("CLASSIFICATION",classification)
  out||=.BrandJourneyPopulationCanonical~field("OUTCOME_KIND",outcomeKind)
  out||=.BrandJourneyPopulationCanonical~field("OUTCOME_OCCURRED",outcomeOccurred)
  out||=.BrandJourneyPopulationCanonical~field("OUTCOME_LAG_SECONDS",outcomeLagSeconds)
  out||=.BrandJourneyPopulationCanonical~field("CLASSIFIER_ID",classifierId)
  out||=.BrandJourneyPopulationCanonical~field("TAXONOMY_VERSION",taxonomyVersion)
  out||=.BrandJourneyPopulationCanonical~field("PROCESS_VERSION",processVersion)
  out||=.BrandJourneyPopulationCanonical~field("MODEL_VERSION",modelVersion)
  out||=.BrandJourneyPopulationCanonical~field("MATERIALITY_SCORE",materialityScore)
  out||=.BrandJourneyPopulationCanonical~join("EXPOSURE",exposures)
  out||=.BrandJourneyPopulationCanonical~join("MODIFIER",modifiers)
  return out

/* Explicit cohort definition.  A denominator has no meaning without its time
   scope and classifier/taxonomy/version provenance. */
::class BrandJourneyCohortDefinition subclass AlchemyObject public
::attribute cohortId get
::attribute role get
::attribute classification get
::attribute fromAt get
::attribute toAt get
::attribute observationDays get
::attribute featureCode get
::attribute outcomeKind get
::attribute outcomeWindowSeconds get
::attribute classifierId get
::attribute taxonomyVersion get
::attribute processVersion get
::attribute modelVersion get
::attribute sourceKind get
::attribute sourceSystem get
::attribute unitKind get
::attribute selectionRuleId get
::attribute samplingMethod get
::attribute inclusionPolicyId get
::attribute exclusionPolicyId get
::attribute deduplicationMethod get
::attribute dedupKeyKind get
::attribute outcomeAscertainmentId get
::attribute sealed get
::method init
  expose cohortId role classification fromAt toAt observationDays featureCode outcomeKind outcomeWindowSeconds classifierId taxonomyVersion processVersion modelVersion sourceKind sourceSystem unitKind selectionRuleId samplingMethod inclusionPolicyId exclusionPolicyId deduplicationMethod dedupKeyKind outcomeAscertainmentId sealed
  use arg idArg, roleArg, classificationArg, fromAtArg, toAtArg, observationDaysArg, featureArg, outcomeKindArg, outcomeWindowSecondsArg=0, classifierIdArg="ANY", taxonomyVersionArg="ANY", processVersionArg="ANY", modelVersionArg="ANY", alchemySealerArg=.nil, alchemyAuthorityArg=.nil
  cohortId=idArg~string
  role=.BrandJourneyPopulationCanonical~token(roleArg)
  classification=.BrandJourneyPopulationCanonical~token(classificationArg)
  fromAt=fromAtArg~string; toAt=toAtArg~string
  observationDays=observationDaysArg+0
  featureCode=.BrandJourneyPopulationCanonical~token(featureArg)
  outcomeKind=.BrandJourneyPopulationCanonical~token(outcomeKindArg)
  outcomeWindowSeconds=outcomeWindowSecondsArg+0
  classifierId=.BrandJourneyPopulationCanonical~token(classifierIdArg)
  taxonomyVersion=.BrandJourneyPopulationCanonical~token(taxonomyVersionArg)
  processVersion=.BrandJourneyPopulationCanonical~token(processVersionArg)
  modelVersion=.BrandJourneyPopulationCanonical~token(modelVersionArg)
  /* v0.3 splits provenance by ownership.  Cohort-local selection and outcome
     rules are known here; upstream source/sampling/deduplication facts are not.
     Legacy configureProvenance() remains supported, but UNKNOWN upstream facts
     stay UNSPECIFIED until the population or caller supplies them. */
  sourceKind="UNSPECIFIED"
  sourceSystem="UNSPECIFIED"
  unitKind="UNSPECIFIED"
  selectionRuleId="JOURNEY_COHORT_DEFINITION_V3"
  samplingMethod="UNSPECIFIED"
  inclusionPolicyId="MATCH_TIME_CLASSIFICATION_FEATURE_OUTCOME_AND_VERSION_SCOPE"
  exclusionPolicyId="EXCLUDE_SCOPE_SCHEMA_AND_INDIVISIBLE_PARTIAL_BUCKET"
  deduplicationMethod="UNSPECIFIED"
  dedupKeyKind="UNSPECIFIED"
  outcomeAscertainmentId="DECLARED_OUTCOME_WITHIN_LAG_WINDOW"
  sealed=.false
  if cohortId="" | role="" | classification="" | fromAt="" | toAt="" | featureCode="" | outcomeKind="" then raise syntax 88.981 array("BrandJourneyCohortDefinition requires id, role, classification, time, feature and outcome")
  self~initAlchemy(.BrandJourneyPopulationAlchemySupport~metadata("explicit time/version-scoped journey cohort definition with cohort-construction provenance"),alchemySealerArg,alchemyAuthorityArg)
  self~registerStateVariable("cohortId","CUSTOMER","cohort definition identifier")
  self~registerStateVariable("role","CUSTOMER","CURRENT/PREVIOUS/LONG_BASELINE role")
  self~registerStateVariable("classification","CUSTOMER","journey population classification")
  self~registerStateVariable("fromAt","CUSTOMER","inclusive cohort start")
  self~registerStateVariable("toAt","CUSTOMER","inclusive cohort end")
  self~registerStateVariable("observationDays","CUSTOMER","declared duration of cohort")
  self~registerStateVariable("featureCode","CUSTOMER","journey exposure under study")
  self~registerStateVariable("outcomeKind","CUSTOMER","outcome under study")
  self~registerStateVariable("outcomeWindowSeconds","CUSTOMER","allowed lag from exposure/reference to outcome")
  self~registerStateVariable("classifierId","CUSTOMER","required frozen classifier or ANY")
  self~registerStateVariable("taxonomyVersion","CUSTOMER","required taxonomy or ANY")
  self~registerStateVariable("processVersion","CUSTOMER","required process/release or ANY")
  self~registerStateVariable("modelVersion","CUSTOMER","required agent/model release or ANY")
  self~registerStateVariable("sourceKind","CUSTOMER","cohort source kind")
  self~registerStateVariable("sourceSystem","CUSTOMER","cohort source system")
  self~registerStateVariable("unitKind","CUSTOMER","analysis unit kind")
  self~registerStateVariable("selectionRuleId","CUSTOMER","explicit selection rule id")
  self~registerStateVariable("samplingMethod","CUSTOMER","sampling/selection method")
  self~registerStateVariable("inclusionPolicyId","CUSTOMER","inclusion policy id")
  self~registerStateVariable("exclusionPolicyId","CUSTOMER","exclusion policy id")
  self~registerStateVariable("deduplicationMethod","CUSTOMER","deduplication method")
  self~registerStateVariable("dedupKeyKind","CUSTOMER","deduplication key kind")
  self~registerStateVariable("outcomeAscertainmentId","CUSTOMER","outcome ascertainment rule id")
  self~registerStateVariable("sealed","CUSTOMER","cohort immutability")
  self~registerInstrumentationPoint("BRAND.JOURNEY.POPULATION.COHORT.SEALED","journey cohort definition sealed",.true,"ALL","INTERNAL")
  self~registerMethodContract("CONFIGUREPROVENANCE","legacy full cohort provenance override before seal",.array~of("SOURCE_KIND","SOURCE_SYSTEM","UNIT_KIND","SELECTION_RULE_ID","SAMPLING_METHOD"),"BRANDJOURNEYPOPULATIONRESULT",.false,"AUTO","INTERNAL","NORMAL","MUTATE","NONE")
  self~registerMethodContract("CONFIGURESELECTIONPROVENANCE","declare cohort-local selection/inclusion/exclusion/outcome rules without asserting upstream source provenance",.array~of("SELECTION_RULE_ID","INCLUSION_POLICY_ID","EXCLUSION_POLICY_ID","OUTCOME_ASCERTAINMENT_ID"),"BRANDJOURNEYPOPULATIONRESULT",.false,"AUTO","INTERNAL","NORMAL","MUTATE","NONE")
::method configureProvenance
  expose sourceKind sourceSystem unitKind selectionRuleId samplingMethod inclusionPolicyId exclusionPolicyId deduplicationMethod dedupKeyKind outcomeAscertainmentId sealed
  use arg sourceKindArg, sourceSystemArg, unitKindArg, selectionRuleArg, samplingArg, inclusionPolicyArg="UNSPECIFIED", exclusionPolicyArg="UNSPECIFIED", dedupMethodArg="OPAQUE_UNIT_KEY", dedupKeyKindArg="BRAND_JOURNEY_UNIT_KEY", outcomeAscertainmentArg="DECLARED_OUTCOME_WITHIN_LAG_WINDOW"
  if sealed then return .BrandJourneyPopulationResult~failure("COHORT_ALREADY_SEALED")
  sk=.BrandJourneyPopulationCanonical~token(sourceKindArg); ss=.BrandJourneyPopulationCanonical~token(sourceSystemArg); uk=.BrandJourneyPopulationCanonical~token(unitKindArg)
  sr=.BrandJourneyPopulationCanonical~token(selectionRuleArg); sm=.BrandJourneyPopulationCanonical~token(samplingArg)
  ip=.BrandJourneyPopulationCanonical~token(inclusionPolicyArg); ep=.BrandJourneyPopulationCanonical~token(exclusionPolicyArg)
  dm=.BrandJourneyPopulationCanonical~token(dedupMethodArg); dk=.BrandJourneyPopulationCanonical~token(dedupKeyKindArg); oa=.BrandJourneyPopulationCanonical~token(outcomeAscertainmentArg)
  if sk="" | ss="" | uk="" | sr="" | sm="" | ip="" | ep="" | dm="" | dk="" | oa="" then return .BrandJourneyPopulationResult~failure("COHORT_PROVENANCE_INVALID")
  sourceKind=sk; sourceSystem=ss; unitKind=uk; selectionRuleId=sr; samplingMethod=sm; inclusionPolicyId=ip; exclusionPolicyId=ep; deduplicationMethod=dm; dedupKeyKind=dk; outcomeAscertainmentId=oa
  self~alchemyTouch("CONFIGURE_PROVENANCE")
  return .BrandJourneyPopulationResult~success(self)
::method configureSelectionProvenance
  expose selectionRuleId inclusionPolicyId exclusionPolicyId outcomeAscertainmentId sealed
  use arg selectionRuleArg, inclusionPolicyArg, exclusionPolicyArg, outcomeAscertainmentArg="DECLARED_OUTCOME_WITHIN_LAG_WINDOW"
  if sealed then return .BrandJourneyPopulationResult~failure("COHORT_ALREADY_SEALED")
  sr=.BrandJourneyPopulationCanonical~token(selectionRuleArg); ip=.BrandJourneyPopulationCanonical~token(inclusionPolicyArg); ep=.BrandJourneyPopulationCanonical~token(exclusionPolicyArg); oa=.BrandJourneyPopulationCanonical~token(outcomeAscertainmentArg)
  if sr="" | ip="" | ep="" | oa="" then return .BrandJourneyPopulationResult~failure("COHORT_SELECTION_PROVENANCE_INVALID")
  selectionRuleId=sr; inclusionPolicyId=ip; exclusionPolicyId=ep; outcomeAscertainmentId=oa
  self~alchemyTouch("CONFIGURE_SELECTION_PROVENANCE")
  return .BrandJourneyPopulationResult~success(self)
::method seal
  expose observationDays outcomeWindowSeconds fromAt toAt sourceKind sourceSystem unitKind selectionRuleId samplingMethod inclusionPolicyId exclusionPolicyId deduplicationMethod dedupKeyKind outcomeAscertainmentId sealed
  if observationDays<=0 then return .BrandJourneyPopulationResult~failure("COHORT_TIME_SCOPE_REQUIRED")
  if outcomeWindowSeconds<0 then return .BrandJourneyPopulationResult~failure("COHORT_OUTCOME_WINDOW_INVALID")
  if fromAt>toAt then return .BrandJourneyPopulationResult~failure("COHORT_TIME_RANGE_INVALID")
  if sourceKind="" | sourceSystem="" | unitKind="" | selectionRuleId="" | samplingMethod="" | inclusionPolicyId="" | exclusionPolicyId="" | deduplicationMethod="" | dedupKeyKind="" | outcomeAscertainmentId="" then return .BrandJourneyPopulationResult~failure("COHORT_PROVENANCE_REQUIRED")
  sealed=.true
  self~alchemyTouch("COHORT_SEAL")
  self~alchemyInstrument("BRAND.JOURNEY.POPULATION.COHORT.SEALED",self~pointId)
  return .BrandJourneyPopulationResult~success(self)
::method pointId
  expose cohortId; return "BRAND_JOURNEY:COHORT:"||cohortId
::method canonicalText
  expose cohortId role classification fromAt toAt observationDays featureCode outcomeKind outcomeWindowSeconds classifierId taxonomyVersion processVersion modelVersion sourceKind sourceSystem unitKind selectionRuleId samplingMethod inclusionPolicyId exclusionPolicyId deduplicationMethod dedupKeyKind outcomeAscertainmentId sealed
  if \sealed then raise syntax 93.981 additional("BrandJourneyCohortDefinition must be sealed")
  out=.BrandJourneyPopulationCanonical~field("COHORT",cohortId)
  out||=.BrandJourneyPopulationCanonical~field("ROLE",role)
  out||=.BrandJourneyPopulationCanonical~field("CLASSIFICATION",classification)
  out||=.BrandJourneyPopulationCanonical~field("FROM",fromAt)
  out||=.BrandJourneyPopulationCanonical~field("TO",toAt)
  out||=.BrandJourneyPopulationCanonical~field("OBSERVATION_DAYS",observationDays)
  out||=.BrandJourneyPopulationCanonical~field("FEATURE",featureCode)
  out||=.BrandJourneyPopulationCanonical~field("OUTCOME",outcomeKind)
  out||=.BrandJourneyPopulationCanonical~field("OUTCOME_WINDOW_SECONDS",outcomeWindowSeconds)
  out||=.BrandJourneyPopulationCanonical~field("CLASSIFIER_ID",classifierId)
  out||=.BrandJourneyPopulationCanonical~field("TAXONOMY_VERSION",taxonomyVersion)
  out||=.BrandJourneyPopulationCanonical~field("PROCESS_VERSION",processVersion)
  out||=.BrandJourneyPopulationCanonical~field("MODEL_VERSION",modelVersion)
  out||=.BrandJourneyPopulationCanonical~field("SELECTION_RULE_ID",selectionRuleId)
  out||=.BrandJourneyPopulationCanonical~field("INCLUSION_POLICY_ID",inclusionPolicyId)
  out||=.BrandJourneyPopulationCanonical~field("EXCLUSION_POLICY_ID",exclusionPolicyId)
  out||=.BrandJourneyPopulationCanonical~field("OUTCOME_ASCERTAINMENT_ID",outcomeAscertainmentId)
  /* Legacy full-provenance overrides remain available for compatibility but are
     labelled as overrides so they cannot be confused with effective composed
     population provenance in downstream reasoning material. */
  if sourceKind<>"UNSPECIFIED" then out||=.BrandJourneyPopulationCanonical~field("LEGACY_SOURCE_KIND_OVERRIDE",sourceKind)
  if sourceSystem<>"UNSPECIFIED" then out||=.BrandJourneyPopulationCanonical~field("LEGACY_SOURCE_SYSTEM_OVERRIDE",sourceSystem)
  if unitKind<>"UNSPECIFIED" then out||=.BrandJourneyPopulationCanonical~field("LEGACY_UNIT_KIND_OVERRIDE",unitKind)
  if samplingMethod<>"UNSPECIFIED" then out||=.BrandJourneyPopulationCanonical~field("LEGACY_SAMPLING_METHOD_OVERRIDE",samplingMethod)
  if deduplicationMethod<>"UNSPECIFIED" then out||=.BrandJourneyPopulationCanonical~field("LEGACY_DEDUPLICATION_METHOD_OVERRIDE",deduplicationMethod)
  if dedupKeyKind<>"UNSPECIFIED" then out||=.BrandJourneyPopulationCanonical~field("LEGACY_DEDUP_KEY_KIND_OVERRIDE",dedupKeyKind)
  return out


/* Pre-aggregated bucket for large populations.  This prevents a 29,234-row
   statistical report from requiring 29,234 live ooRexx objects when the source
   system can already produce privacy-safe grouped counts.  A bucket must be
   wholly inside a cohort window; partial overlap is rejected rather than
   silently prorated. */
::class BrandJourneyPopulationAggregateBucket subclass AlchemyObject public
::attribute bucketId get
::attribute fromAt get
::attribute toAt get
::attribute classification get
::attribute featureCode get
::attribute outcomeKind get
::attribute classifierId get
::attribute taxonomyVersion get
::attribute processVersion get
::attribute modelVersion get
::attribute outcomeWindowSeconds get
::attribute populationCount get
::attribute outcomeCount get
::attribute exposedCount get
::attribute exposedOutcomeCount get
::attribute modifierCode get
::attribute exposedWithModifierCount get
::attribute exposedWithModifierOutcomeCount get
::attribute materialityScore get
::attribute materialOutcomeCount get
::attribute commercialValueAtRisk get
::attribute sealed get
::method init
  expose bucketId fromAt toAt classification featureCode outcomeKind classifierId taxonomyVersion processVersion modelVersion outcomeWindowSeconds populationCount outcomeCount exposedCount exposedOutcomeCount modifierCode exposedWithModifierCount exposedWithModifierOutcomeCount materialityScore materialOutcomeCount commercialValueAtRisk supportPoints counterPoints sealed
  use arg idArg, fromArg, toArg, classificationArg, featureArg, outcomeArg, populationArg, outcomeCountArg, exposedArg, exposedOutcomeArg, classifierArg="ANY", taxonomyArg="ANY", processArg="ANY", modelArg="ANY", outcomeWindowArg=0, modifierArg="", withModifierArg=0, withModifierOutcomeArg=0, alchemySealerArg=.nil, alchemyAuthorityArg=.nil
  bucketId=idArg~string; fromAt=fromArg~string; toAt=toArg~string
  classification=.BrandJourneyPopulationCanonical~token(classificationArg); featureCode=.BrandJourneyPopulationCanonical~token(featureArg); outcomeKind=.BrandJourneyPopulationCanonical~token(outcomeArg)
  classifierId=.BrandJourneyPopulationCanonical~token(classifierArg); taxonomyVersion=.BrandJourneyPopulationCanonical~token(taxonomyArg); processVersion=.BrandJourneyPopulationCanonical~token(processArg); modelVersion=.BrandJourneyPopulationCanonical~token(modelArg)
  outcomeWindowSeconds=outcomeWindowArg+0; populationCount=populationArg+0; outcomeCount=outcomeCountArg+0; exposedCount=exposedArg+0; exposedOutcomeCount=exposedOutcomeArg+0
  modifierCode=.BrandJourneyPopulationCanonical~token(modifierArg); exposedWithModifierCount=withModifierArg+0; exposedWithModifierOutcomeCount=withModifierOutcomeArg+0
  materialityScore=0; materialOutcomeCount=0; commercialValueAtRisk=0; supportPoints=.array~new; counterPoints=.array~new; sealed=.false
  if bucketId="" | fromAt="" | toAt="" | classification="" | featureCode="" | outcomeKind="" then raise syntax 88.985 array("BrandJourneyPopulationAggregateBucket requires id, time, classification, feature and outcome")
  self~initAlchemy(.BrandJourneyPopulationAlchemySupport~metadata("pre-aggregated privacy-safe journey population bucket for large evidence sets"),alchemySealerArg,alchemyAuthorityArg)
  self~registerStateVariable("bucketId","CUSTOMER","aggregate bucket id")
  self~registerStateVariable("fromAt","CUSTOMER","bucket start")
  self~registerStateVariable("toAt","CUSTOMER","bucket end")
  self~registerStateVariable("classification","CUSTOMER","journey classification")
  self~registerStateVariable("featureCode","CUSTOMER","feature exposure")
  self~registerStateVariable("outcomeKind","CUSTOMER","measured outcome")
  self~registerStateVariable("classifierId","CUSTOMER","classifier provenance")
  self~registerStateVariable("taxonomyVersion","CUSTOMER","taxonomy provenance")
  self~registerStateVariable("processVersion","CUSTOMER","process/release provenance")
  self~registerStateVariable("modelVersion","CUSTOMER","agent/model provenance")
  self~registerStateVariable("outcomeWindowSeconds","CUSTOMER","outcome lag window used by aggregate")
  self~registerStateVariable("populationCount","CUSTOMER","bucket denominator")
  self~registerStateVariable("outcomeCount","CUSTOMER","bucket outcome count")
  self~registerStateVariable("exposedCount","CUSTOMER","feature-exposed denominator")
  self~registerStateVariable("exposedOutcomeCount","CUSTOMER","feature/outcome joint count")
  self~registerStateVariable("modifierCode","CUSTOMER","optional recovery/modifier code")
  self~registerStateVariable("exposedWithModifierCount","CUSTOMER","feature-exposed count with modifier")
  self~registerStateVariable("exposedWithModifierOutcomeCount","CUSTOMER","outcomes among feature-exposed with modifier")
  self~registerStateVariable("materialityScore","CUSTOMER","material significance independent of sample size")
  self~registerStateVariable("materialOutcomeCount","CUSTOMER","material outcome count")
  self~registerStateVariable("commercialValueAtRisk","INTERNAL","bounded commercial value")
  self~registerStateVariable("supportPoints","INTERNAL","privacy-safe support exemplars")
  self~registerStateVariable("counterPoints","INTERNAL","privacy-safe counter exemplars")
  self~registerStateVariable("sealed","CUSTOMER","aggregate immutability")
::method setMateriality
  expose sealed materialityScore materialOutcomeCount commercialValueAtRisk
  use arg scoreArg, materialOutcomeCountArg=0, commercialValueArg=0
  if sealed then return .false
  materialityScore=.BrandJourneyPopulationCanonical~clamp(scoreArg)
  if datatype(materialOutcomeCountArg,"W") & materialOutcomeCountArg>=0 then materialOutcomeCount=materialOutcomeCountArg+0
  if datatype(commercialValueArg,"N") & commercialValueArg>=0 then commercialValueAtRisk=commercialValueArg+0
  return .true
::method addSupportPoint
  expose sealed supportPoints
  use arg p
  if sealed | p~string="" then return .false
  if \.BrandJourneyPopulationCanonical~safePoint(p) then return .false
  if \.BrandJourneyPopulationCanonical~contains(supportPoints,p~string) then supportPoints~append(p~string)
  return .true
::method addCounterPoint
  expose sealed counterPoints
  use arg p
  if sealed | p~string="" then return .false
  if \.BrandJourneyPopulationCanonical~safePoint(p) then return .false
  if \.BrandJourneyPopulationCanonical~contains(counterPoints,p~string) then counterPoints~append(p~string)
  return .true
::method supportPoints
  expose supportPoints; return .BrandJourneyPopulationCanonical~copyArray(supportPoints)
::method counterPoints
  expose counterPoints; return .BrandJourneyPopulationCanonical~copyArray(counterPoints)
::method exposedWithoutModifierCount
  expose exposedCount exposedWithModifierCount; return exposedCount-exposedWithModifierCount
::method exposedWithoutModifierOutcomeCount
  expose exposedOutcomeCount exposedWithModifierOutcomeCount; return exposedOutcomeCount-exposedWithModifierOutcomeCount
::method seal
  expose fromAt toAt outcomeWindowSeconds populationCount outcomeCount exposedCount exposedOutcomeCount exposedWithModifierCount exposedWithModifierOutcomeCount sealed
  if fromAt>toAt then return .BrandJourneyPopulationResult~failure("BUCKET_TIME_RANGE_INVALID")
  if outcomeWindowSeconds<0 then return .BrandJourneyPopulationResult~failure("BUCKET_OUTCOME_WINDOW_INVALID")
  if populationCount<0 | outcomeCount<0 | exposedCount<0 | exposedOutcomeCount<0 then return .BrandJourneyPopulationResult~failure("BUCKET_NEGATIVE_COUNT")
  if outcomeCount>populationCount | exposedCount>populationCount | exposedOutcomeCount>outcomeCount | exposedOutcomeCount>exposedCount then return .BrandJourneyPopulationResult~failure("BUCKET_COUNT_INVALID")
  if exposedWithModifierCount<0 | exposedWithModifierCount>exposedCount | exposedWithModifierOutcomeCount<0 | exposedWithModifierOutcomeCount>exposedWithModifierCount | exposedWithModifierOutcomeCount>exposedOutcomeCount then return .BrandJourneyPopulationResult~failure("BUCKET_MODIFIER_COUNT_INVALID")
  sealed=.true; self~alchemyTouch("AGGREGATE_BUCKET_SEAL"); return .BrandJourneyPopulationResult~success(self)
::method pointId
  expose bucketId; return "BRAND_JOURNEY:POPULATION_BUCKET:"||bucketId
::method canonicalText
  expose bucketId fromAt toAt classification featureCode outcomeKind classifierId taxonomyVersion processVersion modelVersion outcomeWindowSeconds populationCount outcomeCount exposedCount exposedOutcomeCount modifierCode exposedWithModifierCount exposedWithModifierOutcomeCount materialityScore materialOutcomeCount sealed
  if \sealed then raise syntax 93.985 additional("BrandJourneyPopulationAggregateBucket must be sealed")
  out=.BrandJourneyPopulationCanonical~field("POPULATION_BUCKET",bucketId)
  out||=.BrandJourneyPopulationCanonical~field("FROM",fromAt)
  out||=.BrandJourneyPopulationCanonical~field("TO",toAt)
  out||=.BrandJourneyPopulationCanonical~field("CLASSIFICATION",classification)
  out||=.BrandJourneyPopulationCanonical~field("FEATURE",featureCode)
  out||=.BrandJourneyPopulationCanonical~field("OUTCOME",outcomeKind)
  out||=.BrandJourneyPopulationCanonical~field("POPULATION",populationCount)
  out||=.BrandJourneyPopulationCanonical~field("OUTCOME_COUNT",outcomeCount)
  out||=.BrandJourneyPopulationCanonical~field("EXPOSED_COUNT",exposedCount)
  out||=.BrandJourneyPopulationCanonical~field("EXPOSED_OUTCOME_COUNT",exposedOutcomeCount)
  out||=.BrandJourneyPopulationCanonical~field("CLASSIFIER_ID",classifierId)
  out||=.BrandJourneyPopulationCanonical~field("TAXONOMY_VERSION",taxonomyVersion)
  out||=.BrandJourneyPopulationCanonical~field("PROCESS_VERSION",processVersion)
  out||=.BrandJourneyPopulationCanonical~field("MODEL_VERSION",modelVersion)
  out||=.BrandJourneyPopulationCanonical~field("OUTCOME_WINDOW_SECONDS",outcomeWindowSeconds)
  if modifierCode<>"" then do
    out||=.BrandJourneyPopulationCanonical~field("MODIFIER",modifierCode)
    out||=.BrandJourneyPopulationCanonical~field("EXPOSED_WITH_MODIFIER_COUNT",exposedWithModifierCount)
    out||=.BrandJourneyPopulationCanonical~field("EXPOSED_WITH_MODIFIER_OUTCOME_COUNT",exposedWithModifierOutcomeCount)
  end
  out||=.BrandJourneyPopulationCanonical~field("MATERIALITY_SCORE",materialityScore)
  out||=.BrandJourneyPopulationCanonical~field("MATERIAL_OUTCOME_COUNT",materialOutcomeCount)
  return out

::class BrandJourneyPopulation subclass AlchemyObject public
::attribute populationId get
::attribute sourceKind get
::attribute sourceSystem get
::attribute unitKind get
::attribute samplingMethod get
::attribute deduplicationMethod get
::attribute dedupKeyKind get
::attribute duplicateAttemptCount get
::attribute sealed get
::method init
  expose populationId observations buckets sourceKind sourceSystem unitKind samplingMethod deduplicationMethod dedupKeyKind duplicateAttemptCount sealed
  use arg idArg, alchemySealerArg=.nil, alchemyAuthorityArg=.nil
  populationId=idArg~string; observations=.array~new; buckets=.array~new; duplicateAttemptCount=0; sealed=.false
  if populationId="" then raise syntax 88.982 array("BrandJourneyPopulation requires id")
  /* Source provenance belongs to the population, not to a time-window cohort.
     Facts this component cannot know remain UNSPECIFIED rather than inferred. */
  sourceKind="BRAND_JOURNEY_POPULATION"
  sourceSystem="UNSPECIFIED"
  unitKind="JOURNEY_ANALYSIS_UNIT"
  samplingMethod="UNSPECIFIED"
  deduplicationMethod="UNSPECIFIED"
  dedupKeyKind="UNSPECIFIED"
  self~initAlchemy(.BrandJourneyPopulationAlchemySupport~metadata("privacy-minimised journey observation population with explicit upstream provenance boundary; not CRM"),alchemySealerArg,alchemyAuthorityArg)
  self~registerStateVariable("populationId","CUSTOMER","population identifier")
  self~registerStateVariable("observations","INTERNAL","sealed privacy-minimised observations")
  self~registerStateVariable("buckets","INTERNAL","sealed pre-aggregated privacy-safe population buckets")
  self~registerStateVariable("sourceKind","CUSTOMER","controlled upstream source kind")
  self~registerStateVariable("sourceSystem","INTERNAL","controlled upstream source system identity or UNSPECIFIED")
  self~registerStateVariable("unitKind","CUSTOMER","analysis unit kind")
  self~registerStateVariable("samplingMethod","CUSTOMER","upstream sampling method or UNSPECIFIED")
  self~registerStateVariable("deduplicationMethod","CUSTOMER","upstream deduplication method or UNSPECIFIED")
  self~registerStateVariable("dedupKeyKind","CUSTOMER","upstream deduplication key kind or UNSPECIFIED")
  self~registerStateVariable("duplicateAttemptCount","INTERNAL","duplicate population-unit attachment attempts rejected locally")
  self~registerStateVariable("sealed","CUSTOMER","population immutability")
  self~registerMethodContract("CONFIGURESOURCEPROVENANCE","declare upstream source/sampling/dedup provenance without changing cohort selection semantics",.array~of("SOURCE_KIND","SOURCE_SYSTEM","UNIT_KIND","SAMPLING_METHOD","DEDUPLICATION_METHOD","DEDUP_KEY_KIND"),"BRANDJOURNEYPOPULATIONRESULT",.false,"AUTO","INTERNAL","NORMAL","MUTATE","NONE")
  self~registerInstrumentationPoint("BRAND.JOURNEY.POPULATION.SEALED","journey population sealed",.true,"ALL","INTERNAL")
::method configureSourceProvenance
  expose sourceKind sourceSystem unitKind samplingMethod deduplicationMethod dedupKeyKind sealed
  use arg sourceKindArg, sourceSystemArg, unitKindArg="JOURNEY_ANALYSIS_UNIT", samplingMethodArg="UNSPECIFIED", dedupMethodArg="UNSPECIFIED", dedupKeyArg="UNSPECIFIED"
  if sealed then return .BrandJourneyPopulationResult~failure("POPULATION_SEALED")
  sk=.BrandJourneyPopulationCanonical~token(sourceKindArg); ss=.BrandJourneyPopulationCanonical~token(sourceSystemArg); uk=.BrandJourneyPopulationCanonical~token(unitKindArg); sm=.BrandJourneyPopulationCanonical~token(samplingMethodArg); dm=.BrandJourneyPopulationCanonical~token(dedupMethodArg); dk=.BrandJourneyPopulationCanonical~token(dedupKeyArg)
  if sk="" | ss="" | uk="" | sm="" | dm="" | dk="" then return .BrandJourneyPopulationResult~failure("POPULATION_SOURCE_PROVENANCE_FIELD_REQUIRED")
  sourceKind=sk; sourceSystem=ss; unitKind=uk; samplingMethod=sm; deduplicationMethod=dm; dedupKeyKind=dk
  self~alchemyTouch("CONFIGURE_SOURCE_PROVENANCE")
  return .BrandJourneyPopulationResult~success(self)
::method addObservation
  expose observations duplicateAttemptCount sealed
  use arg observation
  if sealed then return .BrandJourneyPopulationResult~failure("POPULATION_SEALED")
  if observation==.nil | \observation~sealed then return .BrandJourneyPopulationResult~failure("OBSERVATION_NOT_SEALED")
  do existing over observations
    if existing~observationId==observation~observationId then do
      duplicateAttemptCount+=1
      return .BrandJourneyPopulationResult~failure("OBSERVATION_ALREADY_PRESENT")
    end
  end
  observations~append(observation)
  self~recordRelationship("CONTAINS",observation,"privacy-minimised journey population observation","INTERNAL")
  return .BrandJourneyPopulationResult~success(observation)
::method addBucket
  expose buckets duplicateAttemptCount sealed
  use arg bucket
  if sealed then return .BrandJourneyPopulationResult~failure("POPULATION_SEALED")
  if bucket==.nil | \bucket~sealed then return .BrandJourneyPopulationResult~failure("BUCKET_NOT_SEALED")
  do existing over buckets
    if existing~bucketId==bucket~bucketId then do
      duplicateAttemptCount+=1
      return .BrandJourneyPopulationResult~failure("BUCKET_ALREADY_PRESENT")
    end
  end
  buckets~append(bucket)
  self~recordRelationship("CONTAINS",bucket,"pre-aggregated privacy-safe journey population bucket","INTERNAL")
  return .BrandJourneyPopulationResult~success(bucket)
::method observations
  expose observations; return .BrandJourneyPopulationCanonical~copyArray(observations)
::method buckets
  expose buckets; return .BrandJourneyPopulationCanonical~copyArray(buckets)
::method seal
  expose sealed observations buckets
  if observations~items=0 & buckets~items=0 then return .BrandJourneyPopulationResult~failure("POPULATION_EMPTY")
  sealed=.true
  self~alchemyTouch("POPULATION_SEAL")
  self~alchemyInstrument("BRAND.JOURNEY.POPULATION.SEALED",self~pointId)
  return .BrandJourneyPopulationResult~success(self)
::method pointId
  expose populationId; return "BRAND_JOURNEY:POPULATION:"||populationId

/* Audit the denominator selection.  Exclusion reasons remain visible so a
   reasoning model can see what did NOT enter the population frame. */
::class BrandJourneyPopulationSelection subclass AlchemyObject public
::attribute selectionId get
::attribute totalInput get
::attribute includedCount get
::attribute excludedTime get
::attribute excludedClassification get
::attribute excludedFeatureCode get
::attribute excludedOutcomeKind get
::attribute excludedClassifier get
::attribute excludedTaxonomy get
::attribute excludedProcess get
::attribute excludedModel get
::attribute excludedOutcomeWindowMismatch get
::attribute outcomeOutsideWindow get
::attribute excludedPartialTimeBucket get
::method init
  expose selectionId totalInput includedCount excludedTime excludedClassification excludedFeatureCode excludedOutcomeKind excludedClassifier excludedTaxonomy excludedProcess excludedModel excludedOutcomeWindowMismatch outcomeOutsideWindow excludedPartialTimeBucket
  use arg idArg, totalArg, includedArg, timeArg, classArg, classifierArg, taxonomyArg, processArg, modelArg, windowArg, partialBucketArg=0, outcomeWindowMismatchArg=0, featureArg=0, outcomeKindArg=0, alchemySealerArg=.nil, alchemyAuthorityArg=.nil
  selectionId=idArg~string; totalInput=totalArg+0; includedCount=includedArg+0
  excludedTime=timeArg+0; excludedClassification=classArg+0; excludedFeatureCode=featureArg+0; excludedOutcomeKind=outcomeKindArg+0; excludedClassifier=classifierArg+0; excludedTaxonomy=taxonomyArg+0; excludedProcess=processArg+0; excludedModel=modelArg+0
  outcomeOutsideWindow=windowArg+0; excludedPartialTimeBucket=partialBucketArg+0; excludedOutcomeWindowMismatch=outcomeWindowMismatchArg+0
  self~initAlchemy(.BrandJourneyPopulationAlchemySupport~metadata("auditable journey cohort denominator selection, exclusion accounting and outcome-window handling"),alchemySealerArg,alchemyAuthorityArg)
  self~registerStateVariable("selectionId","CUSTOMER","selection audit id")
  self~registerStateVariable("totalInput","CUSTOMER","total candidate analysis units")
  self~registerStateVariable("includedCount","CUSTOMER","included analyzable cohort denominator")
  self~registerStateVariable("excludedTime","CUSTOMER","outside time scope")
  self~registerStateVariable("excludedClassification","CUSTOMER","wrong journey classification")
  self~registerStateVariable("excludedFeatureCode","CUSTOMER","aggregate feature schema mismatch")
  self~registerStateVariable("excludedOutcomeKind","CUSTOMER","outcome-kind mismatch")
  self~registerStateVariable("excludedClassifier","CUSTOMER","classifier provenance mismatch")
  self~registerStateVariable("excludedTaxonomy","CUSTOMER","taxonomy provenance mismatch")
  self~registerStateVariable("excludedProcess","CUSTOMER","process/release mismatch")
  self~registerStateVariable("excludedModel","CUSTOMER","agent/model version mismatch")
  self~registerStateVariable("excludedOutcomeWindowMismatch","CUSTOMER","aggregate units excluded because declared outcome window differs")
  self~registerStateVariable("outcomeOutsideWindow","CUSTOMER","outcomes observed outside allowed lag and treated as non-outcomes")
  self~registerStateVariable("excludedPartialTimeBucket","CUSTOMER","aggregate units rejected because bucket only partially overlaps cohort")
::method excludedCount
  expose totalInput includedCount
  return totalInput-includedCount
::method canonicalText
  expose selectionId totalInput includedCount excludedTime excludedClassification excludedFeatureCode excludedOutcomeKind excludedClassifier excludedTaxonomy excludedProcess excludedModel excludedOutcomeWindowMismatch outcomeOutsideWindow excludedPartialTimeBucket
  out=.BrandJourneyPopulationCanonical~field("SELECTION",selectionId)
  out||=.BrandJourneyPopulationCanonical~field("TOTAL_INPUT",totalInput)
  out||=.BrandJourneyPopulationCanonical~field("INCLUDED",includedCount)
  out||=.BrandJourneyPopulationCanonical~field("EXCLUDED_TOTAL",self~excludedCount)
  out||=.BrandJourneyPopulationCanonical~field("EXCLUDED_TIME",excludedTime)
  out||=.BrandJourneyPopulationCanonical~field("EXCLUDED_CLASSIFICATION",excludedClassification)
  out||=.BrandJourneyPopulationCanonical~field("EXCLUDED_FEATURE_CODE",excludedFeatureCode)
  out||=.BrandJourneyPopulationCanonical~field("EXCLUDED_OUTCOME_KIND",excludedOutcomeKind)
  out||=.BrandJourneyPopulationCanonical~field("EXCLUDED_CLASSIFIER",excludedClassifier)
  out||=.BrandJourneyPopulationCanonical~field("EXCLUDED_TAXONOMY",excludedTaxonomy)
  out||=.BrandJourneyPopulationCanonical~field("EXCLUDED_PROCESS",excludedProcess)
  out||=.BrandJourneyPopulationCanonical~field("EXCLUDED_MODEL",excludedModel)
  out||=.BrandJourneyPopulationCanonical~field("EXCLUDED_OUTCOME_WINDOW_MISMATCH",excludedOutcomeWindowMismatch)
  out||=.BrandJourneyPopulationCanonical~field("OUTCOME_OUTSIDE_WINDOW",outcomeOutsideWindow)
  out||=.BrandJourneyPopulationCanonical~field("EXCLUDED_PARTIAL_TIME_BUCKET",excludedPartialTimeBucket)
  return out

/* Wilson intervals are supplied as uncertainty material; v0.3 deliberately
   does not relabel them as proof or causal significance. */
::class BrandJourneyRateUncertainty subclass AlchemyObject public
::attribute evidenceId get
::attribute exposedLower95 get
::attribute exposedUpper95 get
::attribute unexposedLower95 get
::attribute unexposedUpper95 get
::attribute confidenceMethod get
::attribute intervalSeparation get
::attribute comparisonAvailable get
::method init
  expose evidenceId exposedLower95 exposedUpper95 unexposedLower95 unexposedUpper95 confidenceMethod intervalSeparation comparisonAvailable
  use arg idArg, exposedN, exposedOutcome, unexposedN, unexposedOutcome, alchemySealerArg=.nil, alchemyAuthorityArg=.nil
  evidenceId=idArg~string
  ex=self~wilson(exposedN,exposedOutcome)
  un=self~wilson(unexposedN,unexposedOutcome)
  exposedLower95=ex[1]; exposedUpper95=ex[2]; unexposedLower95=un[1]; unexposedUpper95=un[2]
  confidenceMethod=.BrandJourneyPopulationConstant~CONFIDENCE_95
  comparisonAvailable=(exposedN+0)>0 & (unexposedN+0)>0
  intervalSeparation=.false
  if comparisonAvailable then if exposedLower95>unexposedUpper95 | unexposedLower95>exposedUpper95 then intervalSeparation=.true
  self~initAlchemy(.BrandJourneyPopulationAlchemySupport~metadata("95 percent Wilson rate intervals as uncertainty material; not causal proof"),alchemySealerArg,alchemyAuthorityArg)
  self~registerStateVariable("evidenceId","CUSTOMER","uncertainty evidence id")
  self~registerStateVariable("exposedLower95","CUSTOMER","lower 95 percent Wilson bound for exposed outcome rate")
  self~registerStateVariable("exposedUpper95","CUSTOMER","upper 95 percent Wilson bound for exposed outcome rate")
  self~registerStateVariable("unexposedLower95","CUSTOMER","lower 95 percent Wilson bound for comparison rate")
  self~registerStateVariable("unexposedUpper95","CUSTOMER","upper 95 percent Wilson bound for comparison rate")
  self~registerStateVariable("confidenceMethod","CUSTOMER","interval method")
  self~registerStateVariable("intervalSeparation","CUSTOMER","whether 95 percent rate intervals are non-overlapping")
  self~registerStateVariable("comparisonAvailable","CUSTOMER","whether both exposed and comparison groups exist")
::method wilson private
  use arg nArg, kArg
  out=.array~new
  n=nArg+0; k=kArg+0
  if n<=0 then do; out~append(0); out~append(0); return out; end
  p=k/n; z=1.96; z2=z*z
  den=1+z2/n
  centre=(p+z2/(2*n))/den
  variance=p*(1-p)/n+z2/(4*n*n)
  rad=z*self~sqrtNumber(variance)/den
  lo=100*(centre-rad); hi=100*(centre+rad)
  if lo<0 then lo=0; if hi>100 then hi=100
  out~append(lo); out~append(hi); return out
::method sqrtNumber private
  use arg value
  if value<=0 then return 0
  x=value
  if x<1 then x=1
  do 20
    x=(x+value/x)/2
  end
  return x
::method canonicalText
  expose evidenceId exposedLower95 exposedUpper95 unexposedLower95 unexposedUpper95 confidenceMethod intervalSeparation comparisonAvailable
  out=.BrandJourneyPopulationCanonical~field("UNCERTAINTY",evidenceId)
  out||=.BrandJourneyPopulationCanonical~field("CONFIDENCE_METHOD",confidenceMethod)
  out||=.BrandJourneyPopulationCanonical~field("COMPARISON_AVAILABLE",comparisonAvailable)
  out||=.BrandJourneyPopulationCanonical~field("EXPOSED_OUTCOME_RATE_LOWER_95_PCT",exposedLower95)
  out||=.BrandJourneyPopulationCanonical~field("EXPOSED_OUTCOME_RATE_UPPER_95_PCT",exposedUpper95)
  out||=.BrandJourneyPopulationCanonical~field("UNEXPOSED_OUTCOME_RATE_LOWER_95_PCT",unexposedLower95)
  out||=.BrandJourneyPopulationCanonical~field("UNEXPOSED_OUTCOME_RATE_UPPER_95_PCT",unexposedUpper95)
  out||=.BrandJourneyPopulationCanonical~field("INTERVAL_SEPARATION",intervalSeparation)
  return out

/* Recovery/modifier stratification asks whether the pattern remains the same
   when a privacy-safe journey modifier (for example cross-domain recovery)
   is present.  Association only: it is not a treatment-effect estimator. */
::class BrandJourneyModifierEvidence subclass AlchemyObject public
::attribute evidenceId get
::attribute featureCode get
::attribute modifierCode get
::attribute withModifierCount get
::attribute withModifierOutcomeCount get
::attribute withoutModifierCount get
::attribute withoutModifierOutcomeCount get
::attribute causalStatus get
::method init
  expose evidenceId featureCode modifierCode withModifierCount withModifierOutcomeCount withoutModifierCount withoutModifierOutcomeCount causalStatus
  use arg idArg, featureArg, modifierArg, withCountArg, withOutcomeArg, withoutCountArg, withoutOutcomeArg, alchemySealerArg=.nil, alchemyAuthorityArg=.nil
  evidenceId=idArg~string; featureCode=.BrandJourneyPopulationCanonical~token(featureArg); modifierCode=.BrandJourneyPopulationCanonical~token(modifierArg)
  withModifierCount=withCountArg+0; withModifierOutcomeCount=withOutcomeArg+0; withoutModifierCount=withoutCountArg+0; withoutModifierOutcomeCount=withoutOutcomeArg+0
  causalStatus=.BrandJourneyPopulationConstant~CAUSAL_ASSOCIATION_ONLY
  self~initAlchemy(.BrandJourneyPopulationAlchemySupport~metadata("journey feature outcome stratification by privacy-safe modifier"),alchemySealerArg,alchemyAuthorityArg)
  self~registerStateVariable("evidenceId","CUSTOMER","modifier evidence id")
  self~registerStateVariable("featureCode","CUSTOMER","journey feature under study")
  self~registerStateVariable("modifierCode","CUSTOMER","modifier/recovery stratum")
  self~registerStateVariable("withModifierCount","CUSTOMER","feature-exposed count with modifier")
  self~registerStateVariable("withModifierOutcomeCount","CUSTOMER","outcomes among feature-exposed with modifier")
  self~registerStateVariable("withoutModifierCount","CUSTOMER","feature-exposed count without modifier")
  self~registerStateVariable("withoutModifierOutcomeCount","CUSTOMER","outcomes among feature-exposed without modifier")
  self~registerStateVariable("causalStatus","CUSTOMER","association-only status")
::method withModifierOutcomeRate
  expose withModifierCount withModifierOutcomeCount
  if withModifierCount<=0 then return 0
  return 100*withModifierOutcomeCount/withModifierCount
::method withoutModifierOutcomeRate
  expose withoutModifierCount withoutModifierOutcomeCount
  if withoutModifierCount<=0 then return 0
  return 100*withoutModifierOutcomeCount/withoutModifierCount
::method rateDelta
  return self~withModifierOutcomeRate-self~withoutModifierOutcomeRate
::method canonicalText
  expose evidenceId featureCode modifierCode withModifierCount withModifierOutcomeCount withoutModifierCount withoutModifierOutcomeCount causalStatus
  out=.BrandJourneyPopulationCanonical~field("MODIFIER_EVIDENCE",evidenceId)
  out||=.BrandJourneyPopulationCanonical~field("FEATURE",featureCode)
  out||=.BrandJourneyPopulationCanonical~field("MODIFIER",modifierCode)
  out||=.BrandJourneyPopulationCanonical~field("WITH_MODIFIER_COUNT",withModifierCount)
  out||=.BrandJourneyPopulationCanonical~field("WITH_MODIFIER_OUTCOME_COUNT",withModifierOutcomeCount)
  out||=.BrandJourneyPopulationCanonical~field("WITH_MODIFIER_OUTCOME_RATE_PCT",self~withModifierOutcomeRate)
  out||=.BrandJourneyPopulationCanonical~field("WITHOUT_MODIFIER_COUNT",withoutModifierCount)
  out||=.BrandJourneyPopulationCanonical~field("WITHOUT_MODIFIER_OUTCOME_COUNT",withoutModifierOutcomeCount)
  out||=.BrandJourneyPopulationCanonical~field("WITHOUT_MODIFIER_OUTCOME_RATE_PCT",self~withoutModifierOutcomeRate)
  out||=.BrandJourneyPopulationCanonical~field("MODIFIER_RATE_DELTA_PCT",self~rateDelta)
  out||=.BrandJourneyPopulationCanonical~field("CAUSAL_STATUS",causalStatus)
  return out

::class BrandJourneyPopulationAnalysis subclass AlchemyObject public
::attribute analysisId get
::attribute cohort get
::attribute selection get
::attribute frame get
::attribute threshold get
::attribute assessment get
::attribute uncertainty get
::attribute modifierEvidence get
::method init
  expose analysisId cohort selection frame threshold assessment uncertainty modifierEvidence
  use arg idArg, cohortArg, selectionArg, frameArg, thresholdArg, assessmentArg, uncertaintyArg, modifierArg=.nil, alchemySealerArg=.nil, alchemyAuthorityArg=.nil
  analysisId=idArg~string; cohort=cohortArg; selection=selectionArg; frame=frameArg; threshold=thresholdArg; assessment=assessmentArg; uncertainty=uncertaintyArg; modifierEvidence=modifierArg
  self~initAlchemy(.BrandJourneyPopulationAlchemySupport~metadata("scoped journey population analysis with denominator audit and uncertainty"),alchemySealerArg,alchemyAuthorityArg)
  self~registerStateVariable("analysisId","CUSTOMER","analysis id")
  self~registerStateVariable("cohort","INTERNAL","sealed cohort definition")
  self~registerStateVariable("selection","CUSTOMER","denominator selection audit")
  self~registerStateVariable("frame","INTERNAL","Brand Interaction statistical evidence frame")
  self~registerStateVariable("threshold","CUSTOMER","evidence sufficiency threshold")
  self~registerStateVariable("assessment","CUSTOMER","statistical/material sufficiency assessment")
  self~registerStateVariable("uncertainty","CUSTOMER","95 percent rate uncertainty material")
  self~registerStateVariable("modifierEvidence","CUSTOMER","optional recovery/modifier stratification")
  if cohort\==.nil & cohort~hasMethod("ALCHEMYOBJECTID") then self~recordRelationship("USES",cohort,"journey cohort definition","INTERNAL")
  if frame\==.nil & frame~hasMethod("ALCHEMYOBJECTID") then self~recordRelationship("USES",frame,"statistical evidence frame","INTERNAL")
::method canonicalText
  expose analysisId cohort selection frame threshold assessment uncertainty modifierEvidence
  out=.BrandJourneyPopulationCanonical~field("JOURNEY_POPULATION_ANALYSIS",analysisId)
  out||=cohort~canonicalText
  out||=selection~canonicalText
  out||=frame~canonicalText
  out||=threshold~canonicalText
  out||=assessment~canonicalText
  out||=uncertainty~canonicalText
  if modifierEvidence\==.nil then out||=modifierEvidence~canonicalText
  return out

::class BrandJourneyPopulationAnalyzer public
/* Build one fully scoped frame from privacy-minimised observations/buckets.
   v0.3 composes Brand Interaction Effect v0.6 cohort provenance and
   treats a missing 2x2 comparison arm as explicit insufficient evidence rather
   than a runtime failure. */
::method analyze
  use arg population, cohort, threshold=.nil, modifierCode=""
  if population==.nil | \population~sealed then return .BrandJourneyPopulationResult~failure("POPULATION_NOT_SEALED")
  if cohort==.nil | \cohort~sealed then return .BrandJourneyPopulationResult~failure("COHORT_NOT_SEALED")
  if threshold==.nil then threshold=.BrandEvidenceThreshold~new
  modifier=.BrandJourneyPopulationCanonical~token(modifierCode)
  total=0; included=0; exTime=0; exClass=0; exFeature=0; exOutcomeKind=0; exClassifier=0; exTax=0; exProcess=0; exModel=0; exOutcomeWindow=0; outsideWindow=0
  outcomes=0; exposed=0; exposedOutcomes=0
  withMod=0; withModOut=0; withoutMod=0; withoutModOut=0
  materialMax=0; materialOutcomeCount=0; commercialTotal=0
  support=.array~new; counter=.array~new
  observations=population~observations; buckets=population~buckets

  do o over observations
    total+=1
    if \.BrandJourneyPopulationCanonical~inWindow(o~occurredAt,cohort~fromAt,cohort~toAt) then do; exTime+=1; iterate; end
    if o~classification<>cohort~classification then do; exClass+=1; iterate; end
    if o~outcomeKind<>cohort~outcomeKind then do; exOutcomeKind+=1; iterate; end
    if cohort~classifierId<>.BrandJourneyPopulationConstant~ANY & o~classifierId<>cohort~classifierId then do; exClassifier+=1; iterate; end
    if cohort~taxonomyVersion<>.BrandJourneyPopulationConstant~ANY & o~taxonomyVersion<>cohort~taxonomyVersion then do; exTax+=1; iterate; end
    if cohort~processVersion<>.BrandJourneyPopulationConstant~ANY & o~processVersion<>cohort~processVersion then do; exProcess+=1; iterate; end
    if cohort~modelVersion<>.BrandJourneyPopulationConstant~ANY & o~modelVersion<>cohort~modelVersion then do; exModel+=1; iterate; end
    included+=1
    isExposed=o~hasExposure(cohort~featureCode)
    isOutcome=o~outcomeOccurred
    if isOutcome & cohort~outcomeWindowSeconds>0 & o~outcomeLagSeconds>cohort~outcomeWindowSeconds then do
      isOutcome=.false; outsideWindow+=1
    end
    if isOutcome then do
      outcomes+=1
      if o~materialityScore>materialMax then materialMax=o~materialityScore
      if o~materialityScore>0 then materialOutcomeCount+=1
      commercialTotal+=o~commercialValueAtRisk
    end
    if isExposed then do
      exposed+=1
      if isOutcome then do
        exposedOutcomes+=1
        if \.BrandJourneyPopulationCanonical~contains(support,o~pointId) then support~append(o~pointId)
      end
      else if \.BrandJourneyPopulationCanonical~contains(counter,o~pointId) then counter~append(o~pointId)
      if modifier<>"" then do
        if o~hasModifier(modifier) then do; withMod+=1; if isOutcome then withModOut+=1; end
        else do; withoutMod+=1; if isOutcome then withoutModOut+=1; end
      end
    end
    else if isOutcome then if \.BrandJourneyPopulationCanonical~contains(counter,o~pointId) then counter~append(o~pointId)
  end

  partialBucket=0
  do b over buckets
    total+=b~populationCount
    /* Aggregate buckets are indivisible. Partial overlap is excluded, never prorated. */
    if b~toAt<cohort~fromAt | b~fromAt>cohort~toAt then do; exTime+=b~populationCount; iterate; end
    if b~fromAt<cohort~fromAt | b~toAt>cohort~toAt then do; partialBucket+=b~populationCount; iterate; end
    if b~classification<>cohort~classification then do; exClass+=b~populationCount; iterate; end
    if b~featureCode<>cohort~featureCode then do; exFeature+=b~populationCount; iterate; end
    if b~outcomeKind<>cohort~outcomeKind then do; exOutcomeKind+=b~populationCount; iterate; end
    if cohort~classifierId<>.BrandJourneyPopulationConstant~ANY & b~classifierId<>cohort~classifierId then do; exClassifier+=b~populationCount; iterate; end
    if cohort~taxonomyVersion<>.BrandJourneyPopulationConstant~ANY & b~taxonomyVersion<>cohort~taxonomyVersion then do; exTax+=b~populationCount; iterate; end
    if cohort~processVersion<>.BrandJourneyPopulationConstant~ANY & b~processVersion<>cohort~processVersion then do; exProcess+=b~populationCount; iterate; end
    if cohort~modelVersion<>.BrandJourneyPopulationConstant~ANY & b~modelVersion<>cohort~modelVersion then do; exModel+=b~populationCount; iterate; end
    if b~outcomeWindowSeconds<>cohort~outcomeWindowSeconds then do; exOutcomeWindow+=b~populationCount; iterate; end
    included+=b~populationCount; outcomes+=b~outcomeCount; exposed+=b~exposedCount; exposedOutcomes+=b~exposedOutcomeCount
    if b~materialityScore>materialMax then materialMax=b~materialityScore
    materialOutcomeCount+=b~materialOutcomeCount; commercialTotal+=b~commercialValueAtRisk
    do p over b~supportPoints; if \.BrandJourneyPopulationCanonical~contains(support,p) then support~append(p); end
    do p over b~counterPoints; if \.BrandJourneyPopulationCanonical~contains(counter,p) then counter~append(p); end
    if modifier<>"" & b~modifierCode=modifier then do
      withMod+=b~exposedWithModifierCount; withModOut+=b~exposedWithModifierOutcomeCount
      withoutMod+=b~exposedWithoutModifierCount; withoutModOut+=b~exposedWithoutModifierOutcomeCount
    end
  end

  selection=.BrandJourneyPopulationSelection~new("SELECT-"||cohort~cohortId,total,included,exTime,exClass,exClassifier,exTax,exProcess,exModel,outsideWindow,partialBucket,exOutcomeWindow,exFeature,exOutcomeKind)
  frame=.BrandEvidenceFrame~new("JOURNEY-"||cohort~cohortId,cohort~role,cohort~classification,cohort~fromAt,cohort~toAt,cohort~observationDays,included,cohort~outcomeKind,outcomes,"JOURNEY_FEATURE",cohort~featureCode,exposed,exposedOutcomes,cohort~classifierId,cohort~taxonomyVersion,cohort~outcomeWindowSeconds)
  frame~setMateriality(materialMax,materialOutcomeCount,commercialTotal)
  do p over support; frame~addSupportPoint(p); end
  do p over counter; frame~addCounterPoint(p); end

  /* Compose provenance by ownership.  Population owns upstream source/sampling/
     deduplication facts; cohort owns local selection and outcome-ascertainment
     rules.  Legacy cohort source fields are fallback only when population source
     provenance is genuinely UNSPECIFIED. */
  sourceKind=population~sourceKind
  if sourceKind="UNSPECIFIED" & cohort~sourceKind<>"UNSPECIFIED" then sourceKind=cohort~sourceKind
  sourceSystem=population~sourceSystem
  if sourceSystem="UNSPECIFIED" & cohort~sourceSystem<>"UNSPECIFIED" then sourceSystem=cohort~sourceSystem
  unitKind=population~unitKind
  if unitKind="UNSPECIFIED" & cohort~unitKind<>"UNSPECIFIED" then unitKind=cohort~unitKind
  samplingMethod=population~samplingMethod
  if samplingMethod="UNSPECIFIED" & cohort~samplingMethod<>"UNSPECIFIED" then samplingMethod=cohort~samplingMethod
  dedupMethod=population~deduplicationMethod
  if dedupMethod="UNSPECIFIED" & cohort~deduplicationMethod<>"UNSPECIFIED" then dedupMethod=cohort~deduplicationMethod
  dedupKey=population~dedupKeyKind
  if dedupKey="UNSPECIFIED" & cohort~dedupKeyKind<>"UNSPECIFIED" then dedupKey=cohort~dedupKeyKind
  prov=.BrandEvidenceCohortProvenance~new("JOURNEY-"||cohort~cohortId,sourceKind,sourceSystem,unitKind,cohort~selectionRuleId,samplingMethod,cohort~inclusionPolicyId,cohort~exclusionPolicyId,dedupMethod,dedupKey,cohort~classifierId,cohort~taxonomyVersion,cohort~outcomeAscertainmentId)
  ignore=prov~setCounts(total,included,included,total-included,0,0,0,0,population~duplicateAttemptCount)
  if exTime>0 then prov~addExclusionReason("OUTSIDE_TIME_SCOPE",exTime)
  if exClass>0 then prov~addExclusionReason("CLASSIFICATION_MISMATCH",exClass)
  if exFeature>0 then prov~addExclusionReason("FEATURE_SCHEMA_MISMATCH",exFeature)
  if exOutcomeKind>0 then prov~addExclusionReason("OUTCOME_KIND_MISMATCH",exOutcomeKind)
  if exClassifier>0 then prov~addExclusionReason("CLASSIFIER_MISMATCH",exClassifier)
  if exTax>0 then prov~addExclusionReason("TAXONOMY_MISMATCH",exTax)
  if exProcess>0 then prov~addExclusionReason("PROCESS_VERSION_MISMATCH",exProcess)
  if exModel>0 then prov~addExclusionReason("MODEL_VERSION_MISMATCH",exModel)
  if exOutcomeWindow>0 then prov~addExclusionReason("OUTCOME_WINDOW_DEFINITION_MISMATCH",exOutcomeWindow)
  if partialBucket>0 then prov~addExclusionReason("INDIVISIBLE_PARTIAL_TIME_BUCKET",partialBucket)
  if outsideWindow>0 then prov~addLimitation("OUTCOMES_OUTSIDE_DECLARED_LAG_WINDOW_TREATED_AS_NONOUTCOMES")
  if observations~items>0 & buckets~items>0 then prov~addLimitation("MIXED_UNIT_FORMS_REQUIRE_UPSTREAM_CROSS_FORM_DEDUP_GUARANTEE")
  if buckets~items>0 then prov~addLimitation("PREAGGREGATED_BUCKETS_RELY_ON_UPSTREAM_COUNT_PROVENANCE")
  if sourceSystem="UNSPECIFIED" then prov~addLimitation("UPSTREAM_SOURCE_SYSTEM_UNSPECIFIED")
  if samplingMethod="UNSPECIFIED" then prov~addLimitation("SAMPLING_METHOD_UNSPECIFIED")
  if dedupMethod="UNSPECIFIED" then prov~addLimitation("UPSTREAM_DEDUPLICATION_UNSPECIFIED")
  if dedupKey="UNSPECIFIED" then prov~addLimitation("UPSTREAM_DEDUP_KEY_UNSPECIFIED")
  pr=prov~seal; if \pr~ok then return .BrandJourneyPopulationResult~failure(pr~code,pr~detail)
  ar=frame~attachCohortProvenance(prov); if \ar~ok then return .BrandJourneyPopulationResult~failure(ar~code,ar~detail)
  sr=frame~seal; if \sr~ok then return .BrandJourneyPopulationResult~failure(sr~code,sr~detail)

  if frame~exposedCount<=0 | frame~unexposedCount<=0 then assessment=self~comparisonInsufficientAssessment(frame,threshold)
  else do
    ev=.BrandEvidenceEngine~new~evaluate(frame,threshold)
    if \ev~ok then return .BrandJourneyPopulationResult~failure(ev~code,ev~detail)
    assessment=ev~value
  end

  uncertainty=.BrandJourneyRateUncertainty~new("UNCERTAINTY-"||cohort~cohortId,frame~exposedCount,frame~exposedOutcomeCount,frame~unexposedCount,frame~unexposedOutcomeCount)
  modEvidence=.nil
  if modifier<>"" then modEvidence=.BrandJourneyModifierEvidence~new("MODIFIER-"||cohort~cohortId,cohort~featureCode,modifier,withMod,withModOut,withoutMod,withoutModOut)
  analysis=.BrandJourneyPopulationAnalysis~new("ANALYSIS-"||cohort~cohortId,cohort,selection,frame,threshold,assessment,uncertainty,modEvidence)
  return .BrandJourneyPopulationResult~success(analysis)

::method comparisonInsufficientAssessment private
  use arg frame, threshold
  coverage=self~thresholdCoverage(frame,threshold)
  material=frame~materialityScore>=threshold~minMaterialityScore & frame~materialOutcomeCount>0
  if material then status=.BrandEvidenceConstant~STATUS_MATERIAL_INVESTIGATION
  else status=.BrandEvidenceConstant~STATUS_INSUFFICIENT
  quality=self~cohortQuality(frame,threshold)
  a=.BrandEvidenceAssessment~new(status,coverage,.false,material,.false,.false,.nil,quality)
  a~addReason("STATISTICAL_COMPARISON_GROUP_REQUIRED")
  if frame~exposedCount<=0 then a~addReason("EXPOSED_GROUP_EMPTY")
  if frame~unexposedCount<=0 then a~addReason("UNEXPOSED_COMPARISON_GROUP_EMPTY")
  if frame~populationCount<threshold~minPopulationCount then a~addReason("POPULATION_BELOW_THRESHOLD")
  if frame~exposedCount<threshold~minExposedCount then a~addReason("EXPOSED_BELOW_THRESHOLD")
  if frame~outcomeCount<threshold~minOutcomeCount then a~addReason("OUTCOMES_BELOW_THRESHOLD")
  if frame~exposedOutcomeCount<threshold~minJointCount then a~addReason("JOINT_BELOW_THRESHOLD")
  if frame~observationDays<threshold~minObservationDays then a~addReason("TIME_WINDOW_BELOW_THRESHOLD")
  if material then a~addReason("HIGH_MATERIALITY_REQUIRES_INVESTIGATION")
  self~appendCohortQualityReasons(a,frame,threshold)
  return a

::method thresholdCoverage private
  use arg frame, threshold
  coverage=100
  coverage=min(coverage,self~ratio(frame~populationCount,threshold~minPopulationCount))
  coverage=min(coverage,self~ratio(frame~exposedCount,threshold~minExposedCount))
  coverage=min(coverage,self~ratio(frame~outcomeCount,threshold~minOutcomeCount))
  coverage=min(coverage,self~ratio(frame~exposedOutcomeCount,threshold~minJointCount))
  coverage=min(coverage,self~ratio(frame~observationDays,threshold~minObservationDays))
  return coverage

::method ratio private
  use arg actual, required
  if required<=0 then return 100
  return min(100,100*actual/required)

::method cohortQuality private
  use arg frame, threshold
  provenance=frame~cohortProvenance; quality=.true
  if threshold~requireCohortProvenance & provenance==.nil then return .false
  if provenance\==.nil then do
    if provenance~selectedAnalysisCoveragePct<threshold~minSelectedAnalysisCoveragePct then quality=.false
    if provenance~incompleteSelectedPct>threshold~maxIncompleteSelectedPct then quality=.false
    if provenance~selectionUnknownPct>threshold~maxSelectionUnknownPct then quality=.false
    if threshold~requireExplicitSelectionRule & provenance~selectionRuleId="UNSPECIFIED" then quality=.false
  end
  return quality

::method appendCohortQualityReasons private
  use arg assessment, frame, threshold
  provenance=frame~cohortProvenance
  if threshold~requireCohortProvenance & provenance==.nil then assessment~addReason("COHORT_PROVENANCE_REQUIRED")
  if provenance\==.nil then do
    if provenance~selectedAnalysisCoveragePct<threshold~minSelectedAnalysisCoveragePct then assessment~addReason("COHORT_SELECTED_ANALYSIS_COVERAGE_BELOW_THRESHOLD")
    if provenance~incompleteSelectedPct>threshold~maxIncompleteSelectedPct then assessment~addReason("COHORT_INCOMPLETE_SELECTED_ABOVE_THRESHOLD")
    if provenance~selectionUnknownPct>threshold~maxSelectionUnknownPct then assessment~addReason("COHORT_SELECTION_UNKNOWN_ABOVE_THRESHOLD")
    if threshold~requireExplicitSelectionRule & provenance~selectionRuleId="UNSPECIFIED" then assessment~addReason("COHORT_SELECTION_RULE_REQUIRED")
  end
  return assessment
/* Build reasoning material.  Strong claims require counterweight/scope through
   BrandEffectEvidencePacket; this method supplies both from the observed
   population instead of emitting a naked journey label. */
::method reasoningReport
  use arg analysis, temporalSeries=.nil
  if analysis==.nil then return .BrandJourneyPopulationResult~failure("ANALYSIS_REQUIRED")
  f=analysis~frame; a=analysis~assessment; t=analysis~threshold
  claim="JOURNEY_FEATURE_OUTCOME_ASSOCIATION"
  packet=.BrandEffectEvidencePacket~new("JOURNEY-"||analysis~analysisId,claim,f~featureClass,f,t,a,temporalSeries)
  do p over f~supportPoints; packet~addSupportPoint(p); end
  do p over f~counterPoints; packet~addCounterPoint(p); end
  packet~addScopeExclusion("OTHER_JOURNEY_CLASSIFICATIONS")
  packet~addScopeExclusion("OUTSIDE_DECLARED_TIME_WINDOW")
  packet~permitInterpretation("INVESTIGATE_ASSOCIATION_WITHIN_SCOPED_JOURNEYS_AND_TIME")
  packet~prohibitInterpretation("JOURNEY_FEATURE_CAUSES_OUTCOME")
  packet~prohibitInterpretation("GENERALISE_BEYOND_SCOPED_JOURNEYS")
  if f~supportPoints~items=0 then packet~addSupportPoint(analysis~cohort~pointId)
  pr=packet~seal; if \pr~ok then return .BrandJourneyPopulationResult~failure(pr~code,pr~detail)
  report=.BrandJourneyPopulationReport~new("REPORT-"||analysis~analysisId,analysis,packet)
  return .BrandJourneyPopulationResult~success(report)

/* Current / previous / baseline populations retain separate denominators and
   scopes; no lifetime aggregate is allowed to hide a current-window shift. */
::method temporalReport
  use arg population, currentCohort, previousCohort, baselineCohort, threshold=.nil, modifierCode=""
  if threshold==.nil then threshold=.BrandEvidenceThreshold~new
  cr=self~analyze(population,currentCohort,threshold,modifierCode); if \cr~ok then return cr
  pr=self~analyze(population,previousCohort,threshold,modifierCode); if \pr~ok then return pr
  br=self~analyze(population,baselineCohort,threshold,modifierCode); if \br~ok then return br
  series=.BrandTemporalEvidenceSeries~new("JOURNEY-TEMPORAL-"||currentCohort~cohortId)
  series~addFrame(cr~value~frame); series~addFrame(pr~value~frame); series~addFrame(br~value~frame)
  ss=series~seal; if \ss~ok then return .BrandJourneyPopulationResult~failure(ss~code,ss~detail)
  rr=self~reasoningReport(cr~value,series); if \rr~ok then return rr
  study=.BrandJourneyTemporalPopulationReport~new("TEMPORAL-"||currentCohort~cohortId,rr~value,pr~value,br~value,series)
  return .BrandJourneyPopulationResult~success(study)

::class BrandJourneyPopulationReport subclass AlchemyObject public
::attribute reportId get
::attribute analysis get
::attribute packet get
::method init
  expose reportId analysis packet
  use arg idArg, analysisArg, packetArg, alchemySealerArg=.nil, alchemyAuthorityArg=.nil
  reportId=idArg~string; analysis=analysisArg; packet=packetArg
  self~initAlchemy(.BrandJourneyPopulationAlchemySupport~metadata("reasoning-ready journey population report; evidence before verdict"),alchemySealerArg,alchemyAuthorityArg)
  self~registerStateVariable("reportId","CUSTOMER","report id")
  self~registerStateVariable("analysis","INTERNAL","scoped population analysis")
  self~registerStateVariable("packet","INTERNAL","statistical/temporal reasoning packet")
  self~registerMethodContract("REASONINGMATERIAL","emit denominator, time scope, uncertainty, counterweight and interpretation bounds",.array~new,"STRING",.false,"AUTO","CUSTOMER","NORMAL","READ","NONE")
  if analysis~hasMethod("ALCHEMYOBJECTID") then self~recordRelationship("USES",analysis,"journey population analysis","INTERNAL")
  if packet~hasMethod("ALCHEMYOBJECTID") then self~recordRelationship("USES",packet,"Brand Interaction evidence packet","INTERNAL")
::method reasoningMaterial
  expose reportId analysis packet
  out=.BrandJourneyPopulationCanonical~field("BRAND_JOURNEY_POPULATION_REPORT",reportId)
  out||=analysis~canonicalText
  out||=.BrandJourneyPopulationCanonical~field("REASONING_PACKET_BEGIN","1")
  out||=packet~canonicalText
  out||=.BrandJourneyPopulationCanonical~field("REASONING_PACKET_END","1")
  return out

::class BrandJourneyTemporalPopulationReport subclass AlchemyObject public
::attribute reportId get
::attribute currentReport get
::attribute previousAnalysis get
::attribute baselineAnalysis get
::attribute temporalSeries get
::method init
  expose reportId currentReport previousAnalysis baselineAnalysis temporalSeries
  use arg idArg, currentArg, previousArg, baselineArg, seriesArg, alchemySealerArg=.nil, alchemyAuthorityArg=.nil
  reportId=idArg~string; currentReport=currentArg; previousAnalysis=previousArg; baselineAnalysis=baselineArg; temporalSeries=seriesArg
  self~initAlchemy(.BrandJourneyPopulationAlchemySupport~metadata("current/previous/baseline journey population report preserving separate time-scoped denominators"),alchemySealerArg,alchemyAuthorityArg)
  self~registerStateVariable("reportId","CUSTOMER","temporal report id")
  self~registerStateVariable("currentReport","INTERNAL","current-window reasoning report")
  self~registerStateVariable("previousAnalysis","INTERNAL","previous-window analysis")
  self~registerStateVariable("baselineAnalysis","INTERNAL","long-baseline analysis")
  self~registerStateVariable("temporalSeries","INTERNAL","Brand Interaction temporal evidence series")
::method reasoningMaterial
  expose reportId currentReport previousAnalysis baselineAnalysis temporalSeries
  out=.BrandJourneyPopulationCanonical~field("BRAND_JOURNEY_TEMPORAL_REPORT",reportId)
  out||=currentReport~reasoningMaterial
  out||=.BrandJourneyPopulationCanonical~field("PREVIOUS_WINDOW_BEGIN","1")
  out||=previousAnalysis~canonicalText
  out||=.BrandJourneyPopulationCanonical~field("PREVIOUS_WINDOW_END","1")
  out||=.BrandJourneyPopulationCanonical~field("BASELINE_WINDOW_BEGIN","1")
  out||=baselineAnalysis~canonicalText
  out||=.BrandJourneyPopulationCanonical~field("BASELINE_WINDOW_END","1")
  out||=.BrandJourneyPopulationCanonical~field("TEMPORAL_COMPARISON_BEGIN","1")
  out||=temporalSeries~canonicalText
  out||=.BrandJourneyPopulationCanonical~field("TEMPORAL_COMPARISON_END","1")
  return out

::class BrandJourneyPopulationLibrary subclass AlchemyObject public
::method init
  expose populations
  use arg alchemySealerArg=.nil, alchemyAuthorityArg=.nil
  populations=.directory~new
  self~initAlchemy(.BrandJourneyPopulationAlchemySupport~metadata("registry of sealed privacy-minimised journey populations; not customer identity"),alchemySealerArg,alchemyAuthorityArg)
  self~registerStateVariable("populations","INTERNAL","sealed journey populations")
  self~registerInstrumentationPoint("BRAND.JOURNEY.POPULATION.REGISTERED","sealed journey population registered",.true,"ALL","INTERNAL")
::method registerPopulation
  expose populations
  use arg population
  if population==.nil | \population~sealed then return .BrandJourneyPopulationResult~failure("POPULATION_NOT_SEALED")
  if populations~hasIndex(population~populationId) then return .BrandJourneyPopulationResult~failure("POPULATION_ALREADY_REGISTERED")
  populations[population~populationId]=population
  self~recordRelationship("CONTAINS",population,"registered privacy-minimised journey population","INTERNAL")
  self~alchemyTouch("REGISTER_POPULATION")
  self~alchemyInstrument("BRAND.JOURNEY.POPULATION.REGISTERED",population~pointId)
  return .BrandJourneyPopulationResult~success(population)
::method population
  expose populations
  use arg idArg
  return populations~at(idArg~string)

::requires "BrandJourney.cls"
::requires "BrandEffectEvidence.cls"
