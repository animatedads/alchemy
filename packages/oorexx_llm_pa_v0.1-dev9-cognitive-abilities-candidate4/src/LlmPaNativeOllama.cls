/* Native local Gemma/Ollama integration for the LLM PA.
 *
 * Model semantics use ooRexx AI Access (AIProviderRequest/Reply).
 * Outbound request ownership uses ooRexx API Client (v0.4.1 preferred; v0.3 compatibility retained).
 * The only HTTP transport admitted here is loopback-only plain HTTP for the
 * local Ollama daemon. It uses RxSock directly and never shells out to curl.
 */

/* API Client v0.4.1 makes ApiResponse~elapsedMs writable.  Keep the PA's
 * transport response writable as well so the native transport remains usable
 * with older v0.3 qualification copies while matching v0.4.1 semantics. */
::class LlmPaApiResponse subclass ApiResponse public
::attribute elapsedMs

::class LlmPaLoopbackHttpTransport subclass ApiTransport public
::method init
  expose timeoutSeconds maxBodyBytes
  use arg timeoutArg = 120, maxBodyArg = 8388608
  if \datatype(timeoutArg, "W") | timeoutArg < 1 | timeoutArg > 300 then raise syntax 88.900 array("loopback HTTP timeout must be 1..300 seconds")
  if \datatype(maxBodyArg, "W") | maxBodyArg < 1024 then raise syntax 88.900 array("loopback HTTP body limit invalid")
  timeoutSeconds = timeoutArg
  maxBodyBytes = maxBodyArg

::method execute
  expose timeoutSeconds maxBodyBytes
  use strict arg request, session = .nil
  started = .DateTime~new~microseconds
  parsed = self~parseUrl(request~url)
  if \parsed~ok then return self~failed(request, started, parsed~code, parsed~detail)
  url = parsed~value
  if url["scheme"] \= "http" then return self~failed(request, started, "LOOPBACK_HTTP_REQUIRED", "local Ollama endpoint must use http")
  host = url["host"]~lower
  if host \= "127.0.0.1" & host \= "localhost" then return self~failed(request, started, "LOOPBACK_HOST_REQUIRED", host)

  sock = .Socket~new("AF_INET", "SOCK_STREAM", "IPPROTO_TCP")
  address = .InetAddress~new(host, url["port"])
  rcConnect = sock~connect(address)
  if rcConnect \= 0 then do
    detail = "errno=" || sock~errno
    ignore = sock~close
    return self~failed(request, started, "OLLAMA_CONNECT_FAILED", detail)
  end

  wire = self~buildRequest(request, url)
  sent = self~sendAll(sock, wire)
  if \sent~ok then do
    ignore = sock~close
    return self~failed(request, started, sent~code, sent~detail)
  end

  /* Keep connect/write simple and bounded by loopback, then use non-blocking
   * reads plus SockSelect so a stalled local model cannot hang the PA forever. */
  nb = sock~ioctl("FIONBIO", 1)
  if nb == .nil then do
    ignore = sock~close
    return self~failed(request, started, "OLLAMA_SOCKET_NONBLOCK_FAILED", "errno=" || sock~errno)
  end

  raw = ""
  do forever
    reads = .array~of(sock)
    writes = .array~new
    excepts = .array~new
    ready = sock~select(reads, writes, excepts, timeoutSeconds)
    if ready == .nil then do
      ignore = sock~close
      return self~failed(request, started, "OLLAMA_SELECT_FAILED", "errno=" || sock~errno)
    end
    if ready = 0 then do
      ignore = sock~close
      return self~failed(request, started, "OLLAMA_READ_TIMEOUT", timeoutSeconds)
    end
    chunk = sock~recv(16384)
    if chunk == .nil then do
      ignore = sock~close
      return self~failed(request, started, "OLLAMA_READ_FAILED", "errno=" || sock~errno)
    end
    if chunk = "" then leave
    raw = raw || chunk
    if raw~length > maxBodyBytes + 131072 then do
      ignore = sock~close
      return self~failed(request, started, "OLLAMA_RESPONSE_TOO_LARGE", maxBodyBytes)
    end
  end
  ignore = sock~close
  return self~decodeResponse(request, started, raw)

