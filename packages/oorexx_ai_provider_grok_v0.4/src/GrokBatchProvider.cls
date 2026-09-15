/* ooRexx AI Provider Grok (xAI) Batch API v0.4
 *
 * Asynchronous bulk / delayed inference path for xAI Batch API.
 * This is deliberately separate from the real-time chat path:
 *   - multi-step (create → add → poll → results / cancel)
 *   - long-horizon work (typically up to ~24 h)
 *   - does not consume real-time rate limits
 *   - WLU admission uses distinct facts, long TTL and low delivery rate
 *
 * Authority boundary (same discipline as real-time):
 *   - model allowlist and output policy checked before credential use
 *   - Secret Broker lease materialised only inside trusted transport
 *   - secrets never on argv; mode-600 curl config
 *   - prompt / request bodies never appear in Alchemy instrumentation
 *   - raw provider error bodies are not returned to callers
 */

::class GrokBatchProviderBuild public
::constant PRODUCT "ooRexx AI Provider - Grok Batch (xAI)"
::constant RELEASE "0.4"
::constant API_VERSION "ai.provider.grok.batch/0.3"
::constant AI_ACCESS_VERSION "0.6"
::constant SECRET_BROKER_VERSION "0.2"
::constant ALCHEMY_OBJECTS_VERSION "0.8"
::constant REALTIME_PROVIDER_VERSION "0.4"

::class GrokBatchTransportResult public
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


/* Non-secret batch admission policy.
 * Shared by the batch adapter and the batch WLU planner.
 * Contains no endpoint, credential, transport or Secret Broker reference. */
::class GrokBatchModelPolicy public
::attribute maxOutputTokensLimit get
::attribute maxRequestsPerAdd get
::attribute maxEstimatedInputTokensPerRequest get

::method init
  expose allowedModels maxOutputTokensLimit maxRequestsPerAdd maxEstimatedInputTokensPerRequest
  use arg allowedModelsArg, maxOutputArg = 8192, maxRequestsArg = 500, maxEstInputArg = 100000
  maxOutputTokensLimit = maxOutputArg
  maxRequestsPerAdd = maxRequestsArg
  maxEstimatedInputTokensPerRequest = maxEstInputArg
  if \datatype(maxOutputTokensLimit, "W") then raise syntax 88.900 array("Grok batch output limit must be whole")
  if maxOutputTokensLimit < 1 then raise syntax 88.900 array("Grok batch output limit must be positive")
  if maxOutputTokensLimit > 65536 then raise syntax 88.900 array("Grok batch output limit is unreasonably large")
  if \datatype(maxRequestsPerAdd, "W") then raise syntax 88.900 array("Grok batch max requests per add must be whole")
  if maxRequestsPerAdd < 1 then raise syntax 88.900 array("Grok batch max requests per add must be positive")
  if maxRequestsPerAdd > 100000 then raise syntax 88.900 array("Grok batch max requests per add exceeds policy")
  if \datatype(maxEstimatedInputTokensPerRequest, "W") then raise syntax 88.900 array("Grok batch max estimated input must be whole")
  if maxEstimatedInputTokensPerRequest < 1 then raise syntax 88.900 array("Grok batch max estimated input must be positive")
  if allowedModelsArg == .nil then raise syntax 88.900 array("Grok batch model allowlist is required")
  if \allowedModelsArg~isa(.Array) then raise syntax 88.900 array("Grok batch model allowlist must be Array")
  if allowedModelsArg~items = 0 then raise syntax 88.900 array("Grok batch model allowlist must not be empty")
  allowedModels = .directory~new
  do modelValue over allowedModelsArg
    modelName = modelValue~string~strip
    if modelName = "" then raise syntax 88.900 array("Grok batch allowed model must not be empty")
    allowedModels[modelName] = .true
  end

::method allowsModel
  expose allowedModels
  use arg modelArg
  return allowedModels[modelArg~string~strip] == .true

::method allowedModelNames
  expose allowedModels
  names = .array~new
  do name over allowedModels~allIndexes
    names~append(name)
  end
  return names

