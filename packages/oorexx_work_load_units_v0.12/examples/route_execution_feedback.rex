/* One chat, one WLU budget, and authenticated evidence of the route actually used. */
MICRO = 1000000
clock = .WLUTestTimeSource~new(1000000)
keys = .WLUFastMacKeyRing~new
keys~addKey("route-demo", "000102030405060708090a0b0c0d0e0f")
auth = .WLUAuthority~new(keys, .WLUMemoryLedger~new, clock)
account = .WLUAccount~new("flylo", 50 * MICRO)
auth~addAccount(account)
auth~bindAccount("FLYLO", "SHANNON:*", account~accountId)
do spec over .array~of("script 20", "gemma 20")
  parse var spec id rate
  pool = .WLUThroughputPool~new(id, rate * MICRO)
  auth~addThroughputPool(pool)
  auth~bindThroughputPool("FLYLO", "SHANNON:" || id~upper, id)
end

plan = .WLUJobPlan~new("shannon.feedback", "1")
plan~addStage(.WLUJobStage~new("SCRIPT", "SHANNON:SCRIPT", 1 * MICRO, 2 * MICRO), .true)
plan~addStage(.WLUJobStage~new("GEMMA", "SHANNON:GEMMA", 4 * MICRO, 6 * MICRO, 1 * MICRO, 1 * MICRO))
plan~addFallback("SCRIPT", "GEMMA")
plan~seal
request = .WLUJobRequest~new("flylo-feedback-1", "CHAT-001", "FLYLO", "SHANNON:CHAT", plan, 6 * MICRO, 15 * MICRO)
manager = .WLUJobBudgetManager~new(auth)
lease = manager~openJob(request)~value

r = manager~reserveStage(lease, "SCRIPT", 30, "script")
lease = r~value[1]; script = r~value[2]
manager~consumeStage(lease, script, 1 * MICRO, "opening")
lease = manager~releaseStage(lease, script)~value

/* Shannon/application policy decides this. WLU records the reason but does
 * not inspect the conversation or decide whether the judgement is correct. */
decision = manager~recordTransition(lease, "SCRIPT", "GEMMA", "QUALITY_POLICY", "quality-event:42", .nil, "fallback-1")
say "fallback reason:" decision~value~reasonCode
say "evidence ref:" decision~value~evidenceRef
say "WLU committed by decision:" lease~committedMicroWlu

r = manager~reserveStage(lease, "GEMMA", 30, "gemma")
lease = r~value[1]; gemma = r~value[2]
clock~advanceSeconds(2)
settled = manager~settleStageBreakdown(lease, gemma, 4 * MICRO, 1 * MICRO, "SUCCESS", "conversation-event:complete")
lease = settled~value[1]
outcome = settled~value[2]
summary = manager~routeSummary(lease)~value

say "same session:" lease~sessionRef
say "job spent WLU:" .WLUUnits~format(lease~spentMicroWlu)
say "Gemma actual work WLU:" .WLUUnits~format(outcome~actualWorkMicroWlu)
say "Gemma handoff WLU:" .WLUUnits~format(outcome~actualHandoffMicroWlu)
say "route transitions:" summary~transitionCount
say "route actual WLU:" .WLUUnits~format(summary~actualMicroWlu)
say "known handoff WLU:" .WLUUnits~format(summary~knownHandoffMicroWlu)

::requires "WLUJobBudget.cls"
