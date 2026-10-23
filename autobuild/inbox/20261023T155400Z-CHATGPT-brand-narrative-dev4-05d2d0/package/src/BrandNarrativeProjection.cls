::class BrandNarrativeProjectionEngine public
::method project
  use strict arg interventionDecision, governanceDecision, directiveId = "", contextEvidence = .nil
  if interventionDecision == .nil then return .BrandNarrativeDirectiveResult~failure("INTERVENTION_DECISION_REQUIRED")
  if \interventionDecision~isA(.BrandInterventionDecision) then return .BrandNarrativeDirectiveResult~failure("INTERVENTION_DECISION_TYPE_INVALID")
  if governanceDecision == .nil then return .BrandNarrativeDirectiveResult~failure("GOVERNANCE_DECISION_REQUIRED")
  if \governanceDecision~isA(.BrandInterventionGovernanceDecision) then return .BrandNarrativeDirectiveResult~failure("GOVERNANCE_DECISION_TYPE_INVALID")
  if \governanceDecision~sealed then return .BrandNarrativeDirectiveResult~failure("GOVERNANCE_DECISION_NOT_SEALED")

  proposal = interventionDecision~proposal
  if proposal == .nil then return .BrandNarrativeDirectiveResult~failure("INTERVENTION_PROPOSAL_REQUIRED")
  if \proposal~sealed then return .BrandNarrativeDirectiveResult~failure("INTERVENTION_PROPOSAL_NOT_SEALED")
  context = interventionDecision~context
  if context == .nil then return .BrandNarrativeDirectiveResult~failure("INTERVENTION_CONTEXT_REQUIRED")
  if \context~sealed then return .BrandNarrativeDirectiveResult~failure("INTERVENTION_CONTEXT_NOT_SEALED")
  binding = interventionDecision~binding
  if binding == .nil then return .BrandNarrativeDirectiveResult~failure("INTERVENTION_BINDING_REQUIRED")
  if \binding~sealed then return .BrandNarrativeDirectiveResult~failure("INTERVENTION_BINDING_NOT_SEALED")
  policy = interventionDecision~policy
  if policy == .nil then return .BrandNarrativeDirectiveResult~failure("INTERVENTION_POLICY_REQUIRED")
  if \policy~sealed then return .BrandNarrativeDirectiveResult~failure("INTERVENTION_POLICY_NOT_SEALED")

  recommendation = governanceDecision~recommendation
  if recommendation == .nil then return .BrandNarrativeDirectiveResult~failure("GOVERNANCE_RECOMMENDATION_REQUIRED")
  if \recommendation~sealed then return .BrandNarrativeDirectiveResult~failure("GOVERNANCE_RECOMMENDATION_NOT_SEALED")
  if proposal~proposalKind \== recommendation~interventionKind then return .BrandNarrativeDirectiveResult~failure("INTERVENTION_KIND_MISMATCH")

  mapped = self~mapDecision(governanceDecision~decisionCode)
  if \mapped~ok then return mapped
  spec = mapped~value
  if spec["requires_managed_policy"] then do
    if \recommendation~institutionalPolicyManaged then return .BrandNarrativeDirectiveResult~failure("OPERATIVE_POLICY_SELECTION_REQUIRED")
  end

  id = directiveId~string~strip
  if id == "" then id = "DIRECTIVE-" || governanceDecision~decisionId
  policyRef = ""
  if recommendation~institutionalPolicyManaged then do
    selection = recommendation~institutionalPolicySelection
    if selection == .nil then return .BrandNarrativeDirectiveResult~failure("OPERATIVE_POLICY_SELECTION_REQUIRED")
    if \selection~sealed then return .BrandNarrativeDirectiveResult~failure("OPERATIVE_POLICY_SELECTION_NOT_SEALED")
    policyRef = selection~pointId
  end

  interventionSnapshot = interventionDecision~reasoningMaterial
  governanceSnapshot = governanceDecision~reasoningMaterial
  directive = .BrandNarrativeDirective~new(id, spec["kind"], spec["effect"], spec["rollout"], proposal~proposalKind, governanceDecision~decisionCode, interventionDecision~decisionId, governanceDecision~decisionId, governanceDecision~decisionRef, recommendation~candidateExposureCapPct, interventionSnapshot, governanceSnapshot, policyRef)
  directive~recordRelationship("PROJECTS", interventionDecision, "projection-time intervention decision", "INTERNAL")
  directive~recordRelationship("GOVERNED_BY", governanceDecision, "named-authority governance decision", "INTERNAL")

  do item over proposal~objectives
    directive~addObjective(item)
  end
  do item over proposal~avoidances
    directive~addAvoidance(item)
  end
  do item over proposal~obligations
    directive~addObligation(item)
  end
  do item over recommendation~conditions
    directive~addCondition(item)
  end
  do item over recommendation~prohibitions
    directive~addProhibition(item)
  end
  do item over proposal~evidencePoints
    directive~addEvidencePoint(item)
  end
  do item over recommendation~evidencePoints
    directive~addEvidencePoint(item)
  end
  directive~addEvidencePoint(interventionDecision~pointId)
  directive~addEvidencePoint(governanceDecision~pointId)
  directive~addEvidencePoint(recommendation~pointId)

  if contextEvidence \== .nil then do
    do evidence over contextEvidence
      added = directive~addContextEvidence(evidence)
      if \added~ok then return added
    end
  end
  sealedResult = directive~seal
  if \sealedResult~ok then return sealedResult
  return .BrandNarrativeDirectiveResult~success(directive)