::method parseModels class
  use arg modelCsv
  text = modelCsv~string~strip
  if text = "" then return .array~of("grok-4", "grok-4.6", "grok-4.5", "grok-4.3")
  names = .array~new
  do while text \= ""
    parse var text item "," text
    item = item~strip
    if item \= "" then names~append(item)
  end
  if names~items = 0 then raise syntax 88.900 array("Grok batch model allowlist CSV produced no models")
  return names

::method fromEnvironment class
  modelCsv = value("AI_GROK_BATCH_MODELS",, "ENVIRONMENT")
  if modelCsv = "" then modelCsv = value("AI_GROK_MODELS",, "ENVIRONMENT")
  maxOutputText = value("AI_GROK_BATCH_MAX_OUTPUT",, "ENVIRONMENT")
  if maxOutputText = "" then maxOutputText = value("AI_GROK_MAX_OUTPUT",, "ENVIRONMENT")
  if maxOutputText = "" then maxOutputText = 8192
  maxReqText = value("AI_GROK_BATCH_MAX_REQUESTS_PER_ADD",, "ENVIRONMENT")
  if maxReqText = "" then maxReqText = 500
  maxEstText = value("AI_GROK_BATCH_MAX_EST_INPUT_TOKENS",, "ENVIRONMENT")
  if maxEstText = "" then maxEstText = 100000
  return self~new(self~parseModels(modelCsv), maxOutputText, maxReqText, maxEstText)


::class GrokBatchProviderConfig public
::attribute endpointBase get
::attribute credentialReference get
::attribute timeoutSeconds get
::attribute allowInsecureHttp get
::attribute modelPolicy get

::method init
  expose endpointBase credentialReference timeoutSeconds allowInsecureHttp modelPolicy
  use arg endpointBaseArg, credentialReferenceArg, modelPolicyArg, timeoutArg = 60, allowHttpArg = .false
  endpointBase = endpointBaseArg~string~strip
  credentialReference = credentialReferenceArg~string~strip
  timeoutSeconds = timeoutArg
  allowInsecureHttp = allowHttpArg == .true
  modelPolicy = modelPolicyArg
  if endpointBase = "" then raise syntax 88.900 array("Grok batch endpoint base must not be empty")
  if endpointBase~right(1) = "/" then endpointBase = endpointBase~left(endpointBase~length - 1)
  if endpointBase~left(8)~lower = "https://" then nop
  else do
    if \allowInsecureHttp then raise syntax 88.900 array("Grok batch endpoint must use https")
    if endpointBase~left(7)~lower \= "http://" then raise syntax 88.900 array("test endpoint must use http or https")
  end
  if credentialReference = "" then raise syntax 88.900 array("Grok batch credential reference must not be empty")
  if \datatype(timeoutSeconds, "W") then raise syntax 88.900 array("Grok batch timeout must be whole")
  if timeoutSeconds < 1 then raise syntax 88.900 array("Grok batch timeout must be positive")
  if \modelPolicy~isa(.GrokBatchModelPolicy) then raise syntax 88.900 array("Grok batch model policy type invalid")

::method disclosureDirectory
  expose endpointBase credentialReference timeoutSeconds allowInsecureHttp modelPolicy
  d = .directory~new
  d["endpoint_base"] = endpointBase
  d["credential_reference"] = credentialReference
  d["timeout_seconds"] = timeoutSeconds
  d["allow_insecure_http"] = allowInsecureHttp
  d["allowed_models"] = modelPolicy~allowedModelNames
  d["max_output_tokens"] = modelPolicy~maxOutputTokensLimit
  d["max_requests_per_add"] = modelPolicy~maxRequestsPerAdd
  return d


/* Reuses the same trusted curl transport pattern as real-time. */
::class GrokBatchCurlTransport subclass AlchemyObject public
::attribute executable get
::attribute allowInsecureHttp get

