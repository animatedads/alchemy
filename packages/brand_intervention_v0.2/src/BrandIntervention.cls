/*
 * Brand Intervention v0.2
 *
 * Reasoning-guidance layer over privacy-minimised Brand Journey and Brand
 * Journey Population evidence.  It does not execute customer actions and it
 * does not turn statistical association into causation.  Its job is to bind
 * sufficiently rich, time-scoped evidence to the current brand-journey state
 * and produce bounded intervention objectives for another reasoning agent.
 */

::class BrandInterventionBuild public
::constant VERSION "0.2"
::constant API_VERSION "brand.intervention/0.2"
::constant PRODUCT "ooRexx Brand Intervention"

::class BrandInterventionAlchemySupport public
::method metadata class
  use arg purposeArg
  d=.directory~new
  d["purpose"]=purposeArg~string
  d["package_version"]=.BrandInterventionBuild~VERSION
  d["api_version"]=.BrandInterventionBuild~API_VERSION
  d["component"]="BRAND_INTERVENTION"
  return d

::class BrandInterventionConstant public
/* Decision modes.  These are guidance states, never action execution. */
::constant MODE_BASELINE_ONLY "BASELINE_ONLY"
::constant MODE_OBSERVE_ONLY "OBSERVE_ONLY"
::constant MODE_REVIEW_REQUIRED "REVIEW_REQUIRED"
::constant MODE_REASONING_GUIDANCE "REASONING_GUIDANCE"

/* Proposal kinds. */
::constant KIND_PRESERVE_BASELINE "PRESERVE_BASELINE_SERVICE"
::constant KIND_OBSERVE "OBSERVE_AND_COLLECT"
::constant KIND_INVESTIGATE "INVESTIGATE_MATERIAL_SIGNAL"
::constant KIND_EVIDENCE_QUALITY "COHORT_EVIDENCE_QUALITY_REVIEW"
::constant KIND_REFRESH_EVIDENCE "REFRESH_STALE_EVIDENCE"
::constant KIND_RECOVERY "SERVICE_RECOVERY_GUIDANCE"
::constant KIND_TONE "TONE_APPROPRIATENESS_GUIDANCE"
::constant KIND_JOURNEY "JOURNEY_CONTINUITY_GUIDANCE"
::constant KIND_GENERAL "BOUNDED_BRAND_GUIDANCE"

::constant CAUSAL_ASSOCIATION_ONLY "ASSOCIATION_ONLY"
::constant AUTHORITY_REQUIRED "EXTERNAL_ACTION_AUTHORITY_REQUIRED"

::class BrandInterventionResult public
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

::class BrandInterventionCanonical public
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
::method clamp class
  use arg value
  n=value+0
  if n<0 then return 0
  if n>100 then return 100
  return n
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
  if p~caselessPos("BRAND_INTERVENTION:")=1 then return .true
  return .false

/* Privacy-minimised current decision context.  Customer identity, raw text and
   free-form prose are intentionally absent.  Sentiment is an assessed token,
   never a fact claim about the customer. */
::class BrandInterventionContext subclass AlchemyObject public
::attribute contextId get
::attribute journeyPoint get
::attribute occurredAt get
::attribute domain get
::attribute journeyState get
::attribute unresolved get
::attribute assessedSentiment get
::attribute issueSeverity get
::attribute explicitSalesInProgress get
::attribute sealed get
::method init
  expose contextId journeyPoint occurredAt domain journeyState unresolved assessedSentiment issueSeverity explicitSalesInProgress findings brandFunctions brandOpportunities obligations prohibitions evidencePoints sealed
  use arg idArg, journeyPointArg, occurredAtArg, domainArg, stateArg="UNKNOWN", unresolvedArg=.false, sentimentArg="UNASSESSED", severityArg=0, explicitSalesArg=.false, alchemySealerArg=.nil, alchemyAuthorityArg=.nil
  contextId=idArg~string; journeyPoint=journeyPointArg~string; occurredAt=occurredAtArg~string
  domain=.BrandInterventionCanonical~token(domainArg); journeyState=.BrandInterventionCanonical~token(stateArg)
  unresolved=unresolvedArg; assessedSentiment=.BrandInterventionCanonical~token(sentimentArg)
  issueSeverity=.BrandInterventionCanonical~clamp(severityArg); explicitSalesInProgress=explicitSalesArg
  findings=.array~new; brandFunctions=.array~new; brandOpportunities=.array~new; obligations=.array~new; prohibitions=.array~new; evidencePoints=.array~new; sealed=.false
  if contextId="" | journeyPoint="" | occurredAt="" | domain="" then raise syntax 88.995 array("BrandInterventionContext requires id, safe journey point, time and domain")
  if \.BrandInterventionCanonical~safePoint(journeyPoint) then raise syntax 88.995 array("journeyPoint must be an opaque stable evidence point")
  self~initAlchemy(.BrandInterventionAlchemySupport~metadata("privacy-minimised current brand state for evidence-grounded intervention reasoning"),alchemySealerArg,alchemyAuthorityArg)
  self~registerStateVariable("contextId","CUSTOMER","decision-local context id")
  self~registerStateVariable("journeyPoint","INTERNAL","privacy-minimised upstream journey evidence point")
  self~registerStateVariable("occurredAt","CUSTOMER","current interaction/journey timestamp")
  self~registerStateVariable("domain","CUSTOMER","current operational domain")
  self~registerStateVariable("journeyState","CUSTOMER","current controlled journey state")
  self~registerStateVariable("unresolved","CUSTOMER","whether current need remains unresolved")
  self~registerStateVariable("assessedSentiment","CUSTOMER","assessed sentiment token; assessment not fact")
  self~registerStateVariable("issueSeverity","CUSTOMER","bounded current issue severity")
  self~registerStateVariable("explicitSalesInProgress","CUSTOMER","observed explicit sales state; never inferred from brand opportunity")
  self~registerStateVariable("findings","CUSTOMER","privacy-safe current journey findings")
  self~registerStateVariable("brandFunctions","CUSTOMER","brand significance; not sales authority")
  self~registerStateVariable("brandOpportunities","CUSTOMER","brand opportunity; not action authority")
  self~registerStateVariable("obligations","CUSTOMER","controlled obligations that intervention must preserve")
  self~registerStateVariable("prohibitions","CUSTOMER","controlled actions/strategies intervention must avoid")
  self~registerStateVariable("evidencePoints","INTERNAL","privacy-safe support points")
  self~registerStateVariable("sealed","CUSTOMER","context immutability")
  self~registerInstrumentationPoint("BRAND.INTERVENTION.CONTEXT.SEALED","intervention context sealed",.true,"ALL","INTERNAL")
