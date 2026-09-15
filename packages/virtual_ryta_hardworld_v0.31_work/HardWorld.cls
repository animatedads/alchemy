/*
 * HardWorld core semantics for the Virtual RYTA deterministic decision testbed.
 * v0.2 semantic-freeze candidate.
 */

::class RYTAConstant public
::constant KNOWLEDGE_KNOWN       'KNOWN'
::constant KNOWLEDGE_UNKNOWN     'UNKNOWN'
::constant KNOWLEDGE_CONFLICT    'CONFLICT'

::constant STATE_NORMAL                 'NORMAL'
::constant STATE_NEEDS_INFORMATION      'NEEDS_INFORMATION'
::constant STATE_REMEDIATION_REQUIRED   'REMEDIATION_REQUIRED'
::constant STATE_ESCALATE               'ESCALATE'
::constant STATE_RULE_CONFLICT          'RULE_CONFLICT'
::constant STATE_UNRESOLVED             'UNRESOLVED'

::constant EXECUTION_READY                        'READY'
::constant EXECUTION_REQUIRED_ACTION_UNAVAILABLE  'REQUIRED_ACTION_UNAVAILABLE'
::constant EXECUTION_CONFLICTING_REQUIREMENTS       'CONFLICTING_REQUIREMENTS'

::constant DISPOSITION_UNRESOLVED         'UNRESOLVED'
::constant DISPOSITION_PERMITTED          'PERMITTED'
::constant DISPOSITION_REQUIRED           'REQUIRED'
::constant DISPOSITION_SUPPRESSED         'SUPPRESSED'
::constant DISPOSITION_PROHIBITED         'PROHIBITED'
::constant DISPOSITION_REQUIRES_APPROVAL  'REQUIRES_APPROVAL'

::constant OVERRIDE_NON_OVERRIDEABLE  'NON_OVERRIDEABLE'
::constant OVERRIDE_CONTEXTUAL        'CONTEXTUAL'
::constant OVERRIDE_APPROVAL_GATE     'APPROVAL_GATE'

::constant TIER_SAFETY_CRITICAL  'SAFETY_CRITICAL'
::constant TIER_SAFETY_NORMAL    'SAFETY_NORMAL'
::constant TIER_OPERATIONAL      'OPERATIONAL'
::constant TIER_COMMERCIAL       'COMMERCIAL'

::constant ACTION_ANSWER_QUERY       'ANSWER_QUERY'
::constant ACTION_SELL_PRODUCT       'SELL_PRODUCT'
::constant ACTION_WARNING            'WARNING'
::constant ACTION_UPSELL             'UPSELL'
::constant ACTION_BIG_UPSELL         'BIG_UPSELL'
::constant ACTION_ASK_INFORMATION    'ASK_INFORMATION'
::constant ACTION_ESCALATE           'ESCALATE'

::constant APPROVAL_APPROVE  'APPROVE'
::constant APPROVAL_DENY     'DENY'

::constant APPROVAL_POLICY_BIG_UPSELL  'BIG_UPSELL_SALES_MANAGER'

::class HardWorldLanguageSpec public

::method isAllowedCombinator
  use arg token
  token = token~upper
  return token == 'ALL' | token == 'ANY'

::method isAllowedEpistemicPredicate
  use arg token
  token = token~upper
  select
    when token == 'KNOWN_TRUE' then return .true
    when token == 'KNOWN_FALSE' then return .true
    when token == 'UNKNOWN' then return .true
    when token == 'CONFLICT' then return .true
    otherwise return .false
  end

::method isAllowedTier
  use arg token
  token = token~upper
  select
    when token == .RYTAConstant~TIER_SAFETY_CRITICAL then return .true
    when token == .RYTAConstant~TIER_SAFETY_NORMAL then return .true
    when token == .RYTAConstant~TIER_OPERATIONAL then return .true
    when token == .RYTAConstant~TIER_COMMERCIAL then return .true
    otherwise return .false
  end

