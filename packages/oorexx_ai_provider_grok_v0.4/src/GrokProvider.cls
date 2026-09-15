/* ooRexx AI Provider Grok (xAI) v0.4
 *
 * Live-capable Grok/xAI provider adapter for the generic AI Access boundary.
 * xAI Inference API is OpenAI-compatible; this module specialises defaults,
 * environment variable names and model policy for api.x.ai.
 *
 * Design rules:
 *   - deployment config owns endpoint, credential reference and model allowlist;
 *   - request text can choose only an allowlisted model;
 *   - the provider acquires a SecretLease by opaque reference;
 *   - the trusted transport materializes the lease and injects Authorization;
 *   - secret material is never placed in command-line arguments or Alchemy
 *     instrumentation;
 *   - raw provider/network error bodies are not returned to the caller.
 */

::class GrokProviderBuild public
::constant PRODUCT "ooRexx AI Provider - Grok (xAI)"
::constant RELEASE "0.4"
::constant API_VERSION "ai.provider.grok/0.3"
::constant AI_ACCESS_VERSION "0.6"
::constant SECRET_BROKER_VERSION "0.2"
::constant ALCHEMY_OBJECTS_VERSION "0.8"

::class GrokTransportResult public
::attribute ok get
::attribute code get
::attribute status get
::attribute body get
::attribute detail get

::method init
  expose ok code status body detail
  use arg okArg, codeArg = "OK", statusArg = 0, bodyArg = "", detailArg = ""
  ok = okArg == .true
  code = codeArg~string~strip
  status = statusArg
  body = bodyArg~string
  detail = detailArg~string

::method success class
  use arg status, body
  return self~new(.true, "OK", status, body, "")

::method failure class
  use arg code, detail = "", status = 0
  return self~new(.false, code, status, "", detail)


/* Shared non-secret model admission policy.
 *
 * The provider and the optional WLU planner both consume copies of this
 * policy.  It deliberately contains no endpoint, credential reference,
 * environment-variable name, transport or secret-broker object. */
::class GrokModelPolicy public
::attribute maxOutputTokensLimit get

::method init
  expose allowedModels maxOutputTokensLimit
  use arg allowedModelsArg, maxOutputArg = 8192
  maxOutputTokensLimit = maxOutputArg
  if \datatype(maxOutputTokensLimit, "W") then raise syntax 88.900 array("Grok output limit must be whole")
  if maxOutputTokensLimit < 1 then raise syntax 88.900 array("Grok output limit must be positive")
  if maxOutputTokensLimit > 65536 then raise syntax 88.900 array("Grok output limit is unreasonably large")
  if allowedModelsArg == .nil then raise syntax 88.900 array("Grok model allowlist is required")
  if \allowedModelsArg~isa(.Array) then raise syntax 88.900 array("Grok model allowlist must be Array")
  if allowedModelsArg~items = 0 then raise syntax 88.900 array("Grok model allowlist must not be empty")
  allowedModels = .directory~new
  do modelValue over allowedModelsArg
    modelName = modelValue~string~strip
    if modelName = "" then raise syntax 88.900 array("Grok allowed model must not be empty")
    allowedModels[modelName] = .true
  end

::method allowsModel
  expose allowedModels
  use arg modelArg
  return allowedModels[modelArg~string~strip] == .true

::method allowedModelNames
  expose allowedModels
  names = .array~new
  do modelName over allowedModels~allIndexes
    names~append(modelName)
  end
  return names

::method fromEnvironment class
  modelCsv = value("AI_GROK_MODELS",, "ENVIRONMENT")
  maxOutputText = value("AI_GROK_MAX_OUTPUT",, "ENVIRONMENT")
  if maxOutputText = "" then maxOutputText = 8192
  return self~new(self~parseModels(modelCsv), maxOutputText)

::method parseModels class
  use arg csvArg
  csv = csvArg~string
  models = .array~new
  remaining = csv
  do while remaining \= ""
    comma = remaining~pos(",")
    if comma = 0 then do
      item = remaining~strip
      remaining = ""
    end
    else do
      item = remaining~left(comma - 1)~strip
      remaining = remaining~substr(comma + 1)
    end
    if item \= "" then models~append(item)
  end
  return models