::method mapDecision
  use strict arg code
  spec = .Directory~new
  select
    when code == .BrandInterventionGovernanceConstant~DECISION_COLLECT then do
      spec["kind"] = .BrandNarrativeDirectiveConstant~KIND_EVIDENCE_ONLY
      spec["effect"] = .BrandNarrativeDirectiveConstant~EFFECT_NONE
      spec["rollout"] = .BrandNarrativeDirectiveConstant~ROLLOUT_NONE
      spec["requires_managed_policy"] = .false
    end
    when code == .BrandInterventionGovernanceConstant~DECISION_NO_CHANGE then do
      spec["kind"] = .BrandNarrativeDirectiveConstant~KIND_PRESERVE_BASELINE
      spec["effect"] = .BrandNarrativeDirectiveConstant~EFFECT_NONE
      spec["rollout"] = .BrandNarrativeDirectiveConstant~ROLLOUT_NONE
      spec["requires_managed_policy"] = .false
    end
    when code == .BrandInterventionGovernanceConstant~DECISION_APPROVE_PILOT then do
      spec["kind"] = .BrandNarrativeDirectiveConstant~KIND_PROPOSE_ADAPTATION
      spec["effect"] = .BrandNarrativeDirectiveConstant~EFFECT_ADAPT
      spec["rollout"] = .BrandNarrativeDirectiveConstant~ROLLOUT_CONTROLLED_PILOT
      spec["requires_managed_policy"] = .true
    end
    when code == .BrandInterventionGovernanceConstant~DECISION_APPROVE_EXPANSION then do
      spec["kind"] = .BrandNarrativeDirectiveConstant~KIND_PROPOSE_ADAPTATION
      spec["effect"] = .BrandNarrativeDirectiveConstant~EFFECT_ADAPT
      spec["rollout"] = .BrandNarrativeDirectiveConstant~ROLLOUT_LIMITED_EXPANSION
      spec["requires_managed_policy"] = .true
    end
    when code == .BrandInterventionGovernanceConstant~DECISION_CONTINUE then do
      spec["kind"] = .BrandNarrativeDirectiveConstant~KIND_CONTINUE_ADAPTATION
      spec["effect"] = .BrandNarrativeDirectiveConstant~EFFECT_CONTINUE
      spec["rollout"] = .BrandNarrativeDirectiveConstant~ROLLOUT_CURRENT
      spec["requires_managed_policy"] = .true
    end
    when code == .BrandInterventionGovernanceConstant~DECISION_PAUSE then do
      spec["kind"] = .BrandNarrativeDirectiveConstant~KIND_PAUSE_ADAPTATION
      spec["effect"] = .BrandNarrativeDirectiveConstant~EFFECT_PAUSE
      spec["rollout"] = .BrandNarrativeDirectiveConstant~ROLLOUT_NONE
      spec["requires_managed_policy"] = .false
    end
    when code == .BrandInterventionGovernanceConstant~DECISION_WITHDRAW then do
      spec["kind"] = .BrandNarrativeDirectiveConstant~KIND_WITHDRAW_ADAPTATION
      spec["effect"] = .BrandNarrativeDirectiveConstant~EFFECT_WITHDRAW
      spec["rollout"] = .BrandNarrativeDirectiveConstant~ROLLOUT_NONE
      spec["requires_managed_policy"] = .false
    end
    otherwise return .BrandNarrativeDirectiveResult~failure("GOVERNANCE_DECISION_CODE_UNSUPPORTED")
  end
  return .BrandNarrativeDirectiveResult~success(spec)