::method isAllowedDisposition
  use arg token
  token = token~upper
  select
    when token == .RYTAConstant~DISPOSITION_REQUIRED then return .true
    when token == .RYTAConstant~DISPOSITION_PERMITTED then return .true
    when token == .RYTAConstant~DISPOSITION_SUPPRESSED then return .true
    when token == .RYTAConstant~DISPOSITION_PROHIBITED then return .true
    when token == .RYTAConstant~DISPOSITION_REQUIRES_APPROVAL then return .true
    otherwise return .false
  end

::method dispositionsConflict
  use arg leftDisposition, rightDisposition
  leftDisposition = leftDisposition~upper
  rightDisposition = rightDisposition~upper
  if leftDisposition == rightDisposition then return .false
  return .true

::method normativeClass
  use arg token
  token = token~upper
  select
    when token == 'MUST' | token == 'REQUIRED' | token == 'REQUIRE' then return 'HARD_OBLIGATION'
    when token == 'MUST_NOT' | token == 'MUST-NOT' | token == 'PROHIBITED' | token == 'PROHIBIT' then return 'HARD_PROHIBITION'
    when token == 'MAY' | token == 'PERMITTED' | token == 'PERMIT' then return 'PERMISSION'
    when token == 'CAN' | token == 'CANNOT' then return 'CAPABILITY_FACT_ONLY'
    when token == 'SHOULD' | token == 'SHOULD_NOT' | token == 'SHOULD-NOT' then return 'BANNED_SOFT_NORM_V1'
    when token == 'MIGHT' | token == 'COULD' then return 'BANNED_UNCERTAIN_NORM_V1'
    otherwise return 'UNKNOWN_TERM'
  end

::method isBannedStructuralToken
  use arg token
  token = token~upper
  select
    when token == 'AND' then return .true
    when token == 'OR' then return .true
    when token == 'NOT' then return .true
    when token == 'XOR' then return .true
    when token == 'IMPLIES' then return .true
    when token == 'ELSE' then return .true
    when token == 'DEFAULT' then return .true
    when token == 'UNLESS' then return .true
    when token == 'EXCEPT' then return .true
    otherwise return .false
  end

::class RYTAFact public
::attribute name
::attribute value
::attribute knowledgeState
::attribute source
::attribute authority
::attribute evidence get

::method init
  expose evidence
  use arg factName, factValue = .nil, knowledgeState = 'KNOWN', source = 'INPUT', authority = 'DECLARED', evidenceArg = .nil
  self~name = factName~upper
  self~value = factValue
  self~knowledgeState = knowledgeState~upper
  self~source = source
  self~authority = authority
  evidence = evidenceArg

::method render
  if self~knowledgeState == .RYTAConstant~KNOWLEDGE_KNOWN then do
    if self~value == .true then renderedValue = 'TRUE'
    else if self~value == .false then renderedValue = 'FALSE'
    else renderedValue = self~value
  end
  else renderedValue = self~knowledgeState
  return self~name || '=' || renderedValue || '|source=' || self~source || '|authority=' || self~authority

::class RYTAWorldState subclass RYTAObject public
::attribute facts get
::attribute snapshotOid

::method init
  expose facts
  use arg snapshotOid = 'WORLD-SNAPSHOT-UNBOUND'
  self~init:super('RYTAWorldState', 'WORLD_STATE')
  self~registerStateVariable('facts', 'INTERNAL', 'evidence/fact map; fact presence is not authority by itself')
  self~registerStateVariable('snapshotOid', 'CUSTOMER', 'caller-supplied world snapshot identity')
  self~registerMethodContract('PUTKNOWN', 'Insert a known fact into this working world state', .array~of('FACT_NAME','FACT_VALUE','SOURCE','AUTHORITY','EVIDENCE'), 'RYTAFACT', .false, 'AUTO', 'INTERNAL', 'SENSITIVE', 'MUTATE', 'USE')
  facts = .directory~new
  self~snapshotOid = snapshotOid

::method hasFact
  expose facts
  use arg factName
  return facts~hasIndex(factName~upper)

::method putKnown
  expose facts
  use arg factName, factValue, source = 'INPUT', authority = 'DECLARED', evidence = .nil
  factKey = factName~upper
  facts[factKey] = .RYTAFact~new(factKey, factValue, .RYTAConstant~KNOWLEDGE_KNOWN, source, authority, evidence)
  return facts[factKey]

