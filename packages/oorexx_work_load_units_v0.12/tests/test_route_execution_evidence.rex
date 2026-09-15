MICRO = 1000000
clock = .WLUTestTimeSource~new(1000000)
keys = .WLUFastMacKeyRing~new
keys~addKey("hot-route", "000102030405060708090a0b0c0d0e0f")
auth = .WLUAuthority~new(keys, .WLUMemoryLedger~new, clock)
account = .WLUAccount~new("flylo-route", 100 * MICRO)
auth~addAccount(account)
auth~bindAccount("FLYLO_ROUTE", "SHANNON:*", account~accountId)
do spec over .array~of("script 20", "gemma 20")
  parse var spec id rate
  pool = .WLUThroughputPool~new(id, rate * MICRO)
  auth~addThroughputPool(pool)
  auth~bindThroughputPool("FLYLO_ROUTE", "SHANNON:" || id~upper, id)
end

plan = .WLUJobPlan~new("shannon.route-evidence", "1")
plan~addStage(.WLUJobStage~new("SCRIPT", "SHANNON:SCRIPT", 1 * MICRO, 2 * MICRO), .true)
plan~addStage(.WLUJobStage~new("GEMMA", "SHANNON:GEMMA", 4 * MICRO, 6 * MICRO, 1 * MICRO, 1 * MICRO))
plan~addFallback("SCRIPT", "GEMMA")
call assertTrue plan~seal~ok, "plan seals"
request = .WLUJobRequest~new("route-chat-1", "CHAT-ROUTE-1", "FLYLO_ROUTE", "SHANNON:CHAT", plan, 6 * MICRO, 20 * MICRO)
manager = .WLUJobBudgetManager~new(auth)
opened = manager~openJob(request)
call assertTrue opened~ok, "job opens"
lease = opened~value

/* Stage admission creates route evidence, but route evidence itself does not
 * alter any budget beyond the real reservation that already happened. */
r = manager~reserveStage(lease, "SCRIPT", 30, "script")
call assertTrue r~ok, "script reserves"
lease = r~value[1]
script = r~value[2]
committed = lease~committedMicroWlu
history = manager~routeHistory(lease)
call assertTrue history~ok, "route history available"
call assertEq 1, history~value~items, "one reservation event"
call assertEq .WLUJobRouteEventType~STAGE_RESERVED, history~value[1]~eventType, "reserve event type"
call assertTrue history~value[1]~verify(keys), "reserve event authenticated"
call assertEq 1, history~value[1]~forecastRevision, "forecast generation pinned at admission"

/* Replaying the same child reservation is idempotent at the logical-job
 * layer too: no duplicate commitment and no duplicate route event. */
replay = manager~reserveStage(lease, "SCRIPT", 30, "script")
call assertTrue replay~ok, "stage reservation replay succeeds"
lease = replay~value[1]
call assertEq committed, lease~committedMicroWlu, "replay does not double commit"
history = manager~routeHistory(lease)
call assertEq 1, history~value~items, "replay does not duplicate route evidence"

manager~consumeStage(lease, script, 1 * MICRO, "script-work")
clock~advanceSeconds(1)
released = manager~releaseStage(lease, script)
call assertTrue released~ok, "script releases"
lease = released~value

/* Application policy says the deterministic opening is not enough. WLU only
 * authenticates that declared reason; it does not inspect conversation text
 * or decide whether the quality judgement was correct. */
