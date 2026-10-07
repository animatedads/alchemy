/* ooRexx AI Provider OpenAI-Compatible v0.6
 *
 * Live-capable provider adapter for the generic AI Access boundary.
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

::class OpenAICompatProviderBuild public
::constant PRODUCT "ooRexx AI Provider - OpenAI Compatible"
::constant RELEASE "0.6"
::constant API_VERSION "ai.provider.openai-compat/0.6"
::constant AI_ACCESS_VERSION "0.5"
::constant SECRET_BROKER_VERSION "0.1"
::constant ALCHEMY_OBJECTS_VERSION "0.7"

::class OpenAICompatTransportResult public
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
::class OpenAICompatModelPolicy public
::attribute maxOutputTokensLimit get

::method init
  expose allowedModels maxOutputTokensLimit
  use arg allowedModelsArg, maxOutputArg = 8192
  maxOutputTokensLimit = maxOutputArg
  if \datatype(maxOutputTokensLimit, "W") then raise syntax 88.900 array("OpenAI-compatible output limit must be whole")
  if maxOutputTokensLimit < 1 then raise syntax 88.900 array("OpenAI-compatible output limit must be positive")
  if maxOutputTokensLimit > 65536 then raise syntax 88.900 array("OpenAI-compatible output limit is unreasonably large")
  if allowedModelsArg == .nil then raise syntax 88.900 array("OpenAI-compatible model allowlist is required")
  if \allowedModelsArg~isa(.Array) then raise syntax 88.900 array("OpenAI-compatible model allowlist must be Array")
  if allowedModelsArg~items = 0 then raise syntax 88.900 array("OpenAI-compatible model allowlist must not be empty")
  allowedModels = .directory~new
  do modelValue over allowedModelsArg
    modelName = modelValue~string~strip
    if modelName = "" then raise syntax 88.900 array("OpenAI-compatible allowed model must not be empty")
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
  modelCsv = value("AI_OPENAI_COMPAT_MODELS",, "ENVIRONMENT")
  maxOutputText = value("AI_OPENAI_COMPAT_MAX_OUTPUT",, "ENVIRONMENT")
  authModeText = value("AI_OPENAI_COMPAT_AUTH_MODE",, "ENVIRONMENT")
  authHeaderText = value("AI_OPENAI_COMPAT_AUTH_HEADER",, "ENVIRONMENT")
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
::class OpenAICompatProviderConfig public
::attribute endpoint get
::attribute credentialReference get
::attribute timeoutSeconds get
::attribute allowInsecureHttp get
::attribute modelPolicy get
::attribute authMode get
::attribute authHeaderName get

::method init
  expose endpoint credentialReference timeoutSeconds allowInsecureHttp modelPolicy authMode authHeaderName
  use arg endpointArg, credentialReferenceArg, allowedModelsArg, timeoutArg = 30, allowHttpArg = .false, maxOutputArg = 8192, authModeArg = "BEARER", authHeaderNameArg = ""
  endpoint = endpointArg~string~strip
  credentialReference = credentialReferenceArg~string~strip
  timeoutSeconds = timeoutArg
  allowInsecureHttp = allowHttpArg == .true
  modelPolicy = .OpenAICompatModelPolicy~new(allowedModelsArg, maxOutputArg)
  authMode = authModeArg~string~strip~upper
  authHeaderName = authHeaderNameArg~string~strip
  if authMode = "" then authMode = "BEARER"
  if authMode <> "BEARER" then do
    if authMode <> "API_KEY" then do
      if authMode <> "NONE" then raise syntax 88.900 array("OpenAI-compatible auth mode must be BEARER, API_KEY or NONE")
    end
  end
  if authMode = "API_KEY" then do
    if authHeaderName = "" then authHeaderName = "api-key"
  end
  else if authMode = "BEARER" then authHeaderName = "Authorization"
  else authHeaderName = ""

  if endpoint = "" then raise syntax 88.900 array("OpenAI-compatible endpoint must not be empty")
  if endpoint~left(8)~lower = "https://" then nop
  else do
    if \allowInsecureHttp then raise syntax 88.900 array("OpenAI-compatible endpoint must use https")
    if endpoint~left(7)~lower \= "http://" then raise syntax 88.900 array("test endpoint must use http or https")
  end
  if authMode <> "NONE" then if credentialReference = "" then raise syntax 88.900 array("OpenAI-compatible credential reference must not be empty")
  if \datatype(timeoutSeconds, "W") then raise syntax 88.900 array("OpenAI-compatible timeout must be whole")
  if timeoutSeconds < 1 then raise syntax 88.900 array("OpenAI-compatible timeout must be positive")
  if timeoutSeconds > 300 then raise syntax 88.900 array("OpenAI-compatible timeout exceeds 300 seconds")

::method needsCredential
  expose authMode
  return authMode <> "NONE"

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
  expose endpoint credentialReference timeoutSeconds allowInsecureHttp modelPolicy authMode authHeaderName
  d = .directory~new
  d["endpoint"] = endpoint
  d["credential_reference"] = credentialReference
  d["timeout_seconds"] = timeoutSeconds
  d["allow_insecure_http"] = allowInsecureHttp
  d["max_output_tokens_limit"] = modelPolicy~maxOutputTokensLimit
  d["allowed_model_count"] = modelPolicy~allowedModelNames~items
  d["auth_mode"] = authMode
  d["auth_header_name"] = authHeaderName
  return d


::class OpenAICompatTransportBase subclass AlchemyObject public

::method init
  meta = .directory~new
  meta["purpose"] = "Trusted HTTP transport for OpenAI-compatible provider adapter"
  meta["package_version"] = .OpenAICompatProviderBuild~RELEASE
  meta["api_version"] = "ai.provider.http-transport/0.1"
  self~initAlchemy(meta)
  self~registerMethodContract("POSTJSON", "POST provider JSON while injecting credential from SecretLease inside transport boundary", .array~of("ENDPOINT", "BODYJSON", "LEASE", "TIMEOUT"), "ANY", .false, "FALSE", "SECRET", "SECURITY_BOUNDARY", "EXTERNAL", "USE")
  self~registerInstrumentationPoint("AI.HTTP.POST.BEFORE", "provider HTTP request entered; endpoint scheme/size only", .true, "ALL", "INTERNAL")
  self~registerInstrumentationPoint("AI.HTTP.POST.AFTER", "provider HTTP request completed; status/size only", .true, "ALL", "INTERNAL")
  self~registerExternalRequirement("library", "alchemy_objects", "v" || .OpenAICompatProviderBuild~ALCHEMY_OBJECTS_VERSION, .true)
  self~registerExternalRequirement("library", "oorexx_secret_broker", "v" || .OpenAICompatProviderBuild~SECRET_BROKER_VERSION, .true)
  self~declareHouseCompliance(95)

::method postJson public
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
    return .OpenAICompatTransportResult~failure("AI_PROVIDER_TRANSPORT_CONTRACT", "transport returned nil")
  end
  if \transportOutcome~isa(.OpenAICompatTransportResult) then do
    after["ok"] = .false
    after["code"] = "AI_PROVIDER_TRANSPORT_CONTRACT"
    self~alchemyInstrument("AI.HTTP.POST.AFTER", after)
    return .OpenAICompatTransportResult~failure("AI_PROVIDER_TRANSPORT_CONTRACT", "transport returned unsupported result")
  end
  after["ok"] = transportOutcome~ok
  after["code"] = transportOutcome~code
  after["status"] = transportOutcome~status
  after["response_bytes"] = transportOutcome~body~length
  self~alchemyInstrument("AI.HTTP.POST.AFTER", after)
  return transportOutcome

transportRaised:
  say "OpenAI transport syntax failure rc=" rc "sigl=" sigl "conditionC=" condition("C") "conditionD=" .OpenAICompatDiagnostic~redacted(condition("D"))
  signal off syntax
  after = .directory~new
  after["ok"] = .false
  after["code"] = "AI_PROVIDER_TRANSPORT_EXCEPTION"
  after["condition"] = condition("C")
  self~alchemyInstrument("AI.HTTP.POST.AFTER", after)
  return .OpenAICompatTransportResult~failure("AI_PROVIDER_TRANSPORT_EXCEPTION", "transport raised a condition")

::method postJsonTrusted protected
  use arg endpoint, bodyJson, lease, timeoutSeconds
  return .OpenAICompatTransportResult~failure("AI_PROVIDER_TRANSPORT_ABSTRACT", "transport did not implement postJsonTrusted")


/* Production/live-capable curl transport.
 *
 * The Authorization header is written to a mode-600 temporary curl config,
 * never appended to commandText.  The command line contains only file paths,
 * endpoint, timeout and non-secret transport flags. */