/* Plain deployment value object.  Secret values are not configuration. */
::class GrokProviderConfig public
::attribute endpoint get
::attribute credentialReference get
::attribute timeoutSeconds get
::attribute allowInsecureHttp get
::attribute modelPolicy get

::method init
  expose endpoint credentialReference timeoutSeconds allowInsecureHttp modelPolicy
  use arg endpointArg, credentialReferenceArg, allowedModelsArg, timeoutArg = 30, allowHttpArg = .false, maxOutputArg = 8192
  endpoint = endpointArg~string~strip
  credentialReference = credentialReferenceArg~string~strip
  timeoutSeconds = timeoutArg
  allowInsecureHttp = allowHttpArg == .true
  modelPolicy = .GrokModelPolicy~new(allowedModelsArg, maxOutputArg)

  if endpoint = "" then raise syntax 88.900 array("Grok endpoint must not be empty")
  if endpoint~left(8)~lower = "https://" then nop
  else do
    if \allowInsecureHttp then raise syntax 88.900 array("Grok endpoint must use https")
    if endpoint~left(7)~lower \= "http://" then raise syntax 88.900 array("test endpoint must use http or https")
  end
  if credentialReference = "" then raise syntax 88.900 array("Grok credential reference must not be empty")
  if \datatype(timeoutSeconds, "W") then raise syntax 88.900 array("Grok timeout must be whole")
  if timeoutSeconds < 1 then raise syntax 88.900 array("Grok timeout must be positive")
  if timeoutSeconds > 300 then raise syntax 88.900 array("Grok timeout exceeds 300 seconds")

::method allowsModel
  expose modelPolicy
  use arg modelArg
  return modelPolicy~allowsModel(modelArg)

::method allowedModelNames
  expose modelPolicy
  return modelPolicy~allowedModelNames

::method maxOutputTokensLimit
  expose modelPolicy
  return modelPolicy~maxOutputTokensLimit

::method safeDescription
  expose endpoint credentialReference timeoutSeconds allowInsecureHttp modelPolicy
  d = .directory~new
  d["endpoint"] = endpoint
  d["credential_reference"] = credentialReference
  d["timeout_seconds"] = timeoutSeconds
  d["allow_insecure_http"] = allowInsecureHttp
  d["max_output_tokens_limit"] = modelPolicy~maxOutputTokensLimit
  d["allowed_model_count"] = modelPolicy~allowedModelNames~items
  return d


::class GrokTransportBase subclass AlchemyObject public

::method init
  meta = .directory~new
  meta["purpose"] = "Trusted HTTP transport for Grok provider adapter"
  meta["package"] = "oorexx_ai_provider_grok"
  meta["package_version"] = .GrokProviderBuild~RELEASE
  meta["api_version"] = "ai.provider.http-transport/0.1"
  meta["authorship"] = "Alchemy ooRexx project"
  meta["standards"] = "ALCHEMY-HOUSE-OBJECT-0.8; ai.provider.grok/0.3; secret.broker/0.2 trusted-consumer credential boundary"
  meta["design_limitations"] = "Transport materializes one SecretLease only inside a bounded curl request; it is not a credential store, provider scheduler, Runtime Registry authority or WLU admission authority"
  self~init:super(meta)
  self~registerMethodContract("POSTJSON", "POST provider JSON while injecting credential from SecretLease inside transport boundary", .array~of("ENDPOINT", "BODYJSON", "LEASE", "TIMEOUT"), "ANY", .true, "FALSE", "SECRET", "SECURITY_BOUNDARY", "EXTERNAL", "USE")
  self~registerInstrumentationPoint("AI.HTTP.POST.BEFORE", "provider HTTP request entered; endpoint scheme/size only", .true, "ALL", "INTERNAL")
  self~registerInstrumentationPoint("AI.HTTP.POST.AFTER", "provider HTTP request completed; status/size only", .true, "ALL", "INTERNAL")
  self~registerExternalRequirement("library", "alchemy_objects", "v" || .GrokProviderBuild~ALCHEMY_OBJECTS_VERSION, .true)
  self~registerExternalRequirement("library", "oorexx_secret_broker", "v" || .GrokProviderBuild~SECRET_BROKER_VERSION, .true)
  self~declareHouseCompliance(95)

