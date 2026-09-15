/* Structural check only -- no live network call (no credential here).
 * Confirms the transport classes compile, construct, and that the
 * request/config/curl-config-building path doesn't blow up before the
 * point where it would actually need network access. */
cfg = .AnthropicRuntimeConfig~new(.AnthropicChannel~direct, .AnthropicCredentialSource~new, "ANTHROPIC_API_KEY", "claude-haiku-4-5-20251001", 512, 30, "curl")
provider = .AnthropicProvider~new(cfg)
if \provider~isa(.AIProviderAdapterBase) then
  raise syntax 88.900 array("FAIL: AnthropicProvider is not an AIProviderAdapterBase")
say "PASS AnthropicProvider constructs and satisfies the AI Access adapter contract"

req = .AIProviderRequest~new("claude-haiku-4-5-20251001", "hello world", 64)
reply = provider~complete(req)
if reply~ok then
  raise syntax 88.900 array("FAIL: expected failure without a real credential/network, got ok reply")
if reply~code \= "AI_ANTHROPIC_TRANSPORT" then
  say "NOTE non-transport failure code (may be credential-missing, which is also correct):" reply~code
say "PASS AnthropicProvider~complete fails closed without live credentials/network:" reply~code

batchCfg = .AnthropicRuntimeConfig~new(.AnthropicChannel~direct, .AnthropicCredentialSource~new, "ANTHROPIC_API_KEY")
batch = .AnthropicBatchProvider~new(batchCfg)
item = .AnthropicBatchRequestItem~new("t1", "claude-haiku-4-5-20251001", "hi", 32)
pd = item~toParamsDirectory
if pd["custom_id"] \= "t1" then raise syntax 88.900 array("FAIL: batch item custom_id wrong")
say "PASS AnthropicBatchRequestItem builds a correct params directory"

say "ALL PASS test_transport_loads"
exit 0

::requires "AnthropicTransport.cls"