standby = manager~standbyStage(lease, "GEMMA", 60, 700, "rescue-standby")
call assertTrue standby~ok, "Gemma standby exists"
transition = manager~recordTransition(lease, "SCRIPT", "GEMMA", "QUALITY_POLICY", "quality-event:42", standby~value, "transition-1")
call assertTrue transition~ok, "declared fallback recorded"
call assertTrue transition~value~verify(keys), "transition authenticated"
call assertEq standby~value~standbyId, transition~value~standbyId, "standby lineage retained"
call assertEq "quality-event:42", transition~value~evidenceRef, "external evidence reference retained"
call assertEq 0, lease~committedMicroWlu, "transition itself reserves no WLU"
replayedTransition = manager~recordTransition(lease, "SCRIPT", "GEMMA", "QUALITY_POLICY", "quality-event:42", standby~value, "transition-1")
call assertTrue replayedTransition~ok, "route decision replay succeeds"
call assertEq transition~value~routeRevision, replayedTransition~value~routeRevision, "route replay returns same evidence"
history = manager~routeHistory(lease)
call assertEq 3, history~value~items, "route replay does not duplicate evidence"
conflictTransition = manager~recordTransition(lease, "SCRIPT", "GEMMA", "PROVIDER_FAILURE", "quality-event:42", standby~value, "transition-1")
call assertTrue \conflictTransition~ok, "route idempotency conflict rejected"
call assertEq "WLU_ROUTE_IDEMPOTENCY_CONFLICT", conflictTransition~code, "route idempotency conflict code"

bad = manager~recordTransition(lease, "GEMMA", "SCRIPT", "APPLICATION_POLICY")
call assertTrue \bad~ok, "undeclared reverse transition rejected"
call assertEq "WLU_ROUTE_TRANSITION_UNDECLARED", bad~code, "undeclared transition code"

clock~advanceSeconds(1)
promoted = manager~promoteStandby(lease, standby~value, 30, "gemma-promote")
call assertTrue promoted~ok, "standby promotes"
lease = promoted~value[1]
gemma = promoted~value[2]
promotedStandby = promoted~value[3]
call assertEq .WLUJobStandbyState~PROMOTED, promotedStandby~state, "standby marked promoted"

/* Change the forecast after admission. The eventual stage outcome must still
 * carry the forecast revision that existed when this execution was admitted. */
forecast = manager~reviseForecast(lease, 8 * MICRO, 10 * MICRO, 8000, "SHANNON", "rescue is now likely")
call assertTrue forecast~ok, "forecast revises"
lease = forecast~value[1]
call assertEq 2, forecast~value[2]~forecastRevision, "new forecast is revision two"

clock~advanceSeconds(2)
settled = manager~settleStageBreakdown(lease, gemma, 4 * MICRO, 1 * MICRO, "SUCCESS", "conversation-event:complete")
call assertTrue settled~ok, "Gemma settles with work/handoff breakdown"
lease = settled~value[1]
outcome = settled~value[2]
call assertEq 5 * MICRO, outcome~actualTotalMicroWlu, "actual total includes handoff"
call assertEq 1 * MICRO, outcome~actualHandoffMicroWlu, "handoff actual preserved"
call assertTrue outcome~breakdownKnown, "breakdown marked known"
call assertEq 1, outcome~forecastRevision, "outcome keeps admission-time forecast generation"
call assertEq standby~value~standbyId, outcome~standbyId, "outcome keeps promoted standby lineage"
call assertEq "SUCCESS", outcome~reasonCode, "application outcome code preserved"
call assertEq "DIRECT", outcome~rateCardId, "valuation id preserved"
call assertEq "1", outcome~rateCardVersion, "valuation version preserved"
call assertTrue outcome~verify(keys), "outcome authenticated"

history = manager~routeHistory(lease)
call assertTrue history~ok, "final route history available"
call assertEq 5, history~value~items, "route has reserve/release/transition/reserve/settle evidence"
do event over history~value
  call assertTrue event~verify(keys), "every route event authenticates"
end
summary = manager~routeSummary(lease)
call assertTrue summary~ok, "route summary derives"
call assertEq 5, summary~value~eventCount, "summary event count"
call assertEq 1, summary~value~transitionCount, "summary transition count"
call assertEq 2, summary~value~stageReservationCount, "summary reservation count"
call assertEq 2, summary~value~stageCloseCount, "summary close count"
call assertEq 6 * MICRO, summary~value~actualMicroWlu, "summary actual WLU equals job spend"
call assertEq 1 * MICRO, summary~value~knownHandoffMicroWlu, "summary known handoff WLU"
call assertEq 0, summary~value~overExpectedCount, "both stages stayed within expected WLU"
call assertEq 6 * MICRO, lease~spentMicroWlu, "logical job spent amount coherent"

say "PASS test_route_execution_evidence"
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