::method init
  expose executable allowInsecureHttp
  use arg executableArg = "curl", allowHttpArg = .false
  executable = executableArg~string~strip
  if executable = "" then executable = "curl"
  allowInsecureHttp = allowHttpArg == .true
  meta = .directory~new
  meta["purpose"] = "Trusted HTTP transport for Grok Batch API"
  meta["package"] = "oorexx_ai_provider_grok"
  meta["package_version"] = .GrokBatchProviderBuild~RELEASE
  meta["api_version"] = "ai.provider.grok.batch.transport/0.3"
  meta["authorship"] = "Alchemy ooRexx project"
  meta["standards"] = "ALCHEMY-HOUSE-OBJECT-0.8; ai.provider.grok.batch/0.3; secret.broker/0.2 trusted-consumer credential boundary"
  meta["design_limitations"] = "Transport performs one bounded Batch API request and temporary secret materialization only; it is not a credential store, batch scheduler or WLU authority"
  self~init:super(meta)
  self~registerExternalRequirement("library", "oorexx_secret_broker", "v" || .GrokBatchProviderBuild~SECRET_BROKER_VERSION, .true)
  self~registerExternalRequirement("library", "alchemy_objects", "v" || .GrokBatchProviderBuild~ALCHEMY_OBJECTS_VERSION, .true)
  self~declareHouseCompliance(95)
  self~registerMethodContract("REQUESTJSON", "execute one Grok Batch HTTP request while materializing SecretLease only inside trusted transport", .array~of("METHOD", "URL", "BODYJSON", "LEASE", "TIMEOUT"), "ANY", .true, "FALSE", "SECRET", "SECURITY_BOUNDARY", "EXTERNAL", "USE")
  self~registerInstrumentationPoint("AI.BATCH.HTTP.BEFORE", "batch HTTP request entered; scheme/size only", .true, "ALL", "INTERNAL")
  self~registerInstrumentationPoint("AI.BATCH.HTTP.AFTER", "batch HTTP request completed; status only", .true, "ALL", "INTERNAL")

::method requestJson public protected
  expose executable allowInsecureHttp
  use arg method, url, bodyJson, lease, timeoutSeconds
  method = method~string~strip~upper
  if method = "" then method = "POST"
  before = .directory~new
  if url~string~left(8)~lower = "https://" then before["scheme"] = "HTTPS"
  else before["scheme"] = "HTTP"
  before["method"] = method
  before["body_bytes"] = bodyJson~string~length
  self~alchemyInstrument("AI.BATCH.HTTP.BEFORE", before)

  outcome = self~requestJsonTrusted(method, url, bodyJson, lease, timeoutSeconds)

  after = .directory~new
  after["ok"] = outcome~ok
  after["status"] = outcome~status
  after["code"] = outcome~code
  self~alchemyInstrument("AI.BATCH.HTTP.AFTER", after)
  return outcome

