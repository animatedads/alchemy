root = arg(1)
if root = "" then root = "."
call main root
exit 0

main:
  procedure
  use arg root
  models = .array~of("fixture-model")
  secret = "AZURE-KEY-123"

  call value "EXPECT_AUTH_MODE", "API_KEY", "ENVIRONMENT"
  call value "EXPECT_SECRET", secret, "ENVIRONMENT"
  broker = .SecretBroker~new~put("azure.primary", secret)
  azureConfig = .OpenAICompatProviderConfig~new("http://fixture.invalid/openai/deployments/d/chat/completions?api-version=2024-10-21", "azure.primary", models, 5, .true, 64, "API_KEY", "api-key")
  azureTransport = .OpenAICompatCurlTransport~new(root || "/tests/fixtures/fake_curl.sh", .true, "API_KEY", "api-key")
  azureProvider = .OpenAICompatProviderAdapter~new(azureConfig, broker, azureTransport)
  azureReply = azureProvider~complete(.AIProviderRequest~new("fixture-model", "write hello", 32))
  call yes azureReply~ok, "Azure API_KEY completion"
  call eq 11, azureReply~usage~inputTokens, "Azure usage input"
  call eq 7, azureReply~usage~outputTokens, "Azure usage output"
  call eq 1, broker~acquisitionCount, "Azure acquires one secret lease"

  call value "EXPECT_AUTH_MODE", "NONE", "ENVIRONMENT"
  call value "EXPECT_SECRET", "UNUSED", "ENVIRONMENT"
  llamaConfig = .OpenAICompatProviderConfig~new("http://127.0.0.1:8080/v1/chat/completions", "", models, 5, .true, 64, "NONE", "")
  llamaTransport = .OpenAICompatCurlTransport~new(root || "/tests/fixtures/fake_curl.sh", .true, "NONE", "")
  llamaProvider = .OpenAICompatProviderAdapter~new(llamaConfig, .nil, llamaTransport)
  llamaReply = llamaProvider~complete(.AIProviderRequest~new("fixture-model", "write hello", 32))
  call yes llamaReply~ok, "llama.cpp no-auth completion"
  call eq 11, llamaReply~usage~inputTokens, "llama usage input"
  call eq 7, llamaReply~usage~outputTokens, "llama usage output"

  call eq "API_KEY", azureConfig~authMode, "Azure auth mode"
  call eq "api-key", azureConfig~authHeaderName, "Azure header name"
  call yes azureConfig~needsCredential, "Azure needs credential"
  call eq "NONE", llamaConfig~authMode, "llama auth mode"
  call no llamaConfig~needsCredential, "llama does not need credential"

  call value "AZURE_OPENAI_ENDPOINT", "https://example.openai.azure.com", "ENVIRONMENT"
  call value "AZURE_OPENAI_DEPLOYMENT", "gpt-test", "ENVIRONMENT"
  call value "AZURE_OPENAI_API_VERSION", "2026-01-01", "ENVIRONMENT"
  call value "AZURE_OPENAI_MODELS", "gpt-test", "ENVIRONMENT"
  azureEnv = .AzureOpenAIProviderConfig~fromEnvironment
  call eq "API_KEY", azureEnv~authMode, "Azure environment config selects API_KEY"
  call yes azureEnv~endpoint~pos("/openai/deployments/gpt-test/chat/completions?api-version=2026-01-01") > 0, "Azure endpoint composed from explicit deployment and API version"

  call value "LLAMA_CPP_ENDPOINT", "http://127.0.0.1:8080/v1/chat/completions", "ENVIRONMENT"
  call value "LLAMA_CPP_MODELS", "fixture-model", "ENVIRONMENT"
  llamaEnv = .LlamaCppProviderConfig~fromEnvironment
  call eq "NONE", llamaEnv~authMode, "llama environment config selects NONE"

  say "PASS Azure api-key transport"
  say "PASS llama.cpp loopback no-auth transport"
  return

yes:
  use arg value, label
  if \value then do; say "FAILED:" label; exit 41; end
  return
no:
  use arg value, label
  if value then do; say "FAILED:" label; exit 42; end
  return
eq:
  use arg expected, actual, label
  if expected \== actual then do; say "FAILED:" label "expected=" expected "actual=" actual; exit 43; end
  return

::requires "OpenAICompatProvider.cls"
