/* FlyLo strict structured-output extension for the Grok-authored v0.4 object.
 * It retains GrokProviderConfig, SecretBroker and Grok transport boundaries,
 * adding only xAI chat/completions response_format=json_schema support.
 */

::class FlyLoStructuredAIRequest subclass AIProviderRequest public
::attribute schemaName get
::method init
  expose schemaName responseSchema
  use arg modelArg, promptArg, maxOutputArg, schemaNameArg, schemaArg
  self~init:super(modelArg, promptArg, maxOutputArg)
  schemaName = schemaNameArg~string~strip
  if schemaName = "" then raise syntax 88.900 array("FLYLO_STRUCTURED_SCHEMA_NAME_REQUIRED")
  if schemaArg == .nil | \schemaArg~isa(.Directory) then raise syntax 88.900 array("FLYLO_STRUCTURED_SCHEMA_REQUIRED")
  responseSchema = .JSON~fromJSON(.JSON~toJSON(schemaArg))
::method responseSchema
  expose responseSchema
  return .JSON~fromJSON(.JSON~toJSON(responseSchema))

::class FlyLoGrokStructuredAdapter subclass GrokProviderAdapter public
::method init
  expose structuredConfig structuredBroker structuredTransport
  use arg configArg, brokerArg, transportArg
  self~init:super(configArg, brokerArg, transportArg)
  /* GrokProviderAdapter's object variables are class-private in ooRexx. Keep
     our own references rather than pretending a subclass can EXPOSE them. */
  structuredConfig = configArg
  structuredBroker = brokerArg
  structuredTransport = transportArg
::method completeRequest protected
  expose structuredConfig structuredBroker structuredTransport
  use arg request
  if \request~isa(.FlyLoStructuredAIRequest) then return self~completeRequest:super(request)
  if \structuredConfig~allowsModel(request~model) then return .AIProviderReply~failure("AI_PROVIDER_MODEL_NOT_ALLOWED", "requested model is not enabled for this deployment", .AIProviderUsage~new(0, 0), request~model)
  if request~maxOutputTokens > structuredConfig~maxOutputTokensLimit then return .AIProviderReply~failure("AI_PROVIDER_OUTPUT_LIMIT", "requested output token limit exceeds deployment policy", .AIProviderUsage~new(0, 0), request~model)

  bodyObject = .directory~new
  bodyObject["model"] = request~model
  bodyObject["max_tokens"] = request~maxOutputTokens
  messageObject = .directory~new
  messageObject["role"] = "user"
  messageObject["content"] = request~prompt
  bodyObject["messages"] = .array~of(messageObject)
  schemaInfo = .directory~new
  schemaInfo["name"] = request~schemaName
  schemaInfo["schema"] = request~responseSchema
  schemaInfo["strict"] = .JSON~true
  responseFormat = .directory~new
  responseFormat["type"] = "json_schema"
  responseFormat["json_schema"] = schemaInfo
  bodyObject["response_format"] = responseFormat
  bodyJson = .JSON~toJSON(bodyObject)

  secretOutcome = structuredBroker~acquire(structuredConfig~credentialReference)
  if \secretOutcome~ok then return .AIProviderReply~failure("AI_PROVIDER_CREDENTIAL_UNAVAILABLE", "provider credential is unavailable", .AIProviderUsage~new(0, 0), request~model)
  lease = secretOutcome~value

  signal on syntax name postRaised
  postOutcome = structuredTransport~postJson(structuredConfig~endpoint, bodyJson, lease, structuredConfig~timeoutSeconds)
  signal off syntax
  lease~retire

  if \postOutcome~ok then return .AIProviderReply~failure(postOutcome~code, postOutcome~detail, .AIProviderUsage~new(0, 0), request~model)
  if postOutcome~status = 401 | postOutcome~status = 403 then return .AIProviderReply~failure("AI_PROVIDER_AUTH_REJECTED", "provider rejected credentials", .AIProviderUsage~new(0, 0), request~model)
  if postOutcome~status = 429 then return .AIProviderReply~failure("AI_PROVIDER_RATE_LIMITED", "provider rate limit reached", .AIProviderUsage~new(0, 0), request~model)
  if postOutcome~status < 200 | postOutcome~status >= 300 then return .AIProviderReply~failure("AI_PROVIDER_HTTP_ERROR", "provider returned non-success status", .AIProviderUsage~new(0, 0), request~model)

  signal on syntax name responseInvalid
  responseObject = .JSON~fromJSON(postOutcome~body)
  signal off syntax
  if \responseObject~isa(.Directory) then return .AIProviderReply~failure("AI_PROVIDER_RESPONSE_INVALID", "provider response must be JSON object", .AIProviderUsage~new(0, 0), request~model)
  choices = responseObject["choices"]
  if choices == .nil | \choices~isa(.Array) | choices~items < 1 then return .AIProviderReply~failure("AI_PROVIDER_RESPONSE_INVALID", "provider response choices invalid", .AIProviderUsage~new(0, 0), request~model)
  choice = choices[1]
  if \choice~isa(.Directory) then return .AIProviderReply~failure("AI_PROVIDER_RESPONSE_INVALID", "provider response choice invalid", .AIProviderUsage~new(0, 0), request~model)
  message = choice["message"]
  if message == .nil | \message~isa(.Directory) then return .AIProviderReply~failure("AI_PROVIDER_RESPONSE_INVALID", "provider response message invalid", .AIProviderUsage~new(0, 0), request~model)
  content = message["content"]
  if content == .nil then return .AIProviderReply~failure("AI_PROVIDER_RESPONSE_INVALID", "provider response content missing", .AIProviderUsage~new(0, 0), request~model)
  /* Strict structured output is still parsed/validated again by FlyLo. */
  text = content~string

  finishReason = "stop"
  finishValue = choice["finish_reason"]
  if finishValue \== .nil then finishReason = finishValue~string
  responseModel = request~model
  modelValue = responseObject["model"]
  if modelValue \== .nil then responseModel = modelValue~string
  inputTokens = 0; outputTokens = 0
  usageObject = responseObject["usage"]
  if usageObject \== .nil then if usageObject~isa(.Directory) then do
    inputValue = usageObject["prompt_tokens"]; outputValue = usageObject["completion_tokens"]
    if inputValue \== .nil then if datatype(inputValue~string, "W") then inputTokens = inputValue~string
    if outputValue \== .nil then if datatype(outputValue~string, "W") then outputTokens = outputValue~string
  end
  return .AIProviderReply~success(text, responseModel, finishReason, .AIProviderUsage~new(inputTokens, outputTokens))