::method addFinding
  expose findings sealed; use arg v; if sealed then return .false
  t=.BrandInterventionCanonical~token(v); if t="" then return .false
  if \.BrandInterventionCanonical~contains(findings,t) then findings~append(t); return .true
::method addBrandFunction
  expose brandFunctions sealed; use arg v; if sealed then return .false
  t=.BrandInterventionCanonical~token(v); if t="" then return .false
  if \.BrandInterventionCanonical~contains(brandFunctions,t) then brandFunctions~append(t); return .true
::method addBrandOpportunity
  expose brandOpportunities sealed; use arg v; if sealed then return .false
  t=.BrandInterventionCanonical~token(v); if t="" then return .false
  if \.BrandInterventionCanonical~contains(brandOpportunities,t) then brandOpportunities~append(t); return .true
::method addObligation
  expose obligations sealed; use arg v; if sealed then return .false
  t=.BrandInterventionCanonical~token(v); if t="" then return .false
  if \.BrandInterventionCanonical~contains(obligations,t) then obligations~append(t); return .true
::method addProhibition
  expose prohibitions sealed; use arg v; if sealed then return .false
  t=.BrandInterventionCanonical~token(v); if t="" then return .false
  if \.BrandInterventionCanonical~contains(prohibitions,t) then prohibitions~append(t); return .true
::method addEvidencePoint
  expose evidencePoints sealed; use arg v
  if sealed | \.BrandInterventionCanonical~safePoint(v) then return .false
  if \.BrandInterventionCanonical~contains(evidencePoints,v~string) then evidencePoints~append(v~string); return .true
::method findings
  expose findings; return .BrandInterventionCanonical~copyArray(findings)
::method brandFunctions
  expose brandFunctions; return .BrandInterventionCanonical~copyArray(brandFunctions)
::method brandOpportunities
  expose brandOpportunities; return .BrandInterventionCanonical~copyArray(brandOpportunities)
::method obligations
  expose obligations; return .BrandInterventionCanonical~copyArray(obligations)
::method prohibitions
  expose prohibitions; return .BrandInterventionCanonical~copyArray(prohibitions)
::method evidencePoints
  expose evidencePoints; return .BrandInterventionCanonical~copyArray(evidencePoints)
::method hasFinding
  expose findings; use arg v; return .BrandInterventionCanonical~contains(findings,.BrandInterventionCanonical~token(v))
::method hasBrandFunction
  expose brandFunctions; use arg v; return .BrandInterventionCanonical~contains(brandFunctions,.BrandInterventionCanonical~token(v))
::method hasBrandOpportunity
  expose brandOpportunities; use arg v; return .BrandInterventionCanonical~contains(brandOpportunities,.BrandInterventionCanonical~token(v))
::method seal
  expose sealed
  sealed=.true; self~alchemyTouch("INTERVENTION_CONTEXT_SEAL"); self~alchemyInstrument("BRAND.INTERVENTION.CONTEXT.SEALED",self~pointId)
  return .BrandInterventionResult~success(self)
::method pointId
  expose contextId; return "BRAND_INTERVENTION:CONTEXT:"||contextId
::method canonicalText
  expose contextId journeyPoint occurredAt domain journeyState unresolved assessedSentiment issueSeverity explicitSalesInProgress findings brandFunctions brandOpportunities obligations prohibitions evidencePoints sealed
  if \sealed then raise syntax 93.995 additional("BrandInterventionContext must be sealed")
  out=.BrandInterventionCanonical~field("INTERVENTION_CONTEXT",contextId)
  out||=.BrandInterventionCanonical~field("JOURNEY_POINT",journeyPoint)
  out||=.BrandInterventionCanonical~field("OCCURRED_AT",occurredAt)
  out||=.BrandInterventionCanonical~field("DOMAIN",domain)
  out||=.BrandInterventionCanonical~field("JOURNEY_STATE",journeyState)
  out||=.BrandInterventionCanonical~field("UNRESOLVED",unresolved)
  out||=.BrandInterventionCanonical~field("ASSESSED_SENTIMENT",assessedSentiment)
  out||=.BrandInterventionCanonical~field("ISSUE_SEVERITY",issueSeverity)
  out||=.BrandInterventionCanonical~field("EXPLICIT_SALES_IN_PROGRESS",explicitSalesInProgress)
  out||=.BrandInterventionCanonical~join("CURRENT_FINDING",findings)
  out||=.BrandInterventionCanonical~join("BRAND_FUNCTION",brandFunctions)
  out||=.BrandInterventionCanonical~join("BRAND_OPPORTUNITY",brandOpportunities)
  out||=.BrandInterventionCanonical~join("OBLIGATION",obligations)
  out||=.BrandInterventionCanonical~join("CURRENT_PROHIBITION",prohibitions)
  out||=.BrandInterventionCanonical~join("CONTEXT_EVIDENCE_POINT",evidencePoints)
  return out

/* Policy controls whether evidence is fresh/sufficient enough to justify even
   reasoning guidance.  The package never executes the proposed action. */
