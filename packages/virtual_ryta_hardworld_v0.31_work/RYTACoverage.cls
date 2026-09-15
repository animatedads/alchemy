/* Relational-style rules-and-holes coverage for HardWorld / Virtual RYTA v0.2. */

::class RYTACoverageIssue public
::attribute code
::attribute holeClass
::attribute severity
::attribute witness
::attribute detail

::method render
  return self~code || '|' || self~holeClass || '|severity=' || self~severity || '|witness=' || self~witness || '|detail=' || self~detail

::class RYTACoverageRow public
::attribute coverageDimension
::attribute vectorId
::attribute essentialState
::attribute immediateState
::attribute custodyState
::attribute matchCount
::attribute highestTier
::attribute winnerRule
::attribute resultState
::attribute expectedState
::attribute hole
::attribute ambiguous
::attribute expectedMatch

::method render
  return self~coverageDimension || '|' || self~vectorId || '|' || self~essentialState || '|' || self~immediateState || '|' || self~custodyState || '|matches=' || self~matchCount || '|tier=' || self~highestTier || '|winner=' || self~winnerRule || '|state=' || self~resultState || '|expected=' || self~expectedState || '|hole=' || self~hole || '|ambiguous=' || self~ambiguous || '|expected_match=' || self~expectedMatch

::class RYTACoverageReport public
::attribute rows get
::attribute issues get
::attribute totalVectors
::attribute holes
::attribute ambiguousWinners
::attribute overlapVectors
::attribute expectedMismatches
::attribute dispositionHoles
::attribute invalidLanguageElements
::attribute unreachableRules get
::attribute shadowedRules get

::method init
  expose rows issues unreachableRules shadowedRules
  rows = .array~new
  issues = .array~new
  unreachableRules = .array~new
  shadowedRules = .array~new
  self~totalVectors = 0
  self~holes = 0
  self~ambiguousWinners = 0
  self~overlapVectors = 0
  self~expectedMismatches = 0
  self~dispositionHoles = 0
  self~invalidLanguageElements = 0

::method addIssue
  expose issues
  use arg code, holeClass, severity, witness, detail
  issue = .RYTACoverageIssue~new
  issue~code = code
  issue~holeClass = holeClass
  issue~severity = severity
  issue~witness = witness
  issue~detail = detail
  issues~append(issue)
  return issue

::method renderSummary
  return 'vectors=' || self~totalVectors || '|holes=' || self~holes || '|ambiguous=' || self~ambiguousWinners || '|overlaps=' || self~overlapVectors || '|expected_mismatches=' || self~expectedMismatches || '|disposition_holes=' || self~dispositionHoles || '|language_issues=' || self~invalidLanguageElements || '|unreachable=' || self~unreachableRules~items || '|shadowed=' || self~shadowedRules~items || '|issues=' || self~issues~items

::method relationLines
  expose rows
  lines = .array~new
  lines~append('coverage_dimension|vector_id|essential|immediate|custody|match_count|highest_tier|winner_rule|result_state|expected_state|hole|ambiguous|expected_match')
  do row over rows
    lines~append(row~coverageDimension || '|' || row~vectorId || '|' || row~essentialState || '|' || row~immediateState || '|' || row~custodyState || '|' || row~matchCount || '|' || row~highestTier || '|' || row~winnerRule || '|' || row~resultState || '|' || row~expectedState || '|' || row~hole || '|' || row~ambiguous || '|' || row~expectedMatch)
  end
  return lines

::class RYTACoverageAnalyzer public