::method parseUrl private
  use arg urlArg
  text = urlArg~string~strip
  marker = text~pos("://")
  if marker = 0 then return .LlmPaResult~failure("OLLAMA_URL_INVALID", text)
  scheme = text~left(marker - 1)~lower
  rest = text~substr(marker + 3)
  slash = rest~pos("/")
  if slash = 0 then do
    authority = rest
    target = "/"
  end
  else do
    authority = rest~left(slash - 1)
    target = rest~substr(slash)
  end
  if authority = "" | authority~pos("@") > 0 | authority~left(1) = "[" then return .LlmPaResult~failure("OLLAMA_URL_INVALID", text)
  colon = authority~lastPos(":")
  if colon > 0 then do
    host = authority~left(colon - 1)
    portText = authority~substr(colon + 1)
    if host = "" | \datatype(portText, "W") then return .LlmPaResult~failure("OLLAMA_URL_INVALID", text)
    port = portText + 0
  end
  else do
    host = authority
    port = 80
  end
  if port < 1 | port > 65535 then return .LlmPaResult~failure("OLLAMA_URL_INVALID", text)
  d = .directory~new
  d["scheme"] = scheme
  d["host"] = host
  d["port"] = port
  d["target"] = target
  if port = 80 then d["authority"] = host
  else d["authority"] = host || ":" || port
  return .LlmPaResult~success(d)

::method buildRequest private
  use arg request, url
  crlf = "0d0a"x
  headers = .directory~new
  do k over request~headers
    headers[k~string~lower] = request~headers[k]~string
  end
  if \headers~hasIndex("host") then headers["host"] = url["authority"]
  if \headers~hasIndex("user-agent") then headers["user-agent"] = "ooRexx-LLMPA/0.1-dev7"
  if \headers~hasIndex("accept") then headers["accept"] = "application/json"
  if \headers~hasIndex("connection") then headers["connection"] = "close"
  body = request~body~string
  if \headers~hasIndex("content-length") then headers["content-length"] = body~length~string
  text = request~method || " " || url["target"] || " HTTP/1.1" || crlf
  keys = .array~new
  do k over headers
    keys~append(k)
  end
  keys~sort
  do k over keys
    text = text || k || ": " || headers[k] || crlf
  end
  return text || crlf || body

::method sendAll private
  use arg sock, data
  offset = 1
  do while offset <= data~length
    count = sock~send(data~substr(offset))
    if count == .nil | count < 1 then return .LlmPaResult~failure("OLLAMA_WRITE_FAILED", "errno=" || sock~errno)
    offset = offset + count
  end
  return .LlmPaResult~success(.true)

::method decodeResponse private
  expose maxBodyBytes
  use arg request, started, raw
  sep = "0d0a0d0a"x
  p = raw~pos(sep)
  if p = 0 then return self~failed(request, started, "OLLAMA_HTTP_INVALID", "response headers missing")
  headText = raw~left(p - 1)
  body = raw~substr(p + 4)
  lines = headText~makeArray("0d0a"x)
  if lines == .nil | lines~items < 1 then return self~failed(request, started, "OLLAMA_HTTP_INVALID", "empty response head")
  statusLine = lines[1]
  parse var statusLine version status reason
  if version~left(5) \= "HTTP/" | \datatype(status, "W") then return self~failed(request, started, "OLLAMA_HTTP_INVALID", statusLine)
  headers = .directory~new
  do i = 2 to lines~items
    line = lines[i]
    colon = line~pos(":")
    if colon <= 1 then iterate
    name = line~left(colon - 1)~strip~lower
    value = line~substr(colon + 1)~strip
    old = headers~at(name)
    if old == .nil then headers[name] = value
    else headers[name] = old || ", " || value
  end
  transfer = self~header(headers, "transfer-encoding", "")~lower
  if transfer~pos("chunked") > 0 then do
    decoded = self~decodeChunked(body, maxBodyBytes)
    if \decoded~ok then return self~failed(request, started, decoded~code, decoded~detail)
    body = decoded~value
  end
  lengthText = self~header(headers, "content-length", "")
  if lengthText \= "" & datatype(lengthText, "W") then do
    wanted = lengthText + 0
    if wanted > maxBodyBytes then return self~failed(request, started, "OLLAMA_RESPONSE_TOO_LARGE", wanted)
    if body~length < wanted then return self~failed(request, started, "OLLAMA_HTTP_TRUNCATED", wanted)
    if body~length > wanted then body = body~left(wanted)
  end
  if body~length > maxBodyBytes then return self~failed(request, started, "OLLAMA_RESPONSE_TOO_LARGE", body~length)
  elapsed = (.DateTime~new~microseconds - started) % 1000
  return .LlmPaApiResponse~new(request~id, status + 0, headers, body, elapsed, "", 0)