::method postJson public protected
  use arg endpoint, bodyJson, lease, timeoutSeconds
  before = .directory~new
  if endpoint~string~left(8)~lower = "https://" then before["scheme"] = "HTTPS"
  else before["scheme"] = "HTTP"
  before["request_bytes"] = bodyJson~string~length
  self~alchemyInstrument("AI.HTTP.POST.BEFORE", before)

  signal on syntax name transportRaised
  transportOutcome = self~postJsonTrusted(endpoint, bodyJson, lease, timeoutSeconds)
  signal off syntax

  after = .directory~new
  if transportOutcome == .nil then do
    after["ok"] = .false
    after["code"] = "AI_PROVIDER_TRANSPORT_CONTRACT"
    self~alchemyInstrument("AI.HTTP.POST.AFTER", after)
    return .GrokTransportResult~failure("AI_PROVIDER_TRANSPORT_CONTRACT", "transport returned nil")
  end
  if \transportOutcome~isa(.GrokTransportResult) then do
    after["ok"] = .false
    after["code"] = "AI_PROVIDER_TRANSPORT_CONTRACT"
    self~alchemyInstrument("AI.HTTP.POST.AFTER", after)
    return .GrokTransportResult~failure("AI_PROVIDER_TRANSPORT_CONTRACT", "transport returned unsupported result")
  end
  after["ok"] = transportOutcome~ok
  after["code"] = transportOutcome~code
  after["status"] = transportOutcome~status
  after["response_bytes"] = transportOutcome~body~length
  self~alchemyInstrument("AI.HTTP.POST.AFTER", after)
  return transportOutcome

transportRaised:
  signal off syntax
  after = .directory~new
  after["ok"] = .false
  after["code"] = "AI_PROVIDER_TRANSPORT_EXCEPTION"
  after["condition"] = condition("C")
  self~alchemyInstrument("AI.HTTP.POST.AFTER", after)
  return .GrokTransportResult~failure("AI_PROVIDER_TRANSPORT_EXCEPTION", "transport raised a condition")

::method postJsonTrusted protected
  use arg endpoint, bodyJson, lease, timeoutSeconds
  return .GrokTransportResult~failure("AI_PROVIDER_TRANSPORT_ABSTRACT", "transport did not implement postJsonTrusted")


/* Production/live-capable curl transport.
 *
 * The Authorization header is written to a mode-600 temporary curl config,
 * never appended to commandText.  The command line contains only file paths,
 * endpoint, timeout and non-secret transport flags. */
::class GrokCurlTransport subclass GrokTransportBase public

::method init
  expose executable allowInsecureHttp
  use arg executableArg = "curl", allowHttpArg = .false
  executable = executableArg~string
  allowInsecureHttp = allowHttpArg == .true
  self~init:super
  self~registerStateVariable("executable", "INTERNAL", "curl executable path/name")
  self~registerStateVariable("allowInsecureHttp", "INTERNAL", "test-only HTTP transport permission")
  self~registerExternalRequirement("executable", "curl", "HTTPS client", .true)