::method analyzeCoreStateMatrix
  use arg stateRules
  report = .RYTACoverageReport~new
  factStates = .array~of('T', 'F', 'U', 'C')
  matchCounts = .directory~new
  winCounts = .directory~new

  do ruleObject over stateRules~rules
    matchCounts[ruleObject~ruleId] = 0
    winCounts[ruleObject~ruleId] = 0
  end

  vectorNumber = 0
  do essentialState over factStates
    do immediateState over factStates
      do custodyState over factStates
        vectorNumber = vectorNumber + 1
        world = .RYTAWorldState~new('COVERAGE-' || vectorNumber)
        populated = self~putState(world, 'ESSENTIAL_MEDICATION', essentialState)
        populated = self~putState(world, 'IMMEDIATE_ACCESS', immediateState)
        populated = self~putState(world, 'GUARANTEED_CUSTODY', custodyState)

        stateEval = stateRules~evaluateState(world)
        row = .RYTACoverageRow~new
        row~coverageDimension = 'CORE_STATE_MATRIX'
        row~vectorId = vectorNumber
        row~essentialState = essentialState
        row~immediateState = immediateState
        row~custodyState = custodyState
        row~matchCount = stateEval~matches~items
        row~highestTier = stateEval~highestTier
        row~resultState = stateEval~state
        row~expectedState = self~expectedState(essentialState, immediateState, custodyState)
        row~hole = stateEval~winnerRule == .nil & \stateEval~ambiguous
        row~ambiguous = stateEval~ambiguous
        row~expectedMatch = row~resultState == row~expectedState
        if stateEval~winnerRule == .nil then row~winnerRule = 'NONE'
        else row~winnerRule = stateEval~winnerRule~ruleId

        do matchedRule over stateEval~matches
          matchCounts[matchedRule~ruleId] = matchCounts[matchedRule~ruleId] + 1
        end
        if stateEval~winnerRule \== .nil then winCounts[stateEval~winnerRule~ruleId] = winCounts[stateEval~winnerRule~ruleId] + 1

        report~rows~append(row)
        report~totalVectors = report~totalVectors + 1
        if row~hole then do
          report~holes = report~holes + 1
          report~addIssue('C1', 'INPUT_HOLE', 'BLOCKER', self~witness(row), 'No winning state rule')
        end
        if row~ambiguous then do
          report~ambiguousWinners = report~ambiguousWinners + 1
          report~addIssue('C3', 'CONFLICTING_WINNER', 'BLOCKER', self~witness(row), 'Highest-tier surviving rules disagree on state')
        end
        if row~matchCount > 1 then report~overlapVectors = report~overlapVectors + 1
        if \row~expectedMatch then do
          report~expectedMismatches = report~expectedMismatches + 1
          report~addIssue('C7', 'TRANSITION_HOLE', 'BLOCKER', self~witness(row), 'Expected ' || row~expectedState || ' but got ' || row~resultState)
        end
      end
    end
  end

  do ruleObject over stateRules~rules
    if matchCounts[ruleObject~ruleId] == 0 then do
      report~unreachableRules~append(ruleObject~ruleId)
      report~addIssue('C5', 'UNREACHABLE_RULE', 'ERROR', ruleObject~ruleId, 'Rule never matches core finite domain')
    end
    else if winCounts[ruleObject~ruleId] == 0 then do
      report~shadowedRules~append(ruleObject~ruleId)
      report~addIssue('C4', 'SHADOWED_RULE', 'ERROR', ruleObject~ruleId, 'Rule matches but never wins core finite domain')
    end
  end

  self~inspectRuleLanguage(stateRules, report)
  self~inspectPolicyMatrix(stateRules, report)
  self~inspectConditionalPolicies(stateRules, report)
  self~inspectActionConstraints(stateRules, report)
  return report

