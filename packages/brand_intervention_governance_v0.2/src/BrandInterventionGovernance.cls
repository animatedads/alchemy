/*
 * Brand Intervention Governance v0.2
 *
 * Governance layer above intervention-effectiveness evidence.  It turns
 * time-scoped, multi-outcome association evidence into bounded review
 * dispositions while preserving the complete evidence material for a
 * reasoning LLM or authorised human.  It never executes an intervention,
 * never collapses guardrails into a single utility score, and never promotes
 * statistical association to causation by itself.
 */

::class BrandInterventionGovernanceBuild public
::constant VERSION "0.2"
::constant API_VERSION "brand.intervention.governance/0.2"
::constant PRODUCT "ooRexx Brand Intervention Governance"

::class BrandInterventionGovernanceAlchemySupport public
::method metadata class
  use arg purposeArg
  d=.directory~new
  d["purpose"]=purposeArg~string
  d["package_version"]=.BrandInterventionGovernanceBuild~VERSION
  d["api_version"]=.BrandInterventionGovernanceBuild~API_VERSION
  d["component"]="BRAND_INTERVENTION_GOVERNANCE"
  return d

::class BrandInterventionGovernanceConstant public
::constant DISPOSITION_MEASURE_MORE "MEASURE_MORE"
::constant DISPOSITION_HOLD_BASELINE "HOLD_BASELINE"
::constant DISPOSITION_REVIEW_REQUIRED "REVIEW_REQUIRED"
::constant DISPOSITION_CONTROLLED_PILOT "CONTROLLED_PILOT_REVIEW"
::constant DISPOSITION_CONTROLLED_EXPANSION "CONTROLLED_EXPANSION_REVIEW"
::constant DISPOSITION_CONTINUE "CONTINUE_CURRENT_REVIEW"
::constant DISPOSITION_WITHDRAWAL "WITHDRAWAL_REVIEW"
::constant DISPOSITION_REGRESSION "REGRESSION_REVIEW"
::constant CAUSAL_ASSOCIATION_ONLY "ASSOCIATION_ONLY"
::constant DECISION_COLLECT "COLLECT_MORE_EVIDENCE"
::constant DECISION_NO_CHANGE "NO_CHANGE"
::constant DECISION_APPROVE_PILOT "APPROVE_CONTROLLED_PILOT"
::constant DECISION_APPROVE_EXPANSION "APPROVE_LIMITED_EXPANSION"
::constant DECISION_CONTINUE "CONTINUE_CURRENT"
::constant DECISION_PAUSE "PAUSE"
::constant DECISION_WITHDRAW "WITHDRAW"

::class BrandInterventionGovernanceResult public
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

::class BrandInterventionGovernanceCanonical public
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
  if p~caselessPos("BRAND_INTERVENTION:GOVERNANCE:")=1 then return .true
  if p~caselessPos("BRAND_INTERVENTION:EFFECTIVENESS_")=1 then return .true
  if p~caselessPos("BRAND_INTERVENTION:OUTCOME:")=1 then return .true
  if p~caselessPos("BRAND_INTERVENTION:DECISION:")=1 then return .true
  if p~caselessPos("BRAND_INTERVENTION:PROPOSAL:")=1 then return .true
  if p~caselessPos("BRAND_JOURNEY:")=1 then return .true
  if p~caselessPos("BRAND_INTERACTION:")=1 then return .true
  if p~caselessPos("INTERACTION_EVENT:")=1 then return .true
  if p~caselessPos("STRUCTURED_UTTERANCE:")=1 then return .true
  return .false
::method percentage class
  use arg part,total
  if total<=0 then return 0
  return 100*part/total
::method safeDecisionRef class
  use arg value
  if value==.nil then return .false
  p=value~string~strip
  if p="" | p~length>160 then return .false
  if p~pos(" ")>0 | p~pos('09'x)>0 | p~pos('0a'x)>0 | p~pos('0d'x)>0 then return .false
  if p~caselessPos("GOVERNANCE_DECISION:")=1 then return .true
  if p~caselessPos("CHANGE:")=1 then return .true
  if p~caselessPos("POLICY_DECISION:")=1 then return .true
  return .false

/* Governance rules are deliberately non-executing.  The rollout percentage is
   a ceiling that may be presented to an authorised decision maker; it is not
   permission for this library to assign or modify customer treatment. */
::class BrandInterventionGovernanceRuleSet subclass AlchemyObject public
::attribute ruleSetId get
::attribute maxEvidenceAgeDays get
::attribute maxCandidateExposurePct get
::attribute requireTemporalForExpansion get
::attribute requireGuardrails get
::attribute sealed get
::method init
  expose ruleSetId maxEvidenceAgeDays maxCandidateExposurePct requireTemporalForExpansion requireGuardrails obligations prohibitions sealed
  use arg idArg="BRAND-GOVERNANCE-V1", maxAgeArg=45, maxExposureArg=25, temporalArg=.true, guardrailsArg=.true
  ruleSetId=.BrandInterventionGovernanceCanonical~token(idArg); maxEvidenceAgeDays=maxAgeArg+0; maxCandidateExposurePct=maxExposureArg+0; requireTemporalForExpansion=temporalArg; requireGuardrails=guardrailsArg
  obligations=.array~new; prohibitions=.array~new; sealed=.false
  if ruleSetId="" | maxEvidenceAgeDays<0 | maxCandidateExposurePct<0 | maxCandidateExposurePct>100 then raise syntax 88.981 array("invalid governance rule set")
  self~initAlchemy(.BrandInterventionGovernanceAlchemySupport~metadata("bounded review rules for intervention evidence; no execution authority"))
  self~registerStateVariable("ruleSetId","CUSTOMER","governance rule set id")
  self~registerStateVariable("maxEvidenceAgeDays","CUSTOMER","maximum accepted evidence age")
  self~registerStateVariable("maxCandidateExposurePct","CUSTOMER","maximum exposure ceiling that may be suggested for controlled expansion review")
  self~registerStateVariable("requireTemporalForExpansion","CUSTOMER","whether expansion review needs current/previous/baseline evidence")
  self~registerStateVariable("requireGuardrails","CUSTOMER","whether guardrail outcomes are required before a positive governance disposition")
  self~registerStateVariable("obligations","CUSTOMER","governance obligations")
  self~registerStateVariable("prohibitions","CUSTOMER","governance prohibitions")
  self~registerStateVariable("sealed","CUSTOMER","rule set immutability")
::method addObligation
  expose obligations sealed; use arg v; if sealed then return .false
  t=.BrandInterventionGovernanceCanonical~token(v); if t<>"" & \.BrandInterventionGovernanceCanonical~contains(obligations,t) then obligations~append(t)
  return .true
::method addProhibition
  expose prohibitions sealed; use arg v; if sealed then return .false
  t=.BrandInterventionGovernanceCanonical~token(v); if t<>"" & \.BrandInterventionGovernanceCanonical~contains(prohibitions,t) then prohibitions~append(t)
  return .true
