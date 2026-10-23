::class BrandNarrativeDirective subclass AlchemyObject public
::attribute directiveId get
::attribute directiveKind get
::attribute runtimeEffect get
::attribute rolloutMode get
::attribute interventionKind get
::attribute governanceDecisionCode get
::attribute sourceInterventionDecisionId get
::attribute sourceGovernanceDecisionId get
::attribute sourceGovernanceDecisionRef get
::attribute exposureCapPct get
::attribute status get
::attribute activationAuthorityRequired get
::attribute causalStatus get
::attribute policySelectionRef get
::attribute sealed get
::method init
  expose directiveId directiveKind runtimeEffect rolloutMode interventionKind governanceDecisionCode sourceInterventionDecisionId sourceGovernanceDecisionId sourceGovernanceDecisionRef exposureCapPct status activationAuthorityRequired causalStatus objectives avoidances obligations conditions prohibitions evidencePoints contextEvidence interventionSnapshot governanceSnapshot policySelectionRef sealed
  use strict arg directiveId, directiveKind, runtimeEffect, rolloutMode, interventionKind, governanceDecisionCode, sourceInterventionDecisionId, sourceGovernanceDecisionId, sourceGovernanceDecisionRef, exposureCapPct, interventionSnapshot, governanceSnapshot, policySelectionRef = ""
  directiveKind = .BrandNarrativeDirectiveCanonical~token(directiveKind)
  runtimeEffect = .BrandNarrativeDirectiveCanonical~token(runtimeEffect)
  rolloutMode = .BrandNarrativeDirectiveCanonical~token(rolloutMode)
  interventionKind = .BrandNarrativeDirectiveCanonical~token(interventionKind)
  governanceDecisionCode = .BrandNarrativeDirectiveCanonical~token(governanceDecisionCode)
  if directiveId~string~strip == "" then raise syntax 93.900 array("BRAND_NARRATIVE_DIRECTIVE_ID_REQUIRED")
  if directiveKind == "" then raise syntax 93.900 array("BRAND_NARRATIVE_DIRECTIVE_KIND_REQUIRED")
  if runtimeEffect == "" then raise syntax 93.900 array("BRAND_NARRATIVE_RUNTIME_EFFECT_REQUIRED")
  if rolloutMode == "" then raise syntax 93.900 array("BRAND_NARRATIVE_ROLLOUT_MODE_REQUIRED")
  if interventionKind == "" then raise syntax 93.900 array("BRAND_NARRATIVE_INTERVENTION_KIND_REQUIRED")
  if governanceDecisionCode == "" then raise syntax 93.900 array("BRAND_NARRATIVE_GOVERNANCE_CODE_REQUIRED")
  if sourceInterventionDecisionId~string~strip == "" then raise syntax 93.900 array("BRAND_NARRATIVE_INTERVENTION_DECISION_REQUIRED")
  if sourceGovernanceDecisionId~string~strip == "" then raise syntax 93.900 array("BRAND_NARRATIVE_GOVERNANCE_DECISION_REQUIRED")
  if sourceGovernanceDecisionRef~string~strip == "" then raise syntax 93.900 array("BRAND_NARRATIVE_GOVERNANCE_DECISION_REF_REQUIRED")
  if \datatype(exposureCapPct, "N") then raise syntax 93.900 array("BRAND_NARRATIVE_EXPOSURE_CAP_NUMERIC_REQUIRED")
  if exposureCapPct < 0 then raise syntax 93.900 array("BRAND_NARRATIVE_EXPOSURE_CAP_RANGE")
  if exposureCapPct > 100 then raise syntax 93.900 array("BRAND_NARRATIVE_EXPOSURE_CAP_RANGE")
  status = .BrandNarrativeDirectiveConstant~STATUS_PROPOSED
  activationAuthorityRequired = .BrandNarrativeDirectiveConstant~AUTHORITY_EXTERNAL
  causalStatus = .BrandNarrativeDirectiveConstant~CAUSAL_ASSOCIATION_ONLY
  objectives = .Array~new
  avoidances = .Array~new
  obligations = .Array~new
  conditions = .Array~new
  prohibitions = .Array~new
  evidencePoints = .Array~new
  contextEvidence = .Array~new
  sealed = .false
  meta = .Directory~new
  meta["purpose"] = "connector-neutral narrative directive projected from governed brand evidence; no activation or publication authority"
  meta["package_version"] = .BrandNarrativeDirectiveBuild~VERSION
  meta["api_version"] = .BrandNarrativeDirectiveBuild~API_VERSION
  meta["component"] = "BRAND_NARRATIVE_DIRECTIVE"
  self~initAlchemy(meta)
  self~registerStateVariable("directiveKind", "CUSTOMER", "controlled narrative projection kind")
  self~registerStateVariable("runtimeEffect", "CUSTOMER", "requested runtime effect; not execution authority")
  self~registerStateVariable("rolloutMode", "CUSTOMER", "governance-limited rollout mode")
  self~registerStateVariable("interventionKind", "CUSTOMER", "underlying governed intervention kind")
  self~registerStateVariable("governanceDecisionCode", "CUSTOMER", "named-authority governance decision code")
  self~registerStateVariable("exposureCapPct", "CUSTOMER", "candidate exposure ceiling, never automatic assignment")
  self~registerStateVariable("status", "CUSTOMER", "always proposed until external narrative authority activates")
  self~registerStateVariable("activationAuthorityRequired", "CUSTOMER", "runtime narrative authority remains external")
  self~registerStateVariable("causalStatus", "CUSTOMER", "association-only evidence status")
  self~registerStateVariable("objectives", "CUSTOMER", "bounded behavioural objectives")
  self~registerStateVariable("avoidances", "CUSTOMER", "bounded strategies to avoid")
  self~registerStateVariable("obligations", "CUSTOMER", "constraints that must survive any narrative adaptation")
  self~registerStateVariable("conditions", "CUSTOMER", "governance conditions")
  self~registerStateVariable("prohibitions", "CUSTOMER", "governance prohibitions")
  self~registerStateVariable("contextEvidence", "INTERNAL", "detached NO_DISPATCH/EVIDENCE_ONLY context references")
  self~registerStateVariable("interventionSnapshot", "INTERNAL", "projection-time upstream intervention reasoning snapshot")
  self~registerStateVariable("governanceSnapshot", "INTERNAL", "projection-time upstream governance reasoning snapshot")
  self~registerStateVariable("policySelectionRef", "INTERNAL", "exact operative policy selection reference when present")
  self~registerStateVariable("sealed", "CUSTOMER", "directive immutability")