::method inspectRuleLanguage
  use arg stateRules, report
  language = .HardWorldLanguageSpec~new
  ruleIds = .directory~new

  do ruleObject over stateRules~rules
    if ruleIds~hasIndex(ruleObject~ruleId) then do
      report~invalidLanguageElements = report~invalidLanguageElements + 1
      report~addIssue('C3', 'CONFLICTING_WINNER', 'BLOCKER', ruleObject~ruleId, 'Duplicate rule id')
    end
    ruleIds[ruleObject~ruleId] = .true

    if \language~isAllowedTier(ruleObject~tier) then do
      report~invalidLanguageElements = report~invalidLanguageElements + 1
      report~addIssue('C10', 'OVERRIDE_POLICY_HOLE', 'BLOCKER', ruleObject~ruleId, 'Invalid tier ' || ruleObject~tier)
    end
    if \language~isAllowedCombinator(ruleObject~conjunction) then do
      report~invalidLanguageElements = report~invalidLanguageElements + 1
      report~addIssue('C12', 'DEFAULT_FALLTHROUGH', 'BLOCKER', ruleObject~ruleId, 'Invalid combinator ' || ruleObject~conjunction || '; only ALL/ANY are permitted')
    end
    do clause over ruleObject~clauses
      if \clause~isValid then do
        report~invalidLanguageElements = report~invalidLanguageElements + 1
        report~addIssue('C11', 'EPISTEMIC_COLLAPSE', 'BLOCKER', ruleObject~ruleId, 'Invalid epistemic predicate ' || clause~operator)
      end
    end
  end

  do ruleObject over stateRules~rules
    do overrideId over ruleObject~overrides
      targetRule = stateRules~rule(overrideId)
      if targetRule == .nil then do
        report~invalidLanguageElements = report~invalidLanguageElements + 1
        report~addIssue('C10', 'OVERRIDE_POLICY_HOLE', 'BLOCKER', ruleObject~ruleId, 'OVERRIDES references missing rule ' || overrideId)
      end
      else do
        if ruleObject~tier \== targetRule~tier then do
          report~invalidLanguageElements = report~invalidLanguageElements + 1
          report~addIssue('C10', 'OVERRIDE_POLICY_HOLE', 'BLOCKER', ruleObject~ruleId, 'OVERRIDES is same-tier only in v0.2; target=' || overrideId || ' target_tier=' || targetRule~tier)
        end
      end
    end
  end
  return report

::method inspectPolicyMatrix
  use arg stateRules, report
  language = .HardWorldLanguageSpec~new
  do state over stateRules~states
    do actionCode over stateRules~actionCodes
      policy = stateRules~basePolicyFor(state, actionCode)
      if policy == .nil then do
        report~dispositionHoles = report~dispositionHoles + 1
        report~addIssue('C6', 'ACTION_DISPOSITION_HOLE', 'BLOCKER', state || '|' || actionCode, 'No explicit base policy row')
        iterate
      end

      if \language~isAllowedDisposition(policy~disposition) then do
        report~invalidLanguageElements = report~invalidLanguageElements + 1
        report~addIssue('C6', 'ACTION_DISPOSITION_HOLE', 'BLOCKER', state || '|' || actionCode, 'Invalid disposition ' || policy~disposition)
      end

      if policy~disposition == .RYTAConstant~DISPOSITION_SUPPRESSED then do
        if policy~overridePolicy \== .RYTAConstant~OVERRIDE_CONTEXTUAL then do
          report~addIssue('C10', 'OVERRIDE_POLICY_HOLE', 'ERROR', state || '|' || actionCode, 'SUPPRESSED must be explicitly CONTEXTUAL in v0.2')
        end
      end

      if policy~disposition == .RYTAConstant~DISPOSITION_PROHIBITED then do
        if policy~overridePolicy \== .RYTAConstant~OVERRIDE_NON_OVERRIDEABLE then do
          report~addIssue('C10', 'OVERRIDE_POLICY_HOLE', 'BLOCKER', state || '|' || actionCode, 'PROHIBITED is NON_OVERRIDEABLE by default in v0.2')
        end
      end

      if policy~disposition == .RYTAConstant~DISPOSITION_REQUIRES_APPROVAL then do
        if policy~approvalPolicyId == '' then report~addIssue('C9', 'APPROVAL_POLICY_HOLE', 'BLOCKER', state || '|' || actionCode, 'Approval-gated effect has no policy id')
      end
    end
  end
  return report