::method putUnknown
  expose facts
  use arg factName, source = 'INPUT', authority = 'DECLARED', evidence = .nil
  factKey = factName~upper
  facts[factKey] = .RYTAFact~new(factKey, .nil, .RYTAConstant~KNOWLEDGE_UNKNOWN, source, authority, evidence)
  return facts[factKey]

::method putConflict
  expose facts
  use arg factName, source = 'INPUT', authority = 'DECLARED', evidence = .nil
  factKey = factName~upper
  facts[factKey] = .RYTAFact~new(factKey, .nil, .RYTAConstant~KNOWLEDGE_CONFLICT, source, authority, evidence)
  return facts[factKey]

::method fact
  expose facts
  use arg factName
  factKey = factName~upper
  if facts~hasIndex(factKey) then return facts[factKey]
  return .RYTAFact~new(factKey, .nil, .RYTAConstant~KNOWLEDGE_UNKNOWN, 'ABSENT', 'NONE')

::method isKnownTrue
  use arg factName
  factObject = self~fact(factName)
  if factObject~knowledgeState \== .RYTAConstant~KNOWLEDGE_KNOWN then return .false
  return factObject~value == .true

::method isKnownFalse
  use arg factName
  factObject = self~fact(factName)
  if factObject~knowledgeState \== .RYTAConstant~KNOWLEDGE_KNOWN then return .false
  return factObject~value == .false

::method knowledgeOf
  use arg factName
  return self~fact(factName)~knowledgeState

::method render
  expose facts
  lines = .array~new
  names = facts~allIndexes
  names~sort
  do factName over names
    lines~append(facts[factName]~render)
  end
  return lines

::class RYTADecisionContext subclass RYTAObject public
::attribute modelId
::attribute modelVersion
::attribute modelHash
::attribute worldSnapshotOid
::attribute scope
::attribute evaluatedAt

::method init
  use arg modelId, modelVersion, modelHash, worldSnapshotOid, scope = 'DEFAULT'
  self~init:super('RYTADecisionContext', 'DECISION_CONTEXT')
  self~modelId = modelId
  self~modelVersion = modelVersion
  self~modelHash = modelHash
  self~worldSnapshotOid = worldSnapshotOid
  self~scope = scope~upper
  self~evaluatedAt = .DateTime~new

::class RYTAApproval public
::attribute approvalId
::attribute authority
::attribute actionCode
::attribute modelId
::attribute modelVersion
::attribute worldSnapshotOid
::attribute scope
::attribute expiresAt
::attribute revoked
::attribute decision
::attribute source

::method init
  use arg approvalId, authority, actionCode, modelId, modelVersion, worldSnapshotOid, scope = 'DEFAULT', expiresAt = .nil, decision = 'APPROVE', source = 'TEST'
  self~approvalId = approvalId
  self~authority = authority~upper
  self~actionCode = actionCode~upper
  self~modelId = modelId
  self~modelVersion = modelVersion
  self~worldSnapshotOid = worldSnapshotOid
  self~scope = scope~upper
  self~expiresAt = expiresAt
  self~revoked = .false
  self~decision = decision~upper
  self~source = source

::method bindingStatus
  use arg requiredAuthority, actionCode, context
  if self~authority \== requiredAuthority~upper then return 'WRONG_AUTHORITY'
  if self~actionCode \== actionCode~upper then return 'WRONG_ACTION'
  if self~modelId \== context~modelId then return 'WRONG_MODEL'
  if self~modelVersion \== context~modelVersion then return 'WRONG_MODEL_VERSION'
  if self~worldSnapshotOid \== context~worldSnapshotOid then return 'WRONG_WORLD_SNAPSHOT'
  if self~scope \== context~scope then return 'WRONG_SCOPE'
  return 'BOUND'

::method bindingMatches
  use arg requiredAuthority, actionCode, context
  return self~bindingStatus(requiredAuthority, actionCode, context) == 'BOUND'

::method isExpired
  use arg evaluatedAt
  if self~expiresAt == .nil then return .false
  return evaluatedAt~compareTo(self~expiresAt) > 0

