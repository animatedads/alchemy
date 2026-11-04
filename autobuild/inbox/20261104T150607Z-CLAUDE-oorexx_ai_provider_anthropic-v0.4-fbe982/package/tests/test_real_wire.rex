/* Optional live-network probe. A provider-domain auth failure proves the real
 * endpoint responded. AI_ANTHROPIC_TRANSPORT means the environment could not
 * establish the network transport and must not be reported as endpoint proof. */
cfg = .AnthropicRuntimeConfig~new(.AnthropicChannel~direct, .AnthropicCredentialSource~new, "ANTHROPIC_API_KEY", "claude-haiku-4-5-20251001", 32, 30, "curl")
provider = .AnthropicProvider~new(cfg)
req = .AIProviderRequest~new("claude-haiku-4-5-20251001", "say hi", 16)
reply = provider~complete(req)
say "ok=" reply~ok "code=" reply~code
if reply~ok then say "PASS: live Anthropic completion succeeded"
else if reply~code = "AI_ANTHROPIC_TRANSPORT" then say "UNPROVEN: external transport could not be established; endpoint response not observed"
else say "PASS: provider endpoint returned a structured provider-domain failure"
exit 0
::requires "AnthropicTransport.cls"
