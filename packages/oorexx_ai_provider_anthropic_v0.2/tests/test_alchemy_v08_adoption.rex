root = arg(1)
if root = "" then root = "."
call main root
exit 0

main:
  procedure
  use arg root
  say "ANTHROPIC V0.2 ALCHEMY V0.8 ADOPTION START"
  call eq "0.2", .AnthropicProviderBuild~RELEASE, "package release"
  call eq "ai.provider.anthropic/0.1", .AnthropicProviderBuild~API_VERSION, "public API stable"
  call eq "0.6", .AnthropicProviderBuild~AI_ACCESS_VERSION, "AI Access qualification"
  call eq "0.8", .AnthropicProviderBuild~ALCHEMY_OBJECTS_VERSION, "Alchemy qualification"
  call eq "0.2", .AnthropicProviderBuild~SECRET_BROKER_VERSION, "Secret Broker qualification"

  secrets = .TestSecretProvider~new
  secrets~put("provider.anthropic.primary", "ADOPTION-SECRET")
  broker = .SecretBroker~new(secrets)
  cfg = .AnthropicRuntimeConfig~new(.AnthropicChannel~direct, broker, "provider.anthropic.primary", "claude-haiku-4-5-20251001", 64, 5, root || "/tests/fixtures/fake_anthropic_curl.sh")

  objects = .array~new
  objects~append(.array~of("AnthropicCapabilitySelector", .AnthropicCapabilitySelector~new))
  objects~append(.array~of("AnthropicProvider", .AnthropicProvider~new(cfg)))
  objects~append(.array~of("AnthropicBatchProvider", .AnthropicBatchProvider~new(cfg)))
  do pair over objects
    call verifyStandard pair[1], pair[2]
  end
  say "  verified_objects=" objects~items
  say "ANTHROPIC V0.2 ALCHEMY V0.8 ADOPTION: OK"
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
  call eq 0, adoption~warnings~items, label || " zero warnings"
  integrity = adoption~evidence["inheritance_integrity"]
  call yes integrity["ok"], label || " reserved base integrity"
  call eq 0, integrity["reserved_override_count"], label || " no reserved overrides"
  construction = adoption~evidence["construction_provenance"]
  call eq "INIT", construction["entrypoint"], label || " construction provenance"
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
  if \value then do; say "FAILED:" label; exit 83; end
  return

::requires "AnthropicTransport.cls"
::requires "AlchemyAdoption.cls"