::method obligations
  expose obligations; return .BrandInterventionGovernanceCanonical~copyArray(obligations)
::method prohibitions
  expose prohibitions; return .BrandInterventionGovernanceCanonical~copyArray(prohibitions)
::method seal
  expose obligations prohibitions sealed
  if obligations~items=0 then do
    obligations~append("PRESERVE_FULL_EVIDENCE_FOR_REASONING")
    obligations~append("PRESERVE_GUARDRAIL_MEASUREMENT")
    obligations~append("PRESERVE_TIME_AND_RELEASE_SCOPE")
    obligations~append("PRESERVE_ELIGIBLE_NOT_APPLIED_COMPARATOR")
  end
  if prohibitions~items=0 then do
    prohibitions~append("AUTOMATIC_EXECUTION")
    prohibitions~append("SELF_PROMOTE_CAUSALITY")
    prohibitions~append("COLLAPSE_GUARDRAILS_INTO_SINGLE_SCORE")
    prohibitions~append("DROP_COUNTEREVIDENCE")
    prohibitions~append("GENERALISE_BEYOND_EVIDENCE_SCOPE")
    prohibitions~append("INFER_SALES_AUTHORITY_FROM_BRAND_CONTEXT")
  end
  sealed=.true; return .BrandInterventionGovernanceResult~success(self)
::method canonicalText
  expose ruleSetId maxEvidenceAgeDays maxCandidateExposurePct requireTemporalForExpansion requireGuardrails obligations prohibitions sealed
  if \sealed then raise syntax 93.981 additional("BrandInterventionGovernanceRuleSet must be sealed")
  out=.BrandInterventionGovernanceCanonical~field("GOVERNANCE_RULE_SET",ruleSetId)
  out||=.BrandInterventionGovernanceCanonical~field("MAX_EVIDENCE_AGE_DAYS",maxEvidenceAgeDays)
  out||=.BrandInterventionGovernanceCanonical~field("MAX_CANDIDATE_EXPOSURE_PCT",maxCandidateExposurePct)
  out||=.BrandInterventionGovernanceCanonical~field("REQUIRE_TEMPORAL_FOR_EXPANSION",requireTemporalForExpansion)
  out||=.BrandInterventionGovernanceCanonical~field("REQUIRE_GUARDRAILS",requireGuardrails)
  out||=.BrandInterventionGovernanceCanonical~join("GOVERNANCE_OBLIGATION",obligations)
  out||=.BrandInterventionGovernanceCanonical~join("GOVERNANCE_PROHIBITION",prohibitions)
  return out

/* Institutional Policy owns which reviewed version is operative.  This object
   retains that externally resolved selection without reimplementing publication,
   deployment, rollout or authority semantics inside Brand Intervention Governance. */
::class BrandInterventionGovernancePolicySelection subclass AlchemyObject public
::attribute selectionId get
::attribute policyId get
::attribute policyVersion get
::attribute policyIdentity get
::attribute resolvedAt get
::attribute resolutionMode get
::attribute deploymentIdentity get
::attribute publicationAssuranceMode get
::attribute ruleSet get
::attribute policyRelease get
::attribute publicationRecord get
::attribute sealed get
::method fromCatalog class
  use arg catalog, policyIdArg="BRAND-INTERVENTION-GOVERNANCE", atTimeArg=.nil, pointArg=.nil, selectionIdArg=""
  if catalog==.nil then return .BrandInterventionGovernanceResult~failure("INSTITUTIONAL_POLICY_CATALOG_REQUIRED")
  if atTimeArg==.nil then atTimeArg=.DateTime~new
  if pointArg==.nil then do
    if \catalog~hasMethod("EXECUTIONCONTEXT") then return .BrandInterventionGovernanceResult~failure("INSTITUTIONAL_POLICY_CATALOG_PROTOCOL_INVALID","EXECUTIONCONTEXT")
    resolved=catalog~executionContext(policyIdArg,atTimeArg)
    resolutionMode="GLOBAL"
  end
  else do
    if \catalog~hasMethod("EXECUTIONCONTEXTFORCONTEXT") then return .BrandInterventionGovernanceResult~failure("INSTITUTIONAL_POLICY_CATALOG_PROTOCOL_INVALID","EXECUTIONCONTEXTFORCONTEXT")
    resolved=catalog~executionContextForContext(policyIdArg,pointArg,atTimeArg)
    resolutionMode="CONTEXTUAL"
  end
  if resolved==.nil | \resolved~hasMethod("OK") then return .BrandInterventionGovernanceResult~failure("INSTITUTIONAL_POLICY_RESOLUTION_PROTOCOL_INVALID")
  if \resolved~ok then return .BrandInterventionGovernanceResult~failure(resolved~code,resolved~detail)
  context=resolved~value
  if context==.nil | \context~hasMethod("POLICY") then return .BrandInterventionGovernanceResult~failure("INSTITUTIONAL_POLICY_CONTEXT_INVALID")
  release=context~policy
  if release==.nil | \release~hasMethod("PAYLOAD") then return .BrandInterventionGovernanceResult~failure("GOVERNANCE_POLICY_PAYLOAD_REQUIRED")
  rules=release~payload
  if rules==.nil | \rules~isA(.BrandInterventionGovernanceRuleSet) then return .BrandInterventionGovernanceResult~failure("GOVERNANCE_POLICY_PAYLOAD_TYPE_INVALID")
  if \rules~sealed then return .BrandInterventionGovernanceResult~failure("GOVERNANCE_POLICY_RULE_SET_NOT_SEALED")
  publication=.nil
  assurance="UNSPECIFIED"
  if catalog~hasMethod("PUBLICATIONRECORD") then do
    pr=catalog~publicationRecord(release~policyId,release~version)
    if pr~ok then do
      publication=pr~value
      if publication~hasMethod("ASSURANCEMODE") then assurance=publication~assuranceMode
    end
  end
  sid=selectionIdArg~string
  if sid="" then sid="SEL-"||release~policyId||"-"||release~version
  selection=self~new(sid,release,context,rules,publication,assurance,resolutionMode)
  sr=selection~seal
  if \sr~ok then return sr
  return .BrandInterventionGovernanceResult~success(selection)