::method decodeChunked private
  use arg raw, maxBytes
  posn = 1
  out = ""
  crlf = "0d0a"x
  do forever
    eol = raw~pos(crlf, posn)
    if eol = 0 then return .LlmPaResult~failure("OLLAMA_HTTP_CHUNK_INVALID", "truncated chunk size")
    line = raw~substr(posn, eol - posn)~strip
    semi = line~pos(";")
    if semi > 0 then line = line~left(semi - 1)~strip
    size = self~hexNumber(line)
    if size < 0 then return .LlmPaResult~failure("OLLAMA_HTTP_CHUNK_INVALID", line)
    posn = eol + 2
    if size = 0 then return .LlmPaResult~success(out)
    if posn + size - 1 > raw~length then return .LlmPaResult~failure("OLLAMA_HTTP_CHUNK_INVALID", "truncated chunk")
    out = out || raw~substr(posn, size)
    if out~length > maxBytes then return .LlmPaResult~failure("OLLAMA_RESPONSE_TOO_LARGE", maxBytes)
    posn = posn + size
    if raw~substr(posn, 2) \= crlf then return .LlmPaResult~failure("OLLAMA_HTTP_CHUNK_INVALID", "chunk terminator")
    posn = posn + 2
  end

::method hexNumber private
  use arg textArg
  text = textArg~string~strip~lower
  if text = "" then return -1
  digits = "0123456789abcdef"
  n = 0
  do i = 1 to text~length
    p = digits~pos(text~substr(i, 1))
    if p = 0 then return -1
    n = n * 16 + p - 1
  end
  return n

::method header private
  use arg headers, name, default = ""
  value = headers~at(name~lower)
  if value == .nil then return default
  return value~string

::method failed private
  use arg request, started, code, detail = ""
  headers = .directory~new
  if detail \= "" then headers["x-llmpa-transport-detail"] = detail~string
  elapsed = (.DateTime~new~microseconds - started) % 1000
  return .LlmPaApiResponse~new(request~id, 0, headers, "", elapsed, code~string, 0)


::class LlmPaOllamaProvider subclass AIProviderAdapterBase public
::method init
  expose apiClient modelName baseUrl verified
  use arg modelArg = "gemma2:2b", baseUrlArg = "http://127.0.0.1:11434", apiClientArg = .nil
  modelName = modelArg~string~strip
  baseUrl = baseUrlArg~string~strip
  if modelName = "" then raise syntax 88.900 array("Gemma model name required")
  if modelName~lower~pos("gemma") = 0 then raise syntax 88.900 array("LLM PA live provider must be a Gemma model", modelName)
  if baseUrl~right(1) = "/" then baseUrl = baseUrl~left(baseUrl~length - 1)
  baseLower = baseUrl~lower
  validLoopback = baseLower = "http://127.0.0.1" | baseLower~left(17) = "http://127.0.0.1:"
  if \validLoopback then validLoopback = baseLower = "http://localhost" | baseLower~left(17) = "http://localhost:"
  if \validLoopback then raise syntax 88.900 array("Ollama base URL must be loopback HTTP", baseUrl)
  if apiClientArg == .nil then apiClient = .ApiClient~new(.LlmPaLoopbackHttpTransport~new)
  else apiClient = apiClientArg
  verified = .false
  self~init:super
  self~registerExternalRequirement("library", "oorexx_api_client", "v0.3", .true)
  self~registerExternalRequirement("service", "ollama", "local Gemma model " || modelName, .true)

