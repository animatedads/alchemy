MICRO = 1000000
clock = .WLUTestTimeSource~new(1000000)
keys = .WLUFastMacKeyRing~new
keys~addKey('hier-job-k1', '000102030405060708090a0b0c0d0e0f')
auth = .WLUAuthority~new(keys, .WLUMemoryLedger~new, clock)
account = .WLUAccount~new('flylo', 100 * MICRO)
auth~addAccount(account)
auth~bindAccount('FLYLO_*', 'SHANNON:*', account~accountId)
do spec over .array~of('script 20', 'gemma 20')
  parse var spec id rate
  pool = .WLUThroughputPool~new(id, rate * MICRO)
  auth~addThroughputPool(pool)
  auth~bindThroughputPool('FLYLO_*', 'SHANNON:' || id~upper, id)
end

hier = .WLUHierarchyBudgetManager~new(keys)
enterprise = hier~createRoot('ENTERPRISE', 'ENTERPRISE', 30 * MICRO)~value
flylo = hier~delegate(enterprise, 'FLYLO', 'TENANT', 20 * MICRO)~value
shannon = hier~delegate(flylo, 'FLYLO.SHANNON', 'SERVICE', 15 * MICRO)~value
chat = hier~delegate(shannon, 'FLYLO.SHANNON.CHAT-001', 'JOB', 12 * MICRO)~value
other = hier~delegate(flylo, 'FLYLO.OTHER', 'SERVICE', 15 * MICRO)~value

plan = .WLUJobPlan~new('shannon.chat', '1')
plan~addStage(.WLUJobStage~new('SCRIPT', 'SHANNON:SCRIPT', 1 * MICRO, 2 * MICRO), .true)
plan~addStage(.WLUJobStage~new('GEMMA', 'SHANNON:GEMMA', 3 * MICRO, 5 * MICRO, 1 * MICRO, 1 * MICRO))
plan~addFallback('SCRIPT', 'GEMMA')
call assertTrue plan~seal~ok, 'plan seals'
request = .WLUJobRequest~new('flylo-chat-001', 'CHAT-001', 'FLYLO_SHANNON', 'SHANNON:CHAT', plan, 5 * MICRO, 12 * MICRO)
manager = .WLUHierarchicalJobManager~new(auth, hier)
opened = manager~openJob(request, chat)
call assertTrue opened~ok, 'job binds to delegated chat budget'
lease = opened~value

/* Forecast evidence travels through the hierarchy bridge but does not reserve
 * parent budget.  A risky projection is information for policy, not a hidden
 * entitlement mutation. */
forecasted = manager~reviseForecast(lease, 5 * MICRO, 13 * MICRO, 8000, 'SHANNON', 'remote rescue is plausible')
call assertTrue forecasted~ok, 'hierarchy bridge records job forecast'
lease = forecasted~value[1]
call assertEq .WLUJobForecastStatus~AT_RISK, forecasted~value[2]~status, 'forecast can exceed delegated job ceiling as warning evidence'
chatBefore = hier~current(chat~nodeId)~value
call assertEq 0, chatBefore~committedMicroWlu, 'forecast consumes no hierarchy budget'
call assertEq 0, chatBefore~spentMicroWlu, 'forecast spends no hierarchy WLU'

r = manager~reserveStage(lease, 'SCRIPT', 60, 'opening')
call assertTrue r~ok, 'script admitted through job and hierarchy'
lease = r~value[1]; script = r~value[2]
call assertEq 2 * MICRO, r~value[3]~committedMicroWlu, 'hierarchy holds same stage ceiling'
used = manager~consumeStage(lease, script, 1 * MICRO, 'script-work')
call assertTrue used~ok, 'script work consumed'
released = manager~releaseStage(lease, script)
call assertTrue released~ok, 'script release preserves actual work in hierarchy'
lease = released~value[1]
chatBudget = released~value[2]
call assertEq 1 * MICRO, chatBudget~spentMicroWlu, 'chat hierarchy records actual script work'

/* Another FlyLo service consumes shared parent headroom.  CHAT still has 11
 * local WLU left, but FlyLo has only 4 available: GEMMA must not reach the
 * core authority when its 6-WLU ceiling is blocked upstream. */
otherNow = hier~current(other~nodeId)~value
bulk = hier~hold(otherNow, 15 * MICRO, 'other-bulk')
call assertTrue bulk~ok, 'other FlyLo workload occupies parent budget'
assessment = manager~assessStage(lease, 'GEMMA')
call assertTrue assessment~ok, 'combined assessment returned'
call assertTrue \assessment~value~viable, 'Gemma blocked by hierarchy'
call assertEq 'FLYLO', assessment~value~hierarchyAssessment~limitingNodeKey, 'FlyLo is limiting ancestor'
call assertEq 2 * MICRO, assessment~value~hierarchyAssessment~shortfallMicroWlu, 'FlyLo shortfall is 2 WLU'
availableBefore = account~availableMicroWlu
blocked = manager~reserveStage(lease, 'GEMMA', 60, 'gemma')
call assertTrue \blocked~ok, 'blocked hierarchy prevents stage reservation'
call assertEq 'WLU_BUDGET_EXHAUSTED', blocked~code, 'hierarchy refusal propagated'
call assertEq availableBefore, account~availableMicroWlu, 'core WLU account untouched on hierarchy denial'

call assertTrue hier~release(bulk~value[2])~ok, 'other workload releases parent headroom'
transition = manager~recordTransition(lease, 'SCRIPT', 'GEMMA', 'QUALITY_POLICY', 'quality-event:hier-1')
call assertTrue transition~ok, 'hierarchy bridge records declared fallback reason without budget mutation'
call assertEq 'QUALITY_POLICY', transition~value~reasonCode, 'transition reason preserved'
r = manager~reserveStage(lease, 'GEMMA', 60, 'gemma')
call assertTrue r~ok, 'Gemma admitted when enterprise hierarchy permits it'
lease = r~value[1]; gemma = r~value[2]
settled = manager~settleStageBreakdown(lease, gemma, 3 * MICRO, 1 * MICRO, 'SUCCESS', 'conversation-event:hier-complete')
call assertTrue settled~ok, 'Gemma settles across both authorities with explicit handoff actual'
lease = settled~value[1]
outcome = settled~value[2]
chatBudget = settled~value[3]
call assertEq 1 * MICRO, outcome~actualHandoffMicroWlu, 'hierarchical settlement retains handoff evidence'
call assertEq 5 * MICRO, lease~spentMicroWlu, 'logical job spent is script + Gemma'
call assertEq 5 * MICRO, chatBudget~spentMicroWlu, 'hierarchy sees same actual job work'
summary = manager~routeSummary(lease)
call assertTrue summary~ok, 'route summary available through hierarchy bridge'
call assertEq 5 * MICRO, summary~value~actualMicroWlu, 'route evidence reconciles to logical-job spend'
call assertEq 1 * MICRO, summary~value~knownHandoffMicroWlu, 'route summary carries known handoff work'
path = hier~path(chatBudget)~value
do node over path
  call assertEq 5 * MICRO, node~spentMicroWlu, 'same five WLU reflected at every ancestor'
end

say 'PASS test_hierarchical_job_budget'
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
