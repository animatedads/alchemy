say 'RYTA ADVERSARIAL CORPUS START'
passed = 0
language = .HardWorldLanguageSpec~new

call passCase '01 implicit AND rejected', language~isAllowedCombinator('AND') == .false
call passCase '02 NOT UNKNOWN rejected', language~isAllowedEpistemicPredicate('NOT') == .false
call passCase '03 NOT structurally banned', language~isBannedStructuralToken('NOT') == .true
call passCase '04 SHOULD banned from executable v1', language~normativeClass('SHOULD') == 'BANNED_SOFT_NORM_V1'
call passCase '05 CAN is capability not permission', language~normativeClass('CAN') == 'CAPABILITY_FACT_ONLY'
caseSix = language~normativeClass('CANNOT') == 'CAPABILITY_FACT_ONLY'
if caseSix then caseSix = language~normativeClass('MUST_NOT') == 'HARD_PROHIBITION'
call passCase '06 CANNOT differs from MUST NOT', caseSix
call passCase '07 MIGHT banned', language~normativeClass('MIGHT') == 'BANNED_UNCERTAIN_NORM_V1'

/* 08 mutually exclusive REQUIRED effects. */
ryta = .VirtualRYTA~new
ryta~stateRules~basePolicyFor(.RYTAConstant~STATE_NORMAL, .RYTAConstant~ACTION_WARNING)~disposition = .RYTAConstant~DISPOSITION_REQUIRED
ryta~stateRules~basePolicyFor(.RYTAConstant~STATE_NORMAL, .RYTAConstant~ACTION_UPSELL)~disposition = .RYTAConstant~DISPOSITION_REQUIRED
ryta~stateRules~addActionConstraint(.RYTAActionConstraint~new('ADV-08', 'MUTUALLY_EXCLUSIVE', .RYTAConstant~ACTION_WARNING, .RYTAConstant~ACTION_UPSELL))
run = ryta~evaluate(makeNormalWorld('ADV-08'))
call passCase '08 mutually exclusive required actions detected', run~executionStatus == .RYTAConstant~EXECUTION_CONFLICTING_REQUIREMENTS

call passCase '09 REQUIRED + PROHIBITED is semantic conflict', language~dispositionsConflict(.RYTAConstant~DISPOSITION_REQUIRED, .RYTAConstant~DISPOSITION_PROHIBITED)

/* 10 required action impossible. */
world = makeSafetyWorld('ADV-10')
world~putKnown('CAN_WARNING', .false)
run = .VirtualRYTA~new~evaluate(world)
caseTen = run~action(.RYTAConstant~ACTION_WARNING)~requirementSatisfied == .false
if caseTen then caseTen = run~executionStatus == .RYTAConstant~EXECUTION_REQUIRED_ACTION_UNAVAILABLE
call passCase '10 required action impossible escalates', caseTen

/* 11-15 approval binding and conflict. */
ryta = .VirtualRYTA~new
ryta~approvals~add(makeApproval('ADV-11-A', ryta, 'ADV-11', 'WRONG'))
run = ryta~evaluate(makeApprovalWorld('ADV-11'), 'RIGHT')
call passCase '11 wrong approval scope rejected', run~action(.RYTAConstant~ACTION_BIG_UPSELL)~finalSelected == .false

ryta = .VirtualRYTA~new
wrongVersion = .RYTAApproval~new('ADV-12-A', 'SALES_MANAGER', .RYTAConstant~ACTION_BIG_UPSELL, ryta~stateRules~modelId, '0.1', 'ADV-12', 'RIGHT')
ryta~approvals~add(wrongVersion)
run = ryta~evaluate(makeApprovalWorld('ADV-12'), 'RIGHT')
call passCase '12 previous model approval rejected', run~action(.RYTAConstant~ACTION_BIG_UPSELL)~finalSelected == .false

ryta = .VirtualRYTA~new
ryta~approvals~add(makeApproval('ADV-13-A', ryta, 'OTHER-WORLD', 'RIGHT'))
run = ryta~evaluate(makeApprovalWorld('ADV-13'), 'RIGHT')
call passCase '13 different world approval rejected', run~action(.RYTAConstant~ACTION_BIG_UPSELL)~finalSelected == .false