::class RYTAApprovalPolicy public
::attribute policyId
::attribute requiredAuthority
::attribute quorum

::method init
  use arg policyId, requiredAuthority, quorum = 1
  self~policyId = policyId~upper
  self~requiredAuthority = requiredAuthority~upper
  self~quorum = quorum

::class RYTAApprovalPolicySet subclass RYTAObject public
::attribute policies get

::method init
  expose policies
  self~init:super('RYTAApprovalPolicySet', 'APPROVAL_POLICY_SET')
  policies = .directory~new

::method add
  expose policies
  use arg policy
  policies[policy~policyId] = policy
  return policy

::method policy
  expose policies
  use arg policyId
  policyKey = policyId~upper
  if policies~hasIndex(policyKey) then return policies[policyKey]
  return .nil

::class RYTAApprovalCheck public
::attribute valid
::attribute reason
::attribute approveCount
::attribute denyCount
::attribute policyId
::attribute approvalIds get
::attribute rejectedReasons get

::method init
  expose approvalIds rejectedReasons
  self~valid = .false
  self~reason = 'NOT_CHECKED'
  self~approveCount = 0
  self~denyCount = 0
  self~policyId = ''
  approvalIds = .array~new
  rejectedReasons = .array~new

::class RYTAApprovalSet subclass RYTAObject public
::attribute approvals get

::method init
  expose approvals
  self~init:super('RYTAApprovalSet', 'APPROVAL_SET')
  approvals = .array~new

::method add
  expose approvals
  use arg approval
  approvals~append(approval)
  return approval

::method evaluatePolicy
  expose approvals
  use arg policy, actionCode, context
  approvalCheck = .RYTAApprovalCheck~new
  if policy == .nil then do
    approvalCheck~reason = 'UNKNOWN_POLICY'
    return approvalCheck
  end

  approvalCheck~policyId = policy~policyId
  seenApprovalIds = .directory~new
  approveCount = 0
  denyCount = 0

  do approval over approvals
    bindingStatus = approval~bindingStatus(policy~requiredAuthority, actionCode, context)
    if bindingStatus \== 'BOUND' then do
      approvalCheck~rejectedReasons~append(approval~approvalId || ':' || bindingStatus)
      iterate
    end
    if approval~revoked then do
      approvalCheck~rejectedReasons~append(approval~approvalId || ':REVOKED')
      iterate
    end
    if approval~isExpired(context~evaluatedAt) then do
      approvalCheck~rejectedReasons~append(approval~approvalId || ':EXPIRED')
      iterate
    end
    if seenApprovalIds~hasIndex(approval~approvalId) then do
      approvalCheck~rejectedReasons~append(approval~approvalId || ':DUPLICATE_ID')
      iterate
    end
    seenApprovalIds[approval~approvalId] = .true
    approvalCheck~approvalIds~append(approval~approvalId)
    if approval~decision == .RYTAConstant~APPROVAL_APPROVE then approveCount = approveCount + 1
    else if approval~decision == .RYTAConstant~APPROVAL_DENY then denyCount = denyCount + 1
    else approvalCheck~rejectedReasons~append(approval~approvalId || ':INVALID_DECISION')
  end

  approvalCheck~approveCount = approveCount
  approvalCheck~denyCount = denyCount

  if approveCount > 0 then do
    if denyCount > 0 then do
      approvalCheck~reason = 'CONFLICTING_APPROVALS'
      return approvalCheck
    end
  end

  if denyCount > 0 then do
    approvalCheck~reason = 'DENIED'
    return approvalCheck
  end

  if approveCount >= policy~quorum then do
    approvalCheck~valid = .true
    approvalCheck~reason = 'VALID'
    return approvalCheck
  end

  approvalCheck~reason = 'INSUFFICIENT_QUORUM'
  return approvalCheck

::class RYTAActionDecision public
::attribute actionCode
::attribute methodName
::attribute capabilityFact
::attribute score
::attribute provisionalSelected
::attribute disposition
::attribute approvalPolicyId
::attribute overridePolicy
::attribute finalSelected
::attribute requirementSatisfied
::attribute capabilityStatus
::attribute approvalStatus
::attribute constraintBlocked
::attribute reasons get