::class BrandInterventionPolicy subclass AlchemyObject public
::attribute policyId get
::attribute maxEvidenceAgeDays get
::attribute allowWeakObservation get
::attribute materialReviewOnly get
::attribute sealed get
::method init
  expose policyId maxEvidenceAgeDays allowWeakObservation materialReviewOnly globalObligations globalProhibitions sealed
  use arg idArg="DEFAULT", maxAgeDaysArg=30, weakObservationArg=.true, alchemySealerArg=.nil, alchemyAuthorityArg=.nil
  policyId=.BrandInterventionCanonical~token(idArg); maxEvidenceAgeDays=maxAgeDaysArg+0; allowWeakObservation=weakObservationArg; materialReviewOnly=.true
  globalObligations=.array~new; globalProhibitions=.array~new; sealed=.false
  if policyId="" | maxEvidenceAgeDays<0 then raise syntax 88.996 array("BrandInterventionPolicy requires id and non-negative evidence age")
  self~initAlchemy(.BrandInterventionAlchemySupport~metadata("policy boundary for evidence-grounded brand intervention guidance"),alchemySealerArg,alchemyAuthorityArg)
  self~registerStateVariable("policyId","CUSTOMER","intervention policy id")
  self~registerStateVariable("maxEvidenceAgeDays","CUSTOMER","maximum accepted age of current evidence window")
  self~registerStateVariable("allowWeakObservation","CUSTOMER","weak signals may guide observation only")
  self~registerStateVariable("materialReviewOnly","CUSTOMER","small but material evidence routes to review, not behaviour change")
  self~registerStateVariable("globalObligations","CUSTOMER","obligations all proposals must preserve")
  self~registerStateVariable("globalProhibitions","CUSTOMER","strategies all proposals must avoid")
  self~registerStateVariable("sealed","CUSTOMER","policy immutability")
::method addObligation
  expose globalObligations sealed; use arg v; if sealed then return .false
  t=.BrandInterventionCanonical~token(v); if t="" then return .false
  if \.BrandInterventionCanonical~contains(globalObligations,t) then globalObligations~append(t); return .true
::method addProhibition
  expose globalProhibitions sealed; use arg v; if sealed then return .false
  t=.BrandInterventionCanonical~token(v); if t="" then return .false
  if \.BrandInterventionCanonical~contains(globalProhibitions,t) then globalProhibitions~append(t); return .true
::method obligations
  expose globalObligations; return .BrandInterventionCanonical~copyArray(globalObligations)
::method prohibitions
  expose globalProhibitions; return .BrandInterventionCanonical~copyArray(globalProhibitions)
::method seal
  expose sealed; sealed=.true; return .BrandInterventionResult~success(self)
::method canonicalText
  expose policyId maxEvidenceAgeDays allowWeakObservation materialReviewOnly globalObligations globalProhibitions sealed
  if \sealed then raise syntax 93.996 additional("BrandInterventionPolicy must be sealed")
  out=.BrandInterventionCanonical~field("INTERVENTION_POLICY",policyId)
  out||=.BrandInterventionCanonical~field("MAX_EVIDENCE_AGE_DAYS",maxEvidenceAgeDays)
  out||=.BrandInterventionCanonical~field("ALLOW_WEAK_OBSERVATION",allowWeakObservation)
  out||=.BrandInterventionCanonical~field("MATERIAL_REVIEW_ONLY",materialReviewOnly)
  out||=.BrandInterventionCanonical~join("POLICY_OBLIGATION",globalObligations)
  out||=.BrandInterventionCanonical~join("POLICY_PROHIBITION",globalProhibitions)
  return out

/* Binds a time-scoped evidence report to the decision time.  Age is supplied
   by the temporal/access layer and retained explicitly; it is not guessed. */
::class BrandInterventionEvidenceBinding subclass AlchemyObject public
::attribute bindingId get
::attribute report get
::attribute asOfAt get
::attribute evidenceAgeDays get
::attribute temporalAuthorityId get
::attribute sealed get
::method init
  expose bindingId report asOfAt evidenceAgeDays temporalAuthorityId sealed
  use arg idArg, reportArg, asOfAtArg, ageDaysArg, temporalAuthorityArg="UNSPECIFIED", alchemySealerArg=.nil, alchemyAuthorityArg=.nil
  bindingId=idArg~string; report=reportArg; asOfAt=asOfAtArg~string; evidenceAgeDays=ageDaysArg+0; temporalAuthorityId=.BrandInterventionCanonical~token(temporalAuthorityArg); sealed=.false
  if bindingId="" | report==.nil | asOfAt="" | evidenceAgeDays<0 then raise syntax 88.997 array("BrandInterventionEvidenceBinding requires report, as-of time and non-negative age")
  if \report~hasMethod("REASONINGMATERIAL") then raise syntax 88.997 array("evidence report must expose reasoningMaterial")
  self~initAlchemy(.BrandInterventionAlchemySupport~metadata("explicit time binding around reasoning-ready population evidence"),alchemySealerArg,alchemyAuthorityArg)
  self~registerStateVariable("bindingId","CUSTOMER","evidence binding id")
  self~registerStateVariable("report","INTERNAL","full population/temporal evidence report")
  self~registerStateVariable("asOfAt","CUSTOMER","decision as-of time")
  self~registerStateVariable("evidenceAgeDays","CUSTOMER","age of current evidence window supplied by temporal authority")
  self~registerStateVariable("temporalAuthorityId","CUSTOMER","provenance for evidence-age computation")
  self~registerStateVariable("sealed","CUSTOMER","binding immutability")
  self~recordRelationship("USES",report,"reasoning-ready population evidence","INTERNAL")
::method assessment
  expose report
  if report~hasMethod("CURRENTREPORT") then return report~currentReport~analysis~assessment
  return report~analysis~assessment
::method frame
  expose report
  if report~hasMethod("CURRENTREPORT") then return report~currentReport~analysis~frame
  return report~analysis~frame
::method packet
  expose report
  if report~hasMethod("CURRENTREPORT") then return report~currentReport~packet
  return report~packet
::method seal
  expose sealed; sealed=.true; return .BrandInterventionResult~success(self)
::method pointId
  expose bindingId; return "BRAND_INTERVENTION:EVIDENCE_BINDING:"||bindingId