::method init
  expose selectionId policyId policyVersion policyIdentity resolvedAt resolutionMode deploymentIdentity publicationAssuranceMode ruleSet policyRelease publicationRecord sealed
  use arg idArg, releaseArg, contextArg, rulesArg, publicationArg=.nil, assuranceArg="UNSPECIFIED", modeArg="GLOBAL"
  selectionId=idArg~string
  policyRelease=releaseArg; ruleSet=rulesArg; publicationRecord=publicationArg
  policyId=releaseArg~policyId~string; policyVersion=releaseArg~version~string; policyIdentity=releaseArg~semanticIdentity~string
  resolvedAt=contextArg~actionTime~string; resolutionMode=.BrandInterventionGovernanceCanonical~token(modeArg)
  deploymentIdentity=""; if contextArg~hasMethod("DEPLOYMENTIDENTITY") then deploymentIdentity=contextArg~deploymentIdentity~string
  publicationAssuranceMode=.BrandInterventionGovernanceCanonical~token(assuranceArg); sealed=.false
  if selectionId="" | policyId="" | policyVersion="" | policyIdentity="" | resolvedAt="" | ruleSet==.nil then raise syntax 88.986 array("institutional policy selection requires exact release/context/rules")
  self~initAlchemy(.BrandInterventionGovernanceAlchemySupport~metadata("exact operative Institutional Policy selection for brand intervention governance"))
  self~registerStateVariable("selectionId","CUSTOMER","institutional policy selection id")
  self~registerStateVariable("policyId","CUSTOMER","selected institutional policy id")
  self~registerStateVariable("policyVersion","CUSTOMER","selected institutional policy version")
  self~registerStateVariable("policyIdentity","INTERNAL","exact selected policy semantic identity")
  self~registerStateVariable("resolvedAt","CUSTOMER","time used for institutional policy resolution")
  self~registerStateVariable("resolutionMode","CUSTOMER","global or contextual policy resolution")
  self~registerStateVariable("deploymentIdentity","INTERNAL","exact deployment/topology identity supplied by Institutional Policy")
  self~registerStateVariable("publicationAssuranceMode","CUSTOMER","publication assurance reported by Institutional Policy")
  self~registerStateVariable("ruleSet","INTERNAL","domain-owned governance rule set carried as policy payload")
  self~registerStateVariable("policyRelease","INTERNAL","exact Institutional Policy release")
  self~registerStateVariable("publicationRecord","INTERNAL","Institutional Policy publication authority evidence")
  self~registerStateVariable("sealed","CUSTOMER","selection immutability")
  self~recordRelationship("SELECTS",ruleSet,"governance rule set resolved through Institutional Policy","INTERNAL")
  self~recordRelationship("RESOLVED_FROM",policyRelease,"exact operative Institutional Policy release","INTERNAL")
  if publicationRecord<>.nil then self~recordRelationship("SUPPORTED_BY",publicationRecord,"Institutional Policy publication authority evidence","INTERNAL")
::method seal
  expose policyRelease policyId policyVersion policyIdentity ruleSet sealed
  if policyRelease==.nil | ruleSet==.nil then return .BrandInterventionGovernanceResult~failure("INSTITUTIONAL_POLICY_SELECTION_INCOMPLETE")
  if \ruleSet~sealed then return .BrandInterventionGovernanceResult~failure("GOVERNANCE_POLICY_RULE_SET_NOT_SEALED")
  if policyRelease~policyId~string<>policyId | policyRelease~version~string<>policyVersion | policyRelease~semanticIdentity~string<>policyIdentity then return .BrandInterventionGovernanceResult~failure("INSTITUTIONAL_POLICY_SELECTION_IDENTITY_MISMATCH")
  if policyRelease~payload \== ruleSet then return .BrandInterventionGovernanceResult~failure("INSTITUTIONAL_POLICY_SELECTION_PAYLOAD_MISMATCH")
  sealed=.true; self~alchemyTouch("INSTITUTIONAL_POLICY_SELECTION_SEAL")
  return .BrandInterventionGovernanceResult~success(self)
::method pointId
  expose selectionId; return "BRAND_INTERVENTION:GOVERNANCE:POLICY_SELECTION:"||selectionId
::method reasoningMaterial
  expose selectionId policyId policyVersion policyIdentity resolvedAt resolutionMode deploymentIdentity publicationAssuranceMode ruleSet policyRelease publicationRecord sealed
  if \sealed then raise syntax 93.986 additional("BrandInterventionGovernancePolicySelection must be sealed")
  out=.BrandInterventionGovernanceCanonical~field("GOVERNANCE_POLICY_SELECTION",selectionId)
  out||=.BrandInterventionGovernanceCanonical~field("INSTITUTIONAL_POLICY_ID",policyId)
  out||=.BrandInterventionGovernanceCanonical~field("INSTITUTIONAL_POLICY_VERSION",policyVersion)
  out||=.BrandInterventionGovernanceCanonical~field("INSTITUTIONAL_POLICY_IDENTITY",policyIdentity)
  out||=.BrandInterventionGovernanceCanonical~field("POLICY_RESOLVED_AT",resolvedAt)
  out||=.BrandInterventionGovernanceCanonical~field("POLICY_RESOLUTION_MODE",resolutionMode)
  out||=.BrandInterventionGovernanceCanonical~field("POLICY_DEPLOYMENT_IDENTITY",deploymentIdentity)
  out||=.BrandInterventionGovernanceCanonical~field("POLICY_PUBLICATION_ASSURANCE",publicationAssuranceMode)
  if policyRelease~hasMethod("PAYLOADIDENTITY") then out||=.BrandInterventionGovernanceCanonical~field("POLICY_PAYLOAD_IDENTITY",policyRelease~payloadIdentity)
  if publicationRecord<>.nil then do
    out||=.BrandInterventionGovernanceCanonical~field("POLICY_PUBLICATION_RECORD_BEGIN",1)
    out||=publicationRecord~canonicalText
    out||=.BrandInterventionGovernanceCanonical~field("POLICY_PUBLICATION_RECORD_END",1)
  end
  return out

/* The age is supplied by an external temporal authority.  This component does
   not infer wall-clock truth from date strings. */
::class BrandInterventionGovernanceEvidenceBinding subclass AlchemyObject public
::attribute bindingId get
::attribute source get
::attribute asOfAt get
::attribute evidenceAgeDays get
::attribute temporalAuthorityId get
::attribute sealed get
::method init
  expose bindingId source asOfAt evidenceAgeDays temporalAuthorityId sealed
  use arg idArg, sourceArg, asOfArg, ageArg, temporalAuthorityArg="UNSPECIFIED"
  bindingId=idArg~string; source=sourceArg; asOfAt=asOfArg~string; evidenceAgeDays=ageArg+0; temporalAuthorityId=.BrandInterventionGovernanceCanonical~token(temporalAuthorityArg); sealed=.false
  if bindingId="" | source==.nil | asOfAt="" | evidenceAgeDays<0 then raise syntax 88.982 array("governance evidence binding requires source, as-of time and non-negative age")
  self~initAlchemy(.BrandInterventionGovernanceAlchemySupport~metadata("time-authorised binding of complete intervention-effectiveness evidence"))
  self~registerStateVariable("bindingId","CUSTOMER","governance evidence binding id")
  self~registerStateVariable("source","INTERNAL","complete effectiveness study or temporal report")
  self~registerStateVariable("asOfAt","CUSTOMER","governance decision as-of time")
  self~registerStateVariable("evidenceAgeDays","CUSTOMER","age supplied by temporal authority")
  self~registerStateVariable("temporalAuthorityId","INTERNAL","authority/source for evidence age")
  self~registerStateVariable("sealed","CUSTOMER","binding immutability")
  self~recordRelationship("USES",source,"complete intervention effectiveness evidence","INTERNAL")