ryta = .VirtualRYTA~new
past = .DateTime~new - .TimeSpan~new(0, 0, 0, 10, 0)
expired = .RYTAApproval~new('ADV-14-A', 'SALES_MANAGER', .RYTAConstant~ACTION_BIG_UPSELL, ryta~stateRules~modelId, ryta~stateRules~modelVersion, 'ADV-14', 'RIGHT', past)
ryta~approvals~add(expired)
run = ryta~evaluate(makeApprovalWorld('ADV-14'), 'RIGHT')
call passCase '14 expired approval rejected', run~action(.RYTAConstant~ACTION_BIG_UPSELL)~finalSelected == .false

ryta = .VirtualRYTA~new
ryta~approvals~add(makeApproval('ADV-15-YES', ryta, 'ADV-15', 'RIGHT'))
deny = .RYTAApproval~new('ADV-15-NO', 'SALES_MANAGER', .RYTAConstant~ACTION_BIG_UPSELL, ryta~stateRules~modelId, ryta~stateRules~modelVersion, 'ADV-15', 'RIGHT', .nil, 'DENY')
ryta~approvals~add(deny)
run = ryta~evaluate(makeApprovalWorld('ADV-15'), 'RIGHT')
call passCase '15 conflicting approvals rejected', run~action(.RYTAConstant~ACTION_BIG_UPSELL)~approvalStatus == 'CONFLICTING_APPROVALS'

/* 16 undeclared same-tier conflict. */
rules = .RYTAStateRules~new
rules~rule('RYTA-CRITICAL-CONFLICT')~clearOverrides
world = .RYTAWorldState~new('ADV-16')
world~putConflict('ESSENTIAL_MEDICATION')
world~putUnknown('IMMEDIATE_ACCESS')
world~putKnown('GUARANTEED_CUSTODY', .true)
stateEval = rules~evaluateState(world)
call passCase '16 same-tier different-state overlap fails closed', stateEval~ambiguous & stateEval~state == .RYTAConstant~STATE_RULE_CONFLICT

/* 17 shadowed lower-tier rule. */
rules = .RYTAStateRules~new
shadow = .HardWorldRule~new('ADV-SHADOW', .RYTAConstant~TIER_COMMERCIAL, 'ALL', .RYTAConstant~STATE_NORMAL)
shadow~addClause(.HardWorldClause~new('ESSENTIAL_MEDICATION', 'KNOWN_TRUE'))
shadow~addClause(.HardWorldClause~new('IMMEDIATE_ACCESS', 'KNOWN_TRUE'))
shadow~addClause(.HardWorldClause~new('GUARANTEED_CUSTODY', 'KNOWN_TRUE'))
rules~addRule(shadow)
report = .RYTACoverageAnalyzer~new~analyzeCoreStateMatrix(rules)
call passCase '17 shadowed lower-tier rule reported', arrayContains(report~shadowedRules, 'ADV-SHADOW')

/* 18 unreachable rule. */
rules = .RYTAStateRules~new
unreachable = .HardWorldRule~new('ADV-UNREACHABLE', .RYTAConstant~TIER_OPERATIONAL, 'ALL', .RYTAConstant~STATE_NORMAL)
unreachable~addClause(.HardWorldClause~new('NEVER_PRESENT_IN_CORE_MATRIX', 'KNOWN_TRUE'))
rules~addRule(unreachable)
report = .RYTACoverageAnalyzer~new~analyzeCoreStateMatrix(rules)
call passCase '18 unreachable rule reported', arrayContains(report~unreachableRules, 'ADV-UNREACHABLE')

/* 19 no default fall-through: removing safe rule creates a real hole. */
rules = .RYTAStateRules~new
removed = rules~removeRule('RYTA-CUSTODY-SAFE')
report = .RYTACoverageAnalyzer~new~analyzeCoreStateMatrix(rules)
call passCase '19 missing state rule creates hole', report~holes > 0

