say 'VIRTUAL RYTA UNKNOWN / CONFLICT START'

unknownWorld = .RYTAWorldState~new
unknownWorld~putKnown('ESSENTIAL_MEDICATION', .true)
unknownWorld~putKnown('IMMEDIATE_ACCESS', .true)
unknownWorld~putUnknown('GUARANTEED_CUSTODY')
unknownRYTA = .VirtualRYTA~new
unknownRun = unknownRYTA~evaluate(unknownWorld)
call assertEqual 'unknown state', .RYTAConstant~STATE_NEEDS_INFORMATION, unknownRun~state
call assertEqual 'ask information required', .true, unknownRun~action(.RYTAConstant~ACTION_ASK_INFORMATION)~finalSelected

conflictWorld = .RYTAWorldState~new
conflictWorld~putKnown('ESSENTIAL_MEDICATION', .true)
conflictWorld~putConflict('IMMEDIATE_ACCESS')
conflictWorld~putUnknown('GUARANTEED_CUSTODY')
conflictRYTA = .VirtualRYTA~new
conflictRun = conflictRYTA~evaluate(conflictWorld)
call assertEqual 'conflict outranks unknown', .RYTAConstant~STATE_ESCALATE, conflictRun~state
call assertEqual 'conflict rule wins', 'RYTA-CRITICAL-CONFLICT', conflictRun~winningRule
call assertEqual 'escalation required', .true, conflictRun~action(.RYTAConstant~ACTION_ESCALATE)~finalSelected

say 'VIRTUAL RYTA UNKNOWN / CONFLICT: OK'
exit 0

assertEqual: procedure
  use arg label, expected, actual
  if expected == actual then return .true
  say 'ASSERT FAILED:' label
  say '  expected:' expected
  say '  actual:  ' actual
  exit 1

::requires '../VirtualRYTA.cls'
