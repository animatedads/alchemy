MICRO = 1000000
clock = .WLUTestTimeSource~new(1000000)
keys = .WLUFastMacKeyRing~new
keys~addKey("hot", "000102030405060708090a0b0c0d0e0f")
auth = .WLUAuthority~new(keys, .WLUMemoryLedger~new, clock)
account = .WLUAccount~new("flylo-shannon", 100 * MICRO)
auth~addAccount(account)
auth~bindAccount("FLYLO_SHANNON", "ABILITY:*", account~accountId)
rate = .WLURateCard~new("ai-common", "2026-08")
rate~addRule(.WLURateRule~new("AI_INPUT_TOKEN", 1000))
rate~addRule(.WLURateRule~new("AI_OUTPUT_TOKEN", 1000))
rate~seal
auth~addRateCard(rate)
auth~bindRateCard("FLYLO_SHANNON", "ABILITY:*", rate~rateCardId, rate~version)
pool = .WLUThroughputPool~new("ai-throughput", 10 * MICRO)
auth~addThroughputPool(pool)
auth~bindThroughputPool("FLYLO_SHANNON", "ABILITY:*", pool~poolId)
importer = .WLUExternalPlanImporter~new(auth)
gemmaPlan = fakePlan("ABILITY:SHANNON.GEMMA", 1000, 500, .nil, 3, 30, "gemma-plan")
grokPlan = fakePlan("ABILITY:SHANNON.GROK", 1200, 1000, 2500000, 2, 45, "grok-plan")
openaiPlan = fakePlan("ABILITY:SHANNON.OPENAI", 1500, 1500, 3500000, 2, 45, "openai-plan")
r = importer~importPlan("FLYLO_SHANNON", "GEMMA", gemmaPlan)
call assertTrue r~ok, "Gemma external plan imports"
gemma = r~value
call assertEq 1500000, gemma~expectedMicroWlu, "Gemma facts valued by WLU rate card"
call assertEq 1500000, gemma~ceilingMicroWlu, "nil external ceiling defaults to WLU quote"
call assertEq 500000, gemma~requestedRateMicroWluPerSecond, "target time becomes WLU/s demand"
call assertEq 30, gemma~ttlSeconds, "external TTL retained"
r = importer~importPlan("FLYLO_SHANNON", "GROK", grokPlan); call assertTrue r~ok, "Grok imports"; grok = r~value
r = importer~importPlan("FLYLO_SHANNON", "OPENAI", openaiPlan); call assertTrue r~ok, "OpenAI imports"; openai = r~value
call assertEq 0, gemmaPlan~invocationCount, "Gemma provider untouched"
call assertEq 0, grokPlan~invocationCount, "Grok provider untouched"
call assertEq 0, openaiPlan~invocationCount, "OpenAI provider untouched"
strategy = .WLUJobPlan~new("flylo.shannon.provider-route", "1")
strategy~addStage(gemma~stage, .true); strategy~addStage(grok~stage); strategy~addStage(openai~stage)
strategy~addFallback("GEMMA", "GROK"); strategy~addFallback("GEMMA", "OPENAI")
call assertTrue strategy~seal~ok, "route seals"
call assertEq 5000000, strategy~strategyCeilingMicroWlu, "alternative rescue paths use max"
request = .WLUJobRequest~new("flylo-api-chat-001", "CHAT-API-001", "FLYLO_SHANNON", "SHANNON:CHAT", strategy, 1500000, 5000000)
manager = .WLUJobBudgetManager~new(auth)
opened = manager~openJob(request); call assertTrue opened~ok, "logical chat opens"; lease = opened~value
reserve = manager~reserveStage(lease, "GEMMA", gemma~ttlSeconds, gemma~requestId); call assertTrue reserve~ok, "Gemma reserves"
lease = reserve~value[1]; gemmaReservation = reserve~value[2]
call assertEq "ai-common", gemmaReservation~rateCardId, "rate card id pinned"
call assertEq "2026-08", gemmaReservation~rateCardVersion, "rate card version pinned"
settled = manager~settleStage(lease, gemmaReservation, 1200000); call assertTrue settled~ok, "Gemma settles"; lease = settled~value
transition = manager~recordTransition(lease, "GEMMA", "GROK", "QUALITY_POLICY", "quality-event:provider-1", .nil, "provider-route-1")
call assertTrue transition~ok, "provider route fallback evidence records"
call assertEq "ai-common", transition~value~rateCardId, "transition keeps target valuation id"
call assertEq "2026-08", transition~value~rateCardVersion, "transition keeps target valuation version"
reserve = manager~reserveStage(lease, "GROK", grok~ttlSeconds, grok~requestId); call assertTrue reserve~ok, "Grok rescue same chat"
lease = reserve~value[1]; grokReservation = reserve~value[2]
settled = manager~settleStage(lease, grokReservation, 2000000); call assertTrue settled~ok, "Grok settles"; lease = settled~value
call assertEq 3200000, lease~spentMicroWlu, "one chat accumulates actual work"
route = manager~routeHistory(lease); call assertTrue route~ok, "provider route evidence available"
call assertEq 5, route~value~items, "provider route has two stage starts, two closes and one transition"
do event over route~value
  call assertTrue event~verify(keys), "provider route event authenticates"
  call assertEq "ai-common", event~rateCardId, "provider route event keeps WLU valuation id"
  call assertEq "2026-08", event~rateCardVersion, "provider route event keeps WLU valuation version"