::method verifyModel public
  expose apiClient modelName baseUrl verified
  headers = .directory~new
  headers["accept"] = "application/json"
  req = .ApiRequest~new(.LlmPaUtil~requestId, "GET", baseUrl || "/api/tags", headers, "", "CONTROL", 100, 1000, 1000)
  response = apiClient~execute(req)
  if \response~ok then return .LlmPaResult~failure("GEMMA_MODEL_PROBE_FAILED", response~errorCode)
  signal on syntax name badJson
  parsed = .JSON~fromJSON(response~body)
  signal off syntax
  if \parsed~isa(.Directory) then return .LlmPaResult~failure("GEMMA_MODEL_PROBE_INVALID", "tags response must be object")
  models = parsed~at("models")
  if models == .nil | \models~isa(.Array) then return .LlmPaResult~failure("GEMMA_MODEL_PROBE_INVALID", "models array missing")
  do entry over models
    if entry~isa(.Directory) then do
      name = entry~at("name")
      if name \== .nil then do
        if name~string~caselessEquals(modelName) then do
          verified = .true
          return .LlmPaResult~success(modelName)
        end
      end
    end
  end
  return .LlmPaResult~failure("GEMMA_MODEL_NOT_INSTALLED", modelName)
badJson:
  signal off syntax
  return .LlmPaResult~failure("GEMMA_MODEL_PROBE_INVALID", "invalid JSON")

::method completeRequest protected
  expose apiClient modelName baseUrl verified
  use arg request
  if \request~isa(.AIProviderRequest) then return .AIProviderReply~failure("AI_PROVIDER_REQUEST_TYPE", "expected AIProviderRequest")
  if \request~model~caselessEquals(modelName) then return .AIProviderReply~failure("GEMMA_MODEL_MISMATCH", "only the verified Gemma model is enabled", .AIProviderUsage~new(0, 0), request~model)
  if \verified then do
    checked = self~verifyModel
    if \checked~ok then return .AIProviderReply~failure(checked~code, checked~detail, .AIProviderUsage~new(0, 0), request~model)
  end

  message = .directory~new
  message["role"] = "user"
  message["content"] = request~prompt
  body = .directory~new
  body["model"] = request~model
  body["messages"] = .array~of(message)
  body["max_tokens"] = request~maxOutputTokens
  body["stream"] = .JSON~false
  headers = .directory~new
  headers["content-type"] = "application/json"
  headers["accept"] = "application/json"
  wire = .JSON~toJSON(body)
  apiRequest = .ApiRequest~new(.LlmPaUtil~requestId, "POST", baseUrl || "/v1/chat/completions", headers, wire, "INTERACTIVE", 80, 1000000, 1000000)
  response = apiClient~execute(apiRequest)
  if \response~ok then return .AIProviderReply~failure("GEMMA_TRANSPORT_FAILED", response~errorCode, .AIProviderUsage~new(0, 0), request~model)

  signal on syntax name badCompletion
  parsed = .JSON~fromJSON(response~body)
  signal off syntax
  if \parsed~isa(.Directory) then return .AIProviderReply~failure("GEMMA_REPLY_INVALID", "completion response must be object", .AIProviderUsage~new(0, 0), request~model)
  choices = parsed~at("choices")
  if choices == .nil | \choices~isa(.Array) | choices~items < 1 then return .AIProviderReply~failure("GEMMA_REPLY_INVALID", "choices missing", .AIProviderUsage~new(0, 0), request~model)
  choice = choices[1]
  if \choice~isa(.Directory) then return .AIProviderReply~failure("GEMMA_REPLY_INVALID", "choice invalid", .AIProviderUsage~new(0, 0), request~model)
  replyMessage = choice~at("message")
  if replyMessage == .nil | \replyMessage~isa(.Directory) then return .AIProviderReply~failure("GEMMA_REPLY_INVALID", "message missing", .AIProviderUsage~new(0, 0), request~model)
  content = replyMessage~at("content")
  if content == .nil then return .AIProviderReply~failure("GEMMA_REPLY_INVALID", "content missing", .AIProviderUsage~new(0, 0), request~model)
  text = content~string~strip
  if text = "" then return .AIProviderReply~failure("GEMMA_REPLY_EMPTY", "model returned empty content", .AIProviderUsage~new(0, 0), request~model)
  returnedModel = parsed~at("model")
  if returnedModel == .nil then returnedModel = request~model
  else returnedModel = returnedModel~string
  if returnedModel~lower~pos("gemma") = 0 then return .AIProviderReply~failure("GEMMA_REPLY_MODEL_MISMATCH", "provider did not identify a Gemma model", .AIProviderUsage~new(0, 0), returnedModel)
  finishReason = choice~at("finish_reason")
  if finishReason == .nil then finishReason = "stop"
  usage = self~usage(parsed~at("usage"))
  return .AIProviderReply~success(text, returnedModel, finishReason~string, usage)
