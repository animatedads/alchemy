/* Deterministic test for Grok Batch WLU planner — long horizon, distinct facts. */
root = arg(1)
if root = "" then root = "."
call main root
exit 0

main:
  procedure
  use arg root
  say "GROK BATCH WLU PLANNER V0.4 START"
  call eq "0.12", .GrokBatchWLUBuild~WLU_VERSION, "WLU v0.12 qualification"

  policy = .GrokBatchModelPolicy~new(.array~of("fixture-model"), 32, 10, 10000)
  budget = .GrokBatchTokenBudgetPolicy~new(1, 8, 86400, 90000, 0)
  estimator = .GrokBatchConservativeTokenEstimator~new(budget)
  planner = .GrokBatchWLUPlanner~new(policy, estimator, budget)
  plannerAdoption = .AlchemyAdoptionVerifier~verify(planner, "STANDARD")
  estimatorAdoption = .AlchemyAdoptionVerifier~verify(estimator, "STANDARD")
  call yes plannerAdoption~ok, "batch planner Alchemy v0.8 STANDARD adoption"
  call yes estimatorAdoption~ok, "batch estimator Alchemy v0.8 STANDARD adoption"
  call eq 0, plannerAdoption~warnings~items, "batch planner adoption warnings"
  call eq 0, estimatorAdoption~warnings~items, "batch estimator adoption warnings"
  call eq "INIT", plannerAdoption~evidence["construction_provenance"]["entrypoint"], "batch planner preferred construction"
  call eq "INIT", estimatorAdoption~evidence["construction_provenance"]["entrypoint"], "batch estimator preferred construction"

  /* Fake descriptor with abilityId */
  descriptor = .directory~new
  descriptor~abilityId = "ai.batch.add"

  body = .directory~new
  body["batch_id"] = "batch-test-1"
  reqs = .array~new
  r1 = .directory~new
  r1["model"] = "fixture-model"
  r1["prompt"] = "hello batch"   /* 11 bytes * 1 + 8 overhead = 19 */
  r1["max_output_tokens"] = 10
  reqs~append(r1)
  r2 = .directory~new
  r2["model"] = "fixture-model"
  r2["prompt"] = "second"
  r2["max_output_tokens"] = 5
  reqs~append(r2)
  body["requests"] = reqs

  outcome = planner~planAddRequests(.nil, descriptor, body)
  call yes outcome~ok, "batch add plan ok"
  plan = outcome~value
  call eq 86400, plan~targetSeconds, "batch target is 24h class"
  call eq 90000, plan~ttlSeconds, "batch TTL is long horizon"
  facts = plan~plannedFacts
  call eq 3, facts~items, "three batch facts"
  call eq "AI_BATCH_REQUEST", facts[1]~factType, "request count fact"
  call eq 2, facts[1]~quantity, "two requests"
  call eq "AI_BATCH_INPUT_TOKEN", facts[2]~factType, "input token fact"
  call eq "AI_BATCH_OUTPUT_TOKEN", facts[3]~factType, "output token fact"
  call eq 15, facts[3]~quantity, "sum of max outputs"

  /* Model not allowed denied before any credential concept */
  bad = .directory~new
  bad["model"] = "not-allowed"
  bad["prompt"] = "x"
  bad["max_output_tokens"] = 1
  body2 = .directory~new
  body2["requests"] = .array~of(bad)
  denied = planner~planAddRequests(.nil, descriptor, body2)
  call no denied~ok, "unlisted model rejected by batch planner"
  call eq "AI_PROVIDER_MODEL_NOT_ALLOWED", denied~code, "model not allowed code"

  /* Request count ceiling */
  many = .array~new
  do i = 1 to 11
    r = .directory~new
    r["model"] = "fixture-model"
    r["prompt"] = "p"
    r["max_output_tokens"] = 1
    many~append(r)
  end
  body3 = .directory~new
  body3["requests"] = many
  limited = planner~planAddRequests(.nil, descriptor, body3)
  call no limited~ok, "request count ceiling enforced"
  call eq "AI_BATCH_REQUESTS_LIMIT", limited~code, "requests limit code"

  /* Create-batch lightweight plan */
  createOutcome = planner~planCreateBatch(.nil, descriptor, .directory~new)
  call yes createOutcome~ok, "create plan ok"
  createPlan = createOutcome~value
  call eq 1, createPlan~plannedFacts~items, "single create fact"
  call eq "AI_BATCH_CREATE", createPlan~plannedFacts[1]~factType, "create fact type"
  call eq 86400, createPlan~targetSeconds, "create also long horizon"

  say "  batch_target_seconds=86400"
  say "  batch_ttl_seconds=90000"
  say "  batch_requested_rate=0"
  say "GROK BATCH WLU PLANNER V0.4: OK"
  return

eq:
  procedure
  use arg expected, actual, label
  if expected \== actual then do
    say "FAILED:" label
    say " expected=" expected
    say " actual=" actual
    exit 71
  end
  return

yes:
  procedure
  use arg value, label
  if \value then do; say "FAILED:" label; exit 73; end
  return

no:
  procedure
  use arg value, label
  if value then do; say "FAILED:" label; exit 74; end
  return

::requires "GrokBatchWLU.cls"
::requires "AlchemyAdoption.cls"