::method postJsonTrusted protected
  expose executable allowInsecureHttp
  use arg endpointArg, bodyJsonArg, lease, timeoutSeconds
  endpoint = endpointArg~string~strip
  bodyJson = bodyJsonArg~string
  if endpoint~left(8)~lower = "https://" then proto = "=https"
  else do
    if \allowInsecureHttp then return .GrokTransportResult~failure("AI_PROVIDER_ENDPOINT_INSECURE", "transport refuses insecure endpoint")
    if endpoint~left(7)~lower \= "http://" then return .GrokTransportResult~failure("AI_PROVIDER_ENDPOINT_INVALID", "transport endpoint scheme unsupported")
    proto = "=http,https"
  end
  if \datatype(timeoutSeconds, "W") then return .GrokTransportResult~failure("AI_PROVIDER_TIMEOUT_INVALID", "timeout must be whole")
  if timeoutSeconds < 1 then return .GrokTransportResult~failure("AI_PROVIDER_TIMEOUT_INVALID", "timeout must be positive")
  if timeoutSeconds > 300 then return .GrokTransportResult~failure("AI_PROVIDER_TIMEOUT_INVALID", "timeout exceeds 300 seconds")
  if lease == .nil then return .GrokTransportResult~failure("AI_PROVIDER_CREDENTIAL_INVALID", "secret lease missing")
  if \lease~isa(.SecretLease) then return .GrokTransportResult~failure("AI_PROVIDER_CREDENTIAL_INVALID", "secret lease type invalid")

  secretOutcome = lease~secretForTrustedConsumer
  if \secretOutcome~ok then return .GrokTransportResult~failure("AI_PROVIDER_CREDENTIAL_UNAVAILABLE", "credential lease unavailable")
  secretText = secretOutcome~value~string
  if secretText = "" then return .GrokTransportResult~failure("AI_PROVIDER_CREDENTIAL_UNAVAILABLE", "credential is empty")
  if secretText~pos('0d'x) > 0 then return .GrokTransportResult~failure("AI_PROVIDER_CREDENTIAL_INVALID", "credential contains forbidden control characters")
  if secretText~pos('0a'x) > 0 then return .GrokTransportResult~failure("AI_PROVIDER_CREDENTIAL_INVALID", "credential contains forbidden control characters")
  if secretText~pos('00'x) > 0 then return .GrokTransportResult~failure("AI_PROVIDER_CREDENTIAL_INVALID", "credential contains forbidden control characters")

  tempBase = .File~temporaryPath
  requestPath = SysTempFileName(.File~new("ai_grok_request.????????", tempBase)~string)
  configPath = SysTempFileName(.File~new("ai_grok_secret.????????", tempBase)~string)
  headerPath = SysTempFileName(.File~new("ai_grok_headers.????????", tempBase)~string)
  responsePath = SysTempFileName(.File~new("ai_grok_response.????????", tempBase)~string)
  errorPath = SysTempFileName(.File~new("ai_grok_error.????????", tempBase)~string)

  if \self~writeFile(requestPath, bodyJson) then return .GrokTransportResult~failure("AI_PROVIDER_TEMPFILE_ERROR", "unable to stage request body")
  configText = 'header = "Authorization: Bearer ' || self~curlConfigEscape(secretText) || '"' || '0a'x
  if \self~writeFile(configPath, configText) then do
    self~cleanup(requestPath, configPath, headerPath, responsePath, errorPath)
    return .GrokTransportResult~failure("AI_PROVIDER_TEMPFILE_ERROR", "unable to stage credential config")
  end
  chmodText = "chmod 600 -- " || self~shellQuote(configPath)
  address system chmodText
  commandMode = rc
  if commandMode \= 0 then do
    self~cleanup(requestPath, configPath, headerPath, responsePath, errorPath)
    return .GrokTransportResult~failure("AI_PROVIDER_TEMPFILE_ERROR", "unable to restrict credential config permissions")
  end

  commandText = self~shellQuote(executable) || -
    " --silent --show-error --max-redirs 0" || -
    " --proto " || self~shellQuote(proto) || -
    " --max-time " || timeoutSeconds || -
    " --request POST" || -
    " --header " || self~shellQuote("Content-Type: application/json") || -
    " --header " || self~shellQuote("Accept: application/json") || -
    " --config " || self~shellQuote(configPath) || -
    " --data-binary " || self~shellQuote("@" || requestPath) || -
    " --dump-header " || self~shellQuote(headerPath) || -
    " --output " || self~shellQuote(responsePath) || -
    " " || self~shellQuote(endpoint) || -
    " 2>" || self~shellQuote(errorPath)

  address system commandText
  commandStatus = rc
  rawHeaders = self~readFile(headerPath)
  responseBody = self~readFile(responsePath)
  self~cleanup(requestPath, configPath, headerPath, responsePath, errorPath)

  secretText = ""
  configText = ""

  if commandStatus \= 0 then return .GrokTransportResult~failure("AI_PROVIDER_TRANSPORT_ERROR", "curl transport failed")
  httpStatus = self~lastHttpStatus(rawHeaders)
  if httpStatus = 0 then return .GrokTransportResult~failure("AI_PROVIDER_HTTP_STATUS_MISSING", "provider response did not include HTTP status")
  return .GrokTransportResult~success(httpStatus, responseBody)

