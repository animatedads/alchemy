say 'VIRTUAL RYTA FACT PLUGIN START'

world = .RYTAWorldState~new
world~putKnown('ESSENTIAL_MEDICATION', .false)
world~putKnown('IMMEDIATE_ACCESS', .false)
world~putKnown('GUARANTEED_CUSTODY', .true)

ryta = .VirtualRYTA~new
ryta~addFactPlugin(.RYTATestFactPlugin~new)
decisionRun = ryta~evaluate(world)

call assertEqual 'plugin fact present', .true, world~isKnownTrue('PRODUCT_VALUE_HIGH')
call assertEqual 'plugin drives big upsell preference', .true, decisionRun~action(.RYTAConstant~ACTION_BIG_UPSELL)~finalSelected
call assertEqual 'plugin drives upsell preference', .true, decisionRun~action(.RYTAConstant~ACTION_UPSELL)~finalSelected

say 'VIRTUAL RYTA FACT PLUGIN: OK'
exit 0

assertEqual: procedure
  use arg label, expected, actual
  if expected == actual then return .true
  say 'ASSERT FAILED:' label
  say '  expected:' expected
  say '  actual:  ' actual
  exit 1

::requires '../VirtualRYTA.cls'
::requires '../plugins/RYTATestFact.cls'
