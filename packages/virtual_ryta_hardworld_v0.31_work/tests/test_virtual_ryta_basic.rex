say 'VIRTUAL RYTA BASIC SMOKE START'

world = .RYTAWorldState~new
world~putKnown('HAS_QUERY', .true)
world~putKnown('PRODUCT_RELEVANT', .true)
world~putKnown('CUSTOMER_ELIGIBLE', .true)
world~putKnown('UPSELL_OPPORTUNITY', .true)
world~putKnown('PRODUCT_VALUE_HIGH', .true)
world~putKnown('ESSENTIAL_MEDICATION', .false)
world~putKnown('IMMEDIATE_ACCESS', .false)
world~putKnown('GUARANTEED_CUSTODY', .true)

ryta = .VirtualRYTA~new
decisionRun = ryta~evaluate(world)

call assertEqual 'normal state', .RYTAConstant~STATE_NORMAL, decisionRun~state
call assertEqual 'answer selected', .true, decisionRun~action(.RYTAConstant~ACTION_ANSWER_QUERY)~finalSelected
call assertEqual 'sell selected', .true, decisionRun~action(.RYTAConstant~ACTION_SELL_PRODUCT)~finalSelected
call assertEqual 'upsell selected', .true, decisionRun~action(.RYTAConstant~ACTION_UPSELL)~finalSelected
call assertEqual 'big upsell selected', .true, decisionRun~action(.RYTAConstant~ACTION_BIG_UPSELL)~finalSelected
call assertEqual 'warning not selected', .false, decisionRun~action(.RYTAConstant~ACTION_WARNING)~finalSelected

say 'VIRTUAL RYTA BASIC SMOKE: OK'
exit 0

assertEqual: procedure
  use arg label, expected, actual
  if expected == actual then return .true
  say 'ASSERT FAILED:' label
  say '  expected:' expected
  say '  actual:  ' actual
  exit 1

::requires '../VirtualRYTA.cls'
