/* Optional live-network Batch probe with the same evidence rule as the
 * real-time probe: transport failure is not endpoint proof. */
cfg = .AnthropicRuntimeConfig~new(.AnthropicChannel~direct, .AnthropicCredentialSource~new, "ANTHROPIC_API_KEY")
batch = .AnthropicBatchProvider~new(cfg)
item = .AnthropicBatchRequestItem~new("t1", "claude-haiku-4-5-20251001", "hi", 16)
outcome = batch~createBatch(.array~of(item))
say "ok=" outcome~ok "code=" outcome~code
if outcome~ok then say "PASS: live Anthropic Batch create succeeded"
else if outcome~code = "AI_ANTHROPIC_TRANSPORT" then say "UNPROVEN: external transport could not be established; Batch endpoint response not observed"
else say "PASS: Batch endpoint returned a structured provider-domain failure"
exit 0
::requires "AnthropicTransport.cls"