::method requestJsonTrusted private
  expose executable allowInsecureHttp
  use arg method, urlArg, bodyJsonArg, lease, timeoutSeconds
  url = urlArg~string~strip
  bodyJson = bodyJsonArg~string
  if url~left(8)~lower = "https://" then proto = "=https"
  else do
    if \allowInsecureHttp then return .GrokBatchTransportResult~failure("AI_PROVIDER_ENDPOINT_INSECURE", "transport refuses insecure endpoint")
    if url~left(7)~lower \= "http://" then return .GrokBatchTransportResult~failure("AI_PROVIDER_ENDPOINT_INVALID", "transport endpoint scheme unsupported")
    proto = "=http,https"
  end

  if lease == .nil then return .GrokBatchTransportResult~failure("AI_PROVIDER_CREDENTIAL_MISSING", "secret lease required")
  if \lease~isa(.SecretLease) then return .GrokBatchTransportResult~failure("AI_PROVIDER_CREDENTIAL_INVALID", "secret lease type invalid")
  secretOutcome = lease~secretForTrustedConsumer
  if \secretOutcome~ok then return .GrokBatchTransportResult~failure("AI_PROVIDER_CREDENTIAL_UNAVAILABLE", "credential lease unavailable")
  secretText = secretOutcome~value~string
  if secretText = "" then return .GrokBatchTransportResult~failure("AI_PROVIDER_CREDENTIAL_EMPTY", "credential value empty")
  if secretText~pos('0d'x) > 0 | secretText~pos('0a'x) > 0 | secretText~pos('00'x) > 0 then ,
    return .GrokBatchTransportResult~failure("AI_PROVIDER_CREDENTIAL_INVALID", "credential contains forbidden control characters")

  tempBase = .File~temporaryPath
  requestPath = SysTempFileName(.File~new("ai_grok_batch_request.????????", tempBase)~string)
  configPath = SysTempFileName(.File~new("ai_grok_batch_secret.????????", tempBase)~string)
  headerPath = SysTempFileName(.File~new("ai_grok_batch_headers.????????", tempBase)~string)
  responsePath = SysTempFileName(.File~new("ai_grok_batch_response.????????", tempBase)~string)
  errorPath = SysTempFileName(.File~new("ai_grok_batch_error.????????", tempBase)~string)

  if bodyJson \= "" then do
    if \self~writeFile(requestPath, bodyJson) then return .GrokBatchTransportResult~failure("AI_PROVIDER_TEMPFILE_ERROR", "unable to stage request body")
  end
  configText = 'header = "Authorization: Bearer ' || self~curlConfigEscape(secretText) || '"' || '0a'x
  if \self~writeFile(configPath, configText) then do
    self~cleanup(requestPath, configPath, headerPath, responsePath, errorPath)
    return .GrokBatchTransportResult~failure("AI_PROVIDER_TEMPFILE_ERROR", "unable to stage credential config")
  end
  chmodText = "chmod 600 -- " || self~shellQuote(configPath)
  address system chmodText
  if rc \= 0 then do
    self~cleanup(requestPath, configPath, headerPath, responsePath, errorPath)
    return .GrokBatchTransportResult~failure("AI_PROVIDER_TEMPFILE_ERROR", "unable to restrict credential config permissions")
  end

  commandText = self~shellQuote(executable) || -
    " --silent --show-error --max-redirs 0" || -
    " --proto " || self~shellQuote(proto) || -
    " --max-time " || timeoutSeconds || -
    " --request " || method || -
    " --header " || self~shellQuote("Content-Type: application/json") || -
    " --header " || self~shellQuote("Accept: application/json") || -
    " --config " || self~shellQuote(configPath) || -
    " --dump-header " || self~shellQuote(headerPath) || -
    " --output " || self~shellQuote(responsePath)
  if bodyJson \= "" then commandText = commandText || " --data-binary " || self~shellQuote("@" || requestPath)
  commandText = commandText || " " || self~shellQuote(url) || " 2>" || self~shellQuote(errorPath)

  address system commandText
  commandStatus = rc
  rawHeaders = self~readFile(headerPath)
  responseBody = self~readFile(responsePath)
  self~cleanup(requestPath, configPath, headerPath, responsePath, errorPath)

  secretText = ""
  configText = ""

  if commandStatus \= 0 then return .GrokBatchTransportResult~failure("AI_PROVIDER_TRANSPORT_ERROR", "curl transport failed")
  httpStatus = self~lastHttpStatus(rawHeaders)
  if httpStatus = 0 then return .GrokBatchTransportResult~failure("AI_PROVIDER_HTTP_STATUS_MISSING", "provider response did not include HTTP status")
  return .GrokBatchTransportResult~success(httpStatus, responseBody)

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


/* Narrow value objects for batch operations. */
::class GrokBatchHandle public
::attribute batchId get
::attribute name get
::attribute createTime get
::attribute state get

::method init
  expose batchId name createTime state
  use arg batchIdArg, nameArg = "", createTimeArg = "", stateArg = .nil
  batchId = batchIdArg~string~strip
  name = nameArg~string
  createTime = createTimeArg~string
  if stateArg == .nil then state = .directory~new
  else state = stateArg

::class GrokBatchAddRequest public
::attribute batchRequestId get
::attribute model get
::attribute prompt get
::attribute maxOutputTokens get

::method init
  expose batchRequestId model prompt maxOutputTokens
  use arg batchRequestIdArg, modelArg, promptArg, maxOutputTokensArg = 256
  batchRequestId = batchRequestIdArg~string~strip
  model = modelArg~string~strip
  prompt = promptArg~string
  maxOutputTokens = maxOutputTokensArg
  if batchRequestId = "" then raise syntax 88.900 array("batch_request_id must not be empty")
  if model = "" then raise syntax 88.900 array("batch request model must not be empty")
  if \datatype(maxOutputTokens, "W") then raise syntax 88.900 array("batch max_output_tokens must be whole")
  if maxOutputTokens < 1 then raise syntax 88.900 array("batch max_output_tokens must be positive")