::class OpenAICompatDiagnostic
::method redacted class
  use arg detail
  return "REDACTED"

::class OpenAICompatCurlUtil
::method lastHttpStatus class
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

::method writeFile class
  use arg path, bytes
  streamObject = .Stream~new(path)
  opened = streamObject~open("WRITE REPLACE")
  if \opened~caselessEquals("READY:") then return .false
  ignore = streamObject~charout(bytes)
  ignore = streamObject~close
  return .true

::method readFile class
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

::method cleanup class
  use arg requestPath, configPath, headerPath, responsePath, errorPath
  paths = .array~of(requestPath, configPath, headerPath, responsePath, errorPath)
  do path over paths
    if stream(path, "c", "query exists") \= "" then ignore = SysFileDelete(path)
  end
  return .true

::method shellQuote class
  use arg valueArg
  text = valueArg~string
  text = text~changestr("'", "'\\''")
  return "'" || text || "'"

::method curlConfigEscape class
  use arg valueArg
  text = valueArg~string
  text = text~changestr("\\", "\\\\")
  text = text~changestr('"', '\\"')
  return text

::class OpenAICompatWireProjector
::method messages class
  use arg genericMessages
  wireMessages = .array~new
  do message over genericMessages
    wire = .directory~new
    wire["role"] = message~role
    wire["content"] = message~content
    if message~role = "assistant" then do
      if message~toolCallCount > 0 then do
        wireCalls = .array~new
        do toolCall over message~toolCalls
          functionObject = .directory~new
          functionObject["name"] = toolCall~name
          functionObject["arguments"] = .JSON~toJSON(toolCall~arguments)
          wireCall = .directory~new
          wireCall["id"] = toolCall~callId
          wireCall["type"] = "function"
          wireCall["function"] = functionObject
          wireCalls~append(wireCall)
        end
        wire["tool_calls"] = wireCalls
      end
    end
    if message~role = "tool" then wire["tool_call_id"] = message~toolCallId
    wireMessages~append(wire)
  end
  return wireMessages

