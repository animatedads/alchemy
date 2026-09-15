root = arg(1)
if root = "" then root = "."
call main root
exit 0

main:
  procedure
  use arg root
  say "GROK BATCH PROVIDER V0.4 START"
  secretMarker = "FAKE-GROK-BATCH-SECRET-7E4B"
  models = .array~of("fixture-model")
  policy = .GrokBatchModelPolicy~new(models, 32, 10, 10000)
  config = .GrokBatchProviderConfig~new("http://fixture.invalid/v1", "provider.primary", policy, 5, .true)
  secrets = .TestSecretProvider~new
  secrets~put("provider.primary", secretMarker)
  broker = .SecretBroker~new(secrets)
  transport = .FixtureBatchTransport~new(secretMarker)
  adapter = .GrokBatchAdapter~new(config, broker, transport)

  created = adapter~createBatch("fixture-batch")
  call yes created["ok"], "batch create succeeds"
  call eq "batch-1", created["batch_id"], "batch id projected"
  call eq 1, broker~acquisitionCount, "one broker acquisition"
  call eq 0, broker~activeLeaseCount, "lease retired after transport"
  call yes transport~sawActiveLease, "transport received active lease"
  call yes transport~sawTrustedSecret, "transport materialized secret through trusted-consumer API"

  before = broker~acquisitionCount
  bad = .array~of(.GrokBatchAddRequest~new("r1", "not-allowed", "never transmit me", 4))
  denied = adapter~addRequests("batch-1", bad)
  call no denied["ok"], "unlisted model rejected"
  call eq "AI_PROVIDER_MODEL_NOT_ALLOWED", denied["code"], "unlisted model code"
  call eq before, broker~acquisitionCount, "policy denial occurs before credential acquisition"

  evidence = .AlchemyCanonical~encode(adapter~instrumentationEvents) || .AlchemyCanonical~encode(broker~instrumentationEvents) || .AlchemyCanonical~encode(secrets~instrumentationEvents)
  call eq 0, evidence~pos(secretMarker), "instrumentation excludes batch provider secret"
  call eq 0, evidence~pos("never transmit me"), "instrumentation excludes rejected prompt"

  say "  secret_acquisitions=" || broker~acquisitionCount
  say "GROK BATCH PROVIDER V0.4: OK"
  return

eq:
  procedure
  use arg expected, actual, label
  if expected \== actual then do
    say "FAILED:" label
    say " expected=" expected
    say " actual=" actual
    exit 91
  end
  return

yes:
  procedure
  use arg value, label
  if \value then do; say "FAILED:" label; exit 92; end
  return

no:
  procedure
  use arg value, label
  if value then do; say "FAILED:" label; exit 93; end
  return

::class FixtureBatchTransport public
::attribute sawActiveLease get
::attribute sawTrustedSecret get
::method init
  expose expectedSecret sawActiveLease sawTrustedSecret
  use arg secretArg
  expectedSecret = secretArg~string
  sawActiveLease = .false
  sawTrustedSecret = .false
::method requestJson
  expose expectedSecret sawActiveLease sawTrustedSecret
  use arg method, url, bodyJson, lease, timeoutSeconds
  sawActiveLease = lease~active
  secretOutcome = lease~secretForTrustedConsumer
  if secretOutcome~ok then if secretOutcome~value~string = expectedSecret then sawTrustedSecret = .true
  return .GrokBatchTransportResult~success(200, '{"batch_id":"batch-1","state":"pending"}')

::requires "GrokBatchProvider.cls"