::method init
  expose reasons
  use arg actionCode, methodName
  self~actionCode = actionCode~upper
  self~methodName = methodName
  self~capabilityFact = 'CAN_' || actionCode~upper
  self~score = 0
  self~provisionalSelected = .false
  self~disposition = .RYTAConstant~DISPOSITION_UNRESOLVED
  self~approvalPolicyId = ''
  self~overridePolicy = .RYTAConstant~OVERRIDE_NON_OVERRIDEABLE
  self~finalSelected = .false
  self~requirementSatisfied = .true
  self~capabilityStatus = 'NOT_CHECKED'
  self~approvalStatus = 'NOT_REQUIRED'
  self~constraintBlocked = .false
  reasons = .array~new

::method adjustScore
  expose reasons
  use arg amount, reason
  self~score = self~score + amount
  reasons~append('SCORE ' || self~formatSigned(amount) || ' ' || reason)
  return self~score

::method setDisposition
  expose reasons
  use arg disposition, reason = '', approvalPolicyId = '', overridePolicy = ''
  if overridePolicy == '' then overridePolicy = .RYTAConstant~OVERRIDE_NON_OVERRIDEABLE
  self~disposition = disposition~upper
  self~approvalPolicyId = approvalPolicyId~upper
  self~overridePolicy = overridePolicy~upper
  if reason \== '' then reasons~append('POLICY ' || self~disposition || ' ' || reason)
  return self~disposition

::method determineCapability
  use arg world
  capability = world~fact(self~capabilityFact)
  if capability~knowledgeState == .RYTAConstant~KNOWLEDGE_UNKNOWN then return 'UNKNOWN'
  if capability~knowledgeState == .RYTAConstant~KNOWLEDGE_CONFLICT then return 'CONFLICT'
  if capability~value == .true then return 'CAPABLE'
  return 'UNAVAILABLE'

::method resolve
  expose reasons
  use arg world, approvalSet, approvalPolicies, context
  self~provisionalSelected = self~score > 0
  self~finalSelected = .false
  self~requirementSatisfied = .true
  self~approvalStatus = 'NOT_REQUIRED'
  self~capabilityStatus = self~determineCapability(world)

  if self~constraintBlocked then do
    self~finalSelected = .false
    if self~disposition == .RYTAConstant~DISPOSITION_REQUIRED then self~requirementSatisfied = .false
    reasons~append('CONSTRAINT action blocked by incompatible simultaneous requirement')
    return self~finalSelected
  end

  select
    when self~disposition == .RYTAConstant~DISPOSITION_REQUIRED then do
      if self~capabilityStatus == 'CAPABLE' then self~finalSelected = .true
      else do
        self~finalSelected = .false
        self~requirementSatisfied = .false
        reasons~append('CAPABILITY required action unavailable status=' || self~capabilityStatus)
      end
    end

    when self~disposition == .RYTAConstant~DISPOSITION_PROHIBITED then self~finalSelected = .false

    when self~disposition == .RYTAConstant~DISPOSITION_SUPPRESSED then self~finalSelected = .false

    when self~disposition == .RYTAConstant~DISPOSITION_PERMITTED then do
      if self~provisionalSelected then do
        if self~capabilityStatus == 'CAPABLE' then self~finalSelected = .true
        else reasons~append('CAPABILITY selected permitted action unavailable status=' || self~capabilityStatus)
      end
    end

    when self~disposition == .RYTAConstant~DISPOSITION_REQUIRES_APPROVAL then do
      self~approvalStatus = 'NOT_CHECKED'
      if self~provisionalSelected then do
        if self~capabilityStatus == 'CAPABLE' then do
          policy = approvalPolicies~policy(self~approvalPolicyId)
          approvalCheck = approvalSet~evaluatePolicy(policy, self~actionCode, context)
          self~approvalStatus = approvalCheck~reason
          if approvalCheck~valid then self~finalSelected = .true
          reasons~append('APPROVAL ' || approvalCheck~reason || ' policy=' || self~approvalPolicyId)
          do rejectedReason over approvalCheck~rejectedReasons
            reasons~append('APPROVAL_REJECTED ' || rejectedReason)
          end
        end
        else reasons~append('CAPABILITY approval-gated action unavailable status=' || self~capabilityStatus)
      end
      else self~approvalStatus = 'NOT_ELECTED'
    end

    otherwise do
      self~finalSelected = .false
      self~requirementSatisfied = .false
      reasons~append('POLICY unresolved disposition fails closed')
    end
  end
  return self~finalSelected