::class OpenAICompatCurlTransport subclass OpenAICompatTransportBase public

::method init
  expose executable allowInsecureHttp authMode authHeaderName
  use arg executableArg = "curl", allowHttpArg = .false, authModeArg = "BEARER", authHeaderNameArg = ""
  executable = executableArg~string
  allowInsecureHttp = allowHttpArg == .true
  authMode = authModeArg~string~strip~upper
  if authMode = "" then authMode = "BEARER"
  authHeaderName = authHeaderNameArg~string~strip
  if authMode = "API_KEY" then do
    if authHeaderName = "" then authHeaderName = "api-key"
  end
  else if authMode = "BEARER" then authHeaderName = "Authorization"
  else if authMode = "NONE" then authHeaderName = ""
  else raise syntax 88.900 array("OpenAI-compatible transport auth mode invalid")
  self~init:super
  self~registerStateVariable("executable", "INTERNAL", "curl executable path/name")
  self~registerStateVariable("allowInsecureHttp", "INTERNAL", "test-only HTTP transport permission")
  self~registerStateVariable("authMode", "INTERNAL", "credential injection mode")
  self~registerStateVariable("authHeaderName", "INTERNAL", "credential header name without secret value")
  self~registerExternalRequirement("executable", "curl", "HTTPS client", .true)

