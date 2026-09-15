MICRO = 1000000
clock = .WLUTestTimeSource~new(1000000)
keys = .WLUFastMacKeyRing~new
ignore = keys~addKey("hot-job", "000102030405060708090a0b0c0d0e0f")
auth = .WLUAuthority~new(keys, .WLUMemoryLedger~new, clock)

account = .WLUAccount~new("flylo-shannon", 100 * MICRO)
auth~addAccount(account)
auth~bindAccount("FLYLO_*", "SHANNON:*", account~accountId)

/* Distinct backend capacity pools.  They are execution resources, not job
 * budgets, and all stages still spend from the same business-job envelope. */
do spec over .array~of("script 20", "gemma 10", "grok 10", "openai 10")
  parse var spec id rate
  pool = .WLUThroughputPool~new(id, rate * MICRO)
  auth~addThroughputPool(pool)
  auth~bindThroughputPool("FLYLO_*", "SHANNON:" || id~upper, id)
end

plan = .WLUJobPlan~new("shannon.conversation", "2026-08")
ignore = plan~addStage(.WLUJobStage~new("SCRIPT", "SHANNON:SCRIPT", 1 * MICRO, 2 * MICRO), .true)
/* Gemma entry includes explicit conversation-state construction from the
 * deterministic opening script. */
ignore = plan~addStage(.WLUJobStage~new("GEMMA", "SHANNON:GEMMA", 4 * MICRO, 6 * MICRO, 1 * MICRO, 1 * MICRO))
/* Remote rescue paths explicitly include history replay / context migration. */
ignore = plan~addStage(.WLUJobStage~new("GROK", "SHANNON:GROK", 7 * MICRO, 9 * MICRO, 1 * MICRO, 2 * MICRO))
ignore = plan~addStage(.WLUJobStage~new("OPENAI", "SHANNON:OPENAI", 9 * MICRO, 12 * MICRO, 2 * MICRO, 3 * MICRO))
ignore = plan~addFallback("SCRIPT", "GEMMA")
ignore = plan~addFallback("GEMMA", "GROK")
ignore = plan~addFallback("GEMMA", "OPENAI")
sealed = plan~seal
call assertTrue sealed~ok, "plan seals"
call assertEq 24 * MICRO, plan~strategyCeilingMicroWlu, "worst credible fallback path"

/* 20 WLU admits the conversation but does not promise every rescue route. */
request = .WLUJobRequest~new("flylo-chat-001", "CHAT-001", "FLYLO_SHANNON", "SHANNON:CHAT", plan, 8 * MICRO, 20 * MICRO)
call assertEq .WLUJobCoverage~PARTIAL, request~coverage, "request exposes partial fallback coverage"
fullRequest = .WLUJobRequest~new("flylo-chat-full", "CHAT-FULL", "FLYLO_SHANNON", "SHANNON:CHAT", plan, 8 * MICRO, 24 * MICRO)
call assertEq .WLUJobCoverage~FULL, fullRequest~coverage, "24 WLU explicitly protects every declared fallback path"
manager = .WLUJobBudgetManager~new(auth)
opened = manager~openJob(request)
call assertTrue opened~ok, "logical chat opens"
lease = opened~value
call assertEq "CHAT-001", lease~sessionRef, "same user-visible session retained"
call assertEq 20 * MICRO, lease~remainingMicroWlu, "whole chat budget initially available"

/* Cheap deterministic opening. */
r = manager~reserveStage(lease, "SCRIPT", 60, "opening")
call assertTrue r~ok, "script stage reserved"
lease = r~value[1]; scriptReservation = r~value[2]
call assertEq 2 * MICRO, lease~committedMicroWlu, "stage ceiling carved from parent budget"
used = manager~consumeStage(lease, scriptReservation, 1 * MICRO, "opening-work")
call assertTrue used~ok, "script work recorded"

/* Conversation is not going well.  Reserve Gemma BEFORE dropping the old
 * execution path: make-before-break escalation. */
r = manager~reserveStage(lease, "GEMMA", 60, "gemma-1")
call assertTrue r~ok, "Gemma stage pre-reserved while script remains active"
lease = r~value[1]; gemmaReservation = r~value[2]
call assertEq 9 * MICRO, lease~committedMicroWlu, "both stage ceilings coexist during handoff"
call assertEq 7 * MICRO, gemmaReservation~reservedMicroWlu, "Gemma child includes handoff allowance"
released = manager~releaseStage(lease, scriptReservation)
call assertTrue released~ok, "old stage releases after replacement admission"
lease = released~value
call assertEq 1 * MICRO, lease~spentMicroWlu, "consumed script work retained through release"
call assertEq 7 * MICRO, lease~committedMicroWlu, "only Gemma remains committed"

settled = manager~settleStage(lease, gemmaReservation, 5 * MICRO)
call assertTrue settled~ok, "Gemma settles"
lease = settled~value
call assertEq 6 * MICRO, lease~spentMicroWlu, "script and Gemma are one parent spend"
call assertEq 14 * MICRO, lease~remainingMicroWlu, "remaining rescue budget"

/* Gemma still cannot finish satisfactorily.  The scheduler can inspect the
 * declared alternatives before touching either remote provider. */
optionsResult = manager~fallbackOptions(lease, "GEMMA")
call assertTrue optionsResult~ok, "fallback options assessed"
options = optionsResult~value
call assertEq 2, options~items, "two declared rescue implementations"

grok = optionById(options, "GROK")
openai = optionById(options, "OPENAI")
call assertTrue grok~viable, "Grok fits remaining budget and live capacity"
call assertEq 0, grok~budgetShortfallMicroWlu, "Grok has no parent-budget shortfall"
call assertTrue \openai~viable, "OpenAI rescue is not admissible under this job budget"
call assertEq 1 * MICRO, openai~budgetShortfallMicroWlu, "OpenAI shortfall includes its history handoff ceiling"

/* Choose Grok.  The user-visible CHAT-001 remains the same logical job. */
r = manager~reserveStage(lease, "GROK", 60, "rescue")
call assertTrue r~ok, "Grok rescue reserves under same chat budget"
lease = r~value[1]; grokReservation = r~value[2]
call assertEq 11 * MICRO, lease~committedMicroWlu, "Grok work plus handoff committed"
call assertEq 3 * MICRO, lease~remainingMicroWlu, "budget remains globally coherent"
settled = manager~settleStage(lease, grokReservation, 9 * MICRO)
call assertTrue settled~ok, "Grok rescue settles"
lease = settled~value
call assertEq 15 * MICRO, lease~spentMicroWlu, "one chat accumulates actual work across implementations"
call assertEq 5 * MICRO, lease~remainingMicroWlu, "unused rescue ceiling returned"

/* A forged/stale parent lease cannot be used to mint another child. */
stale = manager~reserveStage(opened~value, "SCRIPT", 60, "stale")
call assertTrue \stale~ok, "stale job lease rejected"
call assertEq "WLU_JOB_LEASE_STALE", stale~code, "stale budget code"

say "PASS test_job_budget_escalation"
exit 0

optionById: procedure
  use arg options, wanted
  do option over options
    if option~stageId = wanted then return option
  end
  return .nil

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
