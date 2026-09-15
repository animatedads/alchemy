root = arg(1)
if root = "" then root = "."
call main root
exit 0

main:
  procedure
  use arg root
  say "GROK WLU PLANNER V0.4 START"
  call eq "0.12", .GrokWLUBuild~WLU_VERSION, "WLU v0.12 qualification"
  policy = .GrokModelPolicy~new(.array~of("fixture-model"), 32)
  budget = .GrokTokenBudgetPolicy~new(1, 8, 0, 30)
  estimator = .GrokConservativeTokenEstimator~new(budget)
  planner = .GrokWLUPlanner~new(policy, estimator, budget)
  call yes planner~isa(.AlchemyObject), "planner inherits AlchemyObject"
  call yes estimator~isa(.AlchemyObject), "estimator inherits AlchemyObject"
  plannerAdoption = .AlchemyAdoptionVerifier~verify(planner, "STANDARD")
  estimatorAdoption = .AlchemyAdoptionVerifier~verify(estimator, "STANDARD")
  call yes plannerAdoption~ok, "planner Alchemy v0.8 STANDARD adoption"
  call yes estimatorAdoption~ok, "estimator Alchemy v0.8 STANDARD adoption"
  call eq 0, plannerAdoption~warnings~items, "planner adoption warnings"
  call eq 0, estimatorAdoption~warnings~items, "estimator adoption warnings"
  call eq "INIT", plannerAdoption~evidence["construction_provenance"]["entrypoint"], "planner preferred construction"
  call eq "INIT", estimatorAdoption~evidence["construction_provenance"]["entrypoint"], "estimator preferred construction"

  body = .directory~new
  body["model"] = "fixture-model"
  body["prompt"] = "hello provider"
  body["max_output_tokens"] = 7
  outcome = planner~plan(.FakeWluSession~new("client-ai"), .FakeWluDescriptor~new("model.complete"), body)
  call ok outcome, "planner success"
  plan = outcome~value
  facts = plan~plannedFacts
  call eq 2, facts~items, "planned input/output fact count"
  call eq "AI_INPUT_TOKEN", facts[1]~factType, "input fact type"
  call eq 22, facts[1]~quantity, "input estimate = prompt bytes + overhead"
  call eq "AI_OUTPUT_TOKEN", facts[2]~factType, "output fact type"
  call eq 7, facts[2]~quantity, "output reserves requested maximum"
  call eq "ABILITY:MODEL.COMPLETE", plan~scope, "ability scope"

  body["model"] = "other-model"
  blocked = planner~plan(.FakeWluSession~new("client-ai"), .FakeWluDescriptor~new("model.complete"), body)
  call no blocked~ok, "unlisted model rejected in planner"
  call eq "AI_PROVIDER_MODEL_NOT_ALLOWED", blocked~code, "model rejection code"

  body["model"] = "fixture-model"
  body["max_output_tokens"] = 33
  blocked = planner~plan(.FakeWluSession~new("client-ai"), .FakeWluDescriptor~new("model.complete"), body)
  call no blocked~ok, "output cap rejected in planner"
  call eq "AI_PROVIDER_OUTPUT_LIMIT", blocked~code, "output cap code"

  call value "AI_GROK_MODELS", "fixture-model", "ENVIRONMENT"
  call value "AI_GROK_MAX_OUTPUT", "32", "ENVIRONMENT"
  call value "AI_GROK_WLU_INPUT_TOKENS_PER_BYTE", "1", "ENVIRONMENT"
  call value "AI_GROK_WLU_INPUT_OVERHEAD_TOKENS", "8", "ENVIRONMENT"
  envPlanner = .GrokWLUPlanner~fromEnvironment
  body["max_output_tokens"] = 7
  envOutcome = envPlanner~plan(.FakeWluSession~new("client-ai"), .FakeWluDescriptor~new("model.complete"), body)
  call ok envOutcome, "environment planner uses only model/WLU policy"
  call eq 22, envOutcome~value~plannedFacts[1]~quantity, "environment planner estimate"

  evidence = .AlchemyCanonical~encode(planner~instrumentationEvents) || .AlchemyCanonical~encode(estimator~instrumentationEvents)
  call eq 0, evidence~pos("hello provider"), "WLU evidence excludes prompt contents"
  call eq 0, evidence~pos("provider.primary"), "WLU evidence excludes credential reference"
  say "  planned_input_tokens=22"
  say "GROK WLU PLANNER V0.4: OK"
  return

ok:
  use arg outcome, label
  if outcome == .nil then do; say "FAILED:" label "nil"; exit 71; end
  if \outcome~ok then do; say "FAILED:" label outcome~code outcome~detail; exit 71; end
  return

eq:
  use arg expected, actual, label
  if expected \== actual then do
    say "FAILED:" label
    say " expected=" expected
    say " actual=" actual
    exit 72
  end
  return

yes:
  use arg value, label
  if \value then do; say "FAILED:" label; exit 73; end
  return

no:
  use arg value, label
  if value then do; say "FAILED:" label; exit 74; end
  return

::class FakeWluSession public
::attribute clientId get
::method init
  expose clientId
  use arg valueArg
  clientId = valueArg

::class FakeWluDescriptor public
::attribute abilityId get
::method init
  expose abilityId
  use arg valueArg
  abilityId = valueArg

::requires "GrokWLU.cls"
::requires "AlchemyAdoption.cls"