::method postJsonTrusted protected
  expose executable allowInsecureHttp authMode authHeaderName
  use arg endpointArg, bodyJsonArg, lease, timeoutSeconds
  endpoint = endpointArg~string~strip
  bodyJson = bodyJsonArg~string
  if endpoint~left(8)~lower = "https://" then proto = "=https"
  else do
    if \allowInsecureHttp then return .OpenAICompatTransportResult~failure("AI_PROVIDER_ENDPOINT_INSECURE", "transport refuses insecure endpoint")
    if endpoint~left(7)~lower \= "http://" then return .OpenAICompatTransportResult~failure("AI_PROVIDER_ENDPOINT_INVALID", "transport endpoint scheme unsupported")
    proto = "=http,https"
  end
  if \datatype(timeoutSeconds, "W") then return .OpenAICompatTransportResult~failure("AI_PROVIDER_TIMEOUT_INVALID", "timeout must be whole")
  if timeoutSeconds < 1 then return .OpenAICompatTransportResult~failure("AI_PROVIDER_TIMEOUT_INVALID", "timeout must be positive")
  if timeoutSeconds > 300 then return .OpenAICompatTransportResult~failure("AI_PROVIDER_TIMEOUT_INVALID", "timeout exceeds 300 seconds")
  secretText = ""
  if authMode <> "NONE" then do
    if lease == .nil then return .OpenAICompatTransportResult~failure("AI_PROVIDER_CREDENTIAL_INVALID", "secret lease missing")
    if \lease~isa(.SecretLease) then return .OpenAICompatTransportResult~failure("AI_PROVIDER_CREDENTIAL_INVALID", "secret lease type invalid")
    secretOutcome = lease~secretForTrustedConsumer
    if \secretOutcome~ok then return .OpenAICompatTransportResult~failure("AI_PROVIDER_CREDENTIAL_UNAVAILABLE", "credential lease unavailable")
    secretText = secretOutcome~value~string
    if secretText = "" then return .OpenAICompatTransportResult~failure("AI_PROVIDER_CREDENTIAL_UNAVAILABLE", "credential is empty")
    if secretText~pos('0d'x) > 0 then return .OpenAICompatTransportResult~failure("AI_PROVIDER_CREDENTIAL_INVALID", "credential contains forbidden control characters")
    if secretText~pos('0a'x) > 0 then return .OpenAICompatTransportResult~failure("AI_PROVIDER_CREDENTIAL_INVALID", "credential contains forbidden control characters")
    if secretText~pos('00'x) > 0 then return .OpenAICompatTransportResult~failure("AI_PROVIDER_CREDENTIAL_INVALID", "credential contains forbidden control characters")
  end

  tempBase = .File~temporaryPath
  requestPath = SysTempFileName(.File~new("ai_openai_request.????????", tempBase)~string)
  configPath = SysTempFileName(.File~new("ai_openai_secret.????????", tempBase)~string)
  headerPath = SysTempFileName(.File~new("ai_openai_headers.????????", tempBase)~string)
  responsePath = SysTempFileName(.File~new("ai_openai_response.????????", tempBase)~string)
  errorPath = SysTempFileName(.File~new("ai_openai_error.????????", tempBase)~string)

  if \.OpenAICompatCurlUtil~writeFile(requestPath, bodyJson) then return .OpenAICompatTransportResult~failure("AI_PROVIDER_TEMPFILE_ERROR", "unable to stage request body")
  configText = ""
  if authMode = "BEARER" then configText = 'header = "Authorization: Bearer ' || .OpenAICompatCurlUtil~curlConfigEscape(secretText) || '"' || '0a'x
  else if authMode = "API_KEY" then configText = 'header = "' || .OpenAICompatCurlUtil~curlConfigEscape(authHeaderName) || ': ' || .OpenAICompatCurlUtil~curlConfigEscape(secretText) || '"' || '0a'x
  if \.OpenAICompatCurlUtil~writeFile(configPath, configText) then do
    .OpenAICompatCurlUtil~cleanup(requestPath, configPath, headerPath, responsePath, errorPath)
    return .OpenAICompatTransportResult~failure("AI_PROVIDER_TEMPFILE_ERROR", "unable to stage credential config")
  end
  chmodText = "chmod 600 -- " || .OpenAICompatCurlUtil~shellQuote(configPath)
  address system chmodText
  commandMode = rc
  if commandMode \= 0 then do
    .OpenAICompatCurlUtil~cleanup(requestPath, configPath, headerPath, responsePath, errorPath)
    return .OpenAICompatTransportResult~failure("AI_PROVIDER_TEMPFILE_ERROR", "unable to restrict credential config permissions")
  end

  commandText = .OpenAICompatCurlUtil~shellQuote(executable) || -
    " --silent --show-error --max-redirs 0" || -
    " --proto " || .OpenAICompatCurlUtil~shellQuote(proto) || -
    " --max-time " || timeoutSeconds || -
    " --request POST" || -
    " --header " || .OpenAICompatCurlUtil~shellQuote("Content-Type: application/json") || -
    " --header " || .OpenAICompatCurlUtil~shellQuote("Accept: application/json") || -
    " --config " || .OpenAICompatCurlUtil~shellQuote(configPath) || -
    " --data-binary " || .OpenAICompatCurlUtil~shellQuote("@" || requestPath) || -
    " --dump-header " || .OpenAICompatCurlUtil~shellQuote(headerPath) || -
    " --output " || .OpenAICompatCurlUtil~shellQuote(responsePath) || -
    " " || .OpenAICompatCurlUtil~shellQuote(endpoint) || -
    " 2>" || .OpenAICompatCurlUtil~shellQuote(errorPath)

  address system commandText
  commandStatus = rc
  rawHeaders = .OpenAICompatCurlUtil~readFile(headerPath)
  responseBody = .OpenAICompatCurlUtil~readFile(responsePath)
  .OpenAICompatCurlUtil~cleanup(requestPath, configPath, headerPath, responsePath, errorPath)

  secretText = ""
  configText = ""

  if commandStatus \= 0 then return .OpenAICompatTransportResult~failure("AI_PROVIDER_TRANSPORT_ERROR", "curl transport failed")
  httpStatus = .OpenAICompatCurlUtil~lastHttpStatus(rawHeaders)
  if httpStatus = 0 then return .OpenAICompatTransportResult~failure("AI_PROVIDER_HTTP_STATUS_MISSING", "provider response did not include HTTP status")
  return .OpenAICompatTransportResult~success(httpStatus, responseBody)

