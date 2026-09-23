/* Temporary dogfood orchestrator for a bounded OpenAI response. */

::class LlmPaOpenAIOrchestrator public
::attribute modelName get

::method init
  expose provider modelName
  use arg modelArg = "gpt-4o-mini", endpointArg = "https://api.openai.com/v1/chat/completions", credentialEnvArg = "OPENAI_API_KEY"
  modelName = modelArg~string~strip
  endpoint = endpointArg~string~strip
  credentialEnv = credentialEnvArg~string~strip
  if endpoint = "" then endpoint = "https://api.openai.com/v1/chat/completions"
  if credentialEnv = "" then credentialEnv = "OPENAI_API_KEY"
  if modelName = "" | endpoint = "" | credentialEnv = "" then raise syntax 88.900 array("OpenAI dogfood configuration is incomplete")
  models = .OpenAICompatModelPolicy~new(.array~of(modelName), 2048)
  config = .OpenAICompatProviderConfig~new(endpoint, "llmpa-openai-dogfood-key", models~allowedModelNames, 30, .false, 2048)
  secretMap = .directory~new
  secretMap["llmpa-openai-dogfood-key"] = credentialEnv
  broker = .SecretBroker~new(.MappedEnvironmentSecretProvider~new(secretMap))
  provider = .OpenAICompatProviderAdapter~new(config, broker, .OpenAICompatCurlTransport~new("curl", .false))

::method verifyModel
  expose modelName
  return .LlmPaResult~success(modelName)

::method runOnce
  expose provider modelName
  use arg requestedModel = "", prompt, maxOutputTokens = 512
  model = requestedModel~string~strip
  if model = "" then model = modelName
  if \model~caselessEquals(modelName) then return .LlmPaResult~failure("OPENAI_MODEL_MISMATCH", model)
  response = provider~complete(.AIProviderRequest~new(model, prompt, maxOutputTokens))
  if \response~ok then return .LlmPaResult~failure(response~code, response~detail)
  return .LlmPaResult~success(.LlmPaLiveModelResult~new(response~text, response~model))

::requires "LlmPaNativeOllama.cls"
::requires "OpenAICompatProvider.cls"
::requires "SecretBroker.cls"