::method lastHttpStatus private
  use arg rawHeaders
  text = rawHeaders~changestr('0d0a'x, '0a'x)~changestr('0d'x, '0a'x)
  lines = text~makeArray
  found = 0
  do line over lines
    if line~left(5)~translate = "HTTP/" then do
      parse var line . statusCode .
      if datatype(statusCode, "W") then found = statusCode
    end
  end
  return found

::method writeFile private
  use arg path, bytes
  streamObject = .Stream~new(path)
  opened = streamObject~open("WRITE REPLACE")
  if \opened~caselessEquals("READY:") then return .false
  ignore = streamObject~charout(bytes)
  ignore = streamObject~close
  return .true

::method readFile private
  use arg path
  if stream(path, "c", "query exists") = "" then return ""
  streamObject = .Stream~new(path)
  opened = streamObject~open("READ")
  if \opened~caselessEquals("READY:") then return ""
  count = streamObject~chars
  if count > 0 then bytes = streamObject~charin(1, count)
  else bytes = ""
  ignore = streamObject~close
  return bytes

::method cleanup private
  use arg requestPath, configPath, headerPath, responsePath, errorPath
  paths = .array~of(requestPath, configPath, headerPath, responsePath, errorPath)
  do path over paths
    if stream(path, "c", "query exists") \= "" then ignore = SysFileDelete(path)
  end
  return .true

::method shellQuote private
  use arg valueArg
  text = valueArg~string
  text = text~changestr("'", "'\\''")
  return "'" || text || "'"

::method curlConfigEscape private
  use arg valueArg
  text = valueArg~string
  text = text~changestr("\\", "\\\\")
  text = text~changestr('"', '\\"')
  return text


::class GrokProviderAdapter subclass AIProviderAdapterBase public

::method init
  expose providerConfig secretBroker httpTransport
  use arg configArg, brokerArg, transportArg
  if configArg == .nil then raise syntax 88.900 array("Grok provider requires config")
  if \configArg~isa(.GrokProviderConfig) then raise syntax 88.900 array("Grok provider config type invalid")
  if brokerArg == .nil then raise syntax 88.900 array("Grok provider requires secret broker")
  if \brokerArg~hasMethod("ACQUIRE") then raise syntax 88.900 array("Grok provider secret broker contract invalid")
  if transportArg == .nil then raise syntax 88.900 array("Grok provider requires HTTP transport")
  if \transportArg~hasMethod("POSTJSON") then raise syntax 88.900 array("Grok provider transport contract invalid")
  providerConfig = configArg
  secretBroker = brokerArg
  httpTransport = transportArg
  self~init:super
  self~registerStateVariable("providerConfig", "INTERNAL", "frozen non-secret deployment configuration")
  self~registerStateVariable("secretBroker", "SECRET", "secret broker object reference")
  self~registerStateVariable("httpTransport", "INTERNAL", "trusted provider HTTP transport")
  self~registerExternalRequirement("library", "oorexx_ai_access", "v" || .GrokProviderBuild~AI_ACCESS_VERSION, .true)
  self~registerExternalRequirement("library", "oorexx_secret_broker", "v" || .GrokProviderBuild~SECRET_BROKER_VERSION, .true)
  self~recordRelationship("SECRET_BROKER", secretBroker, "credential resolution authority", "SECRET")
  self~recordRelationship("HTTP_TRANSPORT", httpTransport, "trusted provider transport", "INTERNAL")