::method hasTemporal
  expose source
  return source~hasMethod("CURRENTSTUDY") & source~hasMethod("PREVIOUSSTUDY") & source~hasMethod("BASELINESTUDY")
::method currentStudy
  expose source
  if self~hasTemporal then return source~currentStudy
  if source~hasMethod("PRIMARYANALYSIS") then return source
  return .nil
::method previousStudy
  expose source
  if self~hasTemporal then return source~previousStudy
  return .nil
::method baselineStudy
  expose source
  if self~hasTemporal then return source~baselineStudy
  return .nil
::method seal
  expose sealed
  if self~currentStudy==.nil then return .BrandInterventionGovernanceResult~failure("EFFECTIVENESS_SOURCE_UNSUPPORTED")
  if \self~currentStudy~sealed then return .BrandInterventionGovernanceResult~failure("CURRENT_STUDY_NOT_SEALED")
  if self~hasTemporal then do
    if \self~previousStudy~sealed | \self~baselineStudy~sealed then return .BrandInterventionGovernanceResult~failure("TEMPORAL_STUDY_NOT_SEALED")
  end
  sealed=.true; return .BrandInterventionGovernanceResult~success(self)
::method pointId
  expose bindingId; return "BRAND_INTERVENTION:GOVERNANCE:EVIDENCE_BINDING:"||bindingId
::method reasoningMaterial
  expose bindingId source asOfAt evidenceAgeDays temporalAuthorityId sealed
  if \sealed then raise syntax 93.982 additional("BrandInterventionGovernanceEvidenceBinding must be sealed")
  out=.BrandInterventionGovernanceCanonical~field("GOVERNANCE_EVIDENCE_BINDING",bindingId)
  out||=.BrandInterventionGovernanceCanonical~field("AS_OF_AT",asOfAt)
  out||=.BrandInterventionGovernanceCanonical~field("EVIDENCE_AGE_DAYS",evidenceAgeDays)
  out||=.BrandInterventionGovernanceCanonical~field("TEMPORAL_AUTHORITY_ID",temporalAuthorityId)
  out||=.BrandInterventionGovernanceCanonical~field("UPSTREAM_EFFECTIVENESS_BEGIN",1)
  out||=source~reasoningMaterial
  out||=.BrandInterventionGovernanceCanonical~field("UPSTREAM_EFFECTIVENESS_END",1)
  return out

::class BrandInterventionGovernanceRecommendation subclass AlchemyObject public
::attribute recommendationId get
::attribute disposition get
::attribute interventionKind get
::attribute evidenceStatus get
::attribute appliedExposurePct get
::attribute candidateExposureCapPct get
::attribute causalStatus get
::attribute externalAuthorityRequired get
::attribute institutionalPolicySelection get
::attribute institutionalPolicyManaged get
::attribute sealed get
::method init
  expose recommendationId disposition interventionKind evidenceStatus appliedExposurePct candidateExposureCapPct causalStatus externalAuthorityRequired institutionalPolicySelection institutionalPolicyManaged binding rules rationales conditions prohibitions evidencePoints sealed
  use arg idArg, dispositionArg, interventionArg, statusArg, appliedPctArg, capPctArg, bindingArg, rulesArg, alchemySealerArg=.nil, alchemyAuthorityArg=.nil, policySelectionArg=.nil
  recommendationId=idArg~string; disposition=.BrandInterventionGovernanceCanonical~token(dispositionArg); interventionKind=.BrandInterventionGovernanceCanonical~token(interventionArg); evidenceStatus=.BrandInterventionGovernanceCanonical~token(statusArg)
  appliedExposurePct=appliedPctArg+0; candidateExposureCapPct=capPctArg+0; causalStatus=.BrandInterventionGovernanceConstant~CAUSAL_ASSOCIATION_ONLY; externalAuthorityRequired=.true
  binding=bindingArg; rules=rulesArg; institutionalPolicySelection=policySelectionArg; institutionalPolicyManaged=policySelectionArg<>.nil; rationales=.array~new; conditions=.array~new; prohibitions=.array~new; evidencePoints=.array~new; sealed=.false
  if recommendationId="" | disposition="" | interventionKind="" | binding==.nil | rules==.nil then raise syntax 88.983 array("governance recommendation requires id/disposition/intervention/evidence/rules")
  self~initAlchemy(.BrandInterventionGovernanceAlchemySupport~metadata("non-executing intervention governance recommendation preserving complete reasoning evidence"),alchemySealerArg,alchemyAuthorityArg)
  self~registerStateVariable("recommendationId","CUSTOMER","recommendation id")
  self~registerStateVariable("disposition","CUSTOMER","bounded governance review disposition")
  self~registerStateVariable("interventionKind","CUSTOMER","intervention under review")
  self~registerStateVariable("evidenceStatus","CUSTOMER","current effectiveness evidence status")
  self~registerStateVariable("appliedExposurePct","CUSTOMER","current applied share among eligible journeys")
  self~registerStateVariable("candidateExposureCapPct","CUSTOMER","review ceiling, not execution authority")
  self~registerStateVariable("causalStatus","CUSTOMER","association-only causal status")
  self~registerStateVariable("externalAuthorityRequired","CUSTOMER","external authority must decide and external component must execute")
  self~registerStateVariable("institutionalPolicySelection","INTERNAL","exact operative Institutional Policy selection when managed")
  self~registerStateVariable("institutionalPolicyManaged","CUSTOMER","whether recommendation used an Institutional Policy-resolved rule set")
  self~registerStateVariable("binding","INTERNAL","full effectiveness evidence binding")
  self~registerStateVariable("rules","INTERNAL","governance rule set")
  self~registerStateVariable("rationales","CUSTOMER","controlled rationale codes")
  self~registerStateVariable("conditions","CUSTOMER","conditions that must survive a governance decision")
  self~registerStateVariable("prohibitions","CUSTOMER","explicit anti-optimisation and anti-overclaim bounds")
  self~registerStateVariable("evidencePoints","INTERNAL","opaque supporting evidence references")
  self~registerStateVariable("sealed","CUSTOMER","recommendation immutability")
  self~recordRelationship("USES",binding,"full effectiveness evidence","INTERNAL")
  self~recordRelationship("GOVERNED_BY",rules,"governance rule set","INTERNAL")
  if institutionalPolicySelection<>.nil then self~recordRelationship("POLICY_SELECTED_BY",institutionalPolicySelection,"exact Institutional Policy selection","INTERNAL")
  self~registerInstrumentationPoint("BRAND.INTERVENTION.GOVERNANCE.RECOMMENDATION.SEALED","governance recommendation sealed",.true,"ALL","INTERNAL")
