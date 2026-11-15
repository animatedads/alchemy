argv = arg(1)
parse var argv root port secretMarker
if root = "" | port = "" | secretMarker = "" then exit 64
models = .array~of("fixture-model")
config = .OpenAICompatProviderConfig~new("http://127.0.0.1:" || port || "/v1/chat/completions", "provider.primary", models, 10, .true, 32)
secrets = .TestSecretProvider~new
secrets~put("provider.primary", secretMarker)
broker = .SecretBroker~new(secrets)
transport = .OpenAICompatCurlTransport~new("curl", .true)
provider = .OpenAICompatProviderAdapter~new(config, broker, transport)
reply = provider~complete(.AIProviderRequest~new("fixture-model", "hello provider", 7))
if \reply~ok then do
  say "FAILED real curl provider" reply~code reply~detail
  exit 71
end
if reply~text \== "real curl says hello" then do; say "FAILED real curl text"; exit 72; end
if reply~model \== "fixture-model-live" then do; say "FAILED real curl model"; exit 73; end
if reply~usage~inputTokens \= 2 then do; say "FAILED real curl input usage"; exit 74; end
if reply~usage~outputTokens \= 4 then do; say "FAILED real curl output usage"; exit 75; end
evidence = .AlchemyCanonical~encode(provider~instrumentationEvents) || .AlchemyCanonical~encode(transport~instrumentationEvents) || .AlchemyCanonical~encode(broker~instrumentationEvents)
if evidence~pos(secretMarker) > 0 then do; say "FAILED real curl secret evidence leak"; exit 76; end
if evidence~pos("hello provider") > 0 then do; say "FAILED real curl prompt evidence leak"; exit 77; end
say "OPENAI COMPAT REAL CURL: OK"
exit 0
::requires "OpenAICompatProvider.cls"