::method isHardProhibition
  return self~disposition == .RYTAConstant~DISPOSITION_PROHIBITED

::method isSuppressed
  return self~disposition == .RYTAConstant~DISPOSITION_SUPPRESSED

::method formatSigned private
  use arg amount
  if amount >= 0 then return '+' || amount
  return amount


::class RYTAActionConstraint public
::attribute constraintId
::attribute constraintType
::attribute actionA
::attribute actionB
::attribute rationale

::method init
  use arg constraintId, constraintType, actionA, actionB, rationale = ''
  self~constraintId = constraintId~upper
  self~constraintType = constraintType~upper
  self~actionA = actionA~upper
  self~actionB = actionB~upper
  self~rationale = rationale

::method violatedBy
  use arg decisionRun
  if self~constraintType \== 'MUTUALLY_EXCLUSIVE' then return .false
  firstAction = decisionRun~action(self~actionA)
  secondAction = decisionRun~action(self~actionB)
  if firstAction == .nil then return .false
  if secondAction == .nil then return .false
  if firstAction~disposition \== .RYTAConstant~DISPOSITION_REQUIRED then return .false
  if secondAction~disposition \== .RYTAConstant~DISPOSITION_REQUIRED then return .false
  return .true

::class HardWorldClause public
::attribute factName
::attribute operator

::method init
  use arg factName, operator
  self~factName = factName~upper
  self~operator = operator~upper

::method isValid
  language = .HardWorldLanguageSpec~new
  return language~isAllowedEpistemicPredicate(self~operator)

::method matches
  use arg world
  if \self~isValid then return .false
  factObject = world~fact(self~factName)
  select
    when self~operator == 'KNOWN_TRUE' then do
      if factObject~knowledgeState \== .RYTAConstant~KNOWLEDGE_KNOWN then return .false
      return factObject~value == .true
    end
    when self~operator == 'KNOWN_FALSE' then do
      if factObject~knowledgeState \== .RYTAConstant~KNOWLEDGE_KNOWN then return .false
      return factObject~value == .false
    end
    when self~operator == 'UNKNOWN' then return factObject~knowledgeState == .RYTAConstant~KNOWLEDGE_UNKNOWN
    when self~operator == 'CONFLICT' then return factObject~knowledgeState == .RYTAConstant~KNOWLEDGE_CONFLICT
    otherwise return .false
  end

::method render
  return self~factName || ' ' || self~operator

::class HardWorldRule public
::attribute ruleId
::attribute tier
::attribute conjunction
::attribute targetState
::attribute rationale
::attribute clauses get
::attribute overrides get

::method init
  expose clauses overrides
  use arg ruleId, tier, conjunction, targetState, rationale = ''
  self~ruleId = ruleId~upper
  self~tier = tier~upper
  self~conjunction = conjunction~upper
  self~targetState = targetState~upper
  self~rationale = rationale
  clauses = .array~new
  overrides = .array~new

::method addClause
  expose clauses
  use arg clause
  clauses~append(clause)
  return self

::method removeClauseAt
  expose clauses
  use arg position
  if position < 1 then return .false
  if position > clauses~items then return .false
  clauses~delete(position)
  return .true

::method addOverride
  expose overrides
  use arg otherRuleId
  overrides~append(otherRuleId~upper)
  return self

::method clearOverrides
  expose overrides
  overrides = .array~new
  return self

::method overridesRule
  expose overrides
  use arg otherRuleId
  otherRuleId = otherRuleId~upper
  do ruleId over overrides
    if ruleId == otherRuleId then return .true
  end
  return .false

::method matches
  expose clauses
  use arg world
  language = .HardWorldLanguageSpec~new
  if \language~isAllowedCombinator(self~conjunction) then return .false
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