::method addRationale
  expose rationales sealed; use arg v; if sealed then return .false
  t=.BrandInterventionGovernanceCanonical~token(v); if t<>"" & \.BrandInterventionGovernanceCanonical~contains(rationales,t) then rationales~append(t)
  return .true
::method addCondition
  expose conditions sealed; use arg v; if sealed then return .false
  t=.BrandInterventionGovernanceCanonical~token(v); if t<>"" & \.BrandInterventionGovernanceCanonical~contains(conditions,t) then conditions~append(t)
  return .true
::method addProhibition
  expose prohibitions sealed; use arg v; if sealed then return .false
  t=.BrandInterventionGovernanceCanonical~token(v); if t<>"" & \.BrandInterventionGovernanceCanonical~contains(prohibitions,t) then prohibitions~append(t)
  return .true
::method addEvidencePoint
  expose evidencePoints sealed; use arg v
  if sealed | \.BrandInterventionGovernanceCanonical~safePoint(v) then return .false
  if \.BrandInterventionGovernanceCanonical~contains(evidencePoints,v~string) then evidencePoints~append(v~string)
  return .true
::method rationales
  expose rationales; return .BrandInterventionGovernanceCanonical~copyArray(rationales)
::method conditions
  expose conditions; return .BrandInterventionGovernanceCanonical~copyArray(conditions)
::method prohibitions
  expose prohibitions; return .BrandInterventionGovernanceCanonical~copyArray(prohibitions)
::method evidencePoints
  expose evidencePoints; return .BrandInterventionGovernanceCanonical~copyArray(evidencePoints)
::method hasProhibition
  expose prohibitions; use arg v; return .BrandInterventionGovernanceCanonical~contains(prohibitions,.BrandInterventionGovernanceCanonical~token(v))
::method seal
  expose rationales conditions prohibitions sealed
  if rationales~items=0 | conditions~items=0 | prohibitions~items=0 then return .BrandInterventionGovernanceResult~failure("REASONING_BOUNDS_REQUIRED")
  sealed=.true; self~alchemyTouch("GOVERNANCE_RECOMMENDATION_SEAL"); self~alchemyInstrument("BRAND.INTERVENTION.GOVERNANCE.RECOMMENDATION.SEALED",self~pointId)
  return .BrandInterventionGovernanceResult~success(self)
::method pointId
  expose recommendationId; return "BRAND_INTERVENTION:GOVERNANCE:RECOMMENDATION:"||recommendationId
::method reasoningMaterial
  expose recommendationId disposition interventionKind evidenceStatus appliedExposurePct candidateExposureCapPct causalStatus externalAuthorityRequired institutionalPolicySelection institutionalPolicyManaged binding rules rationales conditions prohibitions evidencePoints sealed
  if \sealed then raise syntax 93.983 additional("BrandInterventionGovernanceRecommendation must be sealed")
  out=.BrandInterventionGovernanceCanonical~field("BRAND_INTERVENTION_GOVERNANCE_RECOMMENDATION",recommendationId)
  out||=.BrandInterventionGovernanceCanonical~field("DISPOSITION",disposition)
  out||=.BrandInterventionGovernanceCanonical~field("INTERVENTION_KIND",interventionKind)
  out||=.BrandInterventionGovernanceCanonical~field("EVIDENCE_STATUS",evidenceStatus)
  out||=.BrandInterventionGovernanceCanonical~field("APPLIED_EXPOSURE_PCT",appliedExposurePct)
  out||=.BrandInterventionGovernanceCanonical~field("CANDIDATE_EXPOSURE_CAP_PCT",candidateExposureCapPct)
  out||=.BrandInterventionGovernanceCanonical~field("CAUSAL_STATUS",causalStatus)
  out||=.BrandInterventionGovernanceCanonical~field("EXTERNAL_AUTHORITY_REQUIRED",externalAuthorityRequired)
  out||=.BrandInterventionGovernanceCanonical~field("INSTITUTIONAL_POLICY_MANAGED",institutionalPolicyManaged)
  out||=.BrandInterventionGovernanceCanonical~join("GOVERNANCE_RATIONALE",rationales)
  out||=.BrandInterventionGovernanceCanonical~join("GOVERNANCE_CONDITION",conditions)
  out||=.BrandInterventionGovernanceCanonical~join("GOVERNANCE_PROHIBITION",prohibitions)
  out||=.BrandInterventionGovernanceCanonical~join("GOVERNANCE_EVIDENCE_POINT",evidencePoints)
  out||=.BrandInterventionGovernanceCanonical~field("RULE_SET_BEGIN",1)||rules~canonicalText||.BrandInterventionGovernanceCanonical~field("RULE_SET_END",1)
  if institutionalPolicySelection<>.nil then out||=.BrandInterventionGovernanceCanonical~field("POLICY_SELECTION_BEGIN",1)||institutionalPolicySelection~reasoningMaterial||.BrandInterventionGovernanceCanonical~field("POLICY_SELECTION_END",1)
  out||=.BrandInterventionGovernanceCanonical~field("EVIDENCE_BEGIN",1)||binding~reasoningMaterial||.BrandInterventionGovernanceCanonical~field("EVIDENCE_END",1)
  out||=.BrandInterventionGovernanceCanonical~field("NO_SINGLE_UTILITY_SCORE",1)
  out||=.BrandInterventionGovernanceCanonical~field("INTERPRETATION_BOUND","RECOMMENDATION_NOT_EXECUTION")
  out||=.BrandInterventionGovernanceCanonical~field("INTERPRETATION_BOUND","ASSOCIATION_NOT_CAUSATION")
  return out

::class BrandInterventionGovernanceEngine public
::method recommendUnderInstitutionalPolicy
  use arg binding, policySelection, alchemySealerArg=.nil, alchemyAuthorityArg=.nil
  if policySelection==.nil | \policySelection~isA(.BrandInterventionGovernancePolicySelection) then return .BrandInterventionGovernanceResult~failure("INSTITUTIONAL_POLICY_SELECTION_REQUIRED")
  if \policySelection~sealed then return .BrandInterventionGovernanceResult~failure("INSTITUTIONAL_POLICY_SELECTION_NOT_SEALED")
  return self~recommend(binding,policySelection~ruleSet,alchemySealerArg,alchemyAuthorityArg,policySelection)
