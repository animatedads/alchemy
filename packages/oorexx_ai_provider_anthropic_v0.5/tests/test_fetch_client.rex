/* v0.5: the Messages client over fetch (AnthropicFetchMessageClient), against
   a local stand-in for the API (tests/fixtures/fetch_mock_server.mjs, started
   by tests/test_fetch_client.sh).  Needs ooRexx/WASM (ADDRESS FETCH); under
   native ooRexx it says SKIP and passes.
   Architecture: Tom Dyer.  Code: Claude (Opus 5.5).
   usage: rexx test_fetch_client.rex ROOT BASE_URL */
parse arg root base
if base = "" then base = "http://127.0.0.1:8971"
secrets = .TestSecretProvider~new; secrets~put("provider.anthropic.primary", "FAKE-SECRET-91")
broker = .SecretBroker~new(secrets)
cfg = .AnthropicRuntimeConfig~new(.AnthropicChannel~direct, broker, "provider.anthropic.primary", "claude-haiku-5-5", 64, 10)
client = .AnthropicFetchMessageClient~new(cfg, base)
req = .AnthropicMessageRequest~new("claude-haiku-5-5", "You write ooRexx.", .true, 64)
req~addText("say hello")
r = client~send(req)
if \r~ok, r~message~pos("no ADDRESS FETCH") > 0 then do
  say "ANTHROPIC V0.5 FETCH CLIENT: SKIP (no ADDRESS FETCH: native ooRexx)"
  exit 0
end
call check r~ok, "reply ok over fetch:" r~code r~message
call check r~text == 'say "hello"', "text extracted"
call check r~inputTokens = 120 & r~outputTokens = 9 & r~cacheWriteTokens = 800, "usage read"
call check broker~activeLeaseCount = 0, "lease retired"
cat = .AnthropicModelCatalog~new
call check abs(r~costUsd(cat) - (120*0.10 + 800*0.125 + 9*0.50)/1000000) < 1e-12, "cost from the rate card"
-- the headers sent, and none of them kept for a later request
address fetch "GET" base"/seen INTO seenText"
address fetch "JSON INTO seen"
first = seen[1]; last = seen[seen~items]
call check first["key"] == "FAKE-SECRET-91" & first["version"] == "2023-06-01", "key and version sent"
call check first["browser"] == "true", "the direct-browser-access header sent"
call check last["path"] == "/seen" & last["key"] == "", "the key is not sent with a later request"
-- a wrong key: the API's error surfaced, the key-shaped text redacted
secrets~put("provider.anthropic.primary", "WRONG")
e = client~send(req)
call check \e~ok & e~code == "AI_ANTHROPIC_AUTHENTICATION_ERROR", "authentication error surfaced:" e~code
call check e~message~pos("sk-ant-") = 0 & e~message~pos("<redacted>") > 0, "credential-shaped text redacted"
-- no key at all
none = .SecretBroker~new(.TestSecretProvider~new)
c2 = .AnthropicFetchMessageClient~new(.AnthropicRuntimeConfig~new(.AnthropicChannel~direct, none, "provider.anthropic.primary", "claude-haiku-5-5", 64, 10), base)
call check c2~send(req)~code == "AI_ANTHROPIC_CREDENTIAL_MISSING", "no key: refused before any request"
call check .AnthropicFetchMessageClient~module_version == "0.5", "module_version"
say "ANTHROPIC V0.5 FETCH CLIENT: OK"
exit 0
check: procedure
  use arg ok, label
  if \ok then do; say "FAILED:" label; exit 85; end
  say "  ok" label
  return
::requires "AnthropicMessages.cls"
::requires "AnthropicProvider.cls"
::requires "SecretBroker.cls"