::method reasoningMaterial
  expose bindingId report asOfAt evidenceAgeDays temporalAuthorityId sealed
  if \sealed then raise syntax 93.997 additional("BrandInterventionEvidenceBinding must be sealed")
  out=.BrandInterventionCanonical~field("INTERVENTION_EVIDENCE_BINDING",bindingId)
  out||=.BrandInterventionCanonical~field("AS_OF_AT",asOfAt)
  out||=.BrandInterventionCanonical~field("EVIDENCE_AGE_DAYS",evidenceAgeDays)
  out||=.BrandInterventionCanonical~field("TEMPORAL_AUTHORITY_ID",temporalAuthorityId)
  out||=.BrandInterventionCanonical~field("UPSTREAM_REASONING_MATERIAL_BEGIN",1)
  out||=report~reasoningMaterial
  out||=.BrandInterventionCanonical~field("UPSTREAM_REASONING_MATERIAL_END",1)
  return out

/* Proposal is an objective/constraint set, not customer-facing prose and not
   an executable action.  This preserves room for a reasoning LLM to choose an
   appropriate linguistic realisation within the stated boundaries. */
::class BrandInterventionProposal subclass AlchemyObject public
::attribute proposalId get
::attribute proposalKind get
::attribute sourceFeature get
::attribute priority get
::attribute actionAuthorityRequired get
::attribute causalStatus get
::attribute sealed get
::method init
  expose proposalId proposalKind sourceFeature priority actionAuthorityRequired causalStatus objectives avoidances obligations evidencePoints sealed
  use arg idArg, kindArg, featureArg="NONE", priorityArg=50, alchemySealerArg=.nil, alchemyAuthorityArg=.nil
  proposalId=idArg~string; proposalKind=.BrandInterventionCanonical~token(kindArg); sourceFeature=.BrandInterventionCanonical~token(featureArg); priority=.BrandInterventionCanonical~clamp(priorityArg)
  actionAuthorityRequired=.true; causalStatus=.BrandInterventionConstant~CAUSAL_ASSOCIATION_ONLY
  objectives=.array~new; avoidances=.array~new; obligations=.array~new; evidencePoints=.array~new; sealed=.false
  if proposalId="" | proposalKind="" then raise syntax 88.998 array("BrandInterventionProposal requires id and kind")
  self~initAlchemy(.BrandInterventionAlchemySupport~metadata("bounded intervention objectives; no customer-facing prose and no action authority"),alchemySealerArg,alchemyAuthorityArg)
  self~registerStateVariable("proposalId","CUSTOMER","proposal id")
  self~registerStateVariable("proposalKind","CUSTOMER","controlled proposal kind")
  self~registerStateVariable("sourceFeature","CUSTOMER","evidence feature motivating proposal")
  self~registerStateVariable("priority","CUSTOMER","bounded review/reasoning priority")
  self~registerStateVariable("actionAuthorityRequired","CUSTOMER","external component must decide/action")
  self~registerStateVariable("causalStatus","CUSTOMER","association-only evidence status")
  self~registerStateVariable("objectives","CUSTOMER","desired behavioural/brand objectives")
  self~registerStateVariable("avoidances","CUSTOMER","strategies specifically to avoid")
  self~registerStateVariable("obligations","CUSTOMER","obligations which must survive adaptation")
  self~registerStateVariable("evidencePoints","INTERNAL","privacy-safe evidence references")
  self~registerStateVariable("sealed","CUSTOMER","proposal immutability")
  self~registerInstrumentationPoint("BRAND.INTERVENTION.PROPOSAL.SEALED","bounded non-executable intervention proposal sealed",.true,"ALL","INTERNAL")
::method addObjective
  expose objectives sealed; use arg v; if sealed then return .false
  t=.BrandInterventionCanonical~token(v); if t="" then return .false
  if \.BrandInterventionCanonical~contains(objectives,t) then objectives~append(t); return .true
::method addAvoidance
  expose avoidances sealed; use arg v; if sealed then return .false
  t=.BrandInterventionCanonical~token(v); if t="" then return .false
  if \.BrandInterventionCanonical~contains(avoidances,t) then avoidances~append(t); return .true
::method addObligation
  expose obligations sealed; use arg v; if sealed then return .false
  t=.BrandInterventionCanonical~token(v); if t="" then return .false
  if \.BrandInterventionCanonical~contains(obligations,t) then obligations~append(t); return .true
::method addEvidencePoint
  expose evidencePoints sealed; use arg v
  if sealed | \.BrandInterventionCanonical~safePoint(v) then return .false
  if \.BrandInterventionCanonical~contains(evidencePoints,v~string) then evidencePoints~append(v~string); return .true
::method objectives
  expose objectives; return .BrandInterventionCanonical~copyArray(objectives)
::method avoidances
  expose avoidances; return .BrandInterventionCanonical~copyArray(avoidances)
::method obligations
  expose obligations; return .BrandInterventionCanonical~copyArray(obligations)
::method evidencePoints
  expose evidencePoints; return .BrandInterventionCanonical~copyArray(evidencePoints)
::method hasObjective
  expose objectives; use arg v; return .BrandInterventionCanonical~contains(objectives,.BrandInterventionCanonical~token(v))
::method hasAvoidance
  expose avoidances; use arg v; return .BrandInterventionCanonical~contains(avoidances,.BrandInterventionCanonical~token(v))
::method seal
  expose objectives obligations sealed
  if objectives~items=0 then return .BrandInterventionResult~failure("PROPOSAL_OBJECTIVE_REQUIRED")
  if obligations~items=0 then return .BrandInterventionResult~failure("PROPOSAL_OBLIGATION_REQUIRED")
  sealed=.true; self~alchemyTouch("INTERVENTION_PROPOSAL_SEAL"); self~alchemyInstrument("BRAND.INTERVENTION.PROPOSAL.SEALED",self~pointId)
  return .BrandInterventionResult~success(self)