::class GrokBatchAdapter subclass AlchemyObject public

::method init
  expose providerConfig secretBroker httpTransport
  use arg configArg, brokerArg, transportArg
  if \configArg~isa(.GrokBatchProviderConfig) then raise syntax 88.900 array("Grok batch provider config type invalid")
  providerConfig = configArg
  secretBroker = brokerArg
  httpTransport = transportArg
  meta = .directory~new
  meta["purpose"] = "Grok / xAI Batch API adapter"
  meta["package"] = "oorexx_ai_provider_grok"
  meta["package_version"] = .GrokBatchProviderBuild~RELEASE
  meta["api_version"] = .GrokBatchProviderBuild~API_VERSION
  meta["authorship"] = "Alchemy ooRexx project"
  meta["standards"] = "ALCHEMY-HOUSE-OBJECT-0.8; ai.provider.grok.batch/0.3; secret.broker/0.2"
  meta["design_limitations"] = "Adapter owns bounded Grok Batch API policy/transport coordination only; it does not retain raw credentials, grant WLU entitlement or replace Runtime Registry execution authority"
  self~init:super(meta)
  self~registerStateVariable("providerConfig", "INTERNAL", "frozen non-secret batch deployment configuration")
  self~registerStateVariable("secretBroker", "SECRET", "secret broker reference")
  self~registerStateVariable("httpTransport", "INTERNAL", "batch HTTP transport")
  self~registerExternalRequirement("library", "oorexx_secret_broker", "v" || .GrokBatchProviderBuild~SECRET_BROKER_VERSION, .true)
  self~registerExternalRequirement("library", "alchemy_objects", "v" || .GrokBatchProviderBuild~ALCHEMY_OBJECTS_VERSION, .true)
  self~declareHouseCompliance(95)

::method createBatch
  expose providerConfig secretBroker httpTransport
  use arg nameArg = "ooRexx-batch"
  name = nameArg~string~strip
  if name = "" then name = "ooRexx-batch"
  body = .directory~new
  body["name"] = name
  bodyJson = .Json~new~toJson(body)
  return self~execute("POST", providerConfig~endpointBase || "/batches", bodyJson, "createBatch")

::method addRequests
  expose providerConfig secretBroker httpTransport
  use arg batchIdArg, requestsArg
  batchId = batchIdArg~string~strip
  if batchId = "" then return self~boundedFailure("AI_BATCH_ID_INVALID", "batch_id must not be empty")
  if \requestsArg~isa(.Array) then return self~boundedFailure("AI_BATCH_REQUESTS_INVALID", "requests must be Array")
  if requestsArg~items = 0 then return self~boundedFailure("AI_BATCH_REQUESTS_EMPTY", "at least one request required")
  policy = providerConfig~modelPolicy
  if requestsArg~items > policy~maxRequestsPerAdd then ,
    return self~boundedFailure("AI_BATCH_REQUESTS_LIMIT", "request count exceeds deployment max_requests_per_add")

  batchRequests = .array~new
  do req over requestsArg
    if \req~isa(.GrokBatchAddRequest) then return self~boundedFailure("AI_BATCH_REQUESTS_INVALID", "each request must be GrokBatchAddRequest")
    if \policy~allowsModel(req~model) then return self~boundedFailure("AI_PROVIDER_MODEL_NOT_ALLOWED", "model not enabled for batch: " || req~model)
    if req~maxOutputTokens > policy~maxOutputTokensLimit then ,
      return self~boundedFailure("AI_PROVIDER_OUTPUT_LIMIT", "requested output exceeds batch policy")
    /* Model policy passed before credential acquisition. */
    messages = .array~new
    msg = .directory~new
    msg["role"] = "user"
    msg["content"] = req~prompt
    messages~append(msg)
    item = .directory~new
    item["batch_request_id"] = req~batchRequestId
    br = .directory~new
    responses = .directory~new
    responses["model"] = req~model
    responses["input"] = messages
    /* max_tokens is accepted on responses-style bodies by xAI */
    responses["max_tokens"] = req~maxOutputTokens
    br["responses"] = responses
    item["batch_request"] = br
    batchRequests~append(item)
  end

  body = .directory~new
  body["batch_requests"] = batchRequests
  bodyJson = .Json~new~toJson(body)
  url = providerConfig~endpointBase || "/batches/" || batchId || "/requests"
  return self~execute("POST", url, bodyJson, "addRequests")

