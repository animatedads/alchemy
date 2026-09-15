root = arg(1)
if root = "" then root = "."
call main root
exit 0

main:
  procedure
  use arg root
  say "AI ACCESS V0.6 TOOL PROPOSAL START"

  schema = .directory~new
  schema["type"] = "object"
  properties = .directory~new
  citySchema = .directory~new
  citySchema["type"] = "string"
  properties["city"] = citySchema
  schema["properties"] = properties
  required = .array~of("city")
  schema["required"] = required
  schema["additionalProperties"] = .JSONBoolean~false

  definition = .AIProviderToolDefinition~new("lookup.weather", "Look up weather", schema)
  call no definition~isa(.AlchemyObject), "tool definition remains plain DTO"
  call no definition~hasMethod("ABILITYID"), "tool definition exposes no internal Ability id"
  call no definition~hasMethod("BROKER"), "tool definition exposes no broker authority"
  call no definition~hasMethod("METERFACT"), "tool definition exposes no WLU authority"

  citySchema["type"] = "integer"
  detachedSchema = definition~inputSchema
  call eq "string", detachedSchema~at("properties")~at("city")~at("type"), "definition input schema detached from caller mutation"
  detachedSchema~at("properties")~at("city")["type"] = "boolean"
  call eq "string", definition~inputSchema~at("properties")~at("city")~at("type"), "definition accessor returns detached schema"

  defs = .array~of(definition)
  request = .AIProviderRequest~new("fixture-model", "tool-proposal", 4, defs)
  call no request~isa(.AlchemyObject), "request remains narrow DTO"
  call eq 1, request~toolDefinitionCount, "request has one tool"
  defs~empty
  call eq 1, request~toolDefinitionCount, "request tool array detached from caller container"
  returnedDefs = request~toolDefinitions
  returnedDefs~empty
  call eq 1, request~toolDefinitionCount, "request tool accessor returns detached array"

  provider = .DeterministicAIProvider~new
  providerReply = provider~complete(request)
  call yes providerReply~ok, "provider returns tool proposal"
  call eq 1, providerReply~toolCallCount, "one typed tool call"
  call eq "tool_calls", providerReply~finishReason, "tool finish reason"
  toolCall = providerReply~toolCalls~at(1)
  call no toolCall~isa(.AlchemyObject), "tool call remains plain DTO"
  call no toolCall~hasMethod("ABILITYID"), "tool call exposes no internal Ability id"
  call no toolCall~hasMethod("DISPATCH"), "tool call has no execution authority"
  call eq "call-fixture-1", toolCall~callId, "provider call id"
  call eq "lookup.weather", toolCall~name, "provider call tool name"
  callArgs = toolCall~arguments
  call eq "SECRET-TOOL-ARGUMENT", callArgs~at("city"), "typed arguments preserved"
  callArgs["city"] = "tampered"
  call eq "SECRET-TOOL-ARGUMENT", toolCall~arguments~at("city"), "tool call arguments detached on read"

  providerEvidence = .AlchemyCanonical~encode(provider~instrumentationEvents)
  call eq 0, providerEvidence~pos("SECRET-TOOL-ARGUMENT"), "provider instrumentation excludes tool arguments"
  call yes providerEvidence~pos("tool_call_count") > 0, "provider instrumentation records call count"

  body = .directory~new
  body["model"] = "fixture-model"
  body["prompt"] = "tool-proposal"
  body["max_output_tokens"] = 4
  toolObject = .directory~new
  toolObject["name"] = "lookup.weather"
  toolObject["description"] = "Look up weather"
  toolObject["input_schema"] = definition~inputSchema
  body["tools"] = .array~of(toolObject)
  module = .DeterministicAIProviderModule~new
  context = .FakeAIContext~new(body, .false)
  invocation = module~runtimeInvokeAbility("model.complete", context)
  call yes invocation~ok, "runtime capability projects provider tool call"
  projected = invocation~value
  call eq "", projected~at("text"), "tool proposal may have empty text"
  calls = projected~at("tool_calls")
  call yes calls~isa(.Array), "business reply tool_calls array"
  call eq 1, calls~items, "one business proposal"
  projectedCall = calls~at(1)
  call eq "call-fixture-1", projectedCall~at("call_id"), "projected call id"
  call eq "lookup.weather", projectedCall~at("name"), "projected tool name"
  call eq "SECRET-TOOL-ARGUMENT", projectedCall~at("arguments")~at("city"), "projected business arguments"
  call no projectedCall~hasIndex("ability_id"), "business proposal exposes no Ability id"

  moduleEvidence = .AlchemyCanonical~encode(module~instrumentationEvents)
  call eq 0, moduleEvidence~pos("SECRET-TOOL-ARGUMENT"), "runtime instrumentation excludes tool arguments"
  call yes moduleEvidence~pos("tool_call_count") > 0, "runtime instrumentation records call count"

  managedContext = .FakeAIContext~new(body, .true)
  managedInvocation = module~runtimeInvokeAbility("model.complete", managedContext)
  call yes managedInvocation~ok, "tool proposal preserves outer metering path"
  facts = managedContext~meterFacts
  call eq 2, facts~items, "tool proposal reports input and output work facts"
  call eq "AI_INPUT_TOKEN", facts~at(1)~at("type"), "tool proposal input fact"
  call eq 1, facts~at(2)~at("quantity"), "tool proposal output fact quantity"

  badBody = .directory~new
  badBody["model"] = "fixture-model"
  badBody["prompt"] = "tool-proposal"
  badTool = .directory~new
  badTool["name"] = "lookup.weather"
  badTool["input_schema"] = definition~inputSchema
  badTool["ability_id"] = "internal.weather"
  badBody["tools"] = .array~of(badTool)
  badContext = .FakeAIContext~new(badBody, .false)
  badInvocation = module~runtimeInvokeAbility("model.complete", badContext)
  call no badInvocation~ok, "direct runtime rejects unsupported tool definition field"
  call eq "AI_REQUEST_INVALID", badInvocation~code, "unsupported tool field code"

  say "  tool_definitions=" || request~toolDefinitionCount
  say "  tool_calls=" || providerReply~toolCallCount
  say "AI ACCESS V0.6 TOOL PROPOSAL: OK"
  return