::method pointId
  expose proposalId; return "BRAND_INTERVENTION:PROPOSAL:"||proposalId
::method canonicalText
  expose proposalId proposalKind sourceFeature priority actionAuthorityRequired causalStatus objectives avoidances obligations evidencePoints sealed
  if \sealed then raise syntax 93.998 additional("BrandInterventionProposal must be sealed")
  out=.BrandInterventionCanonical~field("INTERVENTION_PROPOSAL",proposalId)
  out||=.BrandInterventionCanonical~field("PROPOSAL_KIND",proposalKind)
  out||=.BrandInterventionCanonical~field("SOURCE_FEATURE",sourceFeature)
  out||=.BrandInterventionCanonical~field("PRIORITY",priority)
  out||=.BrandInterventionCanonical~field("ACTION_AUTHORITY_REQUIRED",actionAuthorityRequired)
  out||=.BrandInterventionCanonical~field("CAUSAL_STATUS",causalStatus)
  out||=.BrandInterventionCanonical~join("OBJECTIVE",objectives)
  out||=.BrandInterventionCanonical~join("AVOID",avoidances)
  out||=.BrandInterventionCanonical~join("MUST_PRESERVE",obligations)
  out||=.BrandInterventionCanonical~join("PROPOSAL_EVIDENCE_POINT",evidencePoints)
  return out

/* Immutable reasoning packet combining current context, policy and all of the
   upstream evidence.  It is intentionally verbose enough to permit another
   LLM to reason, challenge, qualify and scope the recommendation. */
::class BrandInterventionDecision subclass AlchemyObject public
::attribute decisionId get
::attribute mode get
::attribute evidenceStatus get
::attribute causalStatus get
::attribute actionAuthorityRequired get
::attribute context get
::attribute binding get
::attribute policy get
::attribute proposal get
::method init
  expose decisionId mode evidenceStatus causalStatus actionAuthorityRequired context binding policy proposal rationales
  use arg idArg, modeArg, evidenceStatusArg, contextArg, bindingArg, policyArg, proposalArg, alchemySealerArg=.nil, alchemyAuthorityArg=.nil
  decisionId=idArg~string; mode=.BrandInterventionCanonical~token(modeArg); evidenceStatus=.BrandInterventionCanonical~token(evidenceStatusArg)
  causalStatus=.BrandInterventionConstant~CAUSAL_ASSOCIATION_ONLY; actionAuthorityRequired=.true
  context=contextArg; binding=bindingArg; policy=policyArg; proposal=proposalArg; rationales=.array~new
  if decisionId="" | mode="" | context==.nil | binding==.nil | policy==.nil | proposal==.nil then raise syntax 88.999 array("BrandInterventionDecision requires id, mode, context, evidence, policy and proposal")
  self~initAlchemy(.BrandInterventionAlchemySupport~metadata("reasoning-ready intervention decision with full evidence weight, current state and anti-overclaim bounds"),alchemySealerArg,alchemyAuthorityArg)
  self~registerStateVariable("decisionId","CUSTOMER","decision id")
  self~registerStateVariable("mode","CUSTOMER","guidance/review mode")
  self~registerStateVariable("evidenceStatus","CUSTOMER","upstream statistical/material evidence status")
  self~registerStateVariable("causalStatus","CUSTOMER","association-only causal status")
  self~registerStateVariable("actionAuthorityRequired","CUSTOMER","decision never executes customer action")
  self~registerStateVariable("context","INTERNAL","privacy-minimised current journey state")
  self~registerStateVariable("binding","INTERNAL","full time-scoped evidence binding")
  self~registerStateVariable("policy","INTERNAL","intervention policy")
  self~registerStateVariable("proposal","INTERNAL","bounded objective/constraint proposal")
  self~registerStateVariable("rationales","CUSTOMER","controlled rationale codes")
  self~recordRelationship("USES",context,"current privacy-minimised brand context","INTERNAL")
  self~recordRelationship("USES",binding,"full statistical/temporal evidence binding","INTERNAL")
  self~recordRelationship("GOVERNED_BY",policy,"intervention policy","INTERNAL")
  self~recordRelationship("PROPOSES",proposal,"bounded non-executable intervention objectives","INTERNAL")
::method addRationale
  expose rationales; use arg v
  t=.BrandInterventionCanonical~token(v); if t<>"" & \.BrandInterventionCanonical~contains(rationales,t) then rationales~append(t)
  return self
::method rationales
  expose rationales; return .BrandInterventionCanonical~copyArray(rationales)
::method pointId
  expose decisionId; return "BRAND_INTERVENTION:DECISION:"||decisionId
::method reasoningMaterial
  expose decisionId mode evidenceStatus causalStatus actionAuthorityRequired context binding policy proposal rationales
  out=.BrandInterventionCanonical~field("BRAND_INTERVENTION_DECISION",decisionId)
  out||=.BrandInterventionCanonical~field("DECISION_MODE",mode)
  out||=.BrandInterventionCanonical~field("EVIDENCE_STATUS",evidenceStatus)
  out||=.BrandInterventionCanonical~field("CAUSAL_STATUS",causalStatus)
  out||=.BrandInterventionCanonical~field("ACTION_AUTHORITY_REQUIRED",actionAuthorityRequired)
  out||=.BrandInterventionCanonical~join("DECISION_RATIONALE",rationales)
  out||=.BrandInterventionCanonical~field("CURRENT_CONTEXT_BEGIN",1)
  out||=context~canonicalText
  out||=.BrandInterventionCanonical~field("CURRENT_CONTEXT_END",1)
  out||=.BrandInterventionCanonical~field("POLICY_BEGIN",1)
  out||=policy~canonicalText
  out||=.BrandInterventionCanonical~field("POLICY_END",1)
  out||=.BrandInterventionCanonical~field("EVIDENCE_BEGIN",1)
  out||=binding~reasoningMaterial
  out||=.BrandInterventionCanonical~field("EVIDENCE_END",1)
  out||=.BrandInterventionCanonical~field("PROPOSAL_BEGIN",1)
  out||=proposal~canonicalText
  out||=.BrandInterventionCanonical~field("PROPOSAL_END",1)
  out||=.BrandInterventionCanonical~field("INTERPRETATION_BOUND","GUIDANCE_NOT_EXECUTION")
  out||=.BrandInterventionCanonical~field("INTERPRETATION_BOUND","ASSOCIATION_NOT_CAUSATION")
  return out

