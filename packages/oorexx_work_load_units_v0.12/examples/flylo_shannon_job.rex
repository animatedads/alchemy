/* FlyLo Air borrows Shannon: one user-visible conversation, several possible
 * execution implementations, one WLU budget. */
MICRO = 1000000

keys = .WLUFastMacKeyRing~new
ignore = keys~addKey("demo", "000102030405060708090a0b0c0d0e0f")
auth = .WLUAuthority~new(keys)
acct = .WLUAccount~new("flylo-shannon", 100 * MICRO)
auth~addAccount(acct)
auth~bindAccount("FLYLO_*", "SHANNON:*", acct~accountId)

do id over .array~of("SCRIPT", "GEMMA", "GROK", "OPENAI")
  pool = .WLUThroughputPool~new(id, 20 * MICRO)
  auth~addThroughputPool(pool)
  auth~bindThroughputPool("FLYLO_*", "SHANNON:" || id, id)
end

plan = .WLUJobPlan~new("shannon.conversation", "2026-08")
ignore = plan~addStage(.WLUJobStage~new("SCRIPT", "SHANNON:SCRIPT", 1*MICRO, 2*MICRO), .true)
ignore = plan~addStage(.WLUJobStage~new("GEMMA", "SHANNON:GEMMA", 4*MICRO, 6*MICRO, 1*MICRO, 1*MICRO))
ignore = plan~addStage(.WLUJobStage~new("GROK", "SHANNON:GROK", 7*MICRO, 9*MICRO, 1*MICRO, 2*MICRO))
ignore = plan~addStage(.WLUJobStage~new("OPENAI", "SHANNON:OPENAI", 9*MICRO, 12*MICRO, 2*MICRO, 3*MICRO))
ignore = plan~addFallback("SCRIPT", "GEMMA")
ignore = plan~addFallback("GEMMA", "GROK")
ignore = plan~addFallback("GEMMA", "OPENAI")
ignore = plan~seal

request = .WLUJobRequest~new("flylo-chat-42", "CHAT-42", "FLYLO_SHANNON", "SHANNON:CHAT", plan, 8*MICRO, 20*MICRO)
manager = .WLUJobBudgetManager~new(auth)
opened = manager~openJob(request)
if \opened~ok then do; say opened~code opened~detail; exit 1; end
lease = opened~value
say "session=" lease~sessionRef "budget=" .WLUUnits~format(lease~budgetMicroWlu) "coverage=" lease~coverage
say "declared-strategy-ceiling=" .WLUUnits~format(lease~strategyCeilingMicroWlu)

/* Application quality logic decides when escalation is needed.  WLU only
 * decides whether declared routes remain admissible. */
first = manager~reserveStage(lease, "SCRIPT", 60, "opening")
lease = first~value[1]; script = first~value[2]
ignore = manager~consumeStage(lease, script, 1*MICRO, "opening-work")

/* Make-before-break: reserve replacement before dropping old execution. */
second = manager~reserveStage(lease, "GEMMA", 60, "gemma")
lease = second~value[1]; gemma = second~value[2]
lease = manager~releaseStage(lease, script)~value
lease = manager~settleStage(lease, gemma, 5*MICRO)~value

say "after Gemma: spent=" .WLUUnits~format(lease~spentMicroWlu) "remaining=" .WLUUnits~format(lease~remainingMicroWlu)
options = manager~fallbackOptions(lease, "GEMMA")~value
do option over options
  say option~stageId "viable=" option~viable "stage-ceiling=" .WLUUnits~format(option~stageCeilingMicroWlu) "budget-shortfall=" .WLUUnits~format(option~budgetShortfallMicroWlu)
end
exit 0

::requires "WLUJobBudget.cls"
