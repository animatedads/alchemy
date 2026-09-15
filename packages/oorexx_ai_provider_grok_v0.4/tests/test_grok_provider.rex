root = arg(1)
if root = "" then root = "."
call main root
exit 0

main:
  procedure
  use arg root
  say "GROK PROVIDER V0.4 START"
  secretMarker = "FAKE-GROK-SECRET-7E4B"
  models = .array~of("fixture-model")
  config = .GrokProviderConfig~new("http://fixture.invalid/v1/chat/completions", "provider.primary", models, 5, .true, 32)
  secrets = .TestSecretProvider~new
  secrets~put("provider.primary", secretMarker)
  broker = .SecretBroker~new(secrets)
  transport = .GrokCurlTransport~new(root || "/tests/fixtures/fake_curl.sh", .true)
  provider = .GrokProviderAdapter~new(config, broker, transport)

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

  providerEvidence = .AlchemyCanonical~encode(provider~instrumentationEvents) || .AlchemyCanonical~encode(transport~instrumentationEvents) || .AlchemyCanonical~encode(broker~instrumentationEvents) || .AlchemyCanonical~encode(secrets~instrumentationEvents)
  call eq 0, providerEvidence~pos(secretMarker), "instrumentation excludes provider secret"
  call eq 0, providerEvidence~pos("hello provider"), "instrumentation excludes prompt"

  authConfig = .GrokProviderConfig~new("http://fixture.invalid/authfail", "provider.primary", models, 5, .true, 32)
  authProvider = .GrokProviderAdapter~new(authConfig, broker, transport)
  authReply = authProvider~complete(request)
  call no authReply~ok, "401 becomes bounded auth rejection"
  call eq "AI_PROVIDER_AUTH_REJECTED", authReply~code, "401 code"
  call eq 0, authReply~detail~pos(secretMarker), "401 detail excludes raw provider body"
  authEvidence = .AlchemyCanonical~encode(authProvider~instrumentationEvents) || .AlchemyCanonical~encode(transport~instrumentationEvents)
  call eq 0, authEvidence~pos(secretMarker), "401 evidence excludes raw provider body secret marker"

  rateConfig = .GrokProviderConfig~new("http://fixture.invalid/ratelimit", "provider.primary", models, 5, .true, 32)
  rateProvider = .GrokProviderAdapter~new(rateConfig, broker, transport)
  rateReply = rateProvider~complete(request)
  call no rateReply~ok, "429 becomes bounded rate failure"
  call eq "AI_PROVIDER_RATE_LIMITED", rateReply~code, "429 code"

  badConfig = .GrokProviderConfig~new("http://fixture.invalid/badjson", "provider.primary", models, 5, .true, 32)
  badProvider = .GrokProviderAdapter~new(badConfig, broker, transport)
  badReply = badProvider~complete(request)
  call no badReply~ok, "invalid JSON rejected"
  call eq "AI_PROVIDER_RESPONSE_INVALID", badReply~code, "invalid JSON code"

  say "  secret_acquisitions=" || broker~acquisitionCount
  say "GROK PROVIDER V0.4: OK"
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

::requires "GrokProvider.cls"