::class BrandInterventionEngine public
::method decide
  use arg context, binding, policy=.nil
  if context==.nil | \context~sealed then return .BrandInterventionResult~failure("CONTEXT_NOT_SEALED")
  if binding==.nil | \binding~sealed then return .BrandInterventionResult~failure("EVIDENCE_BINDING_NOT_SEALED")
  if policy==.nil then do
    policy=.BrandInterventionPolicy~new
    policy~addObligation("PRESERVE_TRUTHFULNESS")
    policy~addObligation("PRESERVE_SAFETY_AND_LEGAL_BOUNDARIES")
    policy~addObligation("PRESERVE_CUSTOMER_DATA_BOUNDARIES")
    policy~addProhibition("INFER_SALES_AUTHORITY_FROM_BRAND_CONTEXT")
    policy~seal
  end
  if \policy~sealed then return .BrandInterventionResult~failure("POLICY_NOT_SEALED")
  a=binding~assessment; f=binding~frame; status=a~status; feature=f~featureClass

  if binding~evidenceAgeDays>policy~maxEvidenceAgeDays then do
    mode=.BrandInterventionConstant~MODE_REVIEW_REQUIRED; kind=.BrandInterventionConstant~KIND_REFRESH_EVIDENCE
  end
  else if status=.BrandEvidenceConstant~STATUS_MATERIAL_INVESTIGATION then do
    mode=.BrandInterventionConstant~MODE_REVIEW_REQUIRED; kind=.BrandInterventionConstant~KIND_INVESTIGATE
  end
  else if status=.BrandEvidenceConstant~STATUS_INSUFFICIENT then do
    mode=.BrandInterventionConstant~MODE_BASELINE_ONLY; kind=.BrandInterventionConstant~KIND_PRESERVE_BASELINE
  end
  else if status=.BrandEvidenceConstant~STATUS_WEAK then do
    /* Brand Interaction Effect v0.6 separates statistical/effect/confidence
       sufficiency from cohort-selection quality.  A cohort-quality failure is
       an evidence-construction problem, not a behavioural signal to observe. */
    if \a~cohortQualityGate then do
      mode=.BrandInterventionConstant~MODE_REVIEW_REQUIRED
      kind=.BrandInterventionConstant~KIND_EVIDENCE_QUALITY
    end
    else if policy~allowWeakObservation then do; mode=.BrandInterventionConstant~MODE_OBSERVE_ONLY; kind=.BrandInterventionConstant~KIND_OBSERVE; end
    else do; mode=.BrandInterventionConstant~MODE_BASELINE_ONLY; kind=.BrandInterventionConstant~KIND_PRESERVE_BASELINE; end
  end
  else do
    mode=.BrandInterventionConstant~MODE_REASONING_GUIDANCE
    if feature~pos("SASS")>0 | feature~pos("DISMISS")>0 | feature~pos("APOLOGY")>0 then kind=.BrandInterventionConstant~KIND_TONE
    else if feature~pos("CONTEXT_LOSS")>0 | feature~pos("REPEAT_BURDEN")>0 then kind=.BrandInterventionConstant~KIND_JOURNEY
    else if context~unresolved then kind=.BrandInterventionConstant~KIND_RECOVERY
    else kind=.BrandInterventionConstant~KIND_GENERAL
  end

  p=.BrandInterventionProposal~new("PROPOSAL-"||context~contextId,kind,feature,50)
  ignore=self~applyBaseline(p,context,policy)

  if binding~evidenceAgeDays>policy~maxEvidenceAgeDays then do
    p~addObjective("REFRESH_SCOPED_CURRENT_EVIDENCE")
    p~addAvoidance("ALTER_BEHAVIOUR_FROM_STALE_EVIDENCE")
  end
  else if status=.BrandEvidenceConstant~STATUS_MATERIAL_INVESTIGATION then do
    p~addObjective("AUTHORISED_REVIEW_OF_MATERIAL_SIGNAL")
    p~addObjective("COLLECT_MORE_COMPARABLE_TIME_SCOPED_EVIDENCE")
    p~addAvoidance("GENERALISE_SMALL_SAMPLE")
    p~addAvoidance("AUTOMATIC_BEHAVIOUR_CHANGE_FROM_MATERIALITY_ONLY")
  end
  else if status=.BrandEvidenceConstant~STATUS_INSUFFICIENT then do
    p~addObjective("PRESERVE_BASELINE_SERVICE_BEHAVIOUR")
    p~addAvoidance("EVIDENCE_DRIVEN_STYLE_CHANGE_WITHOUT_SUFFICIENT_SUPPORT")
  end
  else if status=.BrandEvidenceConstant~STATUS_WEAK then do
    if \a~cohortQualityGate then do
      p~addObjective("REPAIR_COHORT_EVIDENCE_BEFORE_BEHAVIOURAL_INFERENCE")
      if .BrandInterventionCanonical~contains(a~reasons,"COHORT_PROVENANCE_REQUIRED") | .BrandInterventionCanonical~contains(a~reasons,"COHORT_SELECTION_RULE_REQUIRED") then p~addObjective("ESTABLISH_EXPLICIT_COHORT_SELECTION_PROVENANCE")
      if .BrandInterventionCanonical~contains(a~reasons,"COHORT_SELECTED_ANALYSIS_COVERAGE_BELOW_THRESHOLD") | .BrandInterventionCanonical~contains(a~reasons,"COHORT_INCOMPLETE_SELECTED_ABOVE_THRESHOLD") then p~addObjective("RESOLVE_SELECTED_UNIT_MISSINGNESS")
      if .BrandInterventionCanonical~contains(a~reasons,"COHORT_SELECTION_UNKNOWN_ABOVE_THRESHOLD") then p~addObjective("RESOLVE_COHORT_ELIGIBILITY_UNCERTAINTY")
      p~addObjective("REANALYZE_AFTER_COHORT_QUALITY_REVIEW")
      p~addAvoidance("ALTER_BEHAVIOUR_FROM_COHORT_QUALITY_FAILED_EVIDENCE")
      p~addAvoidance("TREAT_ANALYZABLE_SUBSET_AS_SOURCE_POPULATION")
      p~addAvoidance("INFER_REPRESENTATIVENESS_FROM_SAMPLE_SIZE")
    end
    else do
      if policy~allowWeakObservation then p~addObjective("OBSERVE_SIGNAL_AND_COLLECT_COMPARABLE_EVIDENCE")
      else p~addObjective("PRESERVE_BASELINE_SERVICE_BEHAVIOUR")
      p~addAvoidance("TREAT_WEAK_SIGNAL_AS_BEHAVIOURAL_RULE")
    end
  end
  else do
    ignore=self~applySupportedFeature(p,context,feature)
  end
  p~addEvidencePoint(context~journeyPoint); p~addEvidencePoint(binding~pointId)
  sr=p~seal; if \sr~ok then return sr
  d=.BrandInterventionDecision~new("DECISION-"||context~contextId,mode,status,context,binding,policy,p)
  if binding~evidenceAgeDays>policy~maxEvidenceAgeDays then d~addRationale("EVIDENCE_STALE")
  else do
    d~addRationale("EVIDENCE_"||status)
    if status=.BrandEvidenceConstant~STATUS_WEAK & \a~cohortQualityGate then d~addRationale("COHORT_QUALITY_GATE_FAILED")
  end
  if context~unresolved then d~addRationale("CURRENT_NEED_UNRESOLVED")
  if context~assessedSentiment<>"UNASSESSED" then d~addRationale("CUSTOMER_STATE_IS_ASSESSED_NOT_FACT")
  if context~brandFunctions~items>0 | context~brandOpportunities~items>0 then d~addRationale("BRAND_EXPERIENCE_CONTEXT_PRESENT")
  return .BrandInterventionResult~success(d)