::class OpenAICompatProviderAdapter subclass AIProviderAdapterBase public

::method init
  expose providerConfig secretBroker httpTransport
  use arg configArg, brokerArg, transportArg
  if configArg == .nil then raise syntax 88.900 array("OpenAI-compatible provider requires config")
  if \configArg~isa(.OpenAICompatProviderConfig) then raise syntax 88.900 array("OpenAI-compatible provider config type invalid")
  if configArg~needsCredential then do
    if brokerArg == .nil then raise syntax 88.900 array("OpenAI-compatible provider requires secret broker")
    if \brokerArg~hasMethod("ACQUIRE") then raise syntax 88.900 array("OpenAI-compatible provider secret broker contract invalid")
  end
  if transportArg == .nil then raise syntax 88.900 array("OpenAI-compatible provider requires HTTP transport")
  if \transportArg~hasMethod("POSTJSON") then raise syntax 88.900 array("OpenAI-compatible provider transport contract invalid")
  providerConfig = configArg
  secretBroker = brokerArg
  httpTransport = transportArg
  self~init:super
  self~registerStateVariable("providerConfig", "INTERNAL", "frozen non-secret deployment configuration")
  self~registerStateVariable("secretBroker", "SECRET", "secret broker object reference")
  self~registerStateVariable("httpTransport", "INTERNAL", "trusted provider HTTP transport")
  self~registerExternalRequirement("library", "oorexx_ai_access", "v" || .OpenAICompatProviderBuild~AI_ACCESS_VERSION, .true)
  self~registerExternalRequirement("library", "oorexx_secret_broker", "v" || .OpenAICompatProviderBuild~SECRET_BROKER_VERSION, .true)
  if secretBroker \== .nil then self~recordRelationship("SECRET_BROKER", secretBroker, "credential resolution authority", "SECRET")
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
  if request~messageCount > 0 then bodyObject["messages"] = .OpenAICompatWireProjector~messages(request~messages)
  else do
    messageObject = .directory~new
    messageObject["role"] = "user"
    messageObject["content"] = request~prompt
    bodyObject["messages"] = .array~of(messageObject)
  end
  if request~toolDefinitionCount > 0 then do
    wireTools = .array~new
    do definition over request~toolDefinitions
      functionObject = .directory~new
      functionObject["name"] = definition~name
      functionObject["description"] = definition~description
      functionObject["parameters"] = definition~inputSchema
      toolObject = .directory~new
      toolObject["type"] = "function"
      toolObject["function"] = functionObject
      wireTools~append(toolObject)
    end
    bodyObject["tools"] = wireTools
  end
  bodyJson = .JSON~toJSON(bodyObject)

  lease = .nil
  if providerConfig~needsCredential then do
    secretOutcome = secretBroker~acquire(providerConfig~credentialReference)
    if \secretOutcome~ok then return .AIProviderReply~failure("AI_PROVIDER_CREDENTIAL_UNAVAILABLE", "provider credential is unavailable", .AIProviderUsage~new(0, 0), request~model)
    lease = secretOutcome~value
  end

  signal on syntax name postRaised
  postOutcome = httpTransport~postJson(providerConfig~endpoint, bodyJson, lease, providerConfig~timeoutSeconds)
  signal off syntax
  if lease \== .nil then lease~retire

  if \postOutcome~ok then return .AIProviderReply~failure(postOutcome~code, postOutcome~detail, .AIProviderUsage~new(0, 0), request~model)
  if postOutcome~status = 401 then return .AIProviderReply~failure("AI_PROVIDER_AUTH_REJECTED", "provider rejected credentials", .AIProviderUsage~new(0, 0), request~model)
  if postOutcome~status = 403 then return .AIProviderReply~failure("AI_PROVIDER_AUTH_REJECTED", "provider rejected credentials", .AIProviderUsage~new(0, 0), request~model)
  if postOutcome~status = 429 then return .AIProviderReply~failure("AI_PROVIDER_RATE_LIMITED", "provider rate limit reached", .AIProviderUsage~new(0, 0), request~model)
  if postOutcome~status < 200 then return .AIProviderReply~failure("AI_PROVIDER_HTTP_ERROR", "provider returned non-success status", .AIProviderUsage~new(0, 0), request~model)
  if postOutcome~status >= 300 then return .AIProviderReply~failure("AI_PROVIDER_HTTP_ERROR", "provider returned non-success status", .AIProviderUsage~new(0, 0), request~model)

  signal on syntax name responseInvalid
  responseObject = .JSON~fromJSON(postOutcome~body)
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
  toolCalls = .array~new
  wireToolCalls = message["tool_calls"]
  if wireToolCalls \== .nil then do
    if \wireToolCalls~isa(.Array) then return .AIProviderReply~failure("AI_PROVIDER_RESPONSE_INVALID", "provider response tool_calls invalid", .AIProviderUsage~new(0, 0), request~model)
    if wireToolCalls~items > 64 then return .AIProviderReply~failure("AI_PROVIDER_RESPONSE_INVALID", "provider response tool_calls exceeds package bound", .AIProviderUsage~new(0, 0), request~model)
    do wireCall over wireToolCalls
      if \wireCall~isa(.Directory) then return .AIProviderReply~failure("AI_PROVIDER_RESPONSE_INVALID", "provider tool call must be object", .AIProviderUsage~new(0, 0), request~model)
      callId = wireCall["id"]
      if callId == .nil then return .AIProviderReply~failure("AI_PROVIDER_RESPONSE_INVALID", "provider tool call id missing", .AIProviderUsage~new(0, 0), request~model)
      callType = wireCall["type"]
      if callType \== .nil then do
        if callType~string~lower \= "function" then return .AIProviderReply~failure("AI_PROVIDER_RESPONSE_INVALID", "provider tool call type unsupported", .AIProviderUsage~new(0, 0), request~model)
      end
      functionValue = wireCall["function"]
      if functionValue == .nil then return .AIProviderReply~failure("AI_PROVIDER_RESPONSE_INVALID", "provider tool call function missing", .AIProviderUsage~new(0, 0), request~model)
      if \functionValue~isa(.Directory) then return .AIProviderReply~failure("AI_PROVIDER_RESPONSE_INVALID", "provider tool call function invalid", .AIProviderUsage~new(0, 0), request~model)
      functionName = functionValue["name"]
      argumentsValue = functionValue["arguments"]
      if functionName == .nil then return .AIProviderReply~failure("AI_PROVIDER_RESPONSE_INVALID", "provider tool call function name missing", .AIProviderUsage~new(0, 0), request~model)
      if argumentsValue == .nil then return .AIProviderReply~failure("AI_PROVIDER_RESPONSE_INVALID", "provider tool call arguments missing", .AIProviderUsage~new(0, 0), request~model)
      if argumentsValue~isa(.Directory) then argumentObject = argumentsValue
      else argumentObject = .JSON~fromJSON(argumentsValue~string)
      if \argumentObject~isa(.Directory) then return .AIProviderReply~failure("AI_PROVIDER_RESPONSE_INVALID", "provider tool call arguments must decode to object", .AIProviderUsage~new(0, 0), request~model)
      toolCalls~append(.AIProviderToolCall~new(callId, functionName, argumentObject))
    end
  end

  content = message["content"]
  if content == .nil then do
    if toolCalls~items = 0 then return .AIProviderReply~failure("AI_PROVIDER_RESPONSE_INVALID", "provider response content missing", .AIProviderUsage~new(0, 0), request~model)
    text = ""
  end
  else text = content~string

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
  signal off syntax
  return .AIProviderReply~success(text, responseModel, finishReason, usage, toolCalls)