::method completeRequest protected
  expose providerConfig secretBroker httpTransport
  use arg request
  if \request~isa(.AIProviderRequest) then return .AIProviderReply~failure("AI_PROVIDER_REQUEST_TYPE", "expected AIProviderRequest")
  if \providerConfig~allowsModel(request~model) then return .AIProviderReply~failure("AI_PROVIDER_MODEL_NOT_ALLOWED", "requested model is not enabled for this deployment", .AIProviderUsage~new(0, 0), request~model)
  if request~maxOutputTokens > providerConfig~maxOutputTokensLimit then return .AIProviderReply~failure("AI_PROVIDER_OUTPUT_LIMIT", "requested output token limit exceeds deployment policy", .AIProviderUsage~new(0, 0), request~model)

  bodyObject = .directory~new
  bodyObject["model"] = request~model
  bodyObject["max_tokens"] = request~maxOutputTokens
  messageObject = .directory~new
  messageObject["role"] = "user"
  messageObject["content"] = request~prompt
  bodyObject["messages"] = .array~of(messageObject)
  bodyJson = .JSON~toJSON(bodyObject)

  secretOutcome = secretBroker~acquire(providerConfig~credentialReference)
  if \secretOutcome~ok then return .AIProviderReply~failure("AI_PROVIDER_CREDENTIAL_UNAVAILABLE", "provider credential is unavailable", .AIProviderUsage~new(0, 0), request~model)
  lease = secretOutcome~value

  signal on syntax name postRaised
  postOutcome = httpTransport~postJson(providerConfig~endpoint, bodyJson, lease, providerConfig~timeoutSeconds)
  signal off syntax
  lease~retire

  if \postOutcome~ok then return .AIProviderReply~failure(postOutcome~code, postOutcome~detail, .AIProviderUsage~new(0, 0), request~model)
  if postOutcome~status = 401 then return .AIProviderReply~failure("AI_PROVIDER_AUTH_REJECTED", "provider rejected credentials", .AIProviderUsage~new(0, 0), request~model)
  if postOutcome~status = 403 then return .AIProviderReply~failure("AI_PROVIDER_AUTH_REJECTED", "provider rejected credentials", .AIProviderUsage~new(0, 0), request~model)
  if postOutcome~status = 429 then return .AIProviderReply~failure("AI_PROVIDER_RATE_LIMITED", "provider rate limit reached", .AIProviderUsage~new(0, 0), request~model)
  if postOutcome~status < 200 then return .AIProviderReply~failure("AI_PROVIDER_HTTP_ERROR", "provider returned non-success status", .AIProviderUsage~new(0, 0), request~model)
  if postOutcome~status >= 300 then return .AIProviderReply~failure("AI_PROVIDER_HTTP_ERROR", "provider returned non-success status", .AIProviderUsage~new(0, 0), request~model)

  signal on syntax name responseInvalid
  responseObject = .JSON~fromJSON(postOutcome~body)
  signal off syntax
  if \responseObject~isa(.Directory) then return .AIProviderReply~failure("AI_PROVIDER_RESPONSE_INVALID", "provider response must be JSON object", .AIProviderUsage~new(0, 0), request~model)
  choices = responseObject["choices"]
  if choices == .nil then return .AIProviderReply~failure("AI_PROVIDER_RESPONSE_INVALID", "provider response choices missing", .AIProviderUsage~new(0, 0), request~model)
  if \choices~isa(.Array) then return .AIProviderReply~failure("AI_PROVIDER_RESPONSE_INVALID", "provider response choices invalid", .AIProviderUsage~new(0, 0), request~model)
  if choices~items < 1 then return .AIProviderReply~failure("AI_PROVIDER_RESPONSE_INVALID", "provider response choices empty", .AIProviderUsage~new(0, 0), request~model)
  choice = choices[1]
  if \choice~isa(.Directory) then return .AIProviderReply~failure("AI_PROVIDER_RESPONSE_INVALID", "provider response choice invalid", .AIProviderUsage~new(0, 0), request~model)
  message = choice["message"]
  if message == .nil then return .AIProviderReply~failure("AI_PROVIDER_RESPONSE_INVALID", "provider response message missing", .AIProviderUsage~new(0, 0), request~model)
  if \message~isa(.Directory) then return .AIProviderReply~failure("AI_PROVIDER_RESPONSE_INVALID", "provider response message invalid", .AIProviderUsage~new(0, 0), request~model)
  content = message["content"]
  if content == .nil then return .AIProviderReply~failure("AI_PROVIDER_RESPONSE_INVALID", "provider response content missing", .AIProviderUsage~new(0, 0), request~model)
  text = content~string

  finishReason = "stop"
  finishValue = choice["finish_reason"]
  if finishValue \== .nil then finishReason = finishValue~string
  responseModel = request~model
  modelValue = responseObject["model"]
  if modelValue \== .nil then responseModel = modelValue~string

  inputTokens = 0
  outputTokens = 0
  usageObject = responseObject["usage"]
  if usageObject \== .nil then do
    if usageObject~isa(.Directory) then do
      inputValue = usageObject["prompt_tokens"]
      outputValue = usageObject["completion_tokens"]
      if inputValue \== .nil then if datatype(inputValue~string, "W") then inputTokens = inputValue~string
      if outputValue \== .nil then if datatype(outputValue~string, "W") then outputTokens = outputValue~string
    end
  end
  usage = .AIProviderUsage~new(inputTokens, outputTokens)
  return .AIProviderReply~success(text, responseModel, finishReason, usage)