::method applyBaseline private
  use arg proposal,context,policy
  proposal~addObligation("PRESERVE_TRUTHFULNESS")
  proposal~addObligation("PRESERVE_SAFETY_AND_LEGAL_BOUNDARIES")
  proposal~addObligation("PRESERVE_CUSTOMER_DATA_BOUNDARIES")
  do x over policy~obligations; proposal~addObligation(x); end
  do x over context~obligations; proposal~addObligation(x); end
  do x over policy~prohibitions; proposal~addAvoidance(x); end
  do x over context~prohibitions; proposal~addAvoidance(x); end
  if context~brandFunctions~items>0 | context~brandOpportunities~items>0 then do
    proposal~addObligation("TREAT_SERVICE_AS_PART_OF_BRAND_EXPERIENCE")
    proposal~addAvoidance("INFER_SALES_AUTHORITY_FROM_BRAND_CONTEXT")
  end
  return .true

::method applySupportedFeature private
  use arg proposal,context,feature
  proposal~addAvoidance("TREAT_ASSOCIATION_AS_CAUSATION")
  proposal~addAvoidance("GENERALISE_BEYOND_EVIDENCE_SCOPE")
  if context~unresolved then do
    proposal~addObjective("PRESERVE_RESOLUTION_FOCUS")
    proposal~addObjective("RESOLVE_CURRENT_NEED_BEFORE_COMMERCIAL_TRANSITION")
    proposal~addAvoidance("INTRODUCE_SALES_BEFORE_RESOLUTION")
  end
  if feature~pos("CONTEXT_LOSS")>0 | context~hasFinding("CROSS_DOMAIN_CONTEXT_LOSS") then do
    proposal~addObjective("RESTORE_RELEVANT_CONTEXT")
    proposal~addObjective("REDUCE_CUSTOMER_REPEAT_BURDEN")
  end
  if feature~pos("REPEAT_BURDEN")>0 | context~hasFinding("CUSTOMER_REPEAT_BURDEN") then proposal~addObjective("AVOID_REASKING_KNOWN_INFORMATION")
  if feature~pos("SASS")>0 | feature~pos("DISMISS")>0 then do
    proposal~addObjective("REDUCE_DISMISSIVE_REGISTER")
    proposal~addObjective("MAINTAIN_SERVICE_ENGAGEMENT")
    proposal~addAvoidance("UNILATERAL_RELATIONAL_CLOSURE")
    /* A tone finding does not imply that the agent should apologise harder. */
    proposal~addAvoidance("EXTREME_APOLOGY_AS_DEFAULT_RECOVERY")
  end
  if feature~pos("APOLOGY")>0 then do
    proposal~addObjective("PREFER_EFFECTIVE_RESOLUTION_OVER_REPEATED_APOLOGY")
    proposal~addAvoidance("ESCALATE_APOLOGY_INTENSITY_AS_DEFAULT")
  end
  if proposal~objectives~items=0 then proposal~addObjective("ADAPT_WITHIN_EVIDENCE_SCOPE_ONLY")
  return .true

/* Post-intervention observation is evidence for later population comparison,
   not proof that the intervention worked. */
