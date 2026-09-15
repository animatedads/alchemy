MICRO = 1000000
clock = .WLUTestTimeSource~new(1000000)
keys = .WLUFastMacKeyRing~new
keys~addKey('standby-k1', '000102030405060708090a0b0c0d0e0f')
auth = .WLUAuthority~new(keys, .WLUMemoryLedger~new, clock)

account = .WLUAccount~new('flylo-standby', 100 * MICRO)
auth~addAccount(account)
auth~bindAccount('FLYLO_*', 'SHANNON:*', account~accountId)

scriptPool = .WLUThroughputPool~new('script', 10 * MICRO)
gemmaPool = .WLUThroughputPool~new('gemma', 10 * MICRO)
grokPool = .WLUThroughputPool~new('grok', 6 * MICRO)
do pool over .array~of(scriptPool, gemmaPool, grokPool)
  auth~addThroughputPool(pool)
end
auth~bindThroughputPool('FLYLO_*', 'SHANNON:SCRIPT', 'script')
auth~bindThroughputPool('FLYLO_*', 'SHANNON:GEMMA', 'gemma')
auth~bindThroughputPool('FLYLO_*', 'SHANNON:GROK', 'grok')

hier = .WLUHierarchyBudgetManager~new(keys)
enterprise = hier~createRoot('ENTERPRISE', 'ENTERPRISE', 40 * MICRO)~value
flylo = hier~delegate(enterprise, 'FLYLO', 'TENANT', 30 * MICRO)~value
shannon = hier~delegate(flylo, 'FLYLO.SHANNON', 'SERVICE', 25 * MICRO)~value
chat = hier~delegate(shannon, 'FLYLO.SHANNON.CHAT-STANDBY', 'JOB', 15 * MICRO)~value

plan = .WLUJobPlan~new('shannon.standby', '1')
plan~addStage(.WLUJobStage~new('SCRIPT', 'SHANNON:SCRIPT', 1 * MICRO, 2 * MICRO), .true)
plan~addStage(.WLUJobStage~new('GEMMA', 'SHANNON:GEMMA', 4 * MICRO, 6 * MICRO))
plan~addStage(.WLUJobStage~new('GROK', 'SHANNON:GROK', 5 * MICRO, 7 * MICRO, 1 * MICRO, 1 * MICRO, 2))
plan~addFallback('SCRIPT', 'GEMMA')
plan~addFallback('GEMMA', 'GROK')
call assertTrue plan~seal~ok, 'standby plan seals'

request = .WLUJobRequest~new('flylo-standby-chat', 'CHAT-STANDBY', 'FLYLO_SHANNON', 'SHANNON:CHAT', plan, 7 * MICRO, 15 * MICRO)
manager = .WLUHierarchicalJobManager~new(auth, hier)
opened = manager~openJob(request, chat)
call assertTrue opened~ok, 'hierarchical standby job opens'
lease = opened~value

/* Forecast can motivate preparation, but preparation still grants nothing. */
forecasted = manager~reviseForecast(lease, 8 * MICRO, 17 * MICRO, 8000, 'SHANNON', 'Gemma may need remote rescue')
call assertTrue forecasted~ok, 'risk forecast accepted'
lease = forecasted~value[1]
call assertEq .WLUJobForecastStatus~AT_RISK, forecasted~value[2]~status, 'risk visible before standby'

accountReservedBefore = account~reservedMicroWlu
chatBefore = hier~current(chat~nodeId)~value
poolReservedBefore = grokPool~reservedRateMicroWluPerSecond
standbyResult = manager~standbyStage(lease, 'GROK', 20, 900, 'rescue-grok')
call assertTrue standbyResult~ok, 'Grok standby intent created'
standby = standbyResult~value
call assertTrue standby~verify(keys), 'standby lease is authenticated'
call assertEq .WLUJobStandbyState~ACTIVE, standby~state, 'standby starts active'
call assertEq 8 * MICRO, standby~ceilingMicroWlu, 'standby binds full stage plus handoff ceiling'
call assertEq 3 * MICRO, standby~requestedRateMicroWluPerSecond, 'standby binds delivery-rate demand'
call assertEq 900, standby~priority, 'advisory priority retained'
call assertEq accountReservedBefore, account~reservedMicroWlu, 'standby reserves no account WLU'
call assertEq poolReservedBefore, grokPool~reservedRateMicroWluPerSecond, 'standby holds no throughput'
chatAfterStandby = hier~current(chat~nodeId)~value
call assertEq chatBefore~committedMicroWlu, chatAfterStandby~committedMicroWlu, 'standby commits no hierarchy WLU'
call assertEq 0, lease~committedMicroWlu, 'standby commits no logical-job WLU'
call assertTrue manager~forecast(lease)~ok, 'creating standby does not stale hard job lease'

idempotent = manager~standbyStage(lease, 'GROK', 20, 900, 'rescue-grok')
call assertTrue idempotent~ok, 'standby request is idempotent'
call assertEq standby~standbyId, idempotent~value~standbyId, 'idempotent standby returns same claim'
conflict = manager~standbyStage(lease, 'GROK', 20, 901, 'rescue-grok')
call assertTrue \conflict~ok, 'same standby key with different priority conflicts'
call assertEq 'WLU_STANDBY_IDEMPOTENCY_CONFLICT', conflict~code, 'standby idempotency conflict code'

claims = manager~standbyClaims(lease)
call assertTrue claims~ok, 'standby claims can be enumerated'
call assertEq 1, claims~value~items, 'one standby claim recorded'

