/* Acceptance for AnthropicCapabilitySelector -- no network required. */

sel = .AnthropicCapabilitySelector~new

/* 1. Low-tier, high-volume, batch-ok, no zone constraint: must NOT pick
 *    Fable/Opus. It should pick the cheapest ECONOMY-or-above model, which
 *    given the placeholder rate card is Haiku. */
p1 = .AnthropicWorkloadProfile~new("LOW", "ANY", .true, 500000, 20000, .nil)
plan1 = sel~selectModel(p1)
if plan1~modelId \= "claude-haiku-4-5-20251001" then
  raise syntax 88.900 array("FAIL: low-tier batch workload did not select the cheapest eligible model, got" plan1~modelId)
if \plan1~useBatch then
  raise syntax 88.900 array("FAIL: batch-ok workload did not route to batch")
say "PASS low-tier workload -> " plan1~modelId "(" plan1~channelId "," plan1~region ") batch=" plan1~useBatch "est=" plan1~estimatedMicroUsd "micro-USD"

/* 2. Same workload but tier floor RESEARCH: now it MUST escalate, because
 *    the workload itself says it needs research-tier capability -- this
 *    proves the selector escalates on genuine need, not by default. */
p2 = .AnthropicWorkloadProfile~new("RESEARCH", "ANY", .false, 500000, 20000, .nil)
plan2 = sel~selectModel(p2)
if plan2~modelId \= "claude-fable-5" then
  raise syntax 88.900 array("FAIL: research-tier workload did not escalate, got" plan2~modelId)
say "PASS research-tier workload -> " plan2~modelId "est=" plan2~estimatedMicroUsd "micro-USD"

/* 3. EU data-sovereignty requirement: the winning channel must NOT be the
 *    US-only direct channel, even though direct is cheapest/available. */
p3 = .AnthropicWorkloadProfile~new("STANDARD", "EU", .false, 2000, 500, .nil)
plan3 = sel~selectModel(p3)
if plan3~channelKind = "DIRECT" then
  raise syntax 88.900 array("FAIL: EU-required workload was routed to the US-only direct channel")
if plan3~region = "" then
  raise syntax 88.900 array("FAIL: EU-required workload has no region on its routing plan")
say "PASS EU-sovereign workload -> " plan3~modelId "on" plan3~channelId "(region=" plan3~region")"

/* 4. A FRONTIER-tier workload that ALSO requires EU: Opus is available on
 *    Bedrock Frankfurt in the catalog, so this must land there -- genuine
 *    capability need AND sovereignty both satisfied, never a silent leak
 *    to the US-only direct channel. */
p4 = .AnthropicWorkloadProfile~new("FRONTIER", "EU", .false, 5000, 1000, .nil)
plan4 = sel~selectModel(p4)
if plan4~channelKind = "DIRECT" then
  raise syntax 88.900 array("FAIL: FRONTIER+EU workload leaked to the direct channel")
if plan4~modelId \= "claude-opus-4-8" then
  raise syntax 88.900 array("FAIL: FRONTIER+EU workload did not select the expected model, got" plan4~modelId)
say "PASS FRONTIER+EU workload -> " plan4~modelId "on" plan4~channelId

/* 4b. RESEARCH-tier (Fable) is direct-only in the catalog -- there is
 *     honestly no EU option for it yet, so a RESEARCH+EU workload must
 *     raise rather than silently downgrade the required capability floor
 *     or silently ignore the sovereignty requirement. */
p4b = .AnthropicWorkloadProfile~new("RESEARCH", "EU", .false, 5000, 1000, .nil)
signal on syntax name researchEuRaised
sel~selectModel(p4b)
raise syntax 88.900 array("FAIL: RESEARCH+EU workload should have been unsatisfiable given the catalog, but selectModel returned a plan")
researchEuRaised:
signal off syntax
say "PASS RESEARCH+EU workload correctly and honestly unsatisfiable (Fable has no EU channel yet)"

/* 5. Cost ceiling: an artificially low ceiling should make an otherwise
 *    eligible high-tier request unsatisfiable and raise, rather than
 *    silently substituting something over budget. */
p5 = .AnthropicWorkloadProfile~new("RESEARCH", "ANY", .false, 5000000, 500000, 1)
signal on syntax name ceilingRaised
sel~selectModel(p5)
raise syntax 88.900 array("FAIL: over-ceiling workload did not raise")
ceilingRaised:
signal off syntax
say "PASS over-ceiling workload correctly unsatisfiable"

/* 6. rankCandidates exposes the full cost-ordered tradeoff, not just the
 *    winner, and it is genuinely sorted. */
p6 = .AnthropicWorkloadProfile~new("STANDARD", "ANY", .false, 10000, 2000, .nil)
ranked = sel~rankCandidates(p6)
if ranked~items < 2 then
  raise syntax 88.900 array("FAIL: expected multiple ranked candidates")
do i = 1 to ranked~items - 1
  if ranked[i]~estimatedMicroUsd > ranked[i + 1]~estimatedMicroUsd then
    raise syntax 88.900 array("FAIL: rankCandidates is not sorted ascending by cost")
end
say "PASS rankCandidates returned" ranked~items "candidates, sorted ascending"

/* 7. Cost query for a job id: nothing recorded yet -> nil; after
 *    recordJobCost -> the record comes back correctly. */
if sel~queryJobCost("no-such-job") \== .nil then
  raise syntax 88.900 array("FAIL: queryJobCost returned a record for an unknown job")
sel~recordJobCost("job-123", "claude-sonnet-5", 42000, .nil, "SUBMITTED")
rec = sel~queryJobCost("job-123")
if rec == .nil then raise syntax 88.900 array("FAIL: queryJobCost did not find a recorded job")
if rec["estimated_micro_usd"] \= 42000 then raise syntax 88.900 array("FAIL: queryJobCost returned wrong estimate")
if rec["status"] \= "SUBMITTED" then raise syntax 88.900 array("FAIL: queryJobCost returned wrong status")
say "PASS queryJobCost round-trips a recorded job"

/* 8. Batch halves cost relative to real-time for a batch-eligible model. */
rt = sel~estimateCost("claude-sonnet-5", 1000000, 1000000, .false)
bt = sel~estimateCost("claude-sonnet-5", 1000000, 1000000, .true)
if bt \= (rt % 2) then
  raise syntax 88.900 array("FAIL: batch cost is not half of real-time cost, rt=" rt "bt=" bt)
say "PASS batch pricing is half of real-time (" rt "->" bt ")"

say "ALL PASS test_capability_selector"
exit 0

::requires "AnthropicProvider.cls"
