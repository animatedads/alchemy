MICRO = 1000000
clock = .WLUTestTimeSource~new(1000000)
keys = .WLUFastMacKeyRing~new
ignore = keys~addKey("hot-forecast", "000102030405060708090a0b0c0d0e0f")
auth = .WLUAuthority~new(keys, .WLUMemoryLedger~new, clock)

account = .WLUAccount~new("flylo-forecast", 100 * MICRO)
auth~addAccount(account)
auth~bindAccount("FLYLO_*", "SHANNON:*", account~accountId)
pool = .WLUThroughputPool~new("shannon", 20 * MICRO)
auth~addThroughputPool(pool)
auth~bindThroughputPool("FLYLO_*", "SHANNON:*", pool~poolId)

plan = .WLUJobPlan~new("shannon.live.forecast", "2026-08")
ignore = plan~addStage(.WLUJobStage~new("SCRIPT", "SHANNON:SCRIPT", 1 * MICRO, 2 * MICRO), .true)
ignore = plan~addStage(.WLUJobStage~new("GEMMA", "SHANNON:GEMMA", 4 * MICRO, 6 * MICRO, 1 * MICRO, 1 * MICRO))
ignore = plan~addFallback("SCRIPT", "GEMMA")
call assertTrue plan~seal~ok, "forecast plan seals"

request = .WLUJobRequest~new("flylo-forecast-chat", "CHAT-FORECAST", "FLYLO_SHANNON", "SHANNON:CHAT", plan, 8 * MICRO, 20 * MICRO)
manager = .WLUJobBudgetManager~new(auth)
opened = manager~openJob(request)
call assertTrue opened~ok, "forecast job opens"
lease0 = opened~value
call assertEq 20 * MICRO, lease0~budgetMicroWlu, "hard job budget"
call assertEq 8 * MICRO, lease0~forecastProjectedExpectedMicroWlu, "initial projected expected total"
call assertEq .WLUJobForecastStatus~WITHIN_BUDGET, lease0~forecastStatus, "initial forecast within budget"

initialResult = manager~forecast(lease0)
call assertTrue initialResult~ok, "initial forecast readable"
initial = initialResult~value
call assertEq 1, initial~forecastRevision, "initial forecast revision"
call assertTrue initial~verify(keys), "initial forecast has valid MAC proof"
call assertEq "INITIAL", initial~trend, "initial trend"

/* The estimator becomes more cautious but still believes the job fits. */
r1 = manager~reviseForecast(lease0, 10 * MICRO, 19 * MICRO, 7500, "SHANNON", "conversation is less deterministic than opening classification")
call assertTrue r1~ok, "within-budget forecast revision accepted"
lease1 = r1~value[1]
f1 = r1~value[2]
call assertEq .WLUJobForecastStatus~WITHIN_BUDGET, f1~status, "upper band still fits"
call assertEq "HIGHER", f1~trend, "projected expected total rose"
call assertEq 10 * MICRO, f1~projectedExpectedMicroWlu, "revised expected total"
call assertEq 19 * MICRO, f1~projectedUpperMicroWlu, "revised upper total"
call assertEq 7500, f1~confidenceBasisPoints, "estimator confidence retained"
call assertEq 20 * MICRO, lease1~budgetMicroWlu, "forecast does not alter hard budget"
call assertEq 0, account~reservedMicroWlu, "forecast creates no WLU reservation"

stale = manager~forecast(lease0)
call assertTrue \stale~ok, "forecast revision stales old authenticated job lease"
call assertEq "WLU_JOB_LEASE_STALE", stale~code, "stale lease code"

/* Execute real work.  The old forecast remains an observation at its original
 * tick; the current lease can infer how much of that projected total remains
 * after authoritative spend is known. */
r = manager~reserveStage(lease1, "SCRIPT", 60, "script")
call assertTrue r~ok, "script reserves despite independent forecast"
lease2 = r~value[1]
scriptReservation = r~value[2]
settled = manager~settleStage(lease2, scriptReservation, 1 * MICRO)
call assertTrue settled~ok, "script settles"
lease3 = settled~value
call assertEq 1 * MICRO, lease3~spentMicroWlu, "actual work is authoritative"
call assertEq 10 * MICRO, lease3~forecastProjectedExpectedMicroWlu, "forecast total does not drift merely because work settles"
call assertEq 9 * MICRO, lease3~forecastInferredExpectedRemainingMicroWlu, "lease infers remaining forecast from actual spend"