eq:
  use arg expected, actual, label
  if expected \== actual then do
    say "FAILED:" label
    say " expected=" expected
    say " actual=" actual
    exit 41
  end
  return

yes:
  use arg value, label
  if \value then do
    say "FAILED:" label
    exit 42
  end
  return

no:
  use arg value, label
  if value then do
    say "FAILED:" label
    exit 43
  end
  return

::class FakeAIResult public
::attribute ok get
::attribute code get
::attribute detail get
::attribute value get
::method init
  expose ok code detail value
  use arg okArg, codeArg = "OK", detailArg = "", valueArg = .nil
  ok = okArg
  code = codeArg
  detail = detailArg
  value = valueArg
::method success class
  use arg value = .nil
  return self~new(.true, "OK", "", value)
::method failure class
  use arg code, detail = ""
  return self~new(.false, code, detail, .nil)

::class FakeAIContext public
::method init
  expose requestBody managed facts
  use arg bodyArg, managedArg = .false
  requestBody = bodyArg
  managed = managedArg == .true
  facts = .array~new
::method body
  expose requestBody
  return requestBody
::method wluManaged
  expose managed
  return managed
::method meterFact
  expose facts
  use arg factType, quantity = 1, source = "", dimensions = .nil
  fact = .directory~new
  fact["type"] = factType
  fact["quantity"] = quantity
  fact["source"] = source
  facts~append(fact)
  return .FakeAIResult~success(fact)
::method meterFacts
  expose facts
  return facts
::method success
  use arg value = .nil
  return .FakeAIResult~success(value)
::method failure
  use arg code, detail = ""
  return .FakeAIResult~failure(code, detail)

::requires "AIProviderAccess.cls"
::requires "DeterministicAIProvider_v1.cls"
::requires "json.cls"
