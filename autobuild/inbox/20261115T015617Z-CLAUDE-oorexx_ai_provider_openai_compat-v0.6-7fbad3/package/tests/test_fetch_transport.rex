/* v0.6: the provider over the fetch transport (OpenAICompatFetchTransport),
   against a local stand-in (tests/fixtures/fetch_mock_server.mjs, started by
   tests/test_fetch_transport.sh).  Needs ooRexx/WASM (ADDRESS FETCH); under
   native ooRexx it says SKIP and passes.
   Architecture: Tom Dyer.  Code: Claude (Opus 5.5).
   usage: rexx test_fetch_transport.rex ROOT BASE_URL */
parse arg root base
if base = "" then base = "http://127.0.0.1:8972"
secrets = .TestSecretProvider~new
secrets~put("provider.primary", "FAKE-OPENAI-SECRET-7E4B")
broker = .SecretBroker~new(secrets)
config = .OpenAICompatProviderConfig~new(base"/v1/chat/completions", "provider.primary", .array~of("fixture-model"), 10, .true, 32)
transport = .OpenAICompatFetchTransport~new(.true)
provider = .OpenAICompatProviderAdapter~new(config, broker, transport)
reply = provider~complete(.AIProviderRequest~new("fixture-model", "hello provider", 7))
if \reply~ok, reply~code == "AI_PROVIDER_TRANSPORT_ERROR" then do
  say "OPENAI COMPAT V0.6 FETCH TRANSPORT: SKIP (no ADDRESS FETCH: native ooRexx)"
  exit 0
end
call check reply~ok, "completion over fetch:" reply~code
call check reply~text == "provider says hello", "text"
call check reply~model == "fixture-model-actual" & reply~finishReason == "stop", "model and finish reason"
call check reply~usage~inputTokens = 2 & reply~usage~outputTokens = 3, "usage"
address fetch "GET" base"/seen INTO seenText"
address fetch "JSON INTO seen"
call check seen[1]["auth"] == "Bearer FAKE-OPENAI-SECRET-7E4B", "Authorization sent"
call check seen[seen~items]["auth"] == "", "the key is not sent with a later request"
call check \.OpenAICompatFetchTransport~new~postJson("http://127.0.0.1:1/x", "{}", .nil, 5)~ok, "insecure http refused unless allowed"
secrets~put("provider.primary", "WRONG")
bad = provider~complete(.AIProviderRequest~new("fixture-model", "hello provider", 7))
call check \bad~ok, "wrong key: not ok (" || bad~code || ")"
call check bad~detail~pos("sk-proj-") = 0, "the provider's key-shaped text not passed on"
call check .OpenAICompatFetchTransport~module_version == "0.6", "module_version"
say "OPENAI COMPAT V0.6 FETCH TRANSPORT: OK"
exit 0
check: procedure
  use arg ok, label
  if \ok then do; say "FAILED:" label; exit 85; end
  say "  ok" label
  return
::requires "OpenAICompatProvider.cls"
::requires "SecretBroker.cls"