::method renderDefinition
  expose clauses overrides
  lines = .array~new
  lines~append('RULE ' || self~ruleId || ' TIER ' || self~tier)
  lines~append('WHEN ' || self~conjunction || ' {')
  do clause over clauses
    lines~append('  ' || clause~render)
  end
  lines~append('}')
  lines~append('THEN { STATE ' || self~targetState || ' }')
  do overrideId over overrides
    lines~append('OVERRIDES ' || overrideId)
  end
  return lines

::class RYTAStateEvaluation subclass RYTAObject public
::attribute state
::attribute winnerRule
::attribute ambiguous
::attribute highestTier
::attribute matches get
::attribute tierMatches get
::attribute survivingRules get

::method init
  expose matches tierMatches survivingRules
  self~init:super('RYTAStateEvaluation', 'STATE_EVALUATION')
  self~state = .RYTAConstant~STATE_UNRESOLVED
  self~winnerRule = .nil
  self~ambiguous = .false
  self~highestTier = ''
  matches = .array~new
  tierMatches = .array~new
  survivingRules = .array~new

::class RYTADecisionRun subclass RYTAObject public
::attribute world
::attribute context
::attribute state
::attribute winningRule
::attribute winningTier
::attribute stateAmbiguous
::attribute executionStatus
::attribute actions get
::attribute outputs get
::attribute trace get
::attribute requiredUnavailable get

::method init
  expose actions outputs trace actionIndex requiredUnavailable
  use arg world, context
  self~init:super('RYTADecisionRun', 'DECISION_RUN')
  self~registerStateVariable('state', 'CUSTOMER', 'resolved HardWorld state')
  self~registerStateVariable('executionStatus', 'CUSTOMER', 'execution readiness/fail-closed state')
  self~registerStateVariable('winningRule', 'CUSTOMER', 'winning rule identifier')
  self~registerStateVariable('winningTier', 'CUSTOMER', 'winning authority tier')
  self~world = world
  self~context = context
  self~state = ''
  self~winningRule = ''
  self~winningTier = ''
  self~stateAmbiguous = .false
  self~executionStatus = .RYTAConstant~EXECUTION_READY
  actions = .array~new
  outputs = .array~new
  trace = .array~new
  actionIndex = .directory~new
  requiredUnavailable = .array~new

::method addAction
  expose actions actionIndex
  use arg action
  actions~append(action)
  actionIndex[action~actionCode] = action
  return action

::method action
  expose actionIndex
  use arg actionCode
  actionKey = actionCode~upper
  if actionIndex~hasIndex(actionKey) then return actionIndex[actionKey]
  return .nil

::method addTrace
  expose trace
  use arg line
  trace~append(line)
  return line

::method addOutput
  expose outputs
  use arg line
  outputs~append(line)
  return line

::method render
  expose actions outputs trace requiredUnavailable
  lines = .array~new
  lines~append('RYTA decision run')
  lines~append('model=' || self~context~modelId || '|version=' || self~context~modelVersion || '|snapshot=' || self~context~worldSnapshotOid)
  lines~append('state=' || self~state || '|rule=' || self~winningRule || '|tier=' || self~winningTier || '|ambiguous=' || self~stateAmbiguous || '|execution=' || self~executionStatus)
  lines~append('actions:')
  do action over actions
    lines~append('  ' || action~actionCode || '|score=' || action~score || '|provisional=' || action~provisionalSelected || '|disposition=' || action~disposition || '|final=' || action~finalSelected || '|capability=' || action~capabilityStatus || '|approval=' || action~approvalStatus || '|override=' || action~overridePolicy)
  end
  if requiredUnavailable~items > 0 then do
    lines~append('required_unavailable:')
    do action over requiredUnavailable
      lines~append('  ' || action~actionCode || '|capability=' || action~capabilityStatus)
    end
  end
  lines~append('outputs:')
  do line over outputs
    lines~append('  ' || line)
  end
  lines~append('trace:')
  do line over trace
    lines~append('  ' || line)
  end
  return lines

::requires "RYTAObject.cls"
