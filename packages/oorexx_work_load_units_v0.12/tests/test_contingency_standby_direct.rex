MICRO = 1000000
clock = .WLUTestTimeSource~new(2000000)
keys = .WLUFastMacKeyRing~new
keys~addKey('standby-direct-k1', '00112233445566778899aabbccddeeff')
auth = .WLUAuthority~new(keys, .WLUMemoryLedger~new, clock)

account = .WLUAccount~new('direct-standby', 50 * MICRO)
auth~addAccount(account)
auth~bindAccount('FLYLO_*', 'SHANNON:*', account~accountId)
pool = .WLUThroughputPool~new('direct-grok', 10 * MICRO)
auth~addThroughputPool(pool)
auth~bindThroughputPool('FLYLO_*', 'SHANNON:GROK', 'direct-grok')

plan = .WLUJobPlan~new('standby.direct', '1')
plan~addStage(.WLUJobStage~new('GROK', 'SHANNON:GROK', 4 * MICRO, 6 * MICRO, 1 * MICRO, 1 * MICRO, 1), .true)
call assertTrue plan~seal~ok, 'direct standby plan seals'
request = .WLUJobRequest~new('direct-standby-job', 'CHAT-DIRECT', 'FLYLO_SHANNON', 'SHANNON:CHAT', plan, 5 * MICRO, 12 * MICRO)
manager = .WLUJobBudgetManager~new(auth)
opened = manager~openJob(request)
call assertTrue opened~ok, 'direct job opens'
lease = opened~value

s = manager~standbyStage(lease, 'GROK', 30, 700, 'grok-ready')
call assertTrue s~ok, 'direct standby created'
standby = s~value
call assertTrue standby~verify(keys), 'direct standby authenticated'
call assertEq 0, account~reservedMicroWlu, 'standby itself reserves no account WLU'
call assertEq 0, pool~reservedRateMicroWluPerSecond, 'standby itself reserves no throughput'

/* The internal mark operation refuses an unrelated reservation id. */
invalidMark = manager~markStandbyPromoted(lease, standby, 'not-a-child')
call assertTrue \invalidMark~ok, 'standby cannot be marked promoted without matching child reservation'
call assertEq 'WLU_STANDBY_RESERVATION_MISMATCH', invalidMark~code, 'reservation mismatch code'

promotedResult = manager~promoteStandby(lease, standby, 60, 'direct-promote')
call assertTrue promotedResult~ok, 'direct standby promotes'
lease2 = promotedResult~value[1]
reservation = promotedResult~value[2]
promoted = promotedResult~value[3]
call assertEq .WLUJobStandbyState~PROMOTED, promoted~state, 'direct standby state promoted'
call assertEq reservation~reservationId, promoted~promotedReservationId, 'direct standby binds child reservation'
call assertEq 7 * MICRO, lease2~committedMicroWlu, 'direct promotion commits full stage plus handoff ceiling'
call assertEq 7 * MICRO, account~reservedMicroWlu, 'direct promotion reserves account WLU'
call assertEq 5 * MICRO, pool~reservedRateMicroWluPerSecond, 'direct promotion reserves requested rate'

settled = manager~settleStage(lease2, reservation, 5 * MICRO)
call assertTrue settled~ok, 'direct promoted stage settles'
lease3 = settled~value
call assertEq 5 * MICRO, lease3~spentMicroWlu, 'direct promotion actual work settled once'
call assertEq 0, lease3~committedMicroWlu, 'direct commitment closes'
call assertEq 0, account~reservedMicroWlu, 'account hold released after settlement'
call assertEq 0, pool~reservedRateMicroWluPerSecond, 'delivery rate released after settlement'

stale = manager~releaseStandby(lease3, standby)
call assertTrue \stale~ok, 'old standby snapshot stale after promotion'
call assertEq 'WLU_STANDBY_STALE', stale~code, 'old standby snapshot rejected'

say 'PASS test_contingency_standby_direct'
exit 0

assertTrue: procedure
  use arg condition, label
  if \condition then do
    say 'FAIL' label
    exit 1
  end
return

assertEq: procedure
  use arg expected, actual, label
  if expected \= actual then do
    say 'FAIL' label 'expected='expected 'actual='actual
    exit 1
  end
return

::requires 'WLUJobBudget.cls'