::method getBatch
  expose providerConfig
  use arg batchIdArg
  batchId = batchIdArg~string~strip
  if batchId = "" then return self~boundedFailure("AI_BATCH_ID_INVALID", "batch_id must not be empty")
  url = providerConfig~endpointBase || "/batches/" || batchId
  return self~execute("GET", url, "", "getBatch")

::method listResults
  expose providerConfig
  use arg batchIdArg, limitArg = 100, paginationTokenArg = ""
  batchId = batchIdArg~string~strip
  if batchId = "" then return self~boundedFailure("AI_BATCH_ID_INVALID", "batch_id must not be empty")
  url = providerConfig~endpointBase || "/batches/" || batchId || "/results?limit=" || limitArg
  if paginationTokenArg~string \= "" then url = url || "&pagination_token=" || paginationTokenArg~string
  return self~execute("GET", url, "", "listResults")

::method cancelBatch
  expose providerConfig
  use arg batchIdArg
  batchId = batchIdArg~string~strip
  if batchId = "" then return self~boundedFailure("AI_BATCH_ID_INVALID", "batch_id must not be empty")
  url = providerConfig~endpointBase || "/batches/" || batchId || ":cancel"
  return self~execute("POST", url, "{}", "cancelBatch")

::method execute private
  expose providerConfig secretBroker httpTransport
  use arg method, url, bodyJson, opName
  /* Acquire lease only after policy checks already performed by caller. */
  secretOutcome = secretBroker~acquire(providerConfig~credentialReference)
  if secretOutcome == .nil then return self~boundedFailure("AI_PROVIDER_CREDENTIAL_UNAVAILABLE", "unable to acquire credential lease")
  if \secretOutcome~hasMethod("OK") then return self~boundedFailure("AI_PROVIDER_CREDENTIAL_UNAVAILABLE", "secret broker returned unsupported acquisition result")
  if \secretOutcome~ok then return self~boundedFailure("AI_PROVIDER_CREDENTIAL_UNAVAILABLE", "unable to acquire credential lease")
  lease = secretOutcome~value
  signal on syntax name transportRaised
  outcome = httpTransport~requestJson(method, url, bodyJson, lease, providerConfig~timeoutSeconds)
  signal off syntax
  ignore = lease~retire
  if \outcome~ok then return self~mapTransportFailure(outcome)
  if outcome~status = 401 | outcome~status = 403 then ,
    return self~boundedFailure("AI_PROVIDER_AUTH_REJECTED", "provider rejected credentials", outcome~status)
  if outcome~status = 429 then ,
    return self~boundedFailure("AI_PROVIDER_RATE_LIMITED", "provider rate limited the batch operation", outcome~status)
  if outcome~status < 200 | outcome~status >= 300 then ,
    return self~boundedFailure("AI_BATCH_HTTP_ERROR", "batch operation HTTP " || outcome~status, outcome~status)
  return self~parseSuccess(outcome~body, opName)

transportRaised:
  signal off syntax
  ignore = lease~retire
  return self~boundedFailure("AI_PROVIDER_TRANSPORT_ERROR", "batch transport raised condition")

::method parseSuccess private
  use arg body, opName
  signal on syntax name parseFail
  parsed = .Json~new~fromJson(body)
  signal off syntax
  response = .directory~new
  response["ok"] = .true
  response["operation"] = opName
  response["body"] = parsed
  if parsed~isa(.Directory) then do
    if parsed~at("batch_id") \== .nil then response["batch_id"] = parsed~at("batch_id")~string
    if parsed~at("state") \== .nil then response["state"] = parsed~at("state")
  end
  return response

parseFail:
  signal off syntax
  return self~boundedFailure("AI_PROVIDER_RESPONSE_INVALID", "batch provider returned invalid JSON")

