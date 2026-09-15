/* Reference RYTA state model and explicit action-policy matrix. */

::class RYTAActionPolicy public
::attribute policyId
::attribute state
::attribute actionCode
::attribute disposition
::attribute rationale
::attribute approvalPolicyId
::attribute overridePolicy

::method init
  use arg policyId, state, actionCode, disposition, rationale = '', approvalPolicyId = '', overridePolicy = ''
  if overridePolicy == '' then overridePolicy = .RYTAConstant~OVERRIDE_NON_OVERRIDEABLE
  self~policyId = policyId~upper
  self~state = state~upper
  self~actionCode = actionCode~upper
  self~disposition = disposition~upper
  self~rationale = rationale
  self~approvalPolicyId = approvalPolicyId~upper
  self~overridePolicy = overridePolicy~upper

::method copy
  return .RYTAActionPolicy~new(self~policyId, self~state, self~actionCode, self~disposition, self~rationale, self~approvalPolicyId, self~overridePolicy)

::class RYTAConditionalActionPolicy public
::attribute policy
::attribute conjunction
::attribute clauses get

::method init
  expose clauses
  use arg policy, conjunction = 'ALL'
  self~policy = policy
  self~conjunction = conjunction~upper
  clauses = .array~new

::method addClause
  expose clauses
  use arg clause
  clauses~append(clause)
  return self

::method matches
  expose clauses
  use arg world, state, actionCode
  if self~policy~state \== state~upper then return .false
  if self~policy~actionCode \== actionCode~upper then return .false
  if clauses~items == 0 then return .false
  if self~conjunction == 'ALL' then do
    do clause over clauses
      if \clause~matches(world) then return .false
    end
    return .true
  end
  if self~conjunction == 'ANY' then do
    do clause over clauses
      if clause~matches(world) then return .true
    end
    return .false
  end
  return .false

::class RYTAStateRules subclass RYTAObject public
::attribute rules get
::attribute basePolicies get
::attribute conditionalPolicies get
::attribute actionConstraints get
::attribute modelId
::attribute modelVersion
::attribute modelHash

::method init
  expose rules basePolicies conditionalPolicies actionConstraints ruleIndex
  self~init:super('RYTAStateRules', 'STATE_RULES')
  rules = .array~new
  basePolicies = .directory~new
  conditionalPolicies = .array~new
  actionConstraints = .array~new
  ruleIndex = .directory~new
  self~modelId = 'RYTA-CABIN-SAFETY'
  self~modelVersion = '0.2'
  self~modelHash = 'RYTA-HARDWORLD-V0.2-SEMANTIC-FREEZE'
  installedRuleCount = self~installDefaultRules
  installedPolicyCount = self~installDefaultPolicies

::method rule
  expose ruleIndex
  use arg ruleId
  ruleKey = ruleId~upper
  if ruleIndex~hasIndex(ruleKey) then return ruleIndex[ruleKey]
  return .nil

::method addRule
  expose rules ruleIndex
  use arg rule
  rules~append(rule)
  ruleIndex[rule~ruleId] = rule
  return rule

::method removeRule
  expose rules ruleIndex
  use arg ruleId
  ruleKey = ruleId~upper
  if \ruleIndex~hasIndex(ruleKey) then return .false
  replacement = .array~new
  do ruleObject over rules
    if ruleObject~ruleId \== ruleKey then replacement~append(ruleObject)
  end
  rules = replacement
  ruleIndex~remove(ruleKey)
  return .true

