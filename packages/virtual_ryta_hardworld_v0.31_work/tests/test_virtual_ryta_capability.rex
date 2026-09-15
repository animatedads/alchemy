say 'VIRTUAL RYTA CAPABILITY START'

world = .RYTAWorldState~new('WORLD-CAPABILITY-1')
world~putKnown('ESSENTIAL_MEDICATION', .true)
world~putKnown('IMMEDIATE_ACCESS', .true)
world~putKnown('GUARANTEED_CUSTODY', .false)
world~putKnown('CAN_WARNING', .false, 'BROKEN_OUTPUT_DEVICE', 'CAPABILITY_PROVIDER')

ryta = .VirtualRYTA~new
decisionRun = ryta~evaluate(world)
warning = decisionRun~action(.RYTAConstant~ACTION_WARNING)
escalation = decisionRun~action(.RYTAConstant~ACTION_ESCALATE)
call assertEqual 'world decision remains remediation', .RYTAConstant~STATE_REMEDIATION_REQUIRED, decisionRun~state
call assertEqual 'warning remains required', .RYTAConstant~DISPOSITION_REQUIRED, warning~disposition
call assertEqual 'warning cannot execute', .false, warning~finalSelected
call assertEqual 'warning requirement unsatisfied', .false, warning~requirementSatisfied
call assertEqual 'execution status records required capability failure', .RYTAConstant~EXECUTION_REQUIRED_ACTION_UNAVAILABLE, decisionRun~executionStatus
call assertEqual 'capability failure requires escalation', .RYTAConstant~DISPOSITION_REQUIRED, escalation~disposition
call assertEqual 'escalation executes', .true, escalation~finalSelected

unknownWorld = .RYTAWorldState~new('WORLD-CAPABILITY-UNKNOWN')
unknownWorld~putKnown('ESSENTIAL_MEDICATION', .true)
unknownWorld~putKnown('IMMEDIATE_ACCESS', .true)
unknownWorld~putKnown('GUARANTEED_CUSTODY', .false)
unknownWorld~putUnknown('CAN_WARNING', 'CAPABILITY_PROVIDER', 'CAPABILITY_PROVIDER')
unknownRun = .VirtualRYTA~new~evaluate(unknownWorld)
call assertEqual 'unknown capability does not satisfy requirement', .false, unknownRun~action(.RYTAConstant~ACTION_WARNING)~requirementSatisfied
call assertEqual 'unknown capability escalates execution status', .RYTAConstant~EXECUTION_REQUIRED_ACTION_UNAVAILABLE, unknownRun~executionStatus

conflictWorld = .RYTAWorldState~new('WORLD-CAPABILITY-CONFLICT')
conflictWorld~putKnown('ESSENTIAL_MEDICATION', .true)
conflictWorld~putKnown('IMMEDIATE_ACCESS', .true)
conflictWorld~putKnown('GUARANTEED_CUSTODY', .false)
conflictWorld~putConflict('CAN_WARNING', 'CAPABILITY_PROVIDER', 'CAPABILITY_PROVIDER')
conflictRun = .VirtualRYTA~new~evaluate(conflictWorld)
call assertEqual 'conflicting capability does not satisfy requirement', .false, conflictRun~action(.RYTAConstant~ACTION_WARNING)~requirementSatisfied

noEscalationWorld = .RYTAWorldState~new('WORLD-CAPABILITY-2')
noEscalationWorld~putKnown('ESSENTIAL_MEDICATION', .true)
noEscalationWorld~putKnown('IMMEDIATE_ACCESS', .true)
noEscalationWorld~putKnown('GUARANTEED_CUSTODY', .false)
noEscalationWorld~putKnown('CAN_WARNING', .false)
noEscalationWorld~putKnown('CAN_ESCALATE', .false)
noEscalationRun = .VirtualRYTA~new~evaluate(noEscalationWorld)
call assertEqual 'escalation itself remains required when incapable', .RYTAConstant~DISPOSITION_REQUIRED, noEscalationRun~action(.RYTAConstant~ACTION_ESCALATE)~disposition
call assertEqual 'escalation requirement is unsatisfied', .false, noEscalationRun~action(.RYTAConstant~ACTION_ESCALATE)~requirementSatisfied
call assertEqual 'two unavailable required actions recorded', 2, noEscalationRun~requiredUnavailable~items

say 'VIRTUAL RYTA CAPABILITY: OK'
exit 0

assertEqual: procedure
  use arg label, expected, actual
  if expected == actual then return .true
  say 'ASSERT FAILED:' label
  say '  expected:' expected
  say '  actual:  ' actual
  exit 1

::requires '../VirtualRYTA.cls'
