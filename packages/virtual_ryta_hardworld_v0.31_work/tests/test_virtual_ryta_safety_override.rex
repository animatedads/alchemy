say 'VIRTUAL RYTA SAFETY OVERRIDE START'

world = .RYTAWorldState~new
world~putKnown('HAS_QUERY', .true)
world~putKnown('PRODUCT_RELEVANT', .true)
world~putKnown('CUSTOMER_ELIGIBLE', .true)
world~putKnown('UPSELL_OPPORTUNITY', .true)
world~putKnown('PRODUCT_VALUE_HIGH', .true)
world~putKnown('ESSENTIAL_MEDICATION', .true)
world~putKnown('IMMEDIATE_ACCESS', .true)
world~putKnown('GUARANTEED_CUSTODY', .false)

ryta = .VirtualRYTA~new
ryta~addScorePlugin(.RYTATestExtremeScoringPlugin~new(.RYTAConstant~ACTION_BIG_UPSELL, 1000000))
ryta~addScorePlugin(.RYTATestExtremeScoringPlugin~new(.RYTAConstant~ACTION_WARNING, -1000000))
decisionRun = ryta~evaluate(world)

call assertEqual 'remediation state', .RYTAConstant~STATE_REMEDIATION_REQUIRED, decisionRun~state
call assertEqual 'unsafe rule', 'RYTA-CUSTODY-UNSAFE', decisionRun~winningRule
call assertEqual 'big upsell has huge positive score', .true, decisionRun~action(.RYTAConstant~ACTION_BIG_UPSELL)~score > 100000
call assertEqual 'big upsell prohibited', .RYTAConstant~DISPOSITION_PROHIBITED, decisionRun~action(.RYTAConstant~ACTION_BIG_UPSELL)~disposition
call assertEqual 'big upsell never selected', .false, decisionRun~action(.RYTAConstant~ACTION_BIG_UPSELL)~finalSelected
call assertEqual 'warning has huge negative score', .true, decisionRun~action(.RYTAConstant~ACTION_WARNING)~score < -100000
call assertEqual 'warning required', .RYTAConstant~DISPOSITION_REQUIRED, decisionRun~action(.RYTAConstant~ACTION_WARNING)~disposition
call assertEqual 'warning selected despite score', .true, decisionRun~action(.RYTAConstant~ACTION_WARNING)~finalSelected

say 'VIRTUAL RYTA SAFETY OVERRIDE: OK'
exit 0

assertEqual: procedure
  use arg label, expected, actual
  if expected == actual then return .true
  say 'ASSERT FAILED:' label
  say '  expected:' expected
  say '  actual:  ' actual
  exit 1

::requires '../VirtualRYTA.cls'
::requires '../plugins/RYTATestExtremeScoring.cls'