::method mapTransportFailure private
  use arg outcome
  return self~boundedFailure(outcome~code, outcome~detail, outcome~status)

::method boundedFailure private
  use arg code, detail = "", status = 0
  failure = .directory~new
  failure["ok"] = .false
  failure["code"] = code~string
  failure["detail"] = detail~string
  failure["status"] = status
  return failure


::class GrokBatchRuntimeModule subclass AlchemyObject public

::method init
  expose deploymentConfig deploymentBroker deploymentTransport
  endpointBase = value("AI_GROK_BATCH_ENDPOINT_BASE",, "ENVIRONMENT")
  if endpointBase = "" then endpointBase = "https://api.x.ai/v1"
  credentialReference = value("AI_GROK_BATCH_CREDENTIAL_REFERENCE",, "ENVIRONMENT")
  if credentialReference = "" then credentialReference = value("AI_GROK_CREDENTIAL_REFERENCE",, "ENVIRONMENT")
  if credentialReference = "" then credentialReference = "xai-api-key"
  credentialEnvName = value("AI_GROK_BATCH_CREDENTIAL_ENV",, "ENVIRONMENT")
  if credentialEnvName = "" then credentialEnvName = value("AI_GROK_CREDENTIAL_ENV",, "ENVIRONMENT")
  if credentialEnvName = "" then credentialEnvName = "XAI_API_KEY"
  timeoutText = value("AI_GROK_BATCH_TIMEOUT",, "ENVIRONMENT")
  if timeoutText = "" then timeoutText = 60
  curlExecutable = value("AI_GROK_BATCH_CURL",, "ENVIRONMENT")
  if curlExecutable = "" then curlExecutable = value("AI_GROK_CURL",, "ENVIRONMENT")
  if curlExecutable = "" then curlExecutable = "curl"
  allowHttpText = value("AI_GROK_BATCH_ALLOW_HTTP_TEST",, "ENVIRONMENT")
  allowHttp = allowHttpText == "1"
  modelPolicy = .GrokBatchModelPolicy~fromEnvironment
  deploymentConfig = .GrokBatchProviderConfig~new(endpointBase, credentialReference, modelPolicy, timeoutText, allowHttp)
  secretMap = .directory~new
  secretMap[credentialReference] = credentialEnvName
  secretProvider = .MappedEnvironmentSecretProvider~new(secretMap)
  deploymentBroker = .SecretBroker~new(secretProvider)
  deploymentTransport = .GrokBatchCurlTransport~new(curlExecutable, allowHttp)
  meta = .directory~new
  meta["purpose"] = "Runtime module for Grok Batch API"
  meta["package"] = "oorexx_ai_provider_grok"
  meta["package_version"] = .GrokBatchProviderBuild~RELEASE
  meta["api_version"] = .GrokBatchProviderBuild~API_VERSION
  meta["authorship"] = "Alchemy ooRexx project"
  meta["standards"] = "ALCHEMY-HOUSE-OBJECT-0.8; ai.provider.grok.batch/0.3 deployment runtime module"
  meta["design_limitations"] = "Deployment module constructs batch adapter, Secret Broker and transport references; it does not expose secret values or grant WLU admission authority"
  self~init:super(meta)
  self~registerExternalRequirement("library", "oorexx_secret_broker", "v" || .GrokBatchProviderBuild~SECRET_BROKER_VERSION, .true)
  self~registerExternalRequirement("library", "alchemy_objects", "v" || .GrokBatchProviderBuild~ALCHEMY_OBJECTS_VERSION, .true)
  self~declareHouseCompliance(95)
  self~registerStateVariable("deploymentConfig", "INTERNAL", "frozen non-secret Grok batch deployment configuration")
  self~registerStateVariable("deploymentBroker", "SECRET", "deployment secret broker")
  self~registerStateVariable("deploymentTransport", "INTERNAL", "deployment batch HTTP transport")

::method createAdapter
  expose deploymentConfig deploymentBroker deploymentTransport
  return .GrokBatchAdapter~new(deploymentConfig, deploymentBroker, deploymentTransport)

::requires "SecretBroker.cls"
::requires "json.cls"
::requires "AlchemyObject.cls"
