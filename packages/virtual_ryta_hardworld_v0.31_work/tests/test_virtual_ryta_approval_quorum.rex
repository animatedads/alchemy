say 'VIRTUAL RYTA APPROVAL QUORUM START'

world = .RYTAWorldState~new('WORLD-QUORUM-1')
world~putKnown('PRODUCT_VALUE_HIGH', .true)
world~putKnown('ESSENTIAL_MEDICATION', .false)
world~putKnown('IMMEDIATE_ACCESS', .false)
world~putKnown('GUARANTEED_CUSTODY', .true)
world~putKnown('BIG_UPSELL_REVIEW_REQUIRED', .true)

ryta = .VirtualRYTA~new
ryta~approvalPolicies~add(.RYTAApprovalPolicy~new('TWO_MANAGER_REVIEW', 'SALES_MANAGER', 2))
ryta~stateRules~conditionalPolicies[1]~policy~approvalPolicyId = 'TWO_MANAGER_REVIEW'

ryta~approvals~add(makeApproval('Q-A1', ryta))
oneRun = ryta~evaluate(world, 'JOURNEY-Q')
call assertEqual 'one approval below quorum', .false, oneRun~action(.RYTAConstant~ACTION_BIG_UPSELL)~finalSelected
call assertEqual 'one approval reason', 'INSUFFICIENT_QUORUM', oneRun~action(.RYTAConstant~ACTION_BIG_UPSELL)~approvalStatus

ryta~approvals~add(makeApproval('Q-A1', ryta))
duplicateRun = ryta~evaluate(world, 'JOURNEY-Q')
call assertEqual 'duplicate id does not count twice', .false, duplicateRun~action(.RYTAConstant~ACTION_BIG_UPSELL)~finalSelected

ryta~approvals~add(makeApproval('Q-A2', ryta))
twoRun = ryta~evaluate(world, 'JOURNEY-Q')
call assertEqual 'two unique approvals satisfy quorum', .true, twoRun~action(.RYTAConstant~ACTION_BIG_UPSELL)~finalSelected
call assertEqual 'quorum approval valid', 'VALID', twoRun~action(.RYTAConstant~ACTION_BIG_UPSELL)~approvalStatus

say 'VIRTUAL RYTA APPROVAL QUORUM: OK'
exit 0

makeApproval: procedure
  use arg approvalId, ryta
  future = .DateTime~new + .TimeSpan~new(0, 0, 10, 0, 0)
  return .RYTAApproval~new(approvalId, 'SALES_MANAGER', .RYTAConstant~ACTION_BIG_UPSELL, ryta~stateRules~modelId, ryta~stateRules~modelVersion, 'WORLD-QUORUM-1', 'JOURNEY-Q', future)

assertEqual: procedure
  use arg label, expected, actual
  if expected == actual then return .true
  say 'ASSERT FAILED:' label
  say '  expected:' expected
  say '  actual:  ' actual
  exit 1

::requires '../VirtualRYTA.cls'
