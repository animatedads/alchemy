say 'VIRTUAL RYTA ACTION CONSTRAINTS START'

world = .RYTAWorldState~new('WORLD-CONSTRAINT-1')
world~putKnown('ESSENTIAL_MEDICATION', .false)
world~putKnown('IMMEDIATE_ACCESS', .false)
world~putKnown('GUARANTEED_CUSTODY', .true)

ryta = .VirtualRYTA~new
warningPolicy = ryta~stateRules~basePolicyFor(.RYTAConstant~STATE_NORMAL, .RYTAConstant~ACTION_WARNING)
warningPolicy~disposition = .RYTAConstant~DISPOSITION_REQUIRED
upsellPolicy = ryta~stateRules~basePolicyFor(.RYTAConstant~STATE_NORMAL, .RYTAConstant~ACTION_UPSELL)
upsellPolicy~disposition = .RYTAConstant~DISPOSITION_REQUIRED
ryta~stateRules~addActionConstraint(.RYTAActionConstraint~new('NO-WARN-AND-UPSELL', 'MUTUALLY_EXCLUSIVE', .RYTAConstant~ACTION_WARNING, .RYTAConstant~ACTION_UPSELL, 'test incompatible obligations'))

decisionRun = ryta~evaluate(world)
call assertEqual 'conflicting requirements execution status', .RYTAConstant~EXECUTION_CONFLICTING_REQUIREMENTS, decisionRun~executionStatus
call assertEqual 'warning remains required', .RYTAConstant~DISPOSITION_REQUIRED, decisionRun~action(.RYTAConstant~ACTION_WARNING)~disposition
call assertEqual 'upsell remains required', .RYTAConstant~DISPOSITION_REQUIRED, decisionRun~action(.RYTAConstant~ACTION_UPSELL)~disposition
call assertEqual 'warning blocked rather than arbitrarily selected', .false, decisionRun~action(.RYTAConstant~ACTION_WARNING)~finalSelected
call assertEqual 'upsell blocked rather than arbitrarily selected', .false, decisionRun~action(.RYTAConstant~ACTION_UPSELL)~finalSelected
call assertEqual 'warning obligation unsatisfied', .false, decisionRun~action(.RYTAConstant~ACTION_WARNING)~requirementSatisfied
call assertEqual 'upsell obligation unsatisfied', .false, decisionRun~action(.RYTAConstant~ACTION_UPSELL)~requirementSatisfied
call assertEqual 'escalation required', .RYTAConstant~DISPOSITION_REQUIRED, decisionRun~action(.RYTAConstant~ACTION_ESCALATE)~disposition
call assertEqual 'escalation executes', .true, decisionRun~action(.RYTAConstant~ACTION_ESCALATE)~finalSelected
coverageReport = .RYTACoverageAnalyzer~new~analyzeCoreStateMatrix(ryta~stateRules)
call assertEqual 'static coverage also sees illegal effect combination', .true, hasIssue(coverageReport, 'C8')

say 'VIRTUAL RYTA ACTION CONSTRAINTS: OK'
exit 0

hasIssue: procedure
  use arg report, code
  do issue over report~issues
    if issue~code == code then return .true
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