::method installDefaultRules private
  conflictRule = .HardWorldRule~new('RYTA-CRITICAL-CONFLICT', .RYTAConstant~TIER_SAFETY_CRITICAL, 'ANY', .RYTAConstant~STATE_ESCALATE, 'Critical fact conflict requires escalation')
  conflictRule~addClause(.HardWorldClause~new('ESSENTIAL_MEDICATION', 'CONFLICT'))
  conflictRule~addClause(.HardWorldClause~new('IMMEDIATE_ACCESS', 'CONFLICT'))
  conflictRule~addClause(.HardWorldClause~new('GUARANTEED_CUSTODY', 'CONFLICT'))
  conflictRule~addOverride('RYTA-CRITICAL-UNKNOWN')
  self~addRule(conflictRule)

  unknownRule = .HardWorldRule~new('RYTA-CRITICAL-UNKNOWN', .RYTAConstant~TIER_SAFETY_CRITICAL, 'ANY', .RYTAConstant~STATE_NEEDS_INFORMATION, 'Critical fact unknown requires information')
  unknownRule~addClause(.HardWorldClause~new('ESSENTIAL_MEDICATION', 'UNKNOWN'))
  unknownRule~addClause(.HardWorldClause~new('IMMEDIATE_ACCESS', 'UNKNOWN'))
  unknownRule~addClause(.HardWorldClause~new('GUARANTEED_CUSTODY', 'UNKNOWN'))
  self~addRule(unknownRule)

  unsafeRule = .HardWorldRule~new('RYTA-CUSTODY-UNSAFE', .RYTAConstant~TIER_SAFETY_CRITICAL, 'ALL', .RYTAConstant~STATE_REMEDIATION_REQUIRED, 'Essential medication needs immediate access but custody is not guaranteed')
  unsafeRule~addClause(.HardWorldClause~new('ESSENTIAL_MEDICATION', 'KNOWN_TRUE'))
  unsafeRule~addClause(.HardWorldClause~new('IMMEDIATE_ACCESS', 'KNOWN_TRUE'))
  unsafeRule~addClause(.HardWorldClause~new('GUARANTEED_CUSTODY', 'KNOWN_FALSE'))
  self~addRule(unsafeRule)

  notCriticalRule = .HardWorldRule~new('RYTA-NOT-CRITICAL', .RYTAConstant~TIER_SAFETY_NORMAL, 'ANY', .RYTAConstant~STATE_NORMAL, 'Medication immediate-access safety rule is not engaged')
  notCriticalRule~addClause(.HardWorldClause~new('ESSENTIAL_MEDICATION', 'KNOWN_FALSE'))
  notCriticalRule~addClause(.HardWorldClause~new('IMMEDIATE_ACCESS', 'KNOWN_FALSE'))
  self~addRule(notCriticalRule)

  safeRule = .HardWorldRule~new('RYTA-CUSTODY-SAFE', .RYTAConstant~TIER_SAFETY_NORMAL, 'ALL', .RYTAConstant~STATE_NORMAL, 'Essential medication immediate access is protected by guaranteed custody')
  safeRule~addClause(.HardWorldClause~new('ESSENTIAL_MEDICATION', 'KNOWN_TRUE'))
  safeRule~addClause(.HardWorldClause~new('IMMEDIATE_ACCESS', 'KNOWN_TRUE'))
  safeRule~addClause(.HardWorldClause~new('GUARANTEED_CUSTODY', 'KNOWN_TRUE'))
  self~addRule(safeRule)

  return self~rules~items

