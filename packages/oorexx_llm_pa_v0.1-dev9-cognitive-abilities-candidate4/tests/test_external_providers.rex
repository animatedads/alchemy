parse source . . here
call value "LLMPA_DEEPSEEK_ENDPOINT", "https://api.deepseek.com/chat/completions", "ENVIRONMENT"
call value "LLMPA_DEEPSEEK_MODELS", "deepseek-chat,deepseek-reasoner", "ENVIRONMENT"
call value "LLMPA_HUGGINGFACE_ENDPOINT", "https://router.huggingface.co/v1/chat/completions", "ENVIRONMENT"
call value "LLMPA_HUGGINGFACE_MODELS", "openai/gpt-oss-120b:cerebras", "ENVIRONMENT"
deep = .LlmPaDeepSeekProviderModule~new
hf = .LlmPaHuggingFaceProviderModule~new
call yes deep~runtimeSelfTest, "DeepSeek runtime module"
call yes hf~runtimeSelfTest, "Hugging Face runtime module"
call yes deep~hasMethod("CREATEPROVIDER"), "DeepSeek provider factory"
call yes hf~hasMethod("CREATEPROVIDER"), "Hugging Face provider factory"
planner = .LlmPaDeepSeekPlanner~new(.OpenAICompatModelPolicy~new(.array~of("deepseek-chat")))
call yes planner~hasMethod("PLAN"), "DeepSeek planner"
planner2 = .LlmPaHuggingFacePlanner~new(.OpenAICompatModelPolicy~new(.array~of("openai/gpt-oss-120b:cerebras")))
call yes planner2~hasMethod("PLAN"), "Hugging Face planner"
say "PASS test_external_providers"
exit 0

yes: procedure
  use arg answer, label
  if \answer then do; say "FAIL" label; exit 1; end
return

::requires "LlmPaExternalProviders.cls"