::method inspectConditionalPolicies
  use arg stateRules, report
  language = .HardWorldLanguageSpec~new
  do conditionalPolicy over stateRules~conditionalPolicies
    policy = conditionalPolicy~policy
    if stateRules~basePolicyFor(policy~state, policy~actionCode) == .nil then do
      report~addIssue('C6', 'ACTION_DISPOSITION_HOLE', 'BLOCKER', policy~state || '|' || policy~actionCode, 'Conditional policy has no explicit base policy row')
    end
    if \language~isAllowedCombinator(conditionalPolicy~conjunction) then do
      report~invalidLanguageElements = report~invalidLanguageElements + 1
      report~addIssue('C12', 'DEFAULT_FALLTHROUGH', 'BLOCKER', policy~policyId, 'Conditional policy uses invalid combinator ' || conditionalPolicy~conjunction)
    end
    do clause over conditionalPolicy~clauses
      if \clause~isValid then do
        report~invalidLanguageElements = report~invalidLanguageElements + 1
        report~addIssue('C11', 'EPISTEMIC_COLLAPSE', 'BLOCKER', policy~policyId, 'Conditional policy uses invalid predicate ' || clause~operator)
      end
    end
    if \language~isAllowedDisposition(policy~disposition) then do
      report~invalidLanguageElements = report~invalidLanguageElements + 1
      report~addIssue('C6', 'ACTION_DISPOSITION_HOLE', 'BLOCKER', policy~policyId, 'Conditional policy has invalid disposition ' || policy~disposition)
    end
    if policy~disposition == .RYTAConstant~DISPOSITION_REQUIRES_APPROVAL then do
      if policy~approvalPolicyId == '' then report~addIssue('C9', 'APPROVAL_POLICY_HOLE', 'BLOCKER', policy~policyId, 'Approval-gated conditional effect has no policy id')
    end
    if policy~disposition == .RYTAConstant~DISPOSITION_PROHIBITED then do
      if policy~overridePolicy \== .RYTAConstant~OVERRIDE_NON_OVERRIDEABLE then report~addIssue('C10', 'OVERRIDE_POLICY_HOLE', 'BLOCKER', policy~policyId, 'Conditional PROHIBITED must be NON_OVERRIDEABLE')
    end
    if policy~disposition == .RYTAConstant~DISPOSITION_SUPPRESSED then do
      if policy~overridePolicy \== .RYTAConstant~OVERRIDE_CONTEXTUAL then report~addIssue('C10', 'OVERRIDE_POLICY_HOLE', 'ERROR', policy~policyId, 'Conditional SUPPRESSED must be CONTEXTUAL')
    end
  end
  return report

::method inspectActionConstraints
  use arg stateRules, report
  do constraint over stateRules~actionConstraints
    if constraint~constraintType \== 'MUTUALLY_EXCLUSIVE' then do
      report~addIssue('C8', 'ILLEGAL_EFFECT_COMBINATION', 'BLOCKER', constraint~constraintId, 'Unknown action constraint type ' || constraint~constraintType)
      iterate
    end
    do state over stateRules~states
      firstPolicy = stateRules~basePolicyFor(state, constraint~actionA)
      secondPolicy = stateRules~basePolicyFor(state, constraint~actionB)
      if firstPolicy \== .nil then do
        if secondPolicy \== .nil then do
          if firstPolicy~disposition == .RYTAConstant~DISPOSITION_REQUIRED then do
            if secondPolicy~disposition == .RYTAConstant~DISPOSITION_REQUIRED then report~addIssue('C8', 'ILLEGAL_EFFECT_COMBINATION', 'BLOCKER', state || '|' || constraint~constraintId, 'Mutually exclusive actions are both REQUIRED in base policy')
          end
        end
      end
    end
  end
  return report

::method expectedState
  use arg essentialState, immediateState, custodyState
  if essentialState == 'C' | immediateState == 'C' | custodyState == 'C' then return .RYTAConstant~STATE_ESCALATE
  if essentialState == 'U' | immediateState == 'U' | custodyState == 'U' then return .RYTAConstant~STATE_NEEDS_INFORMATION
  if essentialState == 'F' | immediateState == 'F' then return .RYTAConstant~STATE_NORMAL
  if custodyState == 'F' then return .RYTAConstant~STATE_REMEDIATION_REQUIRED
  return .RYTAConstant~STATE_NORMAL

::method putState private
  use arg world, factName, stateCode
  select
    when stateCode == 'T' then factObject = world~putKnown(factName, .true)
    when stateCode == 'F' then factObject = world~putKnown(factName, .false)
    when stateCode == 'U' then factObject = world~putUnknown(factName)
    when stateCode == 'C' then factObject = world~putConflict(factName)
    otherwise return .false
  end
  return factObject \== .nil

::method witness private
  use arg row
  return 'E=' || row~essentialState || ',I=' || row~immediateState || ',C=' || row~custodyState

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

::requires 'VirtualRYTA.cls'