/* 20-21 score invariance. */
ryta = .VirtualRYTA~new
ryta~addScorePlugin(.RYTATestExtremeScoringPlugin~new(.RYTAConstant~ACTION_BIG_UPSELL, 1000000))
ryta~addScorePlugin(.RYTATestExtremeScoringPlugin~new(.RYTAConstant~ACTION_WARNING, -1000000))
run = ryta~evaluate(makeSafetyWorld('ADV-20'))
call passCase '20 +1e6 cannot defeat PROHIBITED', run~action(.RYTAConstant~ACTION_BIG_UPSELL)~finalSelected == .false
call passCase '21 -1e6 cannot defeat REQUIRED', run~action(.RYTAConstant~ACTION_WARNING)~finalSelected == .true

/* 22-23 epistemic states remain distinct. */
world = .RYTAWorldState~new('ADV-22')
world~putKnown('ESSENTIAL_MEDICATION', .true)
world~putKnown('IMMEDIATE_ACCESS', .true)
world~putUnknown('GUARANTEED_CUSTODY')
run = .VirtualRYTA~new~evaluate(world)
call passCase '22 UNKNOWN not coerced to FALSE', run~state == .RYTAConstant~STATE_NEEDS_INFORMATION

world = .RYTAWorldState~new('ADV-23')
world~putKnown('ESSENTIAL_MEDICATION', .true)
world~putConflict('IMMEDIATE_ACCESS')
world~putUnknown('GUARANTEED_CUSTODY')
run = .VirtualRYTA~new~evaluate(world)
call passCase '23 CONFLICT not collapsed to UNKNOWN', run~state == .RYTAConstant~STATE_ESCALATE

/* 24 approval cannot override non-overrideable prohibition. */
ryta = .VirtualRYTA~new
ryta~approvals~add(makeApproval('ADV-24-A', ryta, 'ADV-24', 'DEFAULT'))
run = ryta~evaluate(makeSafetyWorld('ADV-24'))
caseTwentyFour = run~action(.RYTAConstant~ACTION_BIG_UPSELL)~disposition == .RYTAConstant~DISPOSITION_PROHIBITED
if caseTwentyFour then caseTwentyFour = run~action(.RYTAConstant~ACTION_BIG_UPSELL)~finalSelected == .false
call passCase '24 approval cannot override NON_OVERRIDEABLE', caseTwentyFour

/* 25 missing reachable action disposition is a coverage blocker. */
rules = .RYTAStateRules~new
removed = rules~removeBasePolicy(.RYTAConstant~STATE_REMEDIATION_REQUIRED, .RYTAConstant~ACTION_WARNING)
report = .RYTACoverageAnalyzer~new~analyzeCoreStateMatrix(rules)
call passCase '25 missing state/action disposition reported', report~dispositionHoles > 0

call assertEqual 'adversarial cases passed', 25, passed
say '  passed:' passed
say 'RYTA ADVERSARIAL CORPUS: OK'
exit 0

passCase: procedure expose passed
  use arg label, condition
  if condition then do
    passed = passed + 1
    return .true
  end
  say 'ADVERSARIAL CASE FAILED:' label
  exit 1

makeNormalWorld: procedure
  use arg snapshotOid
  world = .RYTAWorldState~new(snapshotOid)
  world~putKnown('ESSENTIAL_MEDICATION', .false)
  world~putKnown('IMMEDIATE_ACCESS', .false)
  world~putKnown('GUARANTEED_CUSTODY', .true)
  return world

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
  world = makeNormalWorld(snapshotOid)
  world~putKnown('PRODUCT_VALUE_HIGH', .true)
  world~putKnown('BIG_UPSELL_REVIEW_REQUIRED', .true)
  return world

makeApproval: procedure
  use arg approvalId, ryta, snapshotOid, scope
  future = .DateTime~new + .TimeSpan~new(0, 0, 10, 0, 0)
  return .RYTAApproval~new(approvalId, 'SALES_MANAGER', .RYTAConstant~ACTION_BIG_UPSELL, ryta~stateRules~modelId, ryta~stateRules~modelVersion, snapshotOid, scope, future)

arrayContains: procedure
  use arg items, value
  do item over items
    if item == value then return .true
  end
  return .false

assertEqual: procedure
  use arg label, expected, actual
  if expected == actual then return .true
  say 'ASSERT FAILED:' label
  say '  expected:' expected
  say '  actual:  ' actual
  exit 1

::requires '../RYTACoverage.cls'
::requires '../plugins/RYTATestExtremeScoring.cls'
