say 'RYTA MUTATION GUARDS START'
killed = 0

/* M1 TRUE <-> FALSE in a safety clause. */
rules = .RYTAStateRules~new
rules~rule('RYTA-CUSTODY-UNSAFE')~clauses[3]~operator = 'KNOWN_TRUE'
report = .RYTACoverageAnalyzer~new~analyzeCoreStateMatrix(rules)
call killIf 'M1 TRUE/FALSE swap', report~expectedMismatches > 0

/* M2 UNKNOWN -> FALSE collapse. */
rules = .RYTAStateRules~new
rules~rule('RYTA-CRITICAL-UNKNOWN')~clauses[3]~operator = 'KNOWN_FALSE'
report = .RYTACoverageAnalyzer~new~analyzeCoreStateMatrix(rules)
call killIf 'M2 UNKNOWN->FALSE', report~expectedMismatches > 0 | report~ambiguousWinners > 0

/* M3 CONFLICT -> UNKNOWN collapse. */
rules = .RYTAStateRules~new
rules~rule('RYTA-CRITICAL-CONFLICT')~clauses[3]~operator = 'UNKNOWN'
report = .RYTACoverageAnalyzer~new~analyzeCoreStateMatrix(rules)
call killIf 'M3 CONFLICT->UNKNOWN', report~expectedMismatches > 0

/* M4 ALL -> ANY. */
rules = .RYTAStateRules~new
rules~rule('RYTA-CUSTODY-UNSAFE')~conjunction = 'ANY'
report = .RYTACoverageAnalyzer~new~analyzeCoreStateMatrix(rules)
call killIf 'M4 ALL->ANY', report~expectedMismatches > 0

/* M5 REQUIRED -> PERMITTED. */
ryta = .VirtualRYTA~new
ryta~stateRules~basePolicyFor(.RYTAConstant~STATE_REMEDIATION_REQUIRED, .RYTAConstant~ACTION_WARNING)~disposition = .RYTAConstant~DISPOSITION_PERMITTED
run = ryta~evaluate(makeSafetyWorld('M5'))
call killIf 'M5 REQUIRED->PERMITTED', run~action(.RYTAConstant~ACTION_WARNING)~finalSelected == .false

/* M6 PROHIBITED -> PERMITTED. */
ryta = .VirtualRYTA~new
ryta~stateRules~basePolicyFor(.RYTAConstant~STATE_REMEDIATION_REQUIRED, .RYTAConstant~ACTION_BIG_UPSELL)~disposition = .RYTAConstant~DISPOSITION_PERMITTED
ryta~addScorePlugin(.RYTATestExtremeScoringPlugin~new(.RYTAConstant~ACTION_BIG_UPSELL, 1000000))
run = ryta~evaluate(makeSafetyWorld('M6'))
call killIf 'M6 PROHIBITED->PERMITTED', run~action(.RYTAConstant~ACTION_BIG_UPSELL)~finalSelected == .true

/* M7 remove safety clause. */
rules = .RYTAStateRules~new
removed = rules~rule('RYTA-CUSTODY-UNSAFE')~removeClauseAt(3)
report = .RYTACoverageAnalyzer~new~analyzeCoreStateMatrix(rules)
call killIf 'M7 remove clause', report~expectedMismatches > 0

/* M8 remove rule. */
rules = .RYTAStateRules~new
removed = rules~removeRule('RYTA-CUSTODY-UNSAFE')
report = .RYTACoverageAnalyzer~new~analyzeCoreStateMatrix(rules)
call killIf 'M8 remove rule', report~holes > 0 | report~expectedMismatches > 0

/* M9 remove explicit winning precedence. */
rules = .RYTAStateRules~new
rules~rule('RYTA-CRITICAL-CONFLICT')~clearOverrides
report = .RYTACoverageAnalyzer~new~analyzeCoreStateMatrix(rules)
call killIf 'M9 remove OVERRIDES edge', report~ambiguousWinners > 0

/* M10 remove approval requirement. */
ryta = .VirtualRYTA~new
ryta~stateRules~conditionalPolicies[1]~policy~disposition = .RYTAConstant~DISPOSITION_PERMITTED
run = ryta~evaluate(makeApprovalWorld('M10'), 'JOURNEY-42')
call killIf 'M10 remove approval requirement', run~action(.RYTAConstant~ACTION_BIG_UPSELL)~finalSelected == .true

/* M11 widen approval scope. Exact scope binding must reject wildcard/cross-context approval. */
ryta = .VirtualRYTA~new
approval = .RYTAApproval~new('M11-A', 'SALES_MANAGER', .RYTAConstant~ACTION_BIG_UPSELL, ryta~stateRules~modelId, ryta~stateRules~modelVersion, 'M11', '*')
ryta~approvals~add(approval)
run = ryta~evaluate(makeApprovalWorld('M11'), 'JOURNEY-42')
call killIf 'M11 widen approval scope', run~action(.RYTAConstant~ACTION_BIG_UPSELL)~finalSelected == .false

