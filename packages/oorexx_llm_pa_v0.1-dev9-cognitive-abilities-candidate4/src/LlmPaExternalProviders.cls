/* Named OpenAI-compatible deployments used by the LLM PA.
 *
 * DeepSeek and Hugging Face share the wire protocol, but are deliberately
 * separate Runtime Registry modules. Each receives its own endpoint,
 * credential mapping, model policy and planner identity.
 */

::class LlmPaNamedOpenAICompatModule subclass AIProviderRuntimeCapability public

::method initFor protected
  expose deploymentConfig deploymentBroker deploymentTransport
  use arg endpointDefault, credentialReferenceDefault, credentialEnvDefault, modelsDefault, providerLabel
  endpoint = value(providerLabel || "_ENDPOINT",, "ENVIRONMENT")
  if endpoint = "" then endpoint = endpointDefault
  credentialReference = value(providerLabel || "_CREDENTIAL_REFERENCE",, "ENVIRONMENT")
  if credentialReference = "" then credentialReference = credentialReferenceDefault
  credentialEnvName = value(providerLabel || "_CREDENTIAL_ENV",, "ENVIRONMENT")
  if credentialEnvName = "" then credentialEnvName = credentialEnvDefault
  modelCsv = value(providerLabel || "_MODELS",, "ENVIRONMENT")
  if modelCsv = "" then modelCsv = modelsDefault
  timeoutText = value(providerLabel || "_TIMEOUT",, "ENVIRONMENT")
  if timeoutText = "" then timeoutText = 60
  maxOutputText = value(providerLabel || "_MAX_OUTPUT",, "ENVIRONMENT")
  if maxOutputText = "" then maxOutputText = 8192
  allowHttpText = value(providerLabel || "_ALLOW_HTTP_TEST",, "ENVIRONMENT")
  allowHttp = allowHttpText = "1"
  modelPolicy = .OpenAICompatModelPolicy~new(.OpenAICompatModelPolicy~parseModels(modelCsv), maxOutputText)
  deploymentConfig = .OpenAICompatProviderConfig~new(endpoint, credentialReference, modelPolicy~allowedModelNames, timeoutText, allowHttp, modelPolicy~maxOutputTokensLimit)
  secretMap = .directory~new
  secretMap[credentialReference] = credentialEnvName
  secretProvider = .MappedEnvironmentSecretProvider~new(secretMap)
  deploymentBroker = .SecretBroker~new(secretProvider)
  deploymentTransport = .OpenAICompatCurlTransport~new("curl", allowHttp)
  self~init:super
  self~registerStateVariable("deploymentConfig", "INTERNAL", "frozen non-secret named provider configuration")
  self~registerStateVariable("deploymentBroker", "SECRET", "named provider secret broker")
  self~registerStateVariable("deploymentTransport", "INTERNAL", "named provider HTTP transport")

::method createProvider protected
  expose deploymentConfig deploymentBroker deploymentTransport
  return .OpenAICompatProviderAdapter~new(deploymentConfig, deploymentBroker, deploymentTransport)

::class LlmPaDeepSeekProviderModule subclass LlmPaNamedOpenAICompatModule public
::method init
  self~initFor("https://api.deepseek.com/chat/completions", "deepseek-api-key", "DEEPSEEK_API_KEY", "deepseek-chat,deepseek-reasoner", "LLMPA_DEEPSEEK")

::class LlmPaHuggingFaceProviderModule subclass LlmPaNamedOpenAICompatModule public
::method init
  self~initFor("https://router.huggingface.co/v1/chat/completions", "huggingface-token", "HF_TOKEN", "inclusionAI/Ling-3.0-flash-Fin:novita,inclusionAI/Ling-3.0-flash-VL:novita,prism-ml/Ternary-Bonsai-27B-AWQ-4bit:together,prism-ml/Ternary-Bonsai-27B-gguf:together,openai/gpt-oss-120b:cerebras,openai/gpt-oss-20b:cerebras,Qwen/Qwen3.8-27B:ovhcloud", "LLMPA_HUGGINGFACE")

/* Named planner classes make provider selection visible to Runtime Registry
 * profiles while reusing the certified OpenAI-compatible WLU policy engine. */
::class LlmPaDeepSeekPlanner subclass OpenAICompatWLUPlanner public
::class LlmPaHuggingFacePlanner subclass OpenAICompatWLUPlanner public

::requires "AIProviderAccess.cls"
::requires "OpenAICompatProvider.cls"
::requires "OpenAICompatWLU.cls"
::requires "SecretBroker.cls"
::requires "json.cls"