postRaised:
  say "OpenAI provider post syntax failure rc=" rc "sigl=" sigl "conditionC=" condition("C") "conditionD=" .OpenAICompatDiagnostic~redacted(condition("D"))
  signal off syntax
  if lease \== .nil then lease~retire
  return .AIProviderReply~failure("AI_PROVIDER_TRANSPORT_EXCEPTION", "provider transport raised a condition", .AIProviderUsage~new(0, 0), request~model)

responseInvalid:
  say "OpenAI provider response syntax failure rc=" rc "sigl=" sigl "conditionC=" condition("C") "conditionD=" .OpenAICompatDiagnostic~redacted(condition("D"))
  signal off syntax
  return .AIProviderReply~failure("AI_PROVIDER_RESPONSE_INVALID", "provider returned invalid JSON", .AIProviderUsage~new(0, 0), request~model)




/* Deployment module.  Non-secret configuration is frozen during init.
 * The secret value itself is resolved by reference for each request, allowing
 * host-controlled credential rotation without handing credentials to Runtime
 * Registry or AIProviderRequest. */
::class OpenAICompatRuntimeModule subclass AIProviderRuntimeCapability public

::method init
  expose deploymentConfig deploymentBroker deploymentTransport
  endpoint = value("AI_OPENAI_COMPAT_ENDPOINT",, "ENVIRONMENT")
  credentialReference = value("AI_OPENAI_COMPAT_CREDENTIAL_REFERENCE",, "ENVIRONMENT")
  credentialEnvName = value("AI_OPENAI_COMPAT_CREDENTIAL_ENV",, "ENVIRONMENT")
  modelCsv = value("AI_OPENAI_COMPAT_MODELS",, "ENVIRONMENT")
  timeoutText = value("AI_OPENAI_COMPAT_TIMEOUT",, "ENVIRONMENT")
  curlExecutable = value("AI_OPENAI_COMPAT_CURL",, "ENVIRONMENT")
  allowHttpText = value("AI_OPENAI_COMPAT_ALLOW_HTTP_TEST",, "ENVIRONMENT")
  maxOutputText = value("AI_OPENAI_COMPAT_MAX_OUTPUT",, "ENVIRONMENT")
  authModeText = value("AI_OPENAI_COMPAT_AUTH_MODE",, "ENVIRONMENT")
  authHeaderText = value("AI_OPENAI_COMPAT_AUTH_HEADER",, "ENVIRONMENT")

  if timeoutText = "" then timeoutText = 30
  if curlExecutable = "" then curlExecutable = "curl"
  if maxOutputText = "" then maxOutputText = 8192
  allowHttp = allowHttpText == "1"
  modelPolicy = .OpenAICompatModelPolicy~new(.OpenAICompatModelPolicy~parseModels(modelCsv), maxOutputText)
  if authModeText = "" then authModeText = "BEARER"
  deploymentConfig = .OpenAICompatProviderConfig~new(endpoint, credentialReference, modelPolicy~allowedModelNames, timeoutText, allowHttp, modelPolicy~maxOutputTokensLimit, authModeText, authHeaderText)
  deploymentBroker = .nil
  if deploymentConfig~needsCredential then do
    secretMap = .directory~new
    secretMap[credentialReference] = credentialEnvName
    secretProvider = .MappedEnvironmentSecretProvider~new(secretMap)
    deploymentBroker = .SecretBroker~new(secretProvider)
  end
  deploymentTransport = .OpenAICompatCurlTransport~new(curlExecutable, allowHttp, deploymentConfig~authMode, deploymentConfig~authHeaderName)
  self~init:super
  self~registerStateVariable("deploymentConfig", "INTERNAL", "frozen non-secret OpenAI-compatible deployment configuration")
  self~registerStateVariable("deploymentBroker", "SECRET", "deployment secret broker when authentication requires one")
  self~registerStateVariable("deploymentTransport", "INTERNAL", "deployment HTTP transport")

