/* Virtual RYTA actor and deterministic orchestration flow. */

::class VirtualRYTA subclass RYTAObject public
::attribute factPlugins get
::attribute scorePlugins get
::attribute stateRules
::attribute approvalPolicies get

::method init
  expose factPlugins scorePlugins approvals approvalPolicies
  use arg alchemyOptions = .nil
  self~init:super('VirtualRYTA', 'DECISION_ORCHESTRATOR', alchemyOptions)
  self~registerStateVariable('factPlugins', 'INTERNAL', 'registered fact-producing plugins')
  self~registerStateVariable('scorePlugins', 'INTERNAL', 'registered scoring plugins; score is not authority')
  self~registerStateVariable('stateRules', 'INTERNAL', 'HardWorld rule/policy model')
  self~registerStateVariable('approvalPolicies', 'INTERNAL', 'approval policy set')
  self~registerMethodContract('EVALUATE', 'Evaluate evidence and rules into a deterministic RYTA decision run', .array~of('WORLD', 'CONTEXT'), 'RYTADECISIONRUN', .false, 'AUTO', 'CUSTOMER', 'SENSITIVE', 'MUTATE', 'USE')
  self~registerMethodContract('ADDFACTPLUGIN', 'Register an evidence-producing fact plugin', .array~of('PLUGIN'), 'ANY', .false, 'AUTO', 'INTERNAL', 'SENSITIVE', 'MUTATE', 'NONE')
  self~registerMethodContract('ADDSCOREPLUGIN', 'Register a scoring plugin; score remains non-authoritative', .array~of('PLUGIN'), 'ANY', .false, 'AUTO', 'INTERNAL', 'SENSITIVE', 'MUTATE', 'NONE')
  factPlugins = .array~new
  scorePlugins = .array~new
  approvals = .RYTAApprovalSet~new
  approvalPolicies = .RYTAApprovalPolicySet~new
  self~stateRules = .RYTAStateRules~new
  ignoredAlchemyRelationship = self~recordRelationship('USES', self~stateRules, 'HardWorld state-rule model', 'INTERNAL')
  approvalPolicies~add(.RYTAApprovalPolicy~new(.RYTAConstant~APPROVAL_POLICY_BIG_UPSELL, 'SALES_MANAGER', 1))
  self~addScorePlugin(.RYTABasicScoringPlugin~new)

::method addFactPlugin
  expose factPlugins
  use arg plugin
  factPlugins~append(plugin)
  return plugin

::method addScorePlugin
  expose scorePlugins
  use arg plugin
  scorePlugins~append(plugin)
  return plugin

::method approvals
  expose approvals
  return approvals

::method evaluate
  expose factPlugins scorePlugins approvals approvalPolicies
  use arg world, approvalScope = 'DEFAULT'

  context = .RYTADecisionContext~new(self~stateRules~modelId, self~stateRules~modelVersion, self~stateRules~modelHash, world~snapshotOid, approvalScope)
  decisionRun = .RYTADecisionRun~new(world, context)
  decisionRun~addTrace('MODEL id=' || context~modelId || ' version=' || context~modelVersion || ' snapshot=' || context~worldSnapshotOid)

  installedActions = self~installActions(decisionRun)
  defaultCapabilityCount = self~installTestbedCapabilities(world, decisionRun)
  decisionRun~addTrace('CAPABILITY_DEFAULTS installed=' || defaultCapabilityCount)

  do plugin over factPlugins
    factCount = plugin~contributeFacts(world)
    decisionRun~addTrace('FACT_PLUGIN ' || plugin~pluginId || ' contributed=' || factCount)
  end

  do action over decisionRun~actions
    do plugin over scorePlugins
      scoreAdjustment = plugin~score(world, action~actionCode)
      if scoreAdjustment \= 0 then action~adjustScore(scoreAdjustment, plugin~pluginId)
    end
    action~provisionalSelected = action~score > 0
    decisionRun~addTrace('PROVISIONAL ' || action~actionCode || ' score=' || action~score || ' selected=' || action~provisionalSelected)
  end

  stateEval = self~stateRules~evaluateState(world)
  decisionRun~state = stateEval~state
  decisionRun~stateAmbiguous = stateEval~ambiguous
  decisionRun~winningTier = stateEval~highestTier
  if stateEval~winnerRule == .nil then decisionRun~winningRule = 'NONE'
  else decisionRun~winningRule = stateEval~winnerRule~ruleId

  do ruleObject over stateEval~matches
    decisionRun~addTrace('RULE_MATCH ' || ruleObject~ruleId || ' tier=' || ruleObject~tier || ' state=' || ruleObject~targetState)
  end
  do survivor over stateEval~survivingRules
    decisionRun~addTrace('RULE_SURVIVOR ' || survivor~ruleId || ' tier=' || survivor~tier)
  end
  decisionRun~addTrace('STATE ' || decisionRun~state || ' winner=' || decisionRun~winningRule || ' tier=' || decisionRun~winningTier || ' ambiguous=' || decisionRun~stateAmbiguous)

  self~stateRules~applyEffects(world, decisionRun)

  constraintViolations = self~stateRules~findConstraintViolations(decisionRun)
  if constraintViolations~items > 0 then do
    self~stateRules~applyConstraintFailureOverlay(decisionRun, constraintViolations)
    decisionRun~addTrace('EXECUTION_STATUS ' || decisionRun~executionStatus)
  end

  unavailableCount = self~scanRequiredUnavailable(world, decisionRun)
  if unavailableCount > 0 then do
    if decisionRun~executionStatus == .RYTAConstant~EXECUTION_READY then self~stateRules~applyRequiredUnavailableOverlay(decisionRun)
    additionalUnavailable = self~scanRequiredUnavailable(world, decisionRun)
    decisionRun~addTrace('EXECUTION_STATUS ' || decisionRun~executionStatus)
  end

  do action over decisionRun~actions
    selected = action~resolve(world, approvals, approvalPolicies, context)
    decisionRun~addTrace('FINAL ' || action~actionCode || ' disposition=' || action~disposition || ' selected=' || selected || ' capability=' || action~capabilityStatus || ' approval=' || action~approvalStatus)
    if selected then do
      outputLine = self~sendWith(action~methodName, .array~new)
      decisionRun~addOutput(outputLine)
    end
  end

  return decisionRun