/* M12 make a non-overrideable prohibition effectively overrideable. */
ryta = .VirtualRYTA~new
ryta~approvals~add(.RYTAApproval~new('M12-A', 'SALES_MANAGER', .RYTAConstant~ACTION_BIG_UPSELL, ryta~stateRules~modelId, ryta~stateRules~modelVersion, 'M12', 'DEFAULT'))
run = ryta~evaluate(makeSafetyWorld('M12'))
call killIf 'M12 approval cannot override prohibition', run~action(.RYTAConstant~ACTION_BIG_UPSELL)~finalSelected == .false

/* M13 change safety state target. */
rules = .RYTAStateRules~new
rules~rule('RYTA-CUSTODY-UNSAFE')~targetState = .RYTAConstant~STATE_NORMAL
report = .RYTACoverageAnalyzer~new~analyzeCoreStateMatrix(rules)
call killIf 'M13 change state target', report~expectedMismatches > 0

/* M14 leak score into hard eligibility. */
ryta = .VirtualRYTA~new
ryta~addScorePlugin(.RYTATestExtremeScoringPlugin~new(.RYTAConstant~ACTION_BIG_UPSELL, 1000000))
ryta~addScorePlugin(.RYTATestExtremeScoringPlugin~new(.RYTAConstant~ACTION_WARNING, -1000000))
run = ryta~evaluate(makeSafetyWorld('M14'))
scoreInvariant = run~action(.RYTAConstant~ACTION_BIG_UPSELL)~finalSelected == .false
if scoreInvariant then scoreInvariant = run~action(.RYTAConstant~ACTION_WARNING)~finalSelected == .true
call killIf 'M14 score leak', scoreInvariant

/* M15 accept stale model/world approval. */
ryta = .VirtualRYTA~new
stale = .RYTAApproval~new('M15-A', 'SALES_MANAGER', .RYTAConstant~ACTION_BIG_UPSELL, ryta~stateRules~modelId, '0.1', 'OLD-WORLD', 'JOURNEY-42')
ryta~approvals~add(stale)
run = ryta~evaluate(makeApprovalWorld('M15'), 'JOURNEY-42')
call killIf 'M15 stale approval', run~action(.RYTAConstant~ACTION_BIG_UPSELL)~finalSelected == .false

/* M16 treat capability failure as satisfying REQUIRED. */
world = makeSafetyWorld('M16')
world~putKnown('CAN_WARNING', .false)
run = .VirtualRYTA~new~evaluate(world)
capabilityInvariant = run~action(.RYTAConstant~ACTION_WARNING)~requirementSatisfied == .false
if capabilityInvariant then capabilityInvariant = run~executionStatus == .RYTAConstant~EXECUTION_REQUIRED_ACTION_UNAVAILABLE
call killIf 'M16 required capability failure', capabilityInvariant

call assertEqual 'mutation guards killed', 16, killed
say '  killed:' killed
say '  survivors: 0'
say 'RYTA MUTATION GUARDS: OK'
exit 0

killIf: procedure expose killed
  use arg label, condition
  if condition then do
    killed = killed + 1
    return .true
  end
  say 'MUTATION SURVIVED:' label
  exit 1

makeSafetyWorld: procedure
  use arg snapshotOid
  world = .RYTAWorldState~new(snapshotOid)
  world~putKnown('HAS_QUERY', .true)
  world~putKnown('PRODUCT_RELEVANT', .true)
  world~putKnown('CUSTOMER_ELIGIBLE', .true)
  world~putKnown('UPSELL_OPPORTUNITY', .true)
  world~putKnown('PRODUCT_VALUE_HIGH', .true)
  world~putKnown('ESSENTIAL_MEDICATION', .true)
  world~putKnown('IMMEDIATE_ACCESS', .true)
  world~putKnown('GUARANTEED_CUSTODY', .false)
  return world

makeApprovalWorld: procedure
  use arg snapshotOid
  world = .RYTAWorldState~new(snapshotOid)
  world~putKnown('PRODUCT_VALUE_HIGH', .true)
  world~putKnown('ESSENTIAL_MEDICATION', .false)
  world~putKnown('IMMEDIATE_ACCESS', .false)
  world~putKnown('GUARANTEED_CUSTODY', .true)
  world~putKnown('BIG_UPSELL_REVIEW_REQUIRED', .true)
  return world

assertEqual: procedure
  use arg label, expected, actual
  if expected == actual then return .true
  say 'ASSERT FAILED:' label
  say '  expected:' expected
  say '  actual:  ' actual
  exit 1

::requires '../RYTACoverage.cls'
::requires '../plugins/RYTATestExtremeScoring.cls'