::method createProvider protected
  expose deploymentConfig deploymentBroker deploymentTransport
  return .OpenAICompatProviderAdapter~new(deploymentConfig, deploymentBroker, deploymentTransport)



/* Azure OpenAI deployment helper.  Azure owns deployment name and api-version
 * in the URL while the generic request body remains OpenAI-compatible. */
::class AzureOpenAIProviderConfig public
::method fromEnvironment class
  base = value("AZURE_OPENAI_ENDPOINT",, "ENVIRONMENT")~strip
  deployment = value("AZURE_OPENAI_DEPLOYMENT",, "ENVIRONMENT")~strip
  apiVersion = value("AZURE_OPENAI_API_VERSION",, "ENVIRONMENT")~strip
  credentialRef = value("AZURE_OPENAI_CREDENTIAL_REFERENCE",, "ENVIRONMENT")~strip
  models = value("AZURE_OPENAI_MODELS",, "ENVIRONMENT")
  timeoutText = value("AZURE_OPENAI_TIMEOUT",, "ENVIRONMENT")
  maxOutput = value("AZURE_OPENAI_MAX_OUTPUT",, "ENVIRONMENT")
  if apiVersion = "" then raise syntax 88.900 array("AZURE_OPENAI_API_VERSION required")
  if timeoutText = "" then timeoutText = 30
  if maxOutput = "" then maxOutput = 8192
  if base = "" then raise syntax 88.900 array("AZURE_OPENAI_ENDPOINT required")
  if deployment = "" then raise syntax 88.900 array("AZURE_OPENAI_DEPLOYMENT required")
  if credentialRef = "" then credentialRef = "azure.openai.primary"
  if base~right(1) = "/" then base = base~left(base~length - 1)
  endpoint = base || "/openai/deployments/" || deployment || "/chat/completions?api-version=" || apiVersion
  modelList = .OpenAICompatModelPolicy~parseModels(models)
  if modelList~items = 0 then modelList~append(deployment)
  return .OpenAICompatProviderConfig~new(endpoint, credentialRef, modelList, timeoutText, .false, maxOutput, "API_KEY", "api-key")

