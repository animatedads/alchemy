root = arg(1)
if root = "" then root = "."
call main root
exit 0

main:
  procedure
  use arg root
  say "GROK BATCH CURL V0.4 START"
  secretMarker = "FAKE-GROK-BATCH-CURL-SECRET-7E4B"
  policy = .GrokBatchModelPolicy~new(.array~of("fixture-model"), 32, 10, 10000)
  config = .GrokBatchProviderConfig~new("http://fixture.invalid/v1", "provider.primary", policy, 5, .true)
  secrets = .TestSecretProvider~new
  secrets~put("provider.primary", secretMarker)
  broker = .SecretBroker~new(secrets)
  transport = .GrokBatchCurlTransport~new(root || "/tests/fixtures/fake_batch_curl.sh", .true)
  adapter = .GrokBatchAdapter~new(config, broker, transport)

  created = adapter~createBatch("fixture-batch")
  call yes created["ok"], "batch curl create succeeds"
  call eq "batch-curl-1", created["batch_id"], "batch curl response parsed"
  call eq 1, broker~acquisitionCount, "batch curl acquired one lease"
  call eq 0, broker~activeLeaseCount, "batch curl lease retired"

  evidence = .AlchemyCanonical~encode(transport~instrumentationEvents) || .AlchemyCanonical~encode(adapter~instrumentationEvents) || .AlchemyCanonical~encode(broker~instrumentationEvents)
  call eq 0, evidence~pos(secretMarker), "batch curl instrumentation excludes secret"
  say "  secret_acquisitions=" || broker~acquisitionCount
  say "GROK BATCH CURL V0.4: OK"
  return

eq:
  procedure
  use arg expected, actual, label
  if expected \== actual then do
    say "FAILED:" label
    say " expected=" expected
    say " actual=" actual
    exit 94
  end
  return

yes:
  procedure
  use arg value, label
  if \value then do; say "FAILED:" label; exit 95; end
  return

::requires "GrokBatchProvider.cls"