postRaised:
  signal off syntax
  lease~retire
  return .AIProviderReply~failure("AI_PROVIDER_TRANSPORT_EXCEPTION", "provider transport raised a condition", .AIProviderUsage~new(0, 0), request~model)

responseInvalid:
  signal off syntax
  return .AIProviderReply~failure("AI_PROVIDER_RESPONSE_INVALID", "provider returned invalid JSON", .AIProviderUsage~new(0, 0), request~model)


/* Deployment module.  Non-secret configuration is frozen during init.
 * The secret value itself is resolved by reference for each request, allowing
 * host-controlled credential rotation without handing credentials to Runtime
 * Registry or AIProviderRequest. */
::class GrokRuntimeModule subclass AIProviderRuntimeCapability public

::method init
  expose deploymentConfig deploymentBroker deploymentTransport
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
  if modelCsv = "" then modelCsv = "grok-4,grok-4.6,grok-4.5,grok-4.3,grok-code-fast-1,grok-2-vision,grok-2-vision-1212"
  if timeoutText = "" then timeoutText = 60
  if curlExecutable = "" then curlExecutable = "curl"
  if maxOutputText = "" then maxOutputText = 8192
  allowHttp = allowHttpText == "1"
  modelPolicy = .GrokModelPolicy~new(.GrokModelPolicy~parseModels(modelCsv), maxOutputText)
  deploymentConfig = .GrokProviderConfig~new(endpoint, credentialReference, modelPolicy~allowedModelNames, timeoutText, allowHttp, modelPolicy~maxOutputTokensLimit)
  secretMap = .directory~new
  secretMap[credentialReference] = credentialEnvName
  secretProvider = .MappedEnvironmentSecretProvider~new(secretMap)
  deploymentBroker = .SecretBroker~new(secretProvider)
  deploymentTransport = .GrokCurlTransport~new(curlExecutable, allowHttp)
  self~init:super
  self~registerStateVariable("deploymentConfig", "INTERNAL", "frozen non-secret Grok deployment configuration")
  self~registerStateVariable("deploymentBroker", "SECRET", "deployment secret broker")
  self~registerStateVariable("deploymentTransport", "INTERNAL", "deployment HTTP transport")

::method createProvider protected
  expose deploymentConfig deploymentBroker deploymentTransport
  return .GrokProviderAdapter~new(deploymentConfig, deploymentBroker, deploymentTransport)

::requires "AIProviderAccess.cls"
::requires "SecretBroker.cls"
::requires "json.cls"
