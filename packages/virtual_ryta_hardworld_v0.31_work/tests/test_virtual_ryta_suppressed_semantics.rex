say 'VIRTUAL RYTA SUPPRESSED SEMANTICS START'

unsafeWorld = .RYTAWorldState~new('WORLD-SUPPRESS-1')
unsafeWorld~putKnown('PRODUCT_RELEVANT', .true)
unsafeWorld~putKnown('CUSTOMER_ELIGIBLE', .true)
unsafeWorld~putKnown('UPSELL_OPPORTUNITY', .true)
unsafeWorld~putKnown('PRODUCT_VALUE_HIGH', .true)
unsafeWorld~putKnown('ESSENTIAL_MEDICATION', .true)
unsafeWorld~putKnown('IMMEDIATE_ACCESS', .true)
unsafeWorld~putKnown('GUARANTEED_CUSTODY', .false)

ryta = .VirtualRYTA~new
unsafeRun = ryta~evaluate(unsafeWorld)
sellDecision = unsafeRun~action(.RYTAConstant~ACTION_SELL_PRODUCT)
bigDecision = unsafeRun~action(.RYTAConstant~ACTION_BIG_UPSELL)
call assertEqual 'sell positive preference', .true, sellDecision~score > 0
call assertEqual 'sell is suppressed', .true, sellDecision~isSuppressed
call assertEqual 'suppressed is not hard prohibition', .false, sellDecision~isHardProhibition
call assertEqual 'suppressed does not execute', .false, sellDecision~finalSelected
call assertEqual 'big upsell is hard prohibition', .true, bigDecision~isHardProhibition

safeWorld = .RYTAWorldState~new('WORLD-SUPPRESS-2')
safeWorld~putKnown('PRODUCT_RELEVANT', .true)
safeWorld~putKnown('CUSTOMER_ELIGIBLE', .true)
safeWorld~putKnown('ESSENTIAL_MEDICATION', .false)
safeWorld~putKnown('IMMEDIATE_ACCESS', .false)
safeWorld~putKnown('GUARANTEED_CUSTODY', .true)
safeRun = ryta~evaluate(safeWorld)
safeSell = safeRun~action(.RYTAConstant~ACTION_SELL_PRODUCT)
call assertEqual 'same sale intrinsically permitted in normal context', .RYTAConstant~DISPOSITION_PERMITTED, safeSell~disposition
call assertEqual 'same sale executes when suppression context disappears', .true, safeSell~finalSelected

say 'VIRTUAL RYTA SUPPRESSED SEMANTICS: OK'
exit 0

assertEqual: procedure
  use arg label, expected, actual
  if expected == actual then return .true
  say 'ASSERT FAILED:' label
  say '  expected:' expected
  say '  actual:  ' actual
  exit 1

::requires '../VirtualRYTA.cls'