badCompletion:
  signal off syntax
  return .AIProviderReply~failure("GEMMA_REPLY_INVALID", "invalid JSON", .AIProviderUsage~new(0, 0), request~model)

::method usage private
  use arg value
  inputTokens = 0
  outputTokens = 0
  if value \== .nil then if value~isa(.Directory) then do
    v = value~at("prompt_tokens")
    if v \== .nil then if datatype(v~string, "W") then inputTokens = v + 0
    v = value~at("completion_tokens")
    if v \== .nil then if datatype(v~string, "W") then outputTokens = v + 0
  end
  return .AIProviderUsage~new(inputTokens, outputTokens)


::class LlmPaLiveModelResult public
::attribute text get
::attribute toolExecuted get
::attribute toolName get
::attribute toolCallId get
::attribute model get
::method init
  expose text toolExecuted toolName toolCallId model
  use arg textArg, modelArg
  text = textArg~string
  model = modelArg~string
  toolExecuted = .false
  toolName = ""
  toolCallId = ""


::class LlmPaOllamaOrchestrator public
::attribute modelName get
::method init
  expose provider modelName
  use arg modelArg = "", baseUrlArg = "", apiClientArg = .nil
  if modelArg = "" then modelArg = value("LLMPA_GEMMA_MODEL", , "ENVIRONMENT")
  if modelArg = "" then modelArg = "gemma2:2b"
  if baseUrlArg = "" then baseUrlArg = value("LLMPA_OLLAMA_BASE_URL", , "ENVIRONMENT")
  if baseUrlArg = "" then baseUrlArg = "http://127.0.0.1:11434"
  modelName = modelArg~string~strip
  provider = .LlmPaOllamaProvider~new(modelName, baseUrlArg, apiClientArg)

::method verifyModel
  expose provider
  return provider~verifyModel

::method runOnce
  expose provider modelName
  use arg requestedModel = "", prompt, maxOutputTokens = 512
  model = requestedModel~string~strip
  if model = "" then model = modelName
  if \model~caselessEquals(modelName) then return .LlmPaResult~failure("GEMMA_MODEL_MISMATCH", "configured model is " || modelName)
  response = provider~complete(.AIProviderRequest~new(model, prompt, maxOutputTokens))
  if \response~ok then return .LlmPaResult~failure(response~code, response~detail)
  return .LlmPaResult~success(.LlmPaLiveModelResult~new(response~text, response~model))

::requires "LlmPaCore.cls"
::requires "AIProviderAccess.cls"
::requires "ApiClient.cls"
::requires "json.cls"
::requires "socket.cls"