::class BrandInterventionOutcomeObservation subclass AlchemyObject public
::attribute observationId get
::attribute sourceJourneyPoint get
::attribute proposalPoint get
::attribute interventionKind get
::attribute interventionApplied get
::attribute observedAt get
::attribute outcomeKind get
::attribute outcomeOccurred get
::attribute outcomeLagSeconds get
::attribute causalStatus get
::attribute sealed get
::method init
  expose observationId sourceJourneyPoint proposalPoint interventionKind interventionApplied observedAt outcomeKind outcomeOccurred outcomeLagSeconds causalStatus evidencePoints sealed
  use arg idArg, journeyPointArg, proposalPointArg, kindArg, appliedArg, observedAtArg, outcomeKindArg, outcomeOccurredArg=.false, lagSecondsArg=0, alchemySealerArg=.nil, alchemyAuthorityArg=.nil
  observationId=idArg~string; sourceJourneyPoint=journeyPointArg~string; proposalPoint=proposalPointArg~string; interventionKind=.BrandInterventionCanonical~token(kindArg); interventionApplied=appliedArg; observedAt=observedAtArg~string; outcomeKind=.BrandInterventionCanonical~token(outcomeKindArg); outcomeOccurred=outcomeOccurredArg; outcomeLagSeconds=lagSecondsArg+0; causalStatus=.BrandInterventionConstant~CAUSAL_ASSOCIATION_ONLY; evidencePoints=.array~new; sealed=.false
  if observationId="" | observedAt="" | outcomeKind="" | \.BrandInterventionCanonical~safePoint(sourceJourneyPoint) | \.BrandInterventionCanonical~safePoint(proposalPoint) then raise syntax 88.990 array("BrandInterventionOutcomeObservation requires safe points, time and outcome")
  self~initAlchemy(.BrandInterventionAlchemySupport~metadata("post-intervention outcome observation for later comparative measurement; association only"),alchemySealerArg,alchemyAuthorityArg)
  self~registerStateVariable("observationId","CUSTOMER","outcome observation id")
  self~registerStateVariable("sourceJourneyPoint","INTERNAL","source journey point")
  self~registerStateVariable("proposalPoint","INTERNAL","intervention proposal point")
  self~registerStateVariable("interventionKind","CUSTOMER","controlled intervention kind")
  self~registerStateVariable("interventionApplied","CUSTOMER","whether external system applied intervention")
  self~registerStateVariable("observedAt","CUSTOMER","outcome observation time")
  self~registerStateVariable("outcomeKind","CUSTOMER","measured outcome")
  self~registerStateVariable("outcomeOccurred","CUSTOMER","outcome flag")
  self~registerStateVariable("outcomeLagSeconds","CUSTOMER","post-intervention outcome lag")
  self~registerStateVariable("causalStatus","CUSTOMER","association-only causal status")
  self~registerStateVariable("evidencePoints","INTERNAL","privacy-safe evidence points")
  self~registerStateVariable("sealed","CUSTOMER","observation immutability")
::method addEvidencePoint
  expose evidencePoints sealed; use arg v
  if sealed | \.BrandInterventionCanonical~safePoint(v) then return .false
  if \.BrandInterventionCanonical~contains(evidencePoints,v~string) then evidencePoints~append(v~string); return .true
::method evidencePoints
  expose evidencePoints; return .BrandInterventionCanonical~copyArray(evidencePoints)
::method seal
  expose outcomeLagSeconds sealed
  if outcomeLagSeconds<0 then return .BrandInterventionResult~failure("OUTCOME_LAG_INVALID")
  sealed=.true; return .BrandInterventionResult~success(self)
::method pointId
  expose observationId; return "BRAND_INTERVENTION:OUTCOME:"||observationId
::method canonicalText
  expose observationId interventionKind interventionApplied observedAt outcomeKind outcomeOccurred outcomeLagSeconds causalStatus sealed
  if \sealed then raise syntax 93.990 additional("BrandInterventionOutcomeObservation must be sealed")
  out=.BrandInterventionCanonical~field("INTERVENTION_OUTCOME",observationId)
  out||=.BrandInterventionCanonical~field("INTERVENTION_KIND",interventionKind)
  out||=.BrandInterventionCanonical~field("INTERVENTION_APPLIED",interventionApplied)
  out||=.BrandInterventionCanonical~field("OBSERVED_AT",observedAt)
  out||=.BrandInterventionCanonical~field("OUTCOME_KIND",outcomeKind)
  out||=.BrandInterventionCanonical~field("OUTCOME_OCCURRED",outcomeOccurred)
  out||=.BrandInterventionCanonical~field("OUTCOME_LAG_SECONDS",outcomeLagSeconds)
  out||=.BrandInterventionCanonical~field("CAUSAL_STATUS",causalStatus)
  return out

::class BrandInterventionLibrary subclass AlchemyObject public
::method init
  expose decisions outcomes
  use arg alchemySealerArg=.nil, alchemyAuthorityArg=.nil
  decisions=.directory~new; outcomes=.directory~new
  self~initAlchemy(.BrandInterventionAlchemySupport~metadata("registry of privacy-minimised intervention decisions and outcome evidence; no execution"),alchemySealerArg,alchemyAuthorityArg)
  self~registerStateVariable("decisions","INTERNAL","reasoning decisions")
  self~registerStateVariable("outcomes","INTERNAL","post-intervention outcome observations")
::method registerDecision
  expose decisions; use arg d
  if d==.nil then return .BrandInterventionResult~failure("DECISION_REQUIRED")
  if decisions~hasIndex(d~decisionId) then return .BrandInterventionResult~failure("DECISION_ALREADY_REGISTERED")
  decisions[d~decisionId]=d; self~recordRelationship("CONTAINS",d,"intervention reasoning decision","INTERNAL")
  return .BrandInterventionResult~success(d)
::method registerOutcome
  expose outcomes; use arg o
  if o==.nil | \o~sealed then return .BrandInterventionResult~failure("OUTCOME_NOT_SEALED")
  if outcomes~hasIndex(o~observationId) then return .BrandInterventionResult~failure("OUTCOME_ALREADY_REGISTERED")
  outcomes[o~observationId]=o; self~recordRelationship("CONTAINS",o,"post-intervention outcome observation","INTERNAL")
  return .BrandInterventionResult~success(o)
::method decision
  expose decisions; use arg idArg; return decisions~at(idArg~string)
::method outcome
  expose outcomes; use arg idArg; return outcomes~at(idArg~string)

::requires "BrandJourneyPopulation.cls"
