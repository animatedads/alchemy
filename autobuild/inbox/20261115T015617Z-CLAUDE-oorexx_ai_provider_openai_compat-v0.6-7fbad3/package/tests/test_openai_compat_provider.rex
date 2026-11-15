root = arg(1)
if root = "" then root = "."
call main root
exit 0

main:
  procedure
  use arg root
  say "OPENAI COMPAT PROVIDER V0.5 START"
  secretMarker = "FAKE-OPENAI-SECRET-7E4B"
  models = .array~of("fixture-model")
  config = .OpenAICompatProviderConfig~new("http://fixture.invalid/v1/chat/completions", "provider.primary", models, 5, .true, 32)
  secrets = .TestSecretProvider~new
  secrets~put("provider.primary", secretMarker)
  broker = .SecretBroker~new(secrets)
  transport = .OpenAICompatCurlTransport~new(root || "/tests/fixtures/fake_curl.sh", .true)
  provider = .OpenAICompatProviderAdapter~new(config, broker, transport)

  call yes provider~isa(.AIProviderAdapterBase), "provider subclasses AI provider adapter base"
  call yes provider~isa(.AlchemyObject), "provider inherits AlchemyObject"
  call yes transport~isa(.AlchemyObject), "transport inherits AlchemyObject"

  request = .AIProviderRequest~new("fixture-model", "hello provider", 7)
  reply = provider~complete(request)
  call yes reply~ok, "provider completion"
  call eq "provider says hello", reply~text, "provider text"
  call eq "fixture-model-actual", reply~model, "actual provider model"
  call eq "stop", reply~finishReason, "finish reason"
  call eq 2, reply~usage~inputTokens, "prompt token usage"
  call eq 3, reply~usage~outputTokens, "completion token usage"

  blocked = provider~complete(.AIProviderRequest~new("not-allowed", "hello provider", 7))
  call no blocked~ok, "unlisted model rejected"
  call eq "AI_PROVIDER_MODEL_NOT_ALLOWED", blocked~code, "unlisted model code"
  call eq 1, broker~acquisitionCount, "model rejected before credential acquisition"

  tooLarge = provider~complete(.AIProviderRequest~new("fixture-model", "hello provider", 33))
  call no tooLarge~ok, "deployment output cap enforced"
  call eq "AI_PROVIDER_OUTPUT_LIMIT", tooLarge~code, "output cap code"
  call eq 1, broker~acquisitionCount, "output cap rejected before credential acquisition"

  toolSchema = .directory~new
  toolSchema["type"] = "object"
  toolProperties = .directory~new
  citySchema = .directory~new
  citySchema["type"] = "string"
  toolProperties["city"] = citySchema
  toolSchema["properties"] = toolProperties
  toolSchema["required"] = .array~of("city")
  toolSchema["additionalProperties"] = .JSONBoolean~false
  toolDefinition = .AIProviderToolDefinition~new("lookup.weather", "Look up weather", toolSchema)
  call no toolDefinition~hasMethod("ABILITYID"), "provider tool definition has no Ability id"
  toolRequest = .AIProviderRequest~new("fixture-model", "hello provider", 7, .array~of(toolDefinition))
  toolConfig = .OpenAICompatProviderConfig~new("http://fixture.invalid/toolcall", "provider.primary", models, 5, .true, 32)
  toolProvider = .OpenAICompatProviderAdapter~new(toolConfig, broker, transport)
  toolReply = toolProvider~complete(toolRequest)
  call yes toolReply~ok, "OpenAI tool call response"
  call eq "", toolReply~text, "tool response accepts null content"
  call eq "tool_calls", toolReply~finishReason, "tool finish reason"
  call eq 1, toolReply~toolCallCount, "one generic tool call"
  call eq 5, toolReply~usage~inputTokens, "tool response input usage"
  call eq 2, toolReply~usage~outputTokens, "tool response output usage"
  toolCall = toolReply~toolCalls~at(1)
  call eq "call-openai-1", toolCall~callId, "tool call id"
  call eq "lookup.weather", toolCall~name, "tool call name"
  call eq "TOOL-CITY-LONDON", toolCall~arguments~at("city"), "tool call arguments decoded"
  call no toolCall~hasMethod("DISPATCH"), "provider tool call has no dispatch authority"
  toolArgs = toolCall~arguments
  toolArgs["city"] = "tampered"
  call eq "TOOL-CITY-LONDON", toolCall~arguments~at("city"), "tool call arguments detached"
  toolEvidence = .AlchemyCanonical~encode(toolProvider~instrumentationEvents) || .AlchemyCanonical~encode(transport~instrumentationEvents)
  call eq 0, toolEvidence~pos("TOOL-CITY-LONDON"), "provider evidence excludes tool arguments"
  call yes toolEvidence~pos("tool_call_count") > 0, "provider evidence records tool call count"

  continuationMessages = .array~new
  continuationMessages~append(.AIProviderMessage~user("hello provider"))
  continuationMessages~append(.AIProviderMessage~assistant("", toolReply~toolCalls))
  continuationMessages~append(.AIProviderMessage~tool("call-openai-1", '{"weather":"CONTINUATION-TOOL-RESULT"}'))
  continuationRequest = .AIProviderRequest~new("fixture-model", "", 7, .array~new, continuationMessages)
  continuationConfig = .OpenAICompatProviderConfig~new("http://fixture.invalid/continuation", "provider.primary", models, 5, .true, 32)
  continuationProvider = .OpenAICompatProviderAdapter~new(continuationConfig, broker, transport)
  continuationReply = continuationProvider~complete(continuationRequest)
  call yes continuationReply~ok, "structured continuation request"
  call eq "continuation says done", continuationReply~text, "continuation response text"
  call eq 9, continuationReply~usage~inputTokens, "continuation input usage"
  call eq 4, continuationReply~usage~outputTokens, "continuation output usage"
  continuationEvidence = .AlchemyCanonical~encode(continuationProvider~instrumentationEvents) || .AlchemyCanonical~encode(transport~instrumentationEvents)
  call eq 0, continuationEvidence~pos("CONTINUATION-TOOL-RESULT"), "continuation evidence excludes tool result contents"
  call yes continuationEvidence~pos("message_count") > 0, "continuation evidence records message count"

  badToolConfig = .OpenAICompatProviderConfig~new("http://fixture.invalid/badtoolargs", "provider.primary", models, 5, .true, 32)
  badToolProvider = .OpenAICompatProviderAdapter~new(badToolConfig, broker, transport)
  badToolReply = badToolProvider~complete(toolRequest)
  call no badToolReply~ok, "non-object OpenAI tool arguments rejected"
  call eq "AI_PROVIDER_RESPONSE_INVALID", badToolReply~code, "bad tool arguments code"

  providerEvidence = .AlchemyCanonical~encode(provider~instrumentationEvents) || .AlchemyCanonical~encode(transport~instrumentationEvents) || .AlchemyCanonical~encode(broker~instrumentationEvents) || .AlchemyCanonical~encode(secrets~instrumentationEvents)
  call eq 0, providerEvidence~pos(secretMarker), "instrumentation excludes provider secret"
  call eq 0, providerEvidence~pos("hello provider"), "instrumentation excludes prompt"

  authConfig = .OpenAICompatProviderConfig~new("http://fixture.invalid/authfail", "provider.primary", models, 5, .true, 32)
  authProvider = .OpenAICompatProviderAdapter~new(authConfig, broker, transport)
  authReply = authProvider~complete(request)
  call no authReply~ok, "401 becomes bounded auth rejection"
  call eq "AI_PROVIDER_AUTH_REJECTED", authReply~code, "401 code"
  call eq 0, authReply~detail~pos(secretMarker), "401 detail excludes raw provider body"
  authEvidence = .AlchemyCanonical~encode(authProvider~instrumentationEvents) || .AlchemyCanonical~encode(transport~instrumentationEvents)
  call eq 0, authEvidence~pos(secretMarker), "401 evidence excludes raw provider body secret marker"

  rateConfig = .OpenAICompatProviderConfig~new("http://fixture.invalid/ratelimit", "provider.primary", models, 5, .true, 32)
  rateProvider = .OpenAICompatProviderAdapter~new(rateConfig, broker, transport)
  rateReply = rateProvider~complete(request)
  call no rateReply~ok, "429 becomes bounded rate failure"
  call eq "AI_PROVIDER_RATE_LIMITED", rateReply~code, "429 code"

  badConfig = .OpenAICompatProviderConfig~new("http://fixture.invalid/badjson", "provider.primary", models, 5, .true, 32)
  badProvider = .OpenAICompatProviderAdapter~new(badConfig, broker, transport)
  badReply = badProvider~complete(request)
  call no badReply~ok, "invalid JSON rejected"
  call eq "AI_PROVIDER_RESPONSE_INVALID", badReply~code, "invalid JSON code"

  say "  secret_acquisitions=" || broker~acquisitionCount
  say "OPENAI COMPAT PROVIDER V0.5: OK"
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

::requires "OpenAICompatProvider.cls"