postRaised:
  signal off syntax
  lease~retire
  return .AIProviderReply~failure("AI_PROVIDER_TRANSPORT_EXCEPTION", "provider transport raised a condition", .AIProviderUsage~new(0, 0), request~model)
responseInvalid:
  signal off syntax
  return .AIProviderReply~failure("AI_PROVIDER_RESPONSE_INVALID", "provider returned invalid JSON", .AIProviderUsage~new(0, 0), request~model)

::class FlyLoGrokStructuredProvider public
::method init
  expose adapter
  use arg adapterArg
  adapter = adapterArg
::method complete
  expose adapter
  use arg request
  return adapter~complete(request)
::method fromEnvironment class
  endpoint = value("AI_GROK_ENDPOINT",, "ENVIRONMENT")
  credentialReference = value("AI_GROK_CREDENTIAL_REFERENCE",, "ENVIRONMENT")
  credentialEnvName = value("AI_GROK_CREDENTIAL_ENV",, "ENVIRONMENT")
  modelCsv = value("AI_GROK_MODELS",, "ENVIRONMENT")
  timeoutText = value("AI_GROK_TIMEOUT",, "ENVIRONMENT")
  curlExecutable = value("AI_GROK_CURL",, "ENVIRONMENT")
  allowHttpText = value("AI_GROK_ALLOW_HTTP_TEST",, "ENVIRONMENT")
  maxOutputText = value("AI_GROK_MAX_OUTPUT",, "ENVIRONMENT")
  if endpoint = "" then endpoint = "https://api.x.ai/v1/chat/completions"
  if credentialReference = "" then credentialReference = "xai-api-key"
  if credentialEnvName = "" then credentialEnvName = "XAI_API_KEY"
  if modelCsv = "" then modelCsv = "grok-4.3,grok-4.6,grok-4.5,grok-4"
  if timeoutText = "" then timeoutText = 60
  if curlExecutable = "" then curlExecutable = "curl"
  if maxOutputText = "" then maxOutputText = 8192
  allowHttp = allowHttpText == "1"
  modelPolicy = .GrokModelPolicy~new(.GrokModelPolicy~parseModels(modelCsv), maxOutputText)
  config = .GrokProviderConfig~new(endpoint, credentialReference, modelPolicy~allowedModelNames, timeoutText, allowHttp, modelPolicy~maxOutputTokensLimit)
  secretMap = .directory~new; secretMap[credentialReference] = credentialEnvName
  secretProvider = .MappedEnvironmentSecretProvider~new(secretMap)
  broker = .SecretBroker~new(secretProvider)
  transport = .GrokCurlTransport~new(curlExecutable, allowHttp)
  return self~new(.FlyLoGrokStructuredAdapter~new(config, broker, transport))

::requires "GrokProvider.cls"
::requires "AIProviderAccess.cls"
::requires "SecretBroker.cls"
::requires "json.cls"