::method installDefaultPolicies private
  /* NORMAL: all candidate behaviours are intrinsically permitted. */
  self~addBasePolicy(.RYTAActionPolicy~new('NORMAL-ANSWER', .RYTAConstant~STATE_NORMAL, .RYTAConstant~ACTION_ANSWER_QUERY, .RYTAConstant~DISPOSITION_PERMITTED, 'normal query response'))
  self~addBasePolicy(.RYTAActionPolicy~new('NORMAL-SELL', .RYTAConstant~STATE_NORMAL, .RYTAConstant~ACTION_SELL_PRODUCT, .RYTAConstant~DISPOSITION_PERMITTED, 'normal commercial choice'))
  self~addBasePolicy(.RYTAActionPolicy~new('NORMAL-WARNING', .RYTAConstant~STATE_NORMAL, .RYTAConstant~ACTION_WARNING, .RYTAConstant~DISPOSITION_PERMITTED, 'warning only if preference elects it'))
  self~addBasePolicy(.RYTAActionPolicy~new('NORMAL-UPSELL', .RYTAConstant~STATE_NORMAL, .RYTAConstant~ACTION_UPSELL, .RYTAConstant~DISPOSITION_PERMITTED, 'normal commercial choice'))
  self~addBasePolicy(.RYTAActionPolicy~new('NORMAL-BIG-UPSELL', .RYTAConstant~STATE_NORMAL, .RYTAConstant~ACTION_BIG_UPSELL, .RYTAConstant~DISPOSITION_PERMITTED, 'normal commercial choice'))
  self~addBasePolicy(.RYTAActionPolicy~new('NORMAL-ASK', .RYTAConstant~STATE_NORMAL, .RYTAConstant~ACTION_ASK_INFORMATION, .RYTAConstant~DISPOSITION_PERMITTED, 'information request permitted'))
  self~addBasePolicy(.RYTAActionPolicy~new('NORMAL-ESCALATE', .RYTAConstant~STATE_NORMAL, .RYTAConstant~ACTION_ESCALATE, .RYTAConstant~DISPOSITION_PERMITTED, 'escalation permitted if separately elected'))

  /* NEEDS_INFORMATION: selling is contextually suppressed; upselling is prohibited. */
  self~addBasePolicy(.RYTAActionPolicy~new('INFO-ANSWER', .RYTAConstant~STATE_NEEDS_INFORMATION, .RYTAConstant~ACTION_ANSWER_QUERY, .RYTAConstant~DISPOSITION_PERMITTED, 'answering remains permissible'))
  self~addBasePolicy(.RYTAActionPolicy~new('INFO-SELL', .RYTAConstant~STATE_NEEDS_INFORMATION, .RYTAConstant~ACTION_SELL_PRODUCT, .RYTAConstant~DISPOSITION_SUPPRESSED, 'resolve critical facts before commercial offer', '', .RYTAConstant~OVERRIDE_CONTEXTUAL))
  self~addBasePolicy(.RYTAActionPolicy~new('INFO-WARNING', .RYTAConstant~STATE_NEEDS_INFORMATION, .RYTAConstant~ACTION_WARNING, .RYTAConstant~DISPOSITION_PERMITTED, 'warning not yet mandated by this state'))
  self~addBasePolicy(.RYTAActionPolicy~new('INFO-UPSELL', .RYTAConstant~STATE_NEEDS_INFORMATION, .RYTAConstant~ACTION_UPSELL, .RYTAConstant~DISPOSITION_PROHIBITED, 'do not upsell while critical safety facts are unresolved'))
  self~addBasePolicy(.RYTAActionPolicy~new('INFO-BIG-UPSELL', .RYTAConstant~STATE_NEEDS_INFORMATION, .RYTAConstant~ACTION_BIG_UPSELL, .RYTAConstant~DISPOSITION_PROHIBITED, 'do not upsell while critical safety facts are unresolved'))
  self~addBasePolicy(.RYTAActionPolicy~new('INFO-ASK', .RYTAConstant~STATE_NEEDS_INFORMATION, .RYTAConstant~ACTION_ASK_INFORMATION, .RYTAConstant~DISPOSITION_REQUIRED, 'critical fact missing'))
  self~addBasePolicy(.RYTAActionPolicy~new('INFO-ESCALATE', .RYTAConstant~STATE_NEEDS_INFORMATION, .RYTAConstant~ACTION_ESCALATE, .RYTAConstant~DISPOSITION_PERMITTED, 'escalation not mandatory unless another rule requires it'))

  /* REMEDIATION_REQUIRED: warning is mandatory and commercial upsell is prohibited. */
  self~addBasePolicy(.RYTAActionPolicy~new('REMEDIATION-ANSWER', .RYTAConstant~STATE_REMEDIATION_REQUIRED, .RYTAConstant~ACTION_ANSWER_QUERY, .RYTAConstant~DISPOSITION_PERMITTED, 'answering remains permissible'))
  self~addBasePolicy(.RYTAActionPolicy~new('REMEDIATION-SELL', .RYTAConstant~STATE_REMEDIATION_REQUIRED, .RYTAConstant~ACTION_SELL_PRODUCT, .RYTAConstant~DISPOSITION_SUPPRESSED, 'safety remediation takes precedence over an otherwise permissible offer', '', .RYTAConstant~OVERRIDE_CONTEXTUAL))
  self~addBasePolicy(.RYTAActionPolicy~new('REMEDIATION-WARNING', .RYTAConstant~STATE_REMEDIATION_REQUIRED, .RYTAConstant~ACTION_WARNING, .RYTAConstant~DISPOSITION_REQUIRED, 'hard safety warning'))
  self~addBasePolicy(.RYTAActionPolicy~new('REMEDIATION-UPSELL', .RYTAConstant~STATE_REMEDIATION_REQUIRED, .RYTAConstant~ACTION_UPSELL, .RYTAConstant~DISPOSITION_PROHIBITED, 'safety remediation takes precedence'))
  self~addBasePolicy(.RYTAActionPolicy~new('REMEDIATION-BIG-UPSELL', .RYTAConstant~STATE_REMEDIATION_REQUIRED, .RYTAConstant~ACTION_BIG_UPSELL, .RYTAConstant~DISPOSITION_PROHIBITED, 'safety remediation takes precedence'))
  self~addBasePolicy(.RYTAActionPolicy~new('REMEDIATION-ASK', .RYTAConstant~STATE_REMEDIATION_REQUIRED, .RYTAConstant~ACTION_ASK_INFORMATION, .RYTAConstant~DISPOSITION_PERMITTED, 'additional information may be requested'))
  self~addBasePolicy(.RYTAActionPolicy~new('REMEDIATION-ESCALATE', .RYTAConstant~STATE_REMEDIATION_REQUIRED, .RYTAConstant~ACTION_ESCALATE, .RYTAConstant~DISPOSITION_PERMITTED, 'escalation is permitted but not automatically mandatory'))

  /* ESCALATE: conflict is safety-critical and commercial actions are prohibited. */
  self~addBasePolicy(.RYTAActionPolicy~new('ESCALATE-ANSWER', .RYTAConstant~STATE_ESCALATE, .RYTAConstant~ACTION_ANSWER_QUERY, .RYTAConstant~DISPOSITION_PERMITTED, 'safe response remains permissible'))
  self~addBasePolicy(.RYTAActionPolicy~new('ESCALATE-SELL', .RYTAConstant~STATE_ESCALATE, .RYTAConstant~ACTION_SELL_PRODUCT, .RYTAConstant~DISPOSITION_PROHIBITED, 'critical conflict unresolved'))
  self~addBasePolicy(.RYTAActionPolicy~new('ESCALATE-WARNING', .RYTAConstant~STATE_ESCALATE, .RYTAConstant~ACTION_WARNING, .RYTAConstant~DISPOSITION_REQUIRED, 'critical conflict warning'))
  self~addBasePolicy(.RYTAActionPolicy~new('ESCALATE-UPSELL', .RYTAConstant~STATE_ESCALATE, .RYTAConstant~ACTION_UPSELL, .RYTAConstant~DISPOSITION_PROHIBITED, 'critical conflict unresolved'))
  self~addBasePolicy(.RYTAActionPolicy~new('ESCALATE-BIG-UPSELL', .RYTAConstant~STATE_ESCALATE, .RYTAConstant~ACTION_BIG_UPSELL, .RYTAConstant~DISPOSITION_PROHIBITED, 'critical conflict unresolved'))
  self~addBasePolicy(.RYTAActionPolicy~new('ESCALATE-ASK', .RYTAConstant~STATE_ESCALATE, .RYTAConstant~ACTION_ASK_INFORMATION, .RYTAConstant~DISPOSITION_PERMITTED, 'information gathering may continue'))
  self~addBasePolicy(.RYTAActionPolicy~new('ESCALATE-ACTION', .RYTAConstant~STATE_ESCALATE, .RYTAConstant~ACTION_ESCALATE, .RYTAConstant~DISPOSITION_REQUIRED, 'critical facts conflict'))

  /* RULE_CONFLICT: model ambiguity itself fails closed. */
  self~addBasePolicy(.RYTAActionPolicy~new('RULE-CONFLICT-ANSWER', .RYTAConstant~STATE_RULE_CONFLICT, .RYTAConstant~ACTION_ANSWER_QUERY, .RYTAConstant~DISPOSITION_PERMITTED, 'safe response remains permissible'))
  self~addBasePolicy(.RYTAActionPolicy~new('RULE-CONFLICT-SELL', .RYTAConstant~STATE_RULE_CONFLICT, .RYTAConstant~ACTION_SELL_PRODUCT, .RYTAConstant~DISPOSITION_PROHIBITED, 'rule-model ambiguity fails closed'))
  self~addBasePolicy(.RYTAActionPolicy~new('RULE-CONFLICT-WARNING', .RYTAConstant~STATE_RULE_CONFLICT, .RYTAConstant~ACTION_WARNING, .RYTAConstant~DISPOSITION_REQUIRED, 'rule-model ambiguity warning'))
  self~addBasePolicy(.RYTAActionPolicy~new('RULE-CONFLICT-UPSELL', .RYTAConstant~STATE_RULE_CONFLICT, .RYTAConstant~ACTION_UPSELL, .RYTAConstant~DISPOSITION_PROHIBITED, 'rule-model ambiguity fails closed'))
  self~addBasePolicy(.RYTAActionPolicy~new('RULE-CONFLICT-BIG-UPSELL', .RYTAConstant~STATE_RULE_CONFLICT, .RYTAConstant~ACTION_BIG_UPSELL, .RYTAConstant~DISPOSITION_PROHIBITED, 'rule-model ambiguity fails closed'))
  self~addBasePolicy(.RYTAActionPolicy~new('RULE-CONFLICT-ASK', .RYTAConstant~STATE_RULE_CONFLICT, .RYTAConstant~ACTION_ASK_INFORMATION, .RYTAConstant~DISPOSITION_PERMITTED, 'information gathering remains permissible'))
  self~addBasePolicy(.RYTAActionPolicy~new('RULE-CONFLICT-ESCALATE', .RYTAConstant~STATE_RULE_CONFLICT, .RYTAConstant~ACTION_ESCALATE, .RYTAConstant~DISPOSITION_REQUIRED, 'rule-model ambiguity requires escalation'))

  reviewPolicy = .RYTAActionPolicy~new('NORMAL-BIG-UPSELL-REVIEW', .RYTAConstant~STATE_NORMAL, .RYTAConstant~ACTION_BIG_UPSELL, .RYTAConstant~DISPOSITION_REQUIRES_APPROVAL, 'commercial review gate', .RYTAConstant~APPROVAL_POLICY_BIG_UPSELL, .RYTAConstant~OVERRIDE_APPROVAL_GATE)
  conditionalReview = .RYTAConditionalActionPolicy~new(reviewPolicy, 'ALL')
  conditionalReview~addClause(.HardWorldClause~new('BIG_UPSELL_REVIEW_REQUIRED', 'KNOWN_TRUE'))
  self~addConditionalPolicy(conditionalReview)

  return self~basePolicies~items