::method scanRequiredUnavailable private
  use arg world, decisionRun
  added = 0
  do action over decisionRun~actions
    if action~disposition == .RYTAConstant~DISPOSITION_REQUIRED then do
      capabilityStatus = action~determineCapability(world)
      if capabilityStatus \== 'CAPABLE' then do
        if \self~requiredUnavailableContains(decisionRun, action~actionCode) then do
          action~capabilityStatus = capabilityStatus
          decisionRun~requiredUnavailable~append(action)
          decisionRun~addTrace('REQUIRED_UNAVAILABLE ' || action~actionCode || ' capability=' || capabilityStatus)
          added = added + 1
        end
      end
    end
  end
  return added

::method requiredUnavailableContains private
  use arg decisionRun, actionCode
  do existingAction over decisionRun~requiredUnavailable
    if existingAction~actionCode == actionCode then return .true
  end
  return .false

::method installActions private
  use arg decisionRun
  decisionRun~addAction(.RYTAActionDecision~new(.RYTAConstant~ACTION_ANSWER_QUERY, 'answerQuery'))
  decisionRun~addAction(.RYTAActionDecision~new(.RYTAConstant~ACTION_SELL_PRODUCT, 'sellProduct'))
  decisionRun~addAction(.RYTAActionDecision~new(.RYTAConstant~ACTION_WARNING, 'doWarning'))
  decisionRun~addAction(.RYTAActionDecision~new(.RYTAConstant~ACTION_UPSELL, 'upsellHere'))
  decisionRun~addAction(.RYTAActionDecision~new(.RYTAConstant~ACTION_BIG_UPSELL, 'bigUpsellHere'))
  decisionRun~addAction(.RYTAActionDecision~new(.RYTAConstant~ACTION_ASK_INFORMATION, 'askForInformation'))
  decisionRun~addAction(.RYTAActionDecision~new(.RYTAConstant~ACTION_ESCALATE, 'escalate'))
  return decisionRun~actions~items

::method installTestbedCapabilities private
  use arg world, decisionRun
  added = 0
  do action over decisionRun~actions
    if \world~hasFact(action~capabilityFact) then do
      capabilityFact = world~putKnown(action~capabilityFact, .true, 'VIRTUAL_RYTA_TESTBED_DEFAULT', 'TESTBED_CAPABILITY')
      added = added + 1
    end
  end
  return added

::method answerQuery
  return 'blah blah blah answer query'

::method sellProduct
  return 'sell product'

::method doWarning
  return 'do warning'

::method upsellHere
  return 'upsell here'

::method bigUpsellHere
  return 'big upsell here'

::method askForInformation
  return 'ask for information'

::method escalate
  return 'escalate'

::requires 'HardWorld.cls'
::requires 'RYTAStateRules.cls'
::requires 'plugins/RYTABasicScoring.cls'

::requires "RYTAObject.cls"
