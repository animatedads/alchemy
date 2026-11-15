/* v0.3: multi-block Messages client (system cache + PNG image), fixture curl. */
root = arg(1); if root = "" then root = "."
png = "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg=="
secrets = .TestSecretProvider~new; secrets~put("provider.anthropic.primary", "FAKE-SECRET-91")
broker = .SecretBroker~new(secrets)
cfg = .AnthropicRuntimeConfig~new(.AnthropicChannel~direct, broker, "provider.anthropic.primary", "claude-haiku-5-5", 64, 5, root || "/tests/fixtures/fake_messages_curl.sh")
client = .AnthropicMessageClient~new(cfg)
req = .AnthropicMessageRequest~new("claude-haiku-5-5", "You are a pilot.", .true, 64)
req~addText("frame follows"); req~addPngBase64(png)
r = client~send(req)
call check r~ok, "fixture reply ok (image + cache_control present in body)"
call check r~text == '{"yaw":5}', "text extracted"
call check r~inputTokens = 120 & r~outputTokens = 9 & r~cacheWriteTokens = 800 & r~cacheReadTokens = 0, "usage incl. cache fields"
call check broker~activeLeaseCount = 0, "lease retired"
cat = .AnthropicModelCatalog~new
call check cat~entry("claude-haiku-5-5") \== .nil, "Haiku 5.5 in catalog"
cost = r~costUsd(cat)
call check abs(cost - (120*0.10 + 800*0.125 + 9*0.50)/1000000) < 1e-12, "rate-card cost incl. cache write"
bare = .AnthropicMessageRequest~new("claude-haiku-5-5", "", .false, 64)
bare~addText("no image")
e = client~send(bare)
call check \e~ok & e~code == "AI_ANTHROPIC_INVALID_REQUEST_ERROR", "API error surfaced with type"
call check e~message~pos("sk-ant-") = 0 & e~message~pos("<redacted>") > 0, "credential-shaped text redacted"
t = .AnthropicMessageRequest~new("claude-haiku-5-5", "", .false, 64)
body = .JSON~toJSON(t~thinkingOff~toBody)
call check body~pos('"thinking":{"type":"disabled"}') > 0, "thinking disabled encoded"
body = .JSON~toJSON(t~thinkingAdaptive("MEDIUM")~toBody)
call check body~pos('"type":"adaptive"') > 0 & body~pos('"effort":"medium"') > 0, "adaptive thinking + effort encoded"
say "ANTHROPIC V0.3 MESSAGE CLIENT: OK"
exit 0
check: procedure
  use arg ok, label
  if \ok then do; say "FAILED:" label; exit 85; end
  return
::requires "AnthropicMessages.cls"
::requires "AnthropicProvider.cls"
::requires "SecretBroker.cls"