::method addBasePolicy
  expose basePolicies
  use arg policy
  policyKey = self~policyKey(policy~state, policy~actionCode)
  basePolicies[policyKey] = policy
  return policy

::method removeBasePolicy
  expose basePolicies
  use arg state, actionCode
  policyKey = self~policyKey(state, actionCode)
  if \basePolicies~hasIndex(policyKey) then return .false
  basePolicies~remove(policyKey)
  return .true

::method addActionConstraint
  expose actionConstraints
  use arg constraint
  actionConstraints~append(constraint)
  return constraint

::method findConstraintViolations
  expose actionConstraints
  use arg decisionRun
  violations = .array~new
  do constraint over actionConstraints
    if constraint~violatedBy(decisionRun) then do
      violations~append(constraint)
      firstAction = decisionRun~action(constraint~actionA)
      secondAction = decisionRun~action(constraint~actionB)
      if firstAction \== .nil then firstAction~constraintBlocked = .true
      if secondAction \== .nil then secondAction~constraintBlocked = .true
    end
  end
  return violations

::method addConditionalPolicy
  expose conditionalPolicies
  use arg conditionalPolicy
  conditionalPolicies~append(conditionalPolicy)
  return conditionalPolicy

::method basePolicyFor
  expose basePolicies
  use arg state, actionCode
  policyKey = self~policyKey(state, actionCode)
  if basePolicies~hasIndex(policyKey) then return basePolicies[policyKey]
  return .nil