ready = manager~assessStandby(lease, standby)
call assertTrue ready~ok, 'standby live assessment returned'
call assertTrue ready~value~ready, 'standby is currently promotable'
call assertEq .WLUJobStandbyState~ACTIVE, ready~value~jobAssessment~effectiveState, 'effective standby state active'
call assertTrue ready~value~hierarchyAssessment~ready, 'hierarchy currently permits rescue ceiling'

/* Occupy provider throughput.  The soft claim remains visible and active; a
 * failed promotion must roll back its temporary hierarchy hold and leave all
 * hard job counters unchanged. */
blocker = auth~reserve('FLYLO_SHANNON', 'SHANNON:GROK', 1 * MICRO, 60, 'grok-blocker', 'DIRECT', '1', 1 * MICRO, 5 * MICRO)
call assertTrue blocker~ok, 'provider blocker reserves Grok delivery rate'
blockedAssessment = manager~assessStandby(lease, standby)
call assertTrue blockedAssessment~ok, 'blocked standby still assesses'
call assertTrue \blockedAssessment~value~ready, 'standby shows runtime delivery shortage'
call assertEq 2 * MICRO, blockedAssessment~value~jobAssessment~demandAssessment~deliveryShortfallRateMicroWluPerSecond, 'Grok standby delivery shortfall exposed'

jobCommittedBefore = lease~committedMicroWlu
chatCommittedBefore = hier~current(chat~nodeId)~value~committedMicroWlu
accountBeforePromotion = account~reservedMicroWlu
blockedPromotion = manager~promoteStandby(lease, standby, 60, 'promote-grok')
call assertTrue \blockedPromotion~ok, 'promotion fails while provider rate unavailable'
call assertEq 'WLU_THROUGHPUT_EXHAUSTED', blockedPromotion~code, 'runtime throughput refusal propagated'
call assertEq jobCommittedBefore, lease~committedMicroWlu, 'failed promotion leaves logical job unchanged'
call assertEq chatCommittedBefore, hier~current(chat~nodeId)~value~committedMicroWlu, 'failed promotion rolls hierarchy hold back'
call assertEq accountBeforePromotion, account~reservedMicroWlu, 'failed promotion adds no account reservation'
call assertEq .WLUJobStandbyState~ACTIVE, manager~standbyClaims(lease)~value[1]~state, 'failed promotion leaves standby active'

call assertTrue auth~release(blocker~value)~ok, 'provider blocker releases'
promotedResult = manager~promoteStandby(lease, standby, 60, 'promote-grok')
call assertTrue promotedResult~ok, 'standby promotes when capacity becomes available'
lease2 = promotedResult~value[1]
grok = promotedResult~value[2]
hierarchyLease = promotedResult~value[3]
promoted = promotedResult~value[4]
call assertEq .WLUJobStandbyState~PROMOTED, promoted~state, 'standby records promotion'
call assertEq grok~reservationId, promoted~promotedReservationId, 'standby binds resulting reservation id'
call assertTrue promoted~verify(keys), 'promoted standby proof valid'
call assertEq 8 * MICRO, lease2~committedMicroWlu, 'promotion becomes hard logical-job commitment'
call assertEq 8 * MICRO, hierarchyLease~committedMicroWlu, 'promotion becomes hard hierarchy commitment'
call assertEq 8 * MICRO, account~reservedMicroWlu, 'promotion becomes hard account reservation'
call assertEq 3 * MICRO, grokPool~reservedRateMicroWluPerSecond, 'promotion acquires delivery rate'

settled = manager~settleStage(lease2, grok, 6 * MICRO)
call assertTrue settled~ok, 'promoted rescue stage settles normally'
lease3 = settled~value[1]
chatSettled = settled~value[2]
call assertEq 6 * MICRO, lease3~spentMicroWlu, 'actual rescue work enters job spend once'
call assertEq 6 * MICRO, chatSettled~spentMicroWlu, 'same work enters hierarchy once'
call assertEq 0, account~reservedMicroWlu, 'settlement releases hard account hold'
call assertEq 0, grokPool~reservedRateMicroWluPerSecond, 'settlement releases delivery rate'

notActive = manager~releaseStandby(lease3, promoted)
call assertTrue \notActive~ok, 'promoted standby cannot be released as active intent'
call assertEq 'WLU_STANDBY_NOT_ACTIVE', notActive~code, 'promoted standby state enforced'

/* Expiry is also non-entitling.  It changes effective scheduling state only. */
expiring = manager~standbyStage(lease3, 'GEMMA', 1, 500, 'gemma-short')
call assertTrue expiring~ok, 'short standby created'
expiringLease = expiring~value
clock~advanceSeconds(2)
expiredAssessment = manager~assessStandby(lease3, expiringLease)
call assertTrue expiredAssessment~ok, 'expired standby still produces assessment evidence'
call assertEq .WLUJobStandbyState~EXPIRED, expiredAssessment~value~jobAssessment~effectiveState, 'standby expiry reflected without hard mutation'
expiredPromotion = manager~promoteStandby(lease3, expiringLease, 60, 'late-gemma')
call assertTrue \expiredPromotion~ok, 'expired standby cannot be promoted'
call assertEq 'WLU_STANDBY_EXPIRED', expiredPromotion~code, 'standby expiry code'
call assertEq 6 * MICRO, lease3~spentMicroWlu, 'expired standby spends nothing'
call assertEq 0, lease3~committedMicroWlu, 'expired standby commits nothing'

say 'PASS test_contingency_standby'
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

::requires 'WLUHierarchicalJob.cls'