::method recommend
  use arg binding, rules=.nil, alchemySealerArg=.nil, alchemyAuthorityArg=.nil, policySelectionArg=.nil
  if binding==.nil | \binding~sealed then return .BrandInterventionGovernanceResult~failure("EVIDENCE_BINDING_NOT_SEALED")
  if rules==.nil then return .BrandInterventionGovernanceResult~failure("GOVERNANCE_RULE_SET_REQUIRED","pass an explicit sealed rule set or use recommendUnderInstitutionalPolicy")
  if \rules~sealed then return .BrandInterventionGovernanceResult~failure("RULE_SET_NOT_SEALED")
  if policySelectionArg<>.nil then do
    if \policySelectionArg~isA(.BrandInterventionGovernancePolicySelection) | \policySelectionArg~sealed then return .BrandInterventionGovernanceResult~failure("INSTITUTIONAL_POLICY_SELECTION_INVALID")
    if policySelectionArg~ruleSet \== rules then return .BrandInterventionGovernanceResult~failure("INSTITUTIONAL_POLICY_SELECTION_RULE_SET_MISMATCH")
  end
  s=binding~currentStudy; p=s~primaryAnalysis; a=p~aggregate
  status=s~status; intervention=a~interventionKind; appliedPct=.BrandInterventionGovernanceCanonical~percentage(a~appliedCount,a~eligibleCount)
  disposition=.BrandInterventionGovernanceConstant~DISPOSITION_REVIEW_REQUIRED

  if binding~evidenceAgeDays>rules~maxEvidenceAgeDays then disposition=.BrandInterventionGovernanceConstant~DISPOSITION_REVIEW_REQUIRED
  else if status=.BrandInterventionEffectivenessConstant~STATUS_INSUFFICIENT then disposition=.BrandInterventionGovernanceConstant~DISPOSITION_MEASURE_MORE
  else if status=.BrandInterventionEffectivenessConstant~STATUS_NO_CLEAR then disposition=.BrandInterventionGovernanceConstant~DISPOSITION_HOLD_BASELINE
  else if status=.BrandInterventionEffectivenessConstant~STATUS_REVIEW then disposition=.BrandInterventionGovernanceConstant~DISPOSITION_REVIEW_REQUIRED
  else if status=.BrandInterventionEffectivenessConstant~STATUS_MIXED | status=.BrandInterventionEffectivenessConstant~STATUS_ADVERSE then do
    if binding~hasTemporal & self~priorWasPromising(binding) then disposition=.BrandInterventionGovernanceConstant~DISPOSITION_REGRESSION
    else disposition=.BrandInterventionGovernanceConstant~DISPOSITION_WITHDRAWAL
  end
  else if status=.BrandInterventionEffectivenessConstant~STATUS_PROMISING then do
    if rules~requireGuardrails & s~guardrails~items=0 then disposition=.BrandInterventionGovernanceConstant~DISPOSITION_REVIEW_REQUIRED
    else if rules~requireTemporalForExpansion & \binding~hasTemporal then disposition=.BrandInterventionGovernanceConstant~DISPOSITION_CONTROLLED_PILOT
    else if appliedPct<rules~maxCandidateExposurePct then disposition=.BrandInterventionGovernanceConstant~DISPOSITION_CONTROLLED_EXPANSION
    else disposition=.BrandInterventionGovernanceConstant~DISPOSITION_CONTINUE
  end

  r=.BrandInterventionGovernanceRecommendation~new("REC-"||binding~bindingId,disposition,intervention,status,appliedPct,rules~maxCandidateExposurePct,binding,rules,alchemySealerArg,alchemyAuthorityArg,policySelectionArg)
  ignore=self~applyCommonBounds(r,rules)
  r~addEvidencePoint(binding~pointId)
  r~addRationale("CURRENT_EFFECTIVENESS_STATUS_"||status)
  if policySelectionArg<>.nil then do
    r~addRationale("INSTITUTIONAL_POLICY_SELECTION_ACTIVE")
    r~addCondition("USE_EXACT_SELECTED_POLICY_VERSION")
    r~addEvidencePoint(policySelectionArg~pointId)
  end
  else do
    r~addRationale("EXPLICIT_UNMANAGED_RULE_SET")
    r~addCondition("INSTITUTIONAL_POLICY_SELECTION_REQUIRED_FOR_OPERATIVE_USE")
  end
  if binding~evidenceAgeDays>rules~maxEvidenceAgeDays then do
    r~addRationale("EVIDENCE_STALE")
    r~addCondition("REFRESH_SCOPED_CURRENT_EVIDENCE")
    r~addProhibition("CHANGE_EXPOSURE_FROM_STALE_EVIDENCE")
  end
  if a~assignmentMethod=.BrandInterventionEffectivenessConstant~ASSIGNMENT_RANDOMIZED then r~addRationale("RANDOMIZED_DESIGN_PRESENT_BUT_CAUSAL_AUTHORITY_EXTERNAL")
  if a~assignmentMethod=.BrandInterventionEffectivenessConstant~ASSIGNMENT_OBSERVATIONAL then r~addRationale("INTERVENTION_SELECTION_BIAS_REMAINS_PLAUSIBLE")
  if disposition=.BrandInterventionGovernanceConstant~DISPOSITION_MEASURE_MORE then r~addCondition("COLLECT_MORE_ELIGIBLE_APPLIED_AND_NOT_APPLIED_EVIDENCE")
  if disposition=.BrandInterventionGovernanceConstant~DISPOSITION_HOLD_BASELINE then r~addCondition("PRESERVE_CURRENT_BASELINE_WHILE_OBSERVING")
  if disposition=.BrandInterventionGovernanceConstant~DISPOSITION_CONTROLLED_PILOT then do
    r~addCondition("TEMPORAL_COMPARISON_REQUIRED_BEFORE_EXPANSION")
    r~addCondition("CONTROLLED_PILOT_REQUIRES_NAMED_AUTHORITY")
  end
  if disposition=.BrandInterventionGovernanceConstant~DISPOSITION_CONTROLLED_EXPANSION then do
    r~addCondition("EXPANSION_MUST_REMAIN_WITHIN_DECLARED_EXPOSURE_CAP")
    r~addCondition("MAINTAIN_COMPARATOR_AND_GUARDRAILS_DURING_EXPANSION")
  end
  if disposition=.BrandInterventionGovernanceConstant~DISPOSITION_CONTINUE then r~addCondition("CONTINUE_MEASUREMENT_WITHOUT_ASSUMING_PERMANENT_EFFECT")
  if disposition=.BrandInterventionGovernanceConstant~DISPOSITION_WITHDRAWAL then do
    r~addCondition("AUTHORITATIVE_REVIEW_OF_ADVERSE_OR_MIXED_EFFECTS")
    r~addProhibition("OPTIMISE_PRIMARY_OUTCOME_WHILE_IGNORING_GUARDRAIL_HARM")
  end
  if disposition=.BrandInterventionGovernanceConstant~DISPOSITION_REGRESSION then do
    r~addCondition("INVESTIGATE_CURRENT_WINDOW_REGRESSION_AGAINST_PRIOR_EVIDENCE")
    r~addProhibition("AVERAGE_CURRENT_REGRESSION_AWAY_IN_LONG_BASELINE")
    r~addRationale("CURRENT_EFFECT_REGRESSED_FROM_PRIOR_PROMISING_WINDOW")
  end
  if disposition=.BrandInterventionGovernanceConstant~DISPOSITION_REVIEW_REQUIRED & binding~evidenceAgeDays<=rules~maxEvidenceAgeDays then r~addCondition("AUTHORISED_REVIEW_BEFORE_ANY_EXPOSURE_CHANGE")
  rr=r~seal; if \rr~ok then return rr
  return .BrandInterventionGovernanceResult~success(r)