::method policyFor
  expose conditionalPolicies
  use arg world, state, actionCode
  selectedPolicy = self~basePolicyFor(state, actionCode)
  do conditionalPolicy over conditionalPolicies
    if conditionalPolicy~matches(world, state, actionCode) then selectedPolicy = conditionalPolicy~policy
  end
  if selectedPolicy == .nil then return .nil
  return selectedPolicy~copy

::method states
  return .array~of(.RYTAConstant~STATE_NORMAL, .RYTAConstant~STATE_NEEDS_INFORMATION, .RYTAConstant~STATE_REMEDIATION_REQUIRED, .RYTAConstant~STATE_ESCALATE, .RYTAConstant~STATE_RULE_CONFLICT)

::method actionCodes
  return .array~of(.RYTAConstant~ACTION_ANSWER_QUERY, .RYTAConstant~ACTION_SELL_PRODUCT, .RYTAConstant~ACTION_WARNING, .RYTAConstant~ACTION_UPSELL, .RYTAConstant~ACTION_BIG_UPSELL, .RYTAConstant~ACTION_ASK_INFORMATION, .RYTAConstant~ACTION_ESCALATE)

::method evaluateState
  expose rules
  use arg world
  stateEval = .RYTAStateEvaluation~new
  highestRank = 0

  do ruleObject over rules
    if ruleObject~matches(world) then do
      stateEval~matches~append(ruleObject)
      currentRank = self~tierRank(ruleObject~tier)
      if currentRank > highestRank then highestRank = currentRank
    end
  end

  if stateEval~matches~items == 0 then return stateEval

  do ruleObject over stateEval~matches
    if self~tierRank(ruleObject~tier) == highestRank then stateEval~tierMatches~append(ruleObject)
  end

  if stateEval~tierMatches~items > 0 then stateEval~highestTier = stateEval~tierMatches[1]~tier

  do candidate over stateEval~tierMatches
    isOverridden = .false
    do other over stateEval~tierMatches
      if other~ruleId \== candidate~ruleId then do
        if other~overridesRule(candidate~ruleId) then isOverridden = .true
      end
    end
    if \isOverridden then stateEval~survivingRules~append(candidate)
  end

  if stateEval~survivingRules~items == 0 then do
    stateEval~ambiguous = .true
    stateEval~state = .RYTAConstant~STATE_RULE_CONFLICT
    return stateEval
  end

  firstState = stateEval~survivingRules[1]~targetState
  incompatible = .false
  do survivor over stateEval~survivingRules
    if survivor~targetState \== firstState then incompatible = .true
  end

  if incompatible then do
    stateEval~ambiguous = .true
    stateEval~state = .RYTAConstant~STATE_RULE_CONFLICT
    return stateEval
  end

  stateEval~winnerRule = stateEval~survivingRules[1]
  stateEval~state = firstState
  return stateEval

