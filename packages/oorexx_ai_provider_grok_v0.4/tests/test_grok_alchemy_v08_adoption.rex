root = arg(1)
if root = "" then root = "."
call main root
exit 0

main:
  procedure
  use arg root
  say "GROK ALCHEMY V0.8 ADOPTION START"
  call eq "0.4", .GrokProviderBuild~RELEASE, "Grok package release"
  call eq "ai.provider.grok/0.3", .GrokProviderBuild~API_VERSION, "public real-time API remains stable"
  call eq "0.6", .GrokProviderBuild~AI_ACCESS_VERSION, "AI Access qualification"
  call eq "0.2", .GrokProviderBuild~SECRET_BROKER_VERSION, "Secret Broker qualification"
  call eq "0.8", .GrokProviderBuild~ALCHEMY_OBJECTS_VERSION, "Alchemy Objects qualification"
  call eq "0.4", .GrokBatchProviderBuild~RELEASE, "Grok Batch package release"
  call eq "ai.provider.grok.batch/0.3", .GrokBatchProviderBuild~API_VERSION, "public batch API remains stable"

  secretMarker = "FAKE-GROK-SECRET-ADOPTION"
  secrets = .TestSecretProvider~new
  secrets~put("provider.primary", secretMarker)
  broker = .SecretBroker~new(secrets)

  models = .array~of("fixture-model")
  config = .GrokProviderConfig~new("http://fixture.invalid/v1/chat/completions", "provider.primary", models, 5, .true, 32)
  transport = .GrokCurlTransport~new(root || "/tests/fixtures/fake_curl.sh", .true)
  provider = .GrokProviderAdapter~new(config, broker, transport)
  selector = .GrokCapabilitySelector~new

  batchPolicy = .GrokBatchModelPolicy~new(models, 32, 10, 10000)
  batchConfig = .GrokBatchProviderConfig~new("http://fixture.invalid/v1", "provider.primary", batchPolicy, 5, .true)
  batchTransport = .GrokBatchCurlTransport~new("curl", .true)
  batchAdapter = .GrokBatchAdapter~new(batchConfig, broker, batchTransport)

  call value "AI_GROK_ENDPOINT", "http://fixture.invalid/v1/chat/completions", "ENVIRONMENT"
  call value "AI_GROK_CREDENTIAL_REFERENCE", "provider.primary", "ENVIRONMENT"
  call value "AI_GROK_CREDENTIAL_ENV", "AI_GROK_ADOPTION_SECRET", "ENVIRONMENT"
  call value "AI_GROK_ADOPTION_SECRET", secretMarker, "ENVIRONMENT"
  call value "AI_GROK_MODELS", "fixture-model", "ENVIRONMENT"
  call value "AI_GROK_CURL", "curl", "ENVIRONMENT"
  call value "AI_GROK_ALLOW_HTTP_TEST", "1", "ENVIRONMENT"
  runtimeModule = .GrokRuntimeModule~new

  call value "AI_GROK_BATCH_ENDPOINT_BASE", "http://fixture.invalid/v1", "ENVIRONMENT"
  call value "AI_GROK_BATCH_CREDENTIAL_REFERENCE", "provider.primary", "ENVIRONMENT"
  call value "AI_GROK_BATCH_CREDENTIAL_ENV", "AI_GROK_ADOPTION_SECRET", "ENVIRONMENT"
  call value "AI_GROK_BATCH_MODELS", "fixture-model", "ENVIRONMENT"
  call value "AI_GROK_BATCH_CURL", "curl", "ENVIRONMENT"
  call value "AI_GROK_BATCH_ALLOW_HTTP_TEST", "1", "ENVIRONMENT"
  batchRuntime = .GrokBatchRuntimeModule~new

  objects = .array~new
  objects~append(.array~of("GrokCurlTransport", transport))
  objects~append(.array~of("GrokProviderAdapter", provider))
  objects~append(.array~of("GrokRuntimeModule", runtimeModule))
  objects~append(.array~of("GrokCapabilitySelector", selector))
  objects~append(.array~of("GrokBatchCurlTransport", batchTransport))
  objects~append(.array~of("GrokBatchAdapter", batchAdapter))
  objects~append(.array~of("GrokBatchRuntimeModule", batchRuntime))

  do pair over objects
    call verifyStandard pair[1], pair[2]
  end

  call value "AI_GROK_ADOPTION_SECRET", "", "ENVIRONMENT"
  say "  verified_objects=" || objects~items
  say "GROK ALCHEMY V0.8 ADOPTION: OK"
  return

verifyStandard:
  procedure
  use arg label, object
  call yes object~isa(.AlchemyObject), label || " inherits AlchemyObject"
  adoption = .AlchemyAdoptionVerifier~verify(object, "STANDARD")
  if \adoption~ok then do
    say "FAILED:" label "STANDARD adoption"
    do failure over adoption~failures
      say "  " failure["code"] failure["message"]
    end
    exit 81
  end
  call eq 0, adoption~warnings~items, label || " has zero adoption warnings"
  integrity = adoption~evidence["inheritance_integrity"]
  call yes integrity["ok"], label || " reserved base integrity"
  call eq 0, integrity["reserved_override_count"], label || " no reserved-base overrides"
  construction = adoption~evidence["construction_provenance"]
  call eq "INIT", construction["entrypoint"], label || " preferred construction provenance"
  return

eq:
  procedure
  use arg expected, actual, label
  if expected \== actual then do
    say "FAILED:" label
    say " expected=" expected
    say " actual=" actual
    exit 82
  end
  return

yes:
  procedure
  use arg value, label
  if \value then do
    say "FAILED:" label
    exit 83
  end
  return

::requires "GrokProvider.cls"
::requires "GrokCapability.cls"
::requires "GrokBatchProvider.cls"
::requires "AlchemyAdoption.cls"