end
low = fakePlan("ABILITY:SHANNON.GROK", 1200, 1000, 1000000, 2, 30, "too-low")
rejected = importer~importPlan("FLYLO_SHANNON", "LOW", low)
call assertTrue \rejected~ok, "ceiling below quote rejected"
call assertEq "WLU_EXTERNAL_PLAN_CEILING_BELOW_QUOTE", rejected~code, "understated ceiling code"
rejected = importer~importPlan("FLYLO_SHANNON", "BAD", .BrokenExternalPlan~new)
call assertTrue \rejected~ok, "incomplete external plan rejected"
call assertEq "WLU_EXTERNAL_PLAN_CONTRACT_INVALID", rejected~code, "invalid contract code"
say "PASS test_external_execution_plan_import"
exit 0
fakePlan: procedure
  use strict arg scope, inputTokens, outputTokens, ceiling, targetSeconds, ttlSeconds, requestId
  facts = .array~of(.ExternalMeterFact~new("AI_INPUT_TOKEN", inputTokens, "provider-plan"), .ExternalMeterFact~new("AI_OUTPUT_TOKEN", outputTokens, "provider-plan"))
  return .ExternalExecutionPlan~new(scope, facts, ceiling, targetSeconds, ttlSeconds, requestId)
assertTrue: procedure
  use arg condition, label
  if \condition then do; say "FAIL" label; exit 1; end
  return
assertEq: procedure
  use arg expected, actual, label
  if expected \== actual then do; say "FAIL" label "expected="expected "actual="actual; exit 1; end
  return
::class ExternalMeterFact
::attribute factType get
::attribute quantity get
::attribute source get
::attribute dimensions get
::method init
  expose factType quantity source dimensions
  use strict arg factType, quantity, source = ""
  dimensions = .table~new
::class ExternalExecutionPlan
::attribute scope get
::attribute ceilingMicroWlu get
::attribute targetSeconds get
::attribute ttlSeconds get
::attribute requestId get
::attribute invocationCount get
::method init
  expose scope plannedFacts ceilingMicroWlu targetSeconds ttlSeconds requestId invocationCount
  use strict arg scope, plannedFacts, ceilingMicroWlu = .nil, targetSeconds = 0, ttlSeconds = 30, requestId = ""
  invocationCount = 0
::method plannedFacts
  expose plannedFacts
  copy = .array~new
  do fact over plannedFacts; copy~append(fact); end
  return copy
::method invokeProvider
  expose invocationCount
  invocationCount += 1
  return "SHOULD NOT BE CALLED"
::method prompt
  raise syntax 88.900 array("Importer must never inspect prompt content")
::class BrokenExternalPlan
::method scope
  return "ABILITY:BROKEN"
::requires "WLUExternalPlan.cls"