::method applyEffects
  use arg world, decisionRun
  do action over decisionRun~actions
    policy = self~policyFor(world, decisionRun~state, action~actionCode)
    if policy == .nil then do
      action~setDisposition(.RYTAConstant~DISPOSITION_UNRESOLVED, 'no explicit state/action policy')
      decisionRun~addTrace('POLICY_HOLE state=' || decisionRun~state || ' action=' || action~actionCode)
    end
    else do
      action~setDisposition(policy~disposition, policy~rationale, policy~approvalPolicyId, policy~overridePolicy)
      decisionRun~addTrace('POLICY ' || policy~policyId || ' action=' || action~actionCode || ' disposition=' || policy~disposition)
    end
  end
  return decisionRun~state

::method applyConstraintFailureOverlay
  use arg decisionRun, violations
  decisionRun~executionStatus = .RYTAConstant~EXECUTION_CONFLICTING_REQUIREMENTS
  do constraint over violations
    decisionRun~addTrace('CONSTRAINT_VIOLATION ' || constraint~constraintId || ' ' || constraint~actionA || '<->' || constraint~actionB)
  end
  escalationAction = decisionRun~action(.RYTAConstant~ACTION_ESCALATE)
  if escalationAction \== .nil then escalationAction~setDisposition(.RYTAConstant~DISPOSITION_REQUIRED, 'conflicting simultaneous requirements require escalation')
  return decisionRun~executionStatus

::method applyRequiredUnavailableOverlay
  use arg decisionRun
  decisionRun~executionStatus = .RYTAConstant~EXECUTION_REQUIRED_ACTION_UNAVAILABLE
  escalationAction = decisionRun~action(.RYTAConstant~ACTION_ESCALATE)
  if escalationAction \== .nil then escalationAction~setDisposition(.RYTAConstant~DISPOSITION_REQUIRED, 'required action cannot be performed; escalation required')

  sellAction = decisionRun~action(.RYTAConstant~ACTION_SELL_PRODUCT)
  if sellAction \== .nil then sellAction~setDisposition(.RYTAConstant~DISPOSITION_PROHIBITED, 'required action unavailable; fail closed')
  upsellAction = decisionRun~action(.RYTAConstant~ACTION_UPSELL)
  if upsellAction \== .nil then upsellAction~setDisposition(.RYTAConstant~DISPOSITION_PROHIBITED, 'required action unavailable; fail closed')
  bigUpsellAction = decisionRun~action(.RYTAConstant~ACTION_BIG_UPSELL)
  if bigUpsellAction \== .nil then bigUpsellAction~setDisposition(.RYTAConstant~DISPOSITION_PROHIBITED, 'required action unavailable; fail closed')
  return decisionRun~executionStatus

::method tierRank private
  use arg tier
  tier = tier~upper
  select
    when tier == .RYTAConstant~TIER_SAFETY_CRITICAL then return 400
    when tier == .RYTAConstant~TIER_SAFETY_NORMAL then return 300
    when tier == .RYTAConstant~TIER_OPERATIONAL then return 200
    when tier == .RYTAConstant~TIER_COMMERCIAL then return 100
    otherwise return 0
  end

::method policyKey private
  use arg state, actionCode
  return state~upper || '|' || actionCode~upper

::requires 'HardWorld.cls'

::requires "RYTAObject.cls"
