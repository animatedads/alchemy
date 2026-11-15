root = arg(1)
if root = "" then root = "."
call main root
exit 0

main:
  procedure
  use arg root
  say "OPENAI COMPAT WLU PLANNER V0.4 START"
  policy = .OpenAICompatModelPolicy~new(.array~of("fixture-model"), 32)
  budget = .OpenAICompatTokenBudgetPolicy~new(1, 8, 0, 30)
  estimator = .OpenAICompatConservativeTokenEstimator~new(budget)
  planner = .OpenAICompatWLUPlanner~new(policy, estimator, budget)
  call yes planner~isa(.AlchemyObject), "planner inherits AlchemyObject"
  call yes estimator~isa(.AlchemyObject), "estimator inherits AlchemyObject"

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

  toolSchema = .directory~new
  toolSchema["type"] = "object"
  toolSchema["description"] = "SECRET-SCHEMA-DESCRIPTION"
  toolObject = .directory~new
  toolObject["name"] = "lookup.weather"
  toolObject["description"] = "weather tool"
  toolObject["input_schema"] = toolSchema
  tools = .array~of(toolObject)
  body["tools"] = tools
  toolBytes = .JSON~toJSON(tools)~length
  toolOutcome = planner~plan(.FakeWluSession~new("client-ai"), .FakeWluDescriptor~new("model.complete"), body)
  call ok toolOutcome, "planner includes model-visible tool payload"
  call eq 22 + toolBytes, toolOutcome~value~plannedFacts[1]~quantity, "tool schema bytes increase conservative input budget"
  body~remove("tools")

  body["prompt"] = ""
  messageArgs = .directory~new
  messageArgs["city"] = "MESSAGE-SECRET-CITY"
  messageCall = .directory~new
  messageCall["call_id"] = "call-wlu-1"
  messageCall["name"] = "lookup.weather"
  messageCall["arguments"] = messageArgs
  userMessage = .directory~new; userMessage["role"] = "user"; userMessage["content"] = "MESSAGE-SECRET-USER"
  assistantMessage = .directory~new; assistantMessage["role"] = "assistant"; assistantMessage["content"] = ""; assistantMessage["tool_calls"] = .array~of(messageCall)
  toolMessage = .directory~new; toolMessage["role"] = "tool"; toolMessage["content"] = "MESSAGE-SECRET-RESULT"; toolMessage["tool_call_id"] = "call-wlu-1"
  messages = .array~of(userMessage, assistantMessage, toolMessage)
  body["messages"] = messages
  messageBytes = .JSON~toJSON(messages)~length
  messageOverhead = messages~items * 64 + 96
  messageOutcome = planner~plan(.FakeWluSession~new("client-ai"), .FakeWluDescriptor~new("model.complete"), body)
  call ok messageOutcome, "planner includes structured conversation payload"
  call eq 8 + messageBytes + messageOverhead, messageOutcome~value~plannedFacts[1]~quantity, "conversation bytes plus conservative wire overhead increase input budget"
  body~remove("messages")
  body["prompt"] = "hello provider"

  body["model"] = "other-model"
  blocked = planner~plan(.FakeWluSession~new("client-ai"), .FakeWluDescriptor~new("model.complete"), body)
  call no blocked~ok, "unlisted model rejected in planner"
  call eq "AI_PROVIDER_MODEL_NOT_ALLOWED", blocked~code, "model rejection code"

  body["model"] = "fixture-model"
  body["max_output_tokens"] = 33
  blocked = planner~plan(.FakeWluSession~new("client-ai"), .FakeWluDescriptor~new("model.complete"), body)
  call no blocked~ok, "output cap rejected in planner"
  call eq "AI_PROVIDER_OUTPUT_LIMIT", blocked~code, "output cap code"

  call value "AI_OPENAI_COMPAT_MODELS", "fixture-model", "ENVIRONMENT"
  call value "AI_OPENAI_COMPAT_MAX_OUTPUT", "32", "ENVIRONMENT"
  call value "AI_OPENAI_COMPAT_WLU_INPUT_TOKENS_PER_BYTE", "1", "ENVIRONMENT"
  call value "AI_OPENAI_COMPAT_WLU_INPUT_OVERHEAD_TOKENS", "8", "ENVIRONMENT"
  envPlanner = .OpenAICompatWLUPlanner~fromEnvironment
  body["max_output_tokens"] = 7
  envOutcome = envPlanner~plan(.FakeWluSession~new("client-ai"), .FakeWluDescriptor~new("model.complete"), body)
  call ok envOutcome, "environment planner uses only model/WLU policy"
  call eq 22, envOutcome~value~plannedFacts[1]~quantity, "environment planner estimate"

  evidence = .AlchemyCanonical~encode(planner~instrumentationEvents) || .AlchemyCanonical~encode(estimator~instrumentationEvents)
  call eq 0, evidence~pos("hello provider"), "WLU evidence excludes prompt contents"
  call eq 0, evidence~pos("provider.primary"), "WLU evidence excludes credential reference"
  call eq 0, evidence~pos("SECRET-SCHEMA-DESCRIPTION"), "WLU evidence excludes tool schema contents"
  call yes evidence~pos("tool_input_bytes") > 0, "WLU evidence records only tool payload size"
  call eq 0, evidence~pos("MESSAGE-SECRET-USER"), "WLU evidence excludes conversation user content"
  call eq 0, evidence~pos("MESSAGE-SECRET-RESULT"), "WLU evidence excludes tool result content"
  call eq 0, evidence~pos("MESSAGE-SECRET-CITY"), "WLU evidence excludes historical tool arguments"
  call yes evidence~pos("message_input_bytes") > 0, "WLU evidence records conversation byte count"
  call yes evidence~pos("message_wire_overhead_bytes") > 0, "WLU evidence records conservative wire overhead"
  say "  planned_input_tokens=22"
  say "  tool_input_bytes=" || toolBytes
  say "  message_input_bytes=" || messageBytes
  say "  message_wire_overhead_bytes=" || messageOverhead
  say "OPENAI COMPAT WLU PLANNER V0.4: OK"
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

::requires "OpenAICompatWLU.cls"