::method addObjective
  expose objectives sealed
  use strict arg value
  if sealed then return .false
  return .BrandNarrativeDirectiveCanonical~appendUnique(objectives, .BrandNarrativeDirectiveCanonical~token(value))
::method addAvoidance
  expose avoidances sealed
  use strict arg value
  if sealed then return .false
  return .BrandNarrativeDirectiveCanonical~appendUnique(avoidances, .BrandNarrativeDirectiveCanonical~token(value))
::method addObligation
  expose obligations sealed
  use strict arg value
  if sealed then return .false
  return .BrandNarrativeDirectiveCanonical~appendUnique(obligations, .BrandNarrativeDirectiveCanonical~token(value))
::method addCondition
  expose conditions sealed
  use strict arg value
  if sealed then return .false
  return .BrandNarrativeDirectiveCanonical~appendUnique(conditions, .BrandNarrativeDirectiveCanonical~token(value))
::method addProhibition
  expose prohibitions sealed
  use strict arg value
  if sealed then return .false
  return .BrandNarrativeDirectiveCanonical~appendUnique(prohibitions, .BrandNarrativeDirectiveCanonical~token(value))
::method addEvidencePoint
  expose evidencePoints sealed
  use strict arg value
  if sealed then return .false
  return .BrandNarrativeDirectiveCanonical~appendUnique(evidencePoints, value)
::method addContextEvidence
  expose contextEvidence sealed
  use strict arg evidence
  if sealed then return .BrandNarrativeDirectiveResult~failure("DIRECTIVE_ALREADY_SEALED")
  if evidence == .nil then return .BrandNarrativeDirectiveResult~failure("CONTEXT_EVIDENCE_REQUIRED")
  if \evidence~isA(.BrandNarrativeEvidenceReference) then return .BrandNarrativeDirectiveResult~failure("CONTEXT_EVIDENCE_TYPE_INVALID")
  if \evidence~sealed then return .BrandNarrativeDirectiveResult~failure("CONTEXT_EVIDENCE_NOT_SEALED")
  contextEvidence~append(evidence)
  self~recordRelationship("USES_CONTEXT", evidence, "non-authoritative narrative context evidence", "INTERNAL")
  return .BrandNarrativeDirectiveResult~success(evidence)
