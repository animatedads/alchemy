root = arg(1)
if root = "" then root = "."
call main root
exit 0

main:
  procedure
  use arg root
  say "ANTHROPIC V0.2 SECRET BROKER TRANSPORT START"

  secret = "FAKE-ANTHROPIC-SECRET-7E4B"
  secrets = .TestSecretProvider~new
  secrets~put("provider.anthropic.primary", secret)
  broker = .SecretBroker~new(secrets)
  cfg = .AnthropicRuntimeConfig~new(.AnthropicChannel~direct, broker, "provider.anthropic.primary", "claude-haiku-4-5-20251001", 64, 5, root || "/tests/fixtures/fake_anthropic_curl.sh")

  provider = .AnthropicProvider~new(cfg)
  req = .AIProviderRequest~new("claude-haiku-4-5-20251001", "hello fixture", 32)
  reply = provider~complete(req)
  call yes reply~ok, "real-time fake curl reply"
  call eq "fixture-ok", reply~text, "real-time response text"
  call eq 11, reply~usage~inputTokens, "input tokens"
  call eq 3, reply~usage~outputTokens, "output tokens"
  call eq 0, broker~activeLeaseCount, "real-time lease retired"

  batch = .AnthropicBatchProvider~new(cfg)
  item = .AnthropicBatchRequestItem~new("t1", "claude-haiku-4-5-20251001", "hi", 16)
  bout = batch~createBatch(.array~of(item))
  call yes bout~ok, "batch fake curl reply"
  parsed = .JSON~fromJSON(bout~body)
  call eq "msgbatch_fixture_1", parsed["id"], "batch id"
  call eq 0, broker~activeLeaseCount, "batch lease retired"
  evidence = .AlchemyCanonical~encode(broker~instrumentationEvents) || .AlchemyCanonical~encode(secrets~instrumentationEvents)
  call eq 0, evidence~pos(secret), "secret absent from broker/provider instrumentation"
  rec = batch~selector~queryJobCost("msgbatch_fixture_1")
  call yes rec \== .nil, "batch cost record created"

  before = broker~acquisitionCount
  bad = .AnthropicRuntimeConfig~new(.AnthropicChannel~direct, broker, "missing.secret", "claude-haiku-4-5-20251001", 64, 5, root || "/tests/fixtures/fake_anthropic_curl.sh")
  badProvider = .AnthropicProvider~new(bad)
  badReply = badProvider~complete(req)
  call no badReply~ok, "missing secret fails closed"
  call eq "AI_ANTHROPIC_CREDENTIAL_MISSING", badReply~code, "missing secret code"
  call eq 0, broker~activeLeaseCount, "failed acquisition leaves no active lease"
  call yes broker~acquisitionCount > before, "broker was consulted"

  say "ANTHROPIC V0.2 SECRET BROKER TRANSPORT: OK"
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

no:
  procedure
  use arg value, label
  if value then do; say "FAILED:" label; exit 84; end
  return

::requires "AnthropicTransport.cls"
::requires "SecretBroker.cls"