/* Shannon now sees a credible rescue tail beyond the hard budget.  This is
 * accepted as evidence: hiding a bad forecast would defeat early warning. */
r2 = manager~reviseForecast(lease3, 10 * MICRO, 22 * MICRO, 8000, "SHANNON", "Gemma quality trend may require remote rescue and history replay")
call assertTrue r2~ok, "at-risk forecast is recorded rather than rejected"
lease4 = r2~value[1]
f2 = r2~value[2]
call assertEq .WLUJobForecastStatus~AT_RISK, f2~status, "upper band crosses budget"
call assertEq 0, f2~expectedShortfallMicroWlu, "expected case still fits"
call assertEq 3 * MICRO, f2~upperShortfallMicroWlu, "upper risk shortfall exposed"
call assertEq 20 * MICRO, lease4~budgetMicroWlu, "risk forecast still cannot enlarge entitlement"
call assertEq 19 * MICRO, lease4~remainingMicroWlu, "hard remaining budget unaffected by forecast"

/* Forecast risk is advisory.  A stage that still fits the hard budget and live
 * runtime capacity may be admitted; policy/scheduler decides whether to do so. */
r = manager~reserveStage(lease4, "GEMMA", 60, "gemma")
call assertTrue r~ok, "at-risk forecast does not silently become an admission veto"
lease5 = r~value[1]
gemmaReservation = r~value[2]
call assertEq 7 * MICRO, lease5~committedMicroWlu, "hard stage ceiling committed normally"
released = manager~releaseStage(lease5, gemmaReservation)
call assertTrue released~ok, "unused stage commitment can release"
lease6 = released~value

/* The expected case itself can cross the budget.  Again, record the bad news;
 * do not manufacture entitlement and do not suppress the observation. */
r3 = manager~reviseForecast(lease6, 21 * MICRO, 24 * MICRO, 9000, "SHANNON", "remote escalation now expected")
call assertTrue r3~ok, "expected-over-budget forecast accepted as evidence"
lease7 = r3~value[1]
f3 = r3~value[2]
call assertEq .WLUJobForecastStatus~EXPECTED_OVER_BUDGET, f3~status, "expected case crosses budget"
call assertEq 2 * MICRO, f3~expectedShortfallMicroWlu, "expected budget shortfall exposed"
call assertEq 5 * MICRO, f3~upperShortfallMicroWlu, "upper budget shortfall exposed"
call assertEq 20 * MICRO, lease7~budgetMicroWlu, "forecast still grants zero additional WLU"
call assertEq 1 * MICRO, lease7~spentMicroWlu, "forecast still spends zero WLU"

historyResult = manager~forecastHistory(lease7)
call assertTrue historyResult~ok, "forecast history readable"
history = historyResult~value
call assertEq 4, history~items, "initial plus three estimator revisions retained"
do item over history
  call assertTrue item~verify(keys), "every forecast history record is authenticated"
end

/* A forged history object with a copied proof is rejected. */
forged = .WLUJobForecastRevision~new(f3~jobId, f3~forecastRevision, f3~observedTick, f3~spentMicroWlu, f3~committedMicroWlu, f3~budgetMicroWlu, 1 * MICRO, f3~upperRemainingMicroWlu, f3~confidenceBasisPoints, f3~source, f3~reason, f3~previousProjectedExpectedMicroWlu, f3~proof)
call assertTrue \forged~verify(keys), "forecast proof binds forecast quantities"

invalid = manager~reviseForecast(lease7, 1 * MICRO, 2 * MICRO, 10001, "SHANNON", "invalid confidence")
call assertTrue \invalid~ok, "invalid confidence rejected"
call assertEq "WLU_FORECAST_INVALID", invalid~code, "forecast validation code"
call assertTrue manager~forecast(lease7)~ok, "failed forecast revision does not stale valid lease"

say "PASS test_live_forecast"
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

::requires "WLUJobBudget.cls"
