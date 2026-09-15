/* Low-cost live qualification of the named Hugging Face PA provider. */
call value "LLMPA_HUGGINGFACE_MODELS", "Qwen/Qwen3.8-27B:ovhcloud", "ENVIRONMENT"
call value "LLMPA_HUGGINGFACE_CREDENTIAL_ENV", "HF_TOKEN", "ENVIRONMENT"
module = .LiveHuggingFaceModule~new
provider = module~providerForTest
request = .AIProviderRequest~new("Qwen/Qwen3.8-27B:ovhcloud", "You are an LLM PA. Reply in one short sentence beginning PA-READY and state your role.", 96)
reply = provider~complete(request)
if \reply~ok then do
  say "FAIL test_live_huggingface_pa" reply~code reply~detail
  exit 1
end
text = reply~text~strip
if text~length = 0 then do
  say "FAIL test_live_huggingface_pa empty reply"
  exit 2
end
say "HF_PA_MODEL=" || reply~model
say "HF_PA_REPLY=" || text
say "HF_PA_USAGE=" || reply~usage~totalTokens
say "PASS test_live_huggingface_pa"
exit 0

::class LiveHuggingFaceModule subclass LlmPaHuggingFaceProviderModule public
::method providerForTest public
  return self~createProvider

::requires "LlmPaExternalProviders.cls"