::method applyCommonBounds private
  use arg recommendation,rules
  recommendation~addCondition("NAMED_EXTERNAL_AUTHORITY_REQUIRED")
  recommendation~addCondition("PRESERVE_FULL_REASONING_PACKET")
  do x over rules~obligations; recommendation~addCondition(x); end
  do x over rules~prohibitions; recommendation~addProhibition(x); end
  return .true

::method priorWasPromising private
  use arg binding
  if \binding~hasTemporal then return .false
  ps=binding~previousStudy~status; bs=binding~baselineStudy~status
  return ps=.BrandInterventionEffectivenessConstant~STATUS_PROMISING | bs=.BrandInterventionEffectivenessConstant~STATUS_PROMISING

/* Authority records who may make a governance decision.  It does not receive
   any capability to execute the decision against customer-facing systems. */
::class BrandInterventionGovernanceAuthority subclass AlchemyObject public
::attribute authorityId get
::attribute authorityType get
::attribute scope get
::attribute decisionNamespace get
::method init
  expose authorityId authorityType scope decisionNamespace
  use arg idArg,typeArg,scopeArg="ALL",namespaceArg="BRAND_INTERVENTION_GOVERNANCE"
  authorityId=.BrandInterventionGovernanceCanonical~token(idArg); authorityType=.BrandInterventionGovernanceCanonical~token(typeArg); scope=.BrandInterventionGovernanceCanonical~token(scopeArg); decisionNamespace=.BrandInterventionGovernanceCanonical~token(namespaceArg)
  if authorityId="" | authorityType="" | scope="" | decisionNamespace="" then raise syntax 88.984 array("named governance authority requires id/type/scope/namespace")
  self~initAlchemy(.BrandInterventionGovernanceAlchemySupport~metadata("named external authority allowed to record intervention governance decisions"))
  self~registerStateVariable("authorityId","INTERNAL","named governance authority id")
  self~registerStateVariable("authorityType","CUSTOMER","authority type")
  self~registerStateVariable("scope","CUSTOMER","ALL or intervention-kind scope")
  self~registerStateVariable("decisionNamespace","CUSTOMER","decision namespace")
::method covers
  expose scope; use arg interventionKind
  return scope="ALL" | scope=.BrandInterventionGovernanceCanonical~token(interventionKind)

::class BrandInterventionGovernanceDecision subclass AlchemyObject public
::attribute decisionId get
::attribute recommendation get
::attribute authority get
::attribute decisionCode get
::attribute decisionRef get
::attribute decidedAt get
::attribute alignedWithRecommendation get
::attribute externalExecutionRequired get
::attribute causalStatus get
::attribute sealed get
::method init
  expose decisionId recommendation authority decisionCode decisionRef decidedAt alignedWithRecommendation externalExecutionRequired causalStatus overrideEvidencePoint sealed
  use arg idArg,recommendationArg,authorityArg,codeArg,refArg,decidedAtArg,overridePointArg=""
  decisionId=idArg~string; recommendation=recommendationArg; authority=authorityArg; decisionCode=.BrandInterventionGovernanceCanonical~token(codeArg); decisionRef=refArg~string~strip; decidedAt=decidedAtArg~string; overrideEvidencePoint=overridePointArg~string
  alignedWithRecommendation=.false; externalExecutionRequired=.true; causalStatus=.BrandInterventionGovernanceConstant~CAUSAL_ASSOCIATION_ONLY; sealed=.false
  if decisionId="" | recommendation==.nil | authority==.nil | decisionCode="" | decisionRef="" | decidedAt="" then raise syntax 88.985 array("governance decision requires id/recommendation/authority/code/ref/time")
  self~initAlchemy(.BrandInterventionGovernanceAlchemySupport~metadata("named-authority intervention governance decision; execution remains external"))
  self~registerStateVariable("decisionId","CUSTOMER","governance decision id")
  self~registerStateVariable("recommendation","INTERNAL","sealed recommendation considered")
  self~registerStateVariable("authority","INTERNAL","named authority")
  self~registerStateVariable("decisionCode","CUSTOMER","recorded governance decision")
  self~registerStateVariable("decisionRef","INTERNAL","external decision record reference")
  self~registerStateVariable("decidedAt","CUSTOMER","decision time")
  self~registerStateVariable("alignedWithRecommendation","CUSTOMER","whether decision is one expected by the recommendation disposition")
  self~registerStateVariable("externalExecutionRequired","CUSTOMER","this object does not execute intervention changes")
  self~registerStateVariable("causalStatus","CUSTOMER","governance decision does not alter causal status")
  self~registerStateVariable("overrideEvidencePoint","INTERNAL","opaque justification/evidence point when authority diverges")
  self~registerStateVariable("sealed","CUSTOMER","decision immutability")
  self~recordRelationship("DECIDES_ON",recommendation,"governance recommendation","INTERNAL")
  self~recordRelationship("DECIDED_BY",authority,"named governance authority","INTERNAL")
  self~registerInstrumentationPoint("BRAND.INTERVENTION.GOVERNANCE.DECISION.SEALED","named authority governance decision sealed",.true,"ALL","INTERNAL")
::method seal
  expose recommendation authority decisionCode decisionRef alignedWithRecommendation overrideEvidencePoint sealed
  if \recommendation~sealed then return .BrandInterventionGovernanceResult~failure("RECOMMENDATION_NOT_SEALED")
  if \.BrandInterventionGovernanceCanonical~safeDecisionRef(decisionRef) then return .BrandInterventionGovernanceResult~failure("DECISION_REF_NOT_OPAQUE")
  if \authority~covers(recommendation~interventionKind) then return .BrandInterventionGovernanceResult~failure("AUTHORITY_SCOPE_MISMATCH")
  if \self~validDecision(decisionCode) then return .BrandInterventionGovernanceResult~failure("DECISION_CODE_INVALID")
  if self~increasesExposure(decisionCode) & \recommendation~institutionalPolicyManaged then return .BrandInterventionGovernanceResult~failure("POSITIVE_DECISION_REQUIRES_OPERATIVE_POLICY_SELECTION")
  alignedWithRecommendation=self~isAligned(recommendation~disposition,decisionCode)
  if \alignedWithRecommendation then do
    if overrideEvidencePoint="" | \.BrandInterventionGovernanceCanonical~safePoint(overrideEvidencePoint) then return .BrandInterventionGovernanceResult~failure("DIVERGENT_DECISION_REQUIRES_OPAQUE_EVIDENCE_POINT")
  end
  sealed=.true; self~alchemyTouch("GOVERNANCE_DECISION_SEAL"); self~alchemyInstrument("BRAND.INTERVENTION.GOVERNANCE.DECISION.SEALED",self~pointId)
  return .BrandInterventionGovernanceResult~success(self)