::method objectives
  expose objectives
  return .BrandNarrativeDirectiveCanonical~copyArray(objectives)
::method avoidances
  expose avoidances
  return .BrandNarrativeDirectiveCanonical~copyArray(avoidances)
::method obligations
  expose obligations
  return .BrandNarrativeDirectiveCanonical~copyArray(obligations)
::method conditions
  expose conditions
  return .BrandNarrativeDirectiveCanonical~copyArray(conditions)
::method prohibitions
  expose prohibitions
  return .BrandNarrativeDirectiveCanonical~copyArray(prohibitions)
::method evidencePoints
  expose evidencePoints
  return .BrandNarrativeDirectiveCanonical~copyArray(evidencePoints)
::method contextEvidence
  expose contextEvidence
  return .BrandNarrativeDirectiveCanonical~copyArray(contextEvidence)
::method seal
  expose directiveKind runtimeEffect rolloutMode objectives obligations sealed
  if directiveKind == .BrandNarrativeDirectiveConstant~KIND_PROPOSE_ADAPTATION then do
    if objectives~items == 0 then return .BrandNarrativeDirectiveResult~failure("ADAPTATION_OBJECTIVE_REQUIRED")
    if obligations~items == 0 then return .BrandNarrativeDirectiveResult~failure("ADAPTATION_OBLIGATION_REQUIRED")
    if runtimeEffect \== .BrandNarrativeDirectiveConstant~EFFECT_ADAPT then return .BrandNarrativeDirectiveResult~failure("ADAPTATION_RUNTIME_EFFECT_INVALID")
    if rolloutMode == .BrandNarrativeDirectiveConstant~ROLLOUT_NONE then return .BrandNarrativeDirectiveResult~failure("ADAPTATION_ROLLOUT_REQUIRED")
  end
  sealed = .true
  self~alchemyTouch("BRAND_NARRATIVE_DIRECTIVE_SEAL")
  return .BrandNarrativeDirectiveResult~success(self)
::method pointId
  expose directiveId
  return "BRAND_NARRATIVE:DIRECTIVE:" || directiveId
::method toDirectory
  expose directiveId directiveKind runtimeEffect rolloutMode interventionKind governanceDecisionCode sourceInterventionDecisionId sourceGovernanceDecisionId sourceGovernanceDecisionRef exposureCapPct status activationAuthorityRequired causalStatus objectives avoidances obligations conditions prohibitions evidencePoints contextEvidence policySelectionRef sealed
  if \sealed then raise syntax 93.900 array("BRAND_NARRATIVE_DIRECTIVE_NOT_SEALED")
  out = .Directory~new
  out["schema"] = "brand.narrative.directive/0.1"
  out["directive_id"] = directiveId
  out["directive_kind"] = directiveKind
  out["runtime_effect"] = runtimeEffect
  out["rollout_mode"] = rolloutMode
  out["intervention_kind"] = interventionKind
  out["governance_decision_code"] = governanceDecisionCode
  out["source_intervention_decision_id"] = sourceInterventionDecisionId
  out["source_governance_decision_id"] = sourceGovernanceDecisionId
  out["source_governance_decision_ref"] = sourceGovernanceDecisionRef
  out["candidate_exposure_cap_pct"] = exposureCapPct
  out["status"] = status
  out["activation_authority_required"] = activationAuthorityRequired
  out["causal_status"] = causalStatus
  out["objectives"] = .BrandNarrativeDirectiveCanonical~copyArray(objectives)
  out["avoidances"] = .BrandNarrativeDirectiveCanonical~copyArray(avoidances)
  out["obligations"] = .BrandNarrativeDirectiveCanonical~copyArray(obligations)
  out["governance_conditions"] = .BrandNarrativeDirectiveCanonical~copyArray(conditions)
  out["governance_prohibitions"] = .BrandNarrativeDirectiveCanonical~copyArray(prohibitions)
  out["evidence_points"] = .BrandNarrativeDirectiveCanonical~copyArray(evidencePoints)
  refs = .Array~new
  do item over contextEvidence
    refs~append(item~toDirectory)
  end
  out["context_evidence"] = refs
  out["policy_selection_ref"] = policySelectionRef
  return out
