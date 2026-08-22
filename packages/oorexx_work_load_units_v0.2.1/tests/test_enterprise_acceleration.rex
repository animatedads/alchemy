MICRO = 1000000
clock = .WLUTestTimeSource~new(1000000)
keys = .WLUFastMacKeyRing~new
ignore = keys~addKey("hot-enterprise", "000102030405060708090a0b0c0d0e0f")
ledger = .WLUMemoryLedger~new
auth = .WLUAuthority~new(keys, ledger, clock)

account = .WLUAccount~new("acct-enterprise-ai", 200 * MICRO)
auth~addAccount(account)
auth~bindAccount("AI_*", "AI:*", account~accountId)

/* This is a logical enterprise capacity pool.  Provider adapters may grow it
 * when they provision another worker/session; the WLU core need not know how. */
pool = .WLUThroughputPool~new("ai-enterprise-throughput", 5 * MICRO)
auth~addThroughputPool(pool)
auth~bindThroughputPool("AI_*", "AI:*", pool~poolId)

/* Same intrinsic work.  Only the requested delivery envelope changes. */
slow = .WLUWorkDemand~new(20 * MICRO, 25 * MICRO, 20)
fast = .WLUWorkDemand~new(20 * MICRO, 25 * MICRO, 4)
call assertEq 20 * MICRO, slow~expectedMicroWlu, "slow work estimate"
call assertEq 20 * MICRO, fast~expectedMicroWlu, "fast work estimate unchanged"
call assertEq 25 * MICRO, slow~ceilingMicroWlu, "slow ceiling"
call assertEq 25 * MICRO, fast~ceilingMicroWlu, "fast ceiling unchanged"
call assertEq 1 * MICRO, slow~requestedRateMicroWluPerSecond, "slow delivery rate"
call assertEq 5 * MICRO, fast~requestedRateMicroWluPerSecond, "accelerated delivery rate"

/* Existing lower-rate work occupies part of the enterprise delivery capacity. */
backgroundDemand = .WLUWorkDemand~new(20 * MICRO, 20 * MICRO, 10) /* 2 WLU/s */
background = auth~reserveDemand("AI_BATCH", "AI:INFERENCE", backgroundDemand, 60, "background")
call assertTrue background~ok, "background reservation"
call assertEq 2 * MICRO, pool~reservedRateMicroWluPerSecond, "background holds throughput"

/* Accelerated work needs 5 WLU/s, but only 3 WLU/s is presently free. */
assessmentResult = auth~assessDemand("AI_GPT", "AI:INFERENCE", fast)
call assertTrue assessmentResult~ok, "assessment returns structured result"
assessment = assessmentResult~value
call assertEq 3 * MICRO, assessment~deliveryAvailableRateMicroWluPerSecond, "available throughput"
call assertEq 2 * MICRO, assessment~deliveryShortfallRateMicroWluPerSecond, "delivery shortfall"
call assertEq 1, assessment~limitingThroughputPoolIds~items, "limiting pool identified"
call assertTrue \assessment~ready, "assessment not ready"

beforeReserved = account~reservedMicroWlu
denied = auth~reserveDemand("AI_GPT", "AI:INFERENCE", fast, 30, "urgent-denied")
call assertTrue \denied~ok, "accelerated request refused before work"
call assertEq "WLU_THROUGHPUT_EXHAUSTED", denied~code, "throughput refusal code"
call assertEq beforeReserved, account~reservedMicroWlu, "failed acceleration has no entitlement side effect"

/* Enterprise option 1: scale out.  A provider/runtime adapter contributes
 * another 2 WLU/s to the same logical capacity pool. */
call assertEq 7 * MICRO, pool~increaseCapacityRate(2 * MICRO), "provider capacity added"
urgent = auth~reserveDemand("AI_GPT", "AI:INFERENCE", fast, 30, "urgent-scaled")
call assertTrue urgent~ok, "accelerated request admitted after scale-out"
call assertEq 5 * MICRO, urgent~value~reservedRateMicroWluPerSecond, "reservation carries delivery promise"
call assertEq 20 * MICRO, urgent~value~expectedMicroWlu, "reservation carries forecast"
call assertEq 25 * MICRO, urgent~value~reservedMicroWlu, "reservation carries work ceiling"
call assertEq 7 * MICRO, pool~reservedRateMicroWluPerSecond, "both jobs consume delivery capacity"

/* Acceleration does not itself create extra WLU.  This task actually used
 * only 18 WLU; its unused work ceiling is released normally. */
settled = auth~settle(urgent~value, 18 * MICRO)
call assertTrue settled~ok, "urgent settlement"
call assertEq 18 * MICRO, account~spentMicroWlu, "only actual work becomes spent WLU"
call assertEq 2 * MICRO, pool~reservedRateMicroWluPerSecond, "delivery capacity returned on settlement"

/* Enterprise option 2: throttle/release other work rather than scale further. */
call assertTrue pool~setCapacityRate(5 * MICRO), "scaled capacity can be reduced after urgent release"
blockedAgain = auth~reserveDemand("AI_GPT", "AI:INFERENCE", fast, 30, "urgent-blocked-again")
call assertTrue \blockedAgain~ok, "background work again prevents full acceleration"
call assertEq "WLU_THROUGHPUT_EXHAUSTED", blockedAgain~code, "throttle scenario refusal"
throttled = auth~changeDeliveryRate(background~value, 0)
call assertTrue throttled~ok, "scheduler throttles background delivery rate"
call assertEq 0, pool~reservedRateMicroWluPerSecond, "background remains admitted but releases delivery capacity"
urgent2 = auth~reserveDemand("AI_GPT", "AI:INFERENCE", fast, 30, "urgent-after-throttle")
call assertTrue urgent2~ok, "urgent request admitted after scheduler frees capacity"
call assertEq 5 * MICRO, pool~reservedRateMicroWluPerSecond, "urgent receives full delivery rate"

/* Live acceleration of an already-admitted job is a rate reshaping operation,
 * not a WLU top-up. */
ignore = auth~release(urgent2~value)
moderate = .WLUWorkDemand~new(20 * MICRO, 25 * MICRO, 10) /* 2 WLU/s */
job = auth~reserveDemand("AI_GPT", "AI:INFERENCE", moderate, 30, "reshape-job")
call assertTrue job~ok, "moderate job admitted"
oldAmount = job~value~reservedMicroWlu
accelerated = auth~changeDeliveryRate(job~value, 5 * MICRO)
call assertTrue accelerated~ok, "live acceleration succeeds with spare throughput"
call assertEq oldAmount, accelerated~value~reservedMicroWlu, "acceleration does not alter work ceiling"
call assertEq 5 * MICRO, accelerated~value~reservedRateMicroWluPerSecond, "new delivery promise bound into proof"
call assertEq 5 * MICRO, pool~reservedRateMicroWluPerSecond, "pool reflects accelerated rate"
ignore = auth~release(accelerated~value)
ignore = auth~release(throttled~value)

say "PASS test_enterprise_acceleration"
exit 0

assertEq: procedure
  use arg expected, actual, label
  if expected \== actual then do
    say "FAIL" label "expected="expected "actual="actual
    exit 1
  end
  return
assertTrue: procedure
  use arg condition, label
  if \condition then do
    say "FAIL" label
    exit 1
  end
  return

::requires "WorkLoadUnits.cls"
