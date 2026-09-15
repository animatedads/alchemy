say 'VIRTUAL RYTA APPROVAL BINDING START'

world = makeApprovalWorld('WORLD-APPROVAL-1')
ryta = .VirtualRYTA~new
withoutApproval = ryta~evaluate(world, 'JOURNEY-42')
call assertEqual 'normal state', .RYTAConstant~STATE_NORMAL, withoutApproval~state
call assertEqual 'review disposition', .RYTAConstant~DISPOSITION_REQUIRES_APPROVAL, withoutApproval~action(.RYTAConstant~ACTION_BIG_UPSELL)~disposition
call assertEqual 'not selected without approval', .false, withoutApproval~action(.RYTAConstant~ACTION_BIG_UPSELL)~finalSelected

validApproval = makeApproval('A-VALID', ryta, 'WORLD-APPROVAL-1', 'JOURNEY-42')
ryta~approvals~add(validApproval)
withApproval = ryta~evaluate(world, 'JOURNEY-42')
call assertEqual 'selected with bound approval', .true, withApproval~action(.RYTAConstant~ACTION_BIG_UPSELL)~finalSelected
call assertEqual 'approval status valid', 'VALID', withApproval~action(.RYTAConstant~ACTION_BIG_UPSELL)~approvalStatus

wrongScopeRyta = .VirtualRYTA~new
wrongScopeRyta~approvals~add(makeApproval('A-SCOPE', wrongScopeRyta, 'WORLD-APPROVAL-1', 'OTHER-JOURNEY'))
wrongScopeRun = wrongScopeRyta~evaluate(world, 'JOURNEY-42')
call assertEqual 'wrong scope rejected', .false, wrongScopeRun~action(.RYTAConstant~ACTION_BIG_UPSELL)~finalSelected

wrongSnapshotRyta = .VirtualRYTA~new
wrongSnapshotRyta~approvals~add(makeApproval('A-SNAPSHOT', wrongSnapshotRyta, 'WORLD-OLD', 'JOURNEY-42'))
wrongSnapshotRun = wrongSnapshotRyta~evaluate(world, 'JOURNEY-42')
call assertEqual 'wrong snapshot rejected', .false, wrongSnapshotRun~action(.RYTAConstant~ACTION_BIG_UPSELL)~finalSelected

wrongVersionRyta = .VirtualRYTA~new
wrongVersion = .RYTAApproval~new('A-VERSION', 'SALES_MANAGER', .RYTAConstant~ACTION_BIG_UPSELL, wrongVersionRyta~stateRules~modelId, '0.1', 'WORLD-APPROVAL-1', 'JOURNEY-42')
wrongVersionRyta~approvals~add(wrongVersion)
wrongVersionRun = wrongVersionRyta~evaluate(world, 'JOURNEY-42')
call assertEqual 'wrong model version rejected', .false, wrongVersionRun~action(.RYTAConstant~ACTION_BIG_UPSELL)~finalSelected

expiredRyta = .VirtualRYTA~new
past = .DateTime~new - .TimeSpan~new(0, 0, 0, 10, 0)
expired = .RYTAApproval~new('A-EXPIRED', 'SALES_MANAGER', .RYTAConstant~ACTION_BIG_UPSELL, expiredRyta~stateRules~modelId, expiredRyta~stateRules~modelVersion, 'WORLD-APPROVAL-1', 'JOURNEY-42', past)
expiredRyta~approvals~add(expired)
expiredRun = expiredRyta~evaluate(world, 'JOURNEY-42')
call assertEqual 'expired approval rejected', .false, expiredRun~action(.RYTAConstant~ACTION_BIG_UPSELL)~finalSelected

revokedRyta = .VirtualRYTA~new
revoked = makeApproval('A-REVOKED', revokedRyta, 'WORLD-APPROVAL-1', 'JOURNEY-42')
revoked~revoked = .true
revokedRyta~approvals~add(revoked)
revokedRun = revokedRyta~evaluate(world, 'JOURNEY-42')
call assertEqual 'revoked approval rejected', .false, revokedRun~action(.RYTAConstant~ACTION_BIG_UPSELL)~finalSelected

conflictRyta = .VirtualRYTA~new
conflictRyta~approvals~add(makeApproval('A-YES', conflictRyta, 'WORLD-APPROVAL-1', 'JOURNEY-42'))
deny = .RYTAApproval~new('A-NO', 'SALES_MANAGER', .RYTAConstant~ACTION_BIG_UPSELL, conflictRyta~stateRules~modelId, conflictRyta~stateRules~modelVersion, 'WORLD-APPROVAL-1', 'JOURNEY-42', .nil, 'DENY')
conflictRyta~approvals~add(deny)
conflictRun = conflictRyta~evaluate(world, 'JOURNEY-42')
call assertEqual 'conflicting approvals rejected', .false, conflictRun~action(.RYTAConstant~ACTION_BIG_UPSELL)~finalSelected
call assertEqual 'conflicting approval status', 'CONFLICTING_APPROVALS', conflictRun~action(.RYTAConstant~ACTION_BIG_UPSELL)~approvalStatus

unsafeWorld = .RYTAWorldState~new('WORLD-UNSAFE-1')
unsafeWorld~putKnown('PRODUCT_VALUE_HIGH', .true)
unsafeWorld~putKnown('ESSENTIAL_MEDICATION', .true)
unsafeWorld~putKnown('IMMEDIATE_ACCESS', .true)
unsafeWorld~putKnown('GUARANTEED_CUSTODY', .false)
unsafeWorld~putKnown('BIG_UPSELL_REVIEW_REQUIRED', .true)
unsafeRyta = .VirtualRYTA~new
unsafeRyta~approvals~add(makeApproval('A-UNSAFE', unsafeRyta, 'WORLD-UNSAFE-1', 'JOURNEY-42'))
unsafeRun = unsafeRyta~evaluate(unsafeWorld, 'JOURNEY-42')
call assertEqual 'approval cannot override prohibition', .false, unsafeRun~action(.RYTAConstant~ACTION_BIG_UPSELL)~finalSelected
call assertEqual 'hard prohibition survives approval', .RYTAConstant~DISPOSITION_PROHIBITED, unsafeRun~action(.RYTAConstant~ACTION_BIG_UPSELL)~disposition

say 'VIRTUAL RYTA APPROVAL BINDING: OK'
exit 0

makeApprovalWorld: procedure
  use arg snapshotOid
  world = .RYTAWorldState~new(snapshotOid)
  world~putKnown('PRODUCT_VALUE_HIGH', .true)
  world~putKnown('ESSENTIAL_MEDICATION', .false)
  world~putKnown('IMMEDIATE_ACCESS', .false)
  world~putKnown('GUARANTEED_CUSTODY', .true)
  world~putKnown('BIG_UPSELL_REVIEW_REQUIRED', .true)
  return world

makeApproval: procedure
  use arg approvalId, ryta, snapshotOid, scope
  future = .DateTime~new + .TimeSpan~new(0, 0, 10, 0, 0)
  return .RYTAApproval~new(approvalId, 'SALES_MANAGER', .RYTAConstant~ACTION_BIG_UPSELL, ryta~stateRules~modelId, ryta~stateRules~modelVersion, snapshotOid, scope, future)

assertEqual: procedure
  use arg label, expected, actual
  if expected == actual then return .true
  say 'ASSERT FAILED:' label
  say '  expected:' expected
  say '  actual:  ' actual
  exit 1

::requires '../VirtualRYTA.cls'