::method reasoningMaterial
  expose directiveId directiveKind runtimeEffect rolloutMode interventionKind governanceDecisionCode sourceInterventionDecisionId sourceGovernanceDecisionId sourceGovernanceDecisionRef exposureCapPct status activationAuthorityRequired causalStatus objectives avoidances obligations conditions prohibitions evidencePoints policySelectionRef interventionSnapshot governanceSnapshot sealed
  if \sealed then raise syntax 93.900 array("BRAND_NARRATIVE_DIRECTIVE_NOT_SEALED")
  out = .BrandNarrativeDirectiveCanonical~field("BRAND_NARRATIVE_DIRECTIVE", directiveId)
  out ||= .BrandNarrativeDirectiveCanonical~field("DIRECTIVE_KIND", directiveKind)
  out ||= .BrandNarrativeDirectiveCanonical~field("RUNTIME_EFFECT", runtimeEffect)
  out ||= .BrandNarrativeDirectiveCanonical~field("ROLLOUT_MODE", rolloutMode)
  out ||= .BrandNarrativeDirectiveCanonical~field("INTERVENTION_KIND", interventionKind)
  out ||= .BrandNarrativeDirectiveCanonical~field("GOVERNANCE_DECISION_CODE", governanceDecisionCode)
  out ||= .BrandNarrativeDirectiveCanonical~field("SOURCE_INTERVENTION_DECISION", sourceInterventionDecisionId)
  out ||= .BrandNarrativeDirectiveCanonical~field("SOURCE_GOVERNANCE_DECISION", sourceGovernanceDecisionId)
  out ||= .BrandNarrativeDirectiveCanonical~field("SOURCE_GOVERNANCE_DECISION_REF", sourceGovernanceDecisionRef)
  out ||= .BrandNarrativeDirectiveCanonical~field("CANDIDATE_EXPOSURE_CAP_PCT", exposureCapPct)
  out ||= .BrandNarrativeDirectiveCanonical~field("STATUS", status)
  out ||= .BrandNarrativeDirectiveCanonical~field("ACTIVATION_AUTHORITY_REQUIRED", activationAuthorityRequired)
  out ||= .BrandNarrativeDirectiveCanonical~field("CAUSAL_STATUS", causalStatus)
  out ||= .BrandNarrativeDirectiveCanonical~join("OBJECTIVE", objectives)
  out ||= .BrandNarrativeDirectiveCanonical~join("AVOID", avoidances)
  out ||= .BrandNarrativeDirectiveCanonical~join("MUST_PRESERVE", obligations)
  out ||= .BrandNarrativeDirectiveCanonical~join("GOVERNANCE_CONDITION", conditions)
  out ||= .BrandNarrativeDirectiveCanonical~join("GOVERNANCE_PROHIBITION", prohibitions)
  out ||= .BrandNarrativeDirectiveCanonical~join("EVIDENCE_POINT", evidencePoints)
  if policySelectionRef \== "" then out ||= .BrandNarrativeDirectiveCanonical~field("POLICY_SELECTION_REF", policySelectionRef)
  out ||= .BrandNarrativeDirectiveCanonical~field("UPSTREAM_INTERVENTION_SNAPSHOT_BEGIN", 1)
  out ||= interventionSnapshot
  out ||= .BrandNarrativeDirectiveCanonical~field("UPSTREAM_INTERVENTION_SNAPSHOT_END", 1)
  out ||= .BrandNarrativeDirectiveCanonical~field("UPSTREAM_GOVERNANCE_SNAPSHOT_BEGIN", 1)
  out ||= governanceSnapshot
  out ||= .BrandNarrativeDirectiveCanonical~field("UPSTREAM_GOVERNANCE_SNAPSHOT_END", 1)
  out ||= .BrandNarrativeDirectiveCanonical~field("INTERPRETATION_BOUND", "DIRECTIVE_NOT_ACTIVATION")
  out ||= .BrandNarrativeDirectiveCanonical~field("INTERPRETATION_BOUND", "EVIDENCE_NOT_CAUSATION")
  return out