::method increasesExposure private
  use arg c
  return c=.BrandInterventionGovernanceConstant~DECISION_APPROVE_PILOT | c=.BrandInterventionGovernanceConstant~DECISION_APPROVE_EXPANSION | c=.BrandInterventionGovernanceConstant~DECISION_CONTINUE
::method validDecision private
  use arg c
  return c=.BrandInterventionGovernanceConstant~DECISION_COLLECT | c=.BrandInterventionGovernanceConstant~DECISION_NO_CHANGE | c=.BrandInterventionGovernanceConstant~DECISION_APPROVE_PILOT | c=.BrandInterventionGovernanceConstant~DECISION_APPROVE_EXPANSION | c=.BrandInterventionGovernanceConstant~DECISION_CONTINUE | c=.BrandInterventionGovernanceConstant~DECISION_PAUSE | c=.BrandInterventionGovernanceConstant~DECISION_WITHDRAW
::method isAligned private
  use arg d,c
  if d=.BrandInterventionGovernanceConstant~DISPOSITION_MEASURE_MORE then return c=.BrandInterventionGovernanceConstant~DECISION_COLLECT | c=.BrandInterventionGovernanceConstant~DECISION_NO_CHANGE
  if d=.BrandInterventionGovernanceConstant~DISPOSITION_HOLD_BASELINE then return c=.BrandInterventionGovernanceConstant~DECISION_NO_CHANGE | c=.BrandInterventionGovernanceConstant~DECISION_COLLECT
  if d=.BrandInterventionGovernanceConstant~DISPOSITION_CONTROLLED_PILOT then return c=.BrandInterventionGovernanceConstant~DECISION_APPROVE_PILOT | c=.BrandInterventionGovernanceConstant~DECISION_COLLECT | c=.BrandInterventionGovernanceConstant~DECISION_NO_CHANGE
  if d=.BrandInterventionGovernanceConstant~DISPOSITION_CONTROLLED_EXPANSION then return c=.BrandInterventionGovernanceConstant~DECISION_APPROVE_EXPANSION | c=.BrandInterventionGovernanceConstant~DECISION_CONTINUE | c=.BrandInterventionGovernanceConstant~DECISION_COLLECT
  if d=.BrandInterventionGovernanceConstant~DISPOSITION_CONTINUE then return c=.BrandInterventionGovernanceConstant~DECISION_CONTINUE | c=.BrandInterventionGovernanceConstant~DECISION_COLLECT | c=.BrandInterventionGovernanceConstant~DECISION_PAUSE
  if d=.BrandInterventionGovernanceConstant~DISPOSITION_WITHDRAWAL | d=.BrandInterventionGovernanceConstant~DISPOSITION_REGRESSION then return c=.BrandInterventionGovernanceConstant~DECISION_PAUSE | c=.BrandInterventionGovernanceConstant~DECISION_WITHDRAW
  if d=.BrandInterventionGovernanceConstant~DISPOSITION_REVIEW_REQUIRED then return c=.BrandInterventionGovernanceConstant~DECISION_PAUSE | c=.BrandInterventionGovernanceConstant~DECISION_COLLECT | c=.BrandInterventionGovernanceConstant~DECISION_NO_CHANGE
  return .false
::method pointId
  expose decisionId; return "BRAND_INTERVENTION:GOVERNANCE:DECISION:"||decisionId
::method reasoningMaterial
  expose decisionId recommendation authority decisionCode decisionRef decidedAt alignedWithRecommendation externalExecutionRequired causalStatus overrideEvidencePoint sealed
  if \sealed then raise syntax 93.985 additional("BrandInterventionGovernanceDecision must be sealed")
  out=.BrandInterventionGovernanceCanonical~field("BRAND_INTERVENTION_GOVERNANCE_DECISION",decisionId)
  out||=.BrandInterventionGovernanceCanonical~field("DECISION_CODE",decisionCode)
  out||=.BrandInterventionGovernanceCanonical~field("DECISION_REF",decisionRef)
  out||=.BrandInterventionGovernanceCanonical~field("DECIDED_AT",decidedAt)
  out||=.BrandInterventionGovernanceCanonical~field("AUTHORITY_TYPE",authority~authorityType)
  out||=.BrandInterventionGovernanceCanonical~field("AUTHORITY_SCOPE",authority~scope)
  out||=.BrandInterventionGovernanceCanonical~field("ALIGNED_WITH_RECOMMENDATION",alignedWithRecommendation)
  out||=.BrandInterventionGovernanceCanonical~field("EXTERNAL_EXECUTION_REQUIRED",externalExecutionRequired)
  out||=.BrandInterventionGovernanceCanonical~field("CAUSAL_STATUS",causalStatus)
  if overrideEvidencePoint<>"" then out||=.BrandInterventionGovernanceCanonical~field("OVERRIDE_EVIDENCE_POINT",overrideEvidencePoint)
  out||=.BrandInterventionGovernanceCanonical~field("RECOMMENDATION_BEGIN",1)||recommendation~reasoningMaterial||.BrandInterventionGovernanceCanonical~field("RECOMMENDATION_END",1)
  return out

::class BrandInterventionGovernanceLibrary subclass AlchemyObject public
::method init
  expose recommendations decisions
  recommendations=.directory~new; decisions=.directory~new
  self~initAlchemy(.BrandInterventionGovernanceAlchemySupport~metadata("registry of sealed intervention governance recommendations and named-authority decisions"))
  self~registerStateVariable("recommendations","INTERNAL","sealed governance recommendations")
  self~registerStateVariable("decisions","INTERNAL","sealed governance decisions")
::method registerRecommendation
  expose recommendations; use arg r
  if r==.nil | \r~sealed then return .BrandInterventionGovernanceResult~failure("RECOMMENDATION_NOT_SEALED")
  if recommendations~hasIndex(r~recommendationId) then return .BrandInterventionGovernanceResult~failure("RECOMMENDATION_ALREADY_REGISTERED")
  recommendations[r~recommendationId]=r; self~recordRelationship("CONTAINS",r,"governance recommendation","INTERNAL"); return .BrandInterventionGovernanceResult~success(r)
::method registerDecision
  expose decisions; use arg d
  if d==.nil | \d~sealed then return .BrandInterventionGovernanceResult~failure("DECISION_NOT_SEALED")
  if decisions~hasIndex(d~decisionId) then return .BrandInterventionGovernanceResult~failure("DECISION_ALREADY_REGISTERED")
  decisions[d~decisionId]=d; self~recordRelationship("CONTAINS",d,"governance decision","INTERNAL"); return .BrandInterventionGovernanceResult~success(d)
::method recommendation
  expose recommendations; use arg idArg; return recommendations~at(idArg~string)
::method decision
  expose decisions; use arg idArg; return decisions~at(idArg~string)

::requires "BrandInterventionEffectiveness.cls"