/* Local llama.cpp helper.  Loopback HTTP is deliberately allowed and no
 * credential or Secret Broker is required. */
::class LlamaCppProviderConfig public
::method fromEnvironment class
  endpoint = value("LLAMA_CPP_ENDPOINT",, "ENVIRONMENT")~strip
  models = value("LLAMA_CPP_MODELS",, "ENVIRONMENT")
  timeoutText = value("LLAMA_CPP_TIMEOUT",, "ENVIRONMENT")
  maxOutput = value("LLAMA_CPP_MAX_OUTPUT",, "ENVIRONMENT")
  if endpoint = "" then endpoint = "http://127.0.0.1:8080/v1/chat/completions"
  if timeoutText = "" then timeoutText = 60
  if maxOutput = "" then maxOutput = 8192
  lowerEndpoint = endpoint~lower
  if lowerEndpoint~left(16) <> "http://127.0.0.1" then do
    if lowerEndpoint~left(16) <> "http://localhost" then raise syntax 88.900 array("llama.cpp endpoint must be loopback HTTP")
  end
  modelList = .OpenAICompatModelPolicy~parseModels(models)
  if modelList~items = 0 then modelList~append("local-model")
  return .OpenAICompatProviderConfig~new(endpoint, "", modelList, timeoutText, .true, maxOutput, "NONE", "")



/* Ready-to-register Azure runtime module.  It keeps the API key behind the
 * Secret Broker boundary and uses the explicit Azure api-key transport. */
::class AzureOpenAIRuntimeModule subclass AIProviderRuntimeCapability public
::method init
  expose deploymentConfig deploymentBroker deploymentTransport
  deploymentConfig = .AzureOpenAIProviderConfig~fromEnvironment
  keyEnvName = value("AZURE_OPENAI_API_KEY_ENV",, "ENVIRONMENT")~strip
  curlExecutable = value("AZURE_OPENAI_CURL",, "ENVIRONMENT")~strip
  if keyEnvName = "" then keyEnvName = "AZURE_OPENAI_API_KEY"
  if curlExecutable = "" then curlExecutable = "curl"
  secretMap = .directory~new
  secretMap[deploymentConfig~credentialReference] = keyEnvName
  secretProvider = .MappedEnvironmentSecretProvider~new(secretMap)
  deploymentBroker = .SecretBroker~new(secretProvider)
  deploymentTransport = .OpenAICompatCurlTransport~new(curlExecutable, .false, "API_KEY", "api-key")
  self~init:super
  self~registerStateVariable("deploymentConfig", "INTERNAL", "Azure OpenAI non-secret deployment configuration")
  self~registerStateVariable("deploymentBroker", "SECRET", "Azure OpenAI Secret Broker")
  self~registerStateVariable("deploymentTransport", "INTERNAL", "Azure OpenAI api-key HTTP transport")
::method createProvider protected
  expose deploymentConfig deploymentBroker deploymentTransport
  return .OpenAICompatProviderAdapter~new(deploymentConfig, deploymentBroker, deploymentTransport)

/* Ready-to-register local llama.cpp runtime module.  It deliberately has no
 * Secret Broker because a loopback no-auth endpoint owns no provider key. */
::class LlamaCppRuntimeModule subclass AIProviderRuntimeCapability public
::method init
  expose deploymentConfig deploymentTransport
  deploymentConfig = .LlamaCppProviderConfig~fromEnvironment
  curlExecutable = value("LLAMA_CPP_CURL",, "ENVIRONMENT")~strip
  if curlExecutable = "" then curlExecutable = "curl"
  deploymentTransport = .OpenAICompatCurlTransport~new(curlExecutable, .true, "NONE", "")
  self~init:super
  self~registerStateVariable("deploymentConfig", "INTERNAL", "llama.cpp loopback deployment configuration")
  self~registerStateVariable("deploymentTransport", "INTERNAL", "llama.cpp no-auth loopback HTTP transport")
::method createProvider protected
  expose deploymentConfig deploymentTransport
  return .OpenAICompatProviderAdapter~new(deploymentConfig, .nil, deploymentTransport)

::requires "AIProviderAccess.cls"
::requires "SecretBroker.cls"
::requires "json.cls"
