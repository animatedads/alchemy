/* Ability HTTP Server v0.7
 *
 * Thin HTTP/1.1 transport above AbilityRegistry.
 *
 * Security/lifecycle constraints:
 *   - binds loopback by default; TLS is expected at a reverse proxy;
 *   - HTTP has no RuntimeRegistry lifecycle authority;
 *   - each authenticated request acquires exactly one AbilitySession;
 *   - invocation context exposes only aliases declared by that ability;
 *   - one request per connection, Connection: close;
 *   - bounded request line, header block and body;
 *   - Transfer-Encoding is rejected in v0.1 to avoid request ambiguity;
 *   - duplicate headers are rejected;
 *   - POST bodies must be application/json and Content-Length framed.
 */

::class AbilityHttpBuild public
::constant PRODUCT "ooRexx Ability HTTP Server"
::constant RELEASE "0.7"
::constant API_VERSION "ability.http/0.7"

::class AbilityCredential public
::attribute keyId get
::attribute environment get
::attribute clientId get

::method init
  expose keyId environment clientId secret
  use arg keyId, secret, environment, clientId
  keyId = keyId~string~strip
  secret = secret~string
  environment = environment~string~strip~lower
  clientId = clientId~string~strip~lower
  if keyId = "" then raise syntax 88.900 array("AbilityCredential keyId must not be empty")
  if secret = "" then raise syntax 88.900 array("AbilityCredential secret must not be empty")
  if keyId~pos(".") > 0 then raise syntax 88.900 array("AbilityCredential keyId must not contain '.'")
  if secret~pos(" ") > 0 then raise syntax 88.900 array("AbilityCredential secret must not contain whitespace")
  if secret~pos("09"x) > 0 then raise syntax 88.900 array("AbilityCredential secret must not contain whitespace")
  if environment = "" then raise syntax 88.900 array("AbilityCredential environment must not be empty")
  if clientId = "" then raise syntax 88.900 array("AbilityCredential clientId must not be empty")

::method tokenMatches
  expose keyId secret
  use arg token
  expected = "ab1." || keyId || "." || secret
  return token == expected

::class AbilityCredentialStore public
::method init
  expose credentials
  credentials = .table~new

::method register
  expose credentials
  use arg keyId, secret, environment, clientId
  key = keyId~string~strip
  if credentials~at(key) \== .nil then return .RuntimeResult~failure("CREDENTIAL_EXISTS", key)
  credential = .AbilityCredential~new(key, secret, environment, clientId)
  credentials~put(credential, key)
  return .RuntimeResult~success(credential)

::method authenticateAuthorization
  expose credentials
  use arg headerValue
  value = headerValue~string~strip
  if value = "" then return .RuntimeResult~failure("AUTHORIZATION_REQUIRED", "Authorization: Bearer token required")
  if words(value) <> 2 then return .RuntimeResult~failure("AUTHORIZATION_INVALID", "Bearer token required")
  if word(value, 1)~upper <> "BEARER" then return .RuntimeResult~failure("AUTHORIZATION_INVALID", "Bearer token required")
  token = word(value, 2)
  if left(token, 4) <> "ab1." then return .RuntimeResult~failure("AUTHORIZATION_INVALID", "unsupported ability credential")
  rest = substr(token, 5)
  dot = pos(".", rest)
  if dot <= 1 then return .RuntimeResult~failure("AUTHORIZATION_INVALID", "malformed ability credential")
  keyId = left(rest, dot - 1)
  credential = credentials~at(keyId)
  if credential == .nil then return .RuntimeResult~failure("AUTHORIZATION_INVALID", "unknown ability credential")
  if \credential~tokenMatches(token) then return .RuntimeResult~failure("AUTHORIZATION_INVALID", "ability credential mismatch")
  return .RuntimeResult~success(credential)

::class AbilityHttpRequest public
::attribute method get
::attribute target get
::attribute path get
::attribute query get
::attribute version get
::attribute headers get
::attribute body get

::method init
  expose method target path query version headers body
  use arg method, target, version, headers, body = ""
  method = method~string~strip~upper
  target = target~string
  version = version~string~strip~upper
  body = body~string
  q = pos("?", target)
  if q > 0 then do
    path = left(target, q - 1)
    query = substr(target, q + 1)
  end
  else do
    path = target
    query = ""
  end

::method header
  expose headers
  use arg name
  return headers~at(name~string~lower)


::class AbilityBoolean public
::attribute value get
::method init
  expose value
  use arg valueArg
  if valueArg then value = .true
  else value = .false

::class AbilityJson public
::method safe class
  use arg value
  if value~isa(.AbilityBoolean) then do
    if value~value then return .JSONBoolean~true
    return .JSONBoolean~false
  end
  if value~isa(.JSONBoolean) then return value
  if value~isa(.Directory) then do
    output = .directory~new
    supplier = value~supplier
    do while supplier~available
      output[supplier~index] = self~safe(supplier~item)
      supplier~next
    end
    return output
  end
  if value~isa(.Array) then do
    output = .array~new
    do i = 1 to value~items
      output~append(self~safe(value~at(i)))
    end
    return output
  end
  return value

::class AbilityHttpResponse public
::attribute status get
::attribute reason get
::attribute headers get
::attribute body get

::method init
  expose status reason headers body
  use arg status, reason, body = "", headers = .nil
  status = status~string~strip
  if \datatype(status, "W") then raise syntax 88.900 array("HTTP status must be a whole number")
  reason = reason~string
  body = body~string
  if headers == .nil then headers = .directory~new

::method json class
  use arg status, value, reason = ""
  if reason = "" then reason = self~reasonFor(status)
  body = .JSON~toJSON(.AbilityJson~safe(value))
  headers = .directory~new
  headers["content-type"] = "application/json; charset=utf-8"
  return self~new(status, reason, body, headers)

::method problem class
  use arg status, problemType, title, detail = "", extras = .nil
  object = .directory~new
  object["type"] = problemType
  object["title"] = title
  object["status"] = status
  if detail <> "" then object["detail"] = detail
  if extras \== .nil then do
    supplier = extras~supplier
    do while supplier~available
      object[supplier~index] = supplier~item
      supplier~next
    end
  end
  body = .JSON~toJSON(object)
  headers = .directory~new
  headers["content-type"] = "application/problem+json; charset=utf-8"
  return self~new(status, self~reasonFor(status), body, headers)

::method reasonFor class
  use arg status
  select
    when status = 200 then return "OK"
    when status = 201 then return "Created"
    when status = 304 then return "Not Modified"
    when status = 400 then return "Bad Request"
    when status = 401 then return "Unauthorized"
    when status = 403 then return "Forbidden"
    when status = 404 then return "Not Found"
    when status = 405 then return "Method Not Allowed"
    when status = 409 then return "Conflict"
    when status = 413 then return "Content Too Large"
    when status = 415 then return "Unsupported Media Type"
    when status = 422 then return "Unprocessable Content"
    when status = 429 then return "Too Many Requests"
    when status = 500 then return "Internal Server Error"
    when status = 501 then return "Not Implemented"
    when status = 503 then return "Service Unavailable"
    otherwise return "HTTP Response"
  end

::method wire
  expose status reason headers body
  crlf = "0d0a"x
  text = "HTTP/1.1 " || status || " " || reason || crlf
  text = text || "Connection: close" || crlf
  text = text || "Content-Length: " || body~length || crlf
  supplier = headers~supplier
  do while supplier~available
    text = text || self~headerCase(supplier~index) || ": " || supplier~item || crlf
    supplier~next
  end
  text = text || crlf || body
  return text

::method headerCase private
  use arg name
  select
    when name = "content-type" then return "Content-Type"
    when name = "allow" then return "Allow"
    when name = "www-authenticate" then return "WWW-Authenticate"
    when name = "location" then return "Location"
    when name = "etag" then return "ETag"
    when name = "cache-control" then return "Cache-Control"
    when name = "vary" then return "Vary"
    when name = "retry-after" then return "Retry-After"
    otherwise return name
  end

::class AbilityHttpLimits public
::attribute maxRequestLine get
::attribute maxHeaderBytes get
::attribute maxHeaderCount get
::attribute maxBodyBytes get

::method init
  expose maxRequestLine maxHeaderBytes maxHeaderCount maxBodyBytes
  use arg maxRequestLine = 4096, maxHeaderBytes = 32768, maxHeaderCount = 64, maxBodyBytes = 1048576

::class AbilityHttpReadResult public
::attribute ok get
::attribute request get
::attribute response get

::method init
  expose ok request response
  use arg ok, request = .nil, response = .nil

::method success class
  use arg request
  return self~new(.true, request, .nil)

::method failure class
  use arg response
  return self~new(.false, .nil, response)

::class AbilityHttpConnectionReader public
::method init
  expose limits
  use arg limits = .nil
  if limits == .nil then limits = .AbilityHttpLimits~new

::method readRequest
  expose limits
  use arg socket
  crlf = "0d0a"x
  terminator = crlf || crlf
  data = ""
  headerEnd = 0
  do while headerEnd = 0
    chunk = socket~recv(4096)
    if chunk == .nil then return .AbilityHttpReadResult~failure(.AbilityHttpResponse~problem(400, "/problems/incomplete-request", "Incomplete request"))
    if chunk == "" then return .AbilityHttpReadResult~failure(.AbilityHttpResponse~problem(400, "/problems/incomplete-request", "Incomplete request"))
    data = data || chunk
    if data~length > limits~maxHeaderBytes + 4 then return .AbilityHttpReadResult~failure(.AbilityHttpResponse~problem(413, "/problems/header-too-large", "Header block too large"))
    headerEnd = pos(terminator, data)
  end

  headerText = left(data, headerEnd - 1)
  bodyStart = headerEnd + terminator~length
  bufferedBody = substr(data, bodyStart)
  parseResult = self~parseHeaders(headerText)
  if \parseResult~ok then return parseResult
  request = parseResult~request

  contentLength = 0
  lengthHeader = request~header("content-length")
  if lengthHeader \== .nil then do
    if lengthHeader = "" then return .AbilityHttpReadResult~failure(.AbilityHttpResponse~problem(400, "/problems/content-length", "Invalid Content-Length"))
    if \lengthHeader~datatype("W") then return .AbilityHttpReadResult~failure(.AbilityHttpResponse~problem(400, "/problems/content-length", "Invalid Content-Length"))
    contentLength = lengthHeader~string~strip
  end
  if contentLength > limits~maxBodyBytes then return .AbilityHttpReadResult~failure(.AbilityHttpResponse~problem(413, "/problems/body-too-large", "Request body too large"))

  transferEncoding = request~header("transfer-encoding")
  if transferEncoding \== .nil then return .AbilityHttpReadResult~failure(.AbilityHttpResponse~problem(501, "/problems/transfer-encoding", "Transfer-Encoding is not supported", "Use Content-Length framing through the trusted reverse proxy"))

  body = bufferedBody
  if body~length > contentLength then body = left(body, contentLength)
  do while body~length < contentLength
    needed = contentLength - body~length
    chunkSize = needed
    if chunkSize > 4096 then chunkSize = 4096
    chunk = socket~recv(chunkSize)
    if chunk == .nil then return .AbilityHttpReadResult~failure(.AbilityHttpResponse~problem(400, "/problems/incomplete-body", "Incomplete request body"))
    if chunk == "" then return .AbilityHttpReadResult~failure(.AbilityHttpResponse~problem(400, "/problems/incomplete-body", "Incomplete request body"))
    body = body || chunk
  end

  return .AbilityHttpReadResult~success(.AbilityHttpRequest~new(request~method, request~target, request~version, request~headers, body))

::method parseHeaders private
  expose limits
  use arg text
  crlf = "0d0a"x
  lines = self~split(text, crlf)
  if lines~items = 0 then return .AbilityHttpReadResult~failure(.AbilityHttpResponse~problem(400, "/problems/request-line", "Missing request line"))
  requestLine = lines~at(1)
  if requestLine~length > limits~maxRequestLine then return .AbilityHttpReadResult~failure(.AbilityHttpResponse~problem(413, "/problems/request-line-too-large", "Request line too large"))
  if words(requestLine) <> 3 then return .AbilityHttpReadResult~failure(.AbilityHttpResponse~problem(400, "/problems/request-line", "Malformed request line"))
  method = word(requestLine, 1)~upper
  target = word(requestLine, 2)
  version = word(requestLine, 3)~upper
  if version <> "HTTP/1.1" then do
    if version <> "HTTP/1.0" then return .AbilityHttpReadResult~failure(.AbilityHttpResponse~problem(400, "/problems/http-version", "Unsupported HTTP version"))
  end
  if left(target, 1) <> "/" then return .AbilityHttpReadResult~failure(.AbilityHttpResponse~problem(400, "/problems/request-target", "Only origin-form request targets are accepted"))
  if target~pos("#") > 0 then return .AbilityHttpReadResult~failure(.AbilityHttpResponse~problem(400, "/problems/request-target", "Fragment is not valid in request target"))

  headers = .directory~new
  count = 0
  do i = 2 to lines~items
    line = lines~at(i)
    if line = "" then iterate
    count = count + 1
    if count > limits~maxHeaderCount then return .AbilityHttpReadResult~failure(.AbilityHttpResponse~problem(413, "/problems/header-count", "Too many request headers"))
    first = left(line, 1)
    if first = " " then return .AbilityHttpReadResult~failure(.AbilityHttpResponse~problem(400, "/problems/header-fold", "Obsolete folded headers are not accepted"))
    if first = "09"x then return .AbilityHttpReadResult~failure(.AbilityHttpResponse~problem(400, "/problems/header-fold", "Obsolete folded headers are not accepted"))
    colon = pos(":", line)
    if colon <= 1 then return .AbilityHttpReadResult~failure(.AbilityHttpResponse~problem(400, "/problems/header", "Malformed request header"))
    name = left(line, colon - 1)~strip~lower
    value = substr(line, colon + 1)~strip
    if name = "" then return .AbilityHttpReadResult~failure(.AbilityHttpResponse~problem(400, "/problems/header-name", "Invalid request header name"))
    if name~pos(" ") > 0 then return .AbilityHttpReadResult~failure(.AbilityHttpResponse~problem(400, "/problems/header-name", "Invalid request header name"))
    if name~pos("09"x) > 0 then return .AbilityHttpReadResult~failure(.AbilityHttpResponse~problem(400, "/problems/header-name", "Invalid request header name"))
    if headers~at(name) \== .nil then return .AbilityHttpReadResult~failure(.AbilityHttpResponse~problem(400, "/problems/duplicate-header", "Duplicate request headers are not accepted", name))
    headers[name] = value
  end

  if version = "HTTP/1.1" then do
    if headers~at("host") == .nil then return .AbilityHttpReadResult~failure(.AbilityHttpResponse~problem(400, "/problems/host-required", "Host header required for HTTP/1.1"))
    if headers~at("host") = "" then return .AbilityHttpReadResult~failure(.AbilityHttpResponse~problem(400, "/problems/host-required", "Host header required for HTTP/1.1"))
  end

  return .AbilityHttpReadResult~success(.AbilityHttpRequest~new(method, target, version, headers, ""))

::method split private
  use arg text, delimiter
  lineArray = .array~new
  start = 1
  do forever
    p = pos(delimiter, text, start)
    if p = 0 then do
      lineArray~append(substr(text, start))
      leave
    end
    lineArray~append(substr(text, start, p - start))
    start = p + delimiter~length
  end
  return lineArray

::class AbilityInvocationContext public
::attribute abilityId get
::attribute clientId get
::attribute profileId get
::attribute revision get
::attribute environment get

::method init
  expose session descriptor body allowedAliases abilityId clientId profileId revision environment wluInvocation
  use arg session, descriptor, body, wluInvocationArg = .nil
  wluInvocation = wluInvocationArg
  abilityId = descriptor~abilityId
  clientId = session~clientId
  profileId = session~profileId
  revision = session~revision
  environment = session~environment
  allowedAliases = .table~new
  aliases = descriptor~requiredAliases
  do i = 1 to aliases~items
    allowedAliases~put(.true, aliases~at(i))
  end

::method body
  expose body
  return body

::method module
  expose session allowedAliases
  use arg alias
  key = alias~string~strip~lower
  if allowedAliases~at(key) == .nil then return .nil
  return session~module(key)

::method runtimeGenerationId
  expose session allowedAliases
  use arg alias
  key = alias~string~strip~lower
  if allowedAliases~at(key) == .nil then return .nil
  return session~runtimeGenerationId(key)

::method runtimeArtifactId
  expose session allowedAliases
  use arg alias
  key = alias~string~strip~lower
  if allowedAliases~at(key) == .nil then return .nil
  return session~runtimeArtifactId(key)

::method runtimeExecutionEvidence
  expose session allowedAliases
  use arg alias
  key = alias~string~strip~lower
  if allowedAliases~at(key) == .nil then return .nil
  return session~runtimeExecutionEvidence(key)

::method runtimeEnvelope
  expose session allowedAliases
  use arg alias, value, locator = ""
  key = alias~string~strip~lower
  if allowedAliases~at(key) == .nil then return .nil
  return session~runtimeEnvelope(key, value, locator)

::method dataBinding
  expose session allowedAliases
  use arg logicalName
  binding = session~dataBinding(logicalName)
  if binding == .nil then return .nil
  if allowedAliases~at(binding~runtimeAlias) == .nil then return .nil
  return binding

::method ruleBinding
  expose session allowedAliases
  use arg logicalName
  binding = session~ruleBinding(logicalName)
  if binding == .nil then return .nil
  if allowedAliases~at(binding~runtimeAlias) == .nil then return .nil
  return binding

::method handlerAlias
  expose descriptor
  aliases = descriptor~requiredAliases
  if aliases~items = 0 then return ""
  return aliases~at(1)

::method success
  use arg value = .nil
  return .RuntimeResult~success(value)

::method failure
  use arg code, detail = ""
  return .RuntimeResult~failure(code, detail)

::method boolean
  use arg value
  return .AbilityBoolean~new(value)

::method wluManaged
  expose wluInvocation
  return wluInvocation \== .nil

::method wluReservationId
  expose wluInvocation
  if wluInvocation == .nil then return ""
  return wluInvocation~reservation~reservationId

::method wluScope
  expose wluInvocation
  if wluInvocation == .nil then return ""
  return wluInvocation~scope

::method meterFact
  expose wluInvocation
  use arg factType, quantity = 1, source = "", dimensions = .nil
  if wluInvocation == .nil then return .RuntimeResult~failure("ABILITY_WLU_NOT_MANAGED", "ability invocation has no WLU reservation")
  return wluInvocation~meterFact(factType, quantity, source, dimensions)

::class AbilityRouteOutcome public
::attribute response get
::attribute retainSession get
::method init
  expose response retainSession
  use arg responseArg, retainArg = .false
  response = responseArg
  retainSession = retainArg

::class AbilityHttpRouter public
::method init
  expose abilityRegistry credentialStore resultStore wluBridge
  use arg abilityRegistry, credentialStore, resultStore = .nil, wluBridgeArg = .nil
  if resultStore == .nil then resultStore = .AbilityResultStore~new
  wluBridge = wluBridgeArg

::method resultStore
  expose resultStore
  return resultStore

/* Trusted in-process route for an already-held AbilitySession.  The caller
 * owns the session lease and remains responsible for releasing it.  This is
 * deliberately limited to ordinary dynamic abilities: query/evaluate must
 * continue through the materialized-result routes so their session ownership
 * and evidence lifetime cannot be bypassed. */
::method routePinnedAbility
  use arg session, abilityIdArg, request
  if session == .nil then return .AbilityHttpResponse~problem(409, "/problems/pinned-session", "Pinned Ability session unavailable", "session missing")
  if \session~isa(.AbilitySession) then return .AbilityHttpResponse~problem(409, "/problems/pinned-session", "Pinned Ability session unavailable", "session type invalid")
  if session~released then return .AbilityHttpResponse~problem(409, "/problems/pinned-session", "Pinned Ability session unavailable", "session already released")
  if request == .nil then return .AbilityHttpResponse~problem(400, "/problems/request", "Ability request missing")

  abilityId = abilityIdArg~string~strip~lower
  if abilityId = "" then return .AbilityHttpResponse~problem(409, "/problems/pinned-ability", "Pinned Ability id required")
  if abilityId = "query" then return .AbilityHttpResponse~problem(409, "/problems/pinned-materialization", "Pinned inline route cannot materialise query")
  if abilityId = "evaluate" then return .AbilityHttpResponse~problem(409, "/problems/pinned-materialization", "Pinned inline route cannot materialise evaluation")
  if request~method \= "POST" then return .AbilityHttpResponse~problem(405, "/problems/method-not-allowed", "Method not allowed")
  requestAbility = self~abilityIdFromPath(request~path)
  if requestAbility = "" then return .AbilityHttpResponse~problem(409, "/problems/pinned-path", "Pinned Ability request path invalid")
  if requestAbility \= abilityId then return .AbilityHttpResponse~problem(409, "/problems/pinned-path", "Pinned Ability request path mismatch")

  signal on syntax name pinnedSyntax
  outcome = self~invoke(session, abilityId, request)
  signal off syntax
  if outcome~retainSession then return .AbilityHttpResponse~problem(409, "/problems/pinned-materialization", "Pinned route cannot retain materialized session")
  return outcome~response

pinnedSyntax:
  signal off syntax
  return .AbilityHttpResponse~problem(500, "/problems/internal", "Pinned Ability processing failed")

::method route
  expose abilityRegistry credentialStore resultStore
  use arg request
  if request~method = "GET" then do
    if request~path = "/v1/health" then return self~health
  end

  authResult = credentialStore~authenticateAuthorization(request~header("authorization"))
  if \authResult~ok then do
    response = .AbilityHttpResponse~problem(401, "/problems/unauthorized", "Unauthorized", authResult~detail)
    response~headers["www-authenticate"] = 'Bearer realm="ability"'
    return response
  end
  credential = authResult~value

  stored = self~materializedPath(request~path)
  if stored \== .nil then return self~routeStored(credential, request, stored)

  acquireResult = abilityRegistry~acquire(credential~environment, credential~clientId)
  if \acquireResult~ok then return .AbilityHttpResponse~problem(503, "/problems/profile-unavailable", "Ability profile unavailable", acquireResult~code || ": " || acquireResult~detail)
  session = acquireResult~value
  outcome = .nil
  signal on syntax name routeSyntax

  routeKey = request~method || " " || request~path
  dynamicAbilityId = self~abilityIdFromPath(request~path)
  select
    when routeKey = "GET /v1/openapi.json" then outcome = .AbilityRouteOutcome~new(self~openapi(session, request))
    when routeKey = "GET /v1/abilities" then outcome = .AbilityRouteOutcome~new(self~abilities(session))
    when routeKey = "GET /v1/resources" then outcome = .AbilityRouteOutcome~new(self~resources(session))
    when routeKey = "GET /v1/rules" then outcome = .AbilityRouteOutcome~new(self~rules(session))
    when routeKey = "POST /v1/queries" then outcome = self~invoke(session, "query", request, "query")
    when routeKey = "POST /v1/evaluations" then outcome = self~invoke(session, "evaluate", request, "evaluation")
    when left(routeKey, 5) = "POST " then do
      if dynamicAbilityId <> "" then do
        if dynamicAbilityId = "query" then outcome = .AbilityRouteOutcome~new(self~notFound)
        else if dynamicAbilityId = "evaluate" then outcome = .AbilityRouteOutcome~new(self~notFound)
        else outcome = self~invoke(session, dynamicAbilityId, request)
      end
      else outcome = .AbilityRouteOutcome~new(self~unknownOrMethod(request~path))
    end
    otherwise outcome = .AbilityRouteOutcome~new(self~unknownOrMethod(request~path))
  end

  signal off syntax
  if \outcome~retainSession then releaseResult = session~release
  return outcome~response

routeSyntax:
  conditionInfo = condition("O")
  signal off syntax
  if session \== .nil then releaseResult = session~release
  detail = "request processing failed"
  if conditionInfo \== .nil then do
    description = conditionInfo~at("MESSAGE")
    if description \== .nil then do
      if description <> "" then detail = description
    end
  end
  return .AbilityHttpResponse~problem(500, "/problems/internal", "Internal server error", detail)

::method unknownOrMethod private
  use arg path
  allowed = self~allowedMethod(path)
  if allowed <> "" then do
    response = .AbilityHttpResponse~problem(405, "/problems/method-not-allowed", "Method not allowed")
    response~headers["allow"] = allowed
    return response
  end
  return .AbilityHttpResponse~problem(404, "/problems/not-found", "Resource not found")

::method allowedMethod private
  use arg path
  if self~abilityIdFromPath(path) <> "" then return "POST"
  if self~materializedPath(path) \== .nil then do
    d = self~materializedPath(path)
    if d~at("type") = "evidence" then return "GET"
    if d~at("sub") = "" then return "GET, DELETE"
    return "GET"
  end
  select
    when path = "/v1/openapi.json" then return "GET"
    when path = "/v1/queries" then return "POST"
    when path = "/v1/evaluations" then return "POST"
    when path = "/v1/abilities" then return "GET"
    when path = "/v1/resources" then return "GET"
    when path = "/v1/rules" then return "GET"
    otherwise return ""
  end

::method abilityIdFromPath private
  use arg path
  prefix = "/v1/abilities/"
  if left(path, prefix~length) \= prefix then return ""
  abilityId = substr(path, prefix~length + 1)~strip~lower
  if abilityId = "" then return ""
  if abilityId~pos("/") > 0 then return ""
  if abilityId~pos("%") > 0 then return ""
  allowed = "abcdefghijklmnopqrstuvwxyz0123456789._-"
  if verify(abilityId, allowed) \= 0 then return ""
  return abilityId

::method materializedPath private
  use arg path
  if path~pos("%") > 0 then return .nil
  evidencePrefix = "/v1/evidence/"
  if left(path, evidencePrefix~length) = evidencePrefix then do
    id = substr(path, evidencePrefix~length + 1)
    if id = "" then return .nil
    if id~pos("/") > 0 then return .nil
    d = .directory~new; d["type"] = "evidence"; d["id"] = id; d["sub"] = ""
    return d
  end
  queryPrefix = "/v1/queries/"
  if left(path, queryPrefix~length) = queryPrefix then return self~parseMaterializedTail("query", substr(path, queryPrefix~length + 1))
  evaluationPrefix = "/v1/evaluations/"
  if left(path, evaluationPrefix~length) = evaluationPrefix then return self~parseMaterializedTail("evaluation", substr(path, evaluationPrefix~length + 1))
  return .nil

::method parseMaterializedTail private
  use arg kind, tail
  if tail = "" then return .nil
  slash = pos("/", tail)
  if slash = 0 then do
    id = tail; sub = ""
  end
  else do
    id = left(tail, slash - 1)
    sub = substr(tail, slash + 1)
    if sub~pos("/") > 0 then return .nil
  end
  if id = "" then return .nil
  if kind = "query" then do
    if sub <> "" then do
      if sub <> "rows" then return .nil
    end
  end
  else do
    if sub <> "" then do
      if sub <> "evidence" then return .nil
    end
  end
  d = .directory~new; d["type"] = kind; d["id"] = id; d["sub"] = sub
  return d

::method routeStored private
  expose resultStore
  use arg credential, request, stored
  clientId = credential~clientId
  kind = stored~at("type")
  id = stored~at("id")
  sub = stored~at("sub")

  if kind = "evidence" then do
    if request~method <> "GET" then return self~storedMethodProblem("GET")
    if request~query <> "" then return .AbilityHttpResponse~problem(400, "/problems/query-parameters", "Query parameters are not accepted")
    lookup = resultStore~getEvidence(clientId, id)
    if \lookup~ok then return self~notFound
    return .AbilityHttpResponse~json(200, lookup~value~detail)
  end

  if sub = "" then do
    if request~query <> "" then return .AbilityHttpResponse~problem(400, "/problems/query-parameters", "Query parameters are not accepted")
    if request~method = "GET" then do
      lookup = resultStore~getResult(clientId, id, kind)
      if \lookup~ok then return self~notFound
      return .AbilityHttpResponse~json(200, lookup~value~descriptor)
    end
    if request~method = "DELETE" then do
      removed = resultStore~deleteResult(clientId, id)
      if \removed~ok then return self~notFound
      d = .directory~new; d["id"] = id; d["released"] = .JSONBoolean~true
      return .AbilityHttpResponse~json(200, d)
    end
    return self~storedMethodProblem("GET, DELETE")
  end

  if request~method <> "GET" then return self~storedMethodProblem("GET")
  if kind = "query" then do
    pageParameters = self~parsePageQuery(request~query)
    if \pageParameters~ok then return .AbilityHttpResponse~problem(400, "/problems/paging", "Invalid paging parameters", pageParameters~detail)
    p = pageParameters~value
    pageResult = resultStore~page(clientId, id, p~at("offset"), p~at("limit"))
    if \pageResult~ok then do
      if pageResult~code = "RESULT_NOT_FOUND" then return self~notFound
      if pageResult~code = "RESULT_EXPIRED" then return self~notFound
      return .AbilityHttpResponse~problem(400, "/problems/paging", "Invalid paging parameters", pageResult~code)
    end
    return .AbilityHttpResponse~json(200, pageResult~value)
  end

  if request~query <> "" then return .AbilityHttpResponse~problem(400, "/problems/query-parameters", "Query parameters are not accepted")
  evidenceResult = resultStore~evidenceForResult(clientId, id, "evaluation")
  if \evidenceResult~ok then return self~notFound
  d = .directory~new; d["id"] = id; d["evidence"] = evidenceResult~value
  return .AbilityHttpResponse~json(200, d)

::method storedMethodProblem private
  use arg allow
  response = .AbilityHttpResponse~problem(405, "/problems/method-not-allowed", "Method not allowed")
  response~headers["allow"] = allow
  return response

::method notFound private
  return .AbilityHttpResponse~problem(404, "/problems/not-found", "Resource not found")

::method parsePageQuery private
  use arg query
  offset = 0; limit = 50
  seenCursor = .false; seenLimit = .false
  if query <> "" then do
    pairs = self~splitQuery(query)
    do i = 1 to pairs~items
      pair = pairs~at(i)
      eq = pos("=", pair)
      if eq <= 1 then return .RuntimeResult~failure("PAGING_INVALID", pair)
      if pos("=", pair, eq + 1) > 0 then return .RuntimeResult~failure("PAGING_INVALID", pair)
      name = left(pair, eq - 1)~lower
      value = substr(pair, eq + 1)
      if name~pos("%") > 0 then return .RuntimeResult~failure("PAGING_INVALID", name)
      if value~pos("%") > 0 then return .RuntimeResult~failure("PAGING_INVALID", value)
      select
        when name = "cursor" then do
          if seenCursor then return .RuntimeResult~failure("PAGING_DUPLICATE", name)
          seenCursor = .true
          if left(value, 2) <> "c." then return .RuntimeResult~failure("CURSOR_INVALID", value)
          rest = substr(value, 3)
          if rest = "" then return .RuntimeResult~failure("CURSOR_INVALID", value)
          if \datatype(rest, "W") then return .RuntimeResult~failure("CURSOR_INVALID", value)
          offset = rest
        end
        when name = "limit" then do
          if seenLimit then return .RuntimeResult~failure("PAGING_DUPLICATE", name)
          seenLimit = .true
          if value = "" then return .RuntimeResult~failure("LIMIT_INVALID", value)
          if \datatype(value, "W") then return .RuntimeResult~failure("LIMIT_INVALID", value)
          limit = value
          if limit < 1 then return .RuntimeResult~failure("LIMIT_INVALID", value)
          if limit > 200 then return .RuntimeResult~failure("LIMIT_INVALID", value)
        end
        otherwise return .RuntimeResult~failure("PAGING_UNKNOWN", name)
      end
    end
  end
  d = .directory~new; d["offset"] = offset; d["limit"] = limit
  return .RuntimeResult~success(d)

::method splitQuery private
  use arg text
  parts = .array~new
  start = 1
  do forever
    p = pos("&", text, start)
    if p = 0 then do
      parts~append(substr(text, start)); leave
    end
    parts~append(substr(text, start, p - start))
    start = p + 1
  end
  return parts

::method health private
  object = .directory~new
  object["status"] = "ok"
  object["service"] = "ability-http"
  object["version"] = .AbilityHttpBuild~RELEASE
  return .AbilityHttpResponse~json(200, object)

::method openapi private
  use arg session, request
  etag = .AbilityOpenApiDescription~etagForSession(session)
  ifNoneMatch = request~header("if-none-match")
  if ifNoneMatch \== .nil then do
    if ifNoneMatch = etag then do
      headers = .directory~new
      headers["etag"] = etag
      headers["cache-control"] = "private, no-cache"
      headers["vary"] = "Authorization"
      return .AbilityHttpResponse~new(304, .AbilityHttpResponse~reasonFor(304), "", headers)
    end
  end
  response = .AbilityHttpResponse~json(200, .AbilityOpenApiDescription~forSession(session))
  response~headers["etag"] = etag
  response~headers["cache-control"] = "private, no-cache"
  response~headers["vary"] = "Authorization"
  return response

::method abilities private
  expose wluBridge
  use arg session
  profile = session~profile
  object = self~sessionEnvelope(session)
  items = .array~new
  ids = profile~abilityIds
  do i = 1 to ids~items
    descriptor = profile~ability(ids~at(i))
    item = .directory~new
    item["id"] = descriptor~abilityId
    item["kind"] = descriptor~kind
    item["read_only"] = self~jsonBoolean(descriptor~readOnly)
    item["description"] = descriptor~description
    aliases = descriptor~requiredAliases
    item["required_aliases"] = aliases
    if aliases~items > 0 then item["handler_alias"] = aliases~at(1)
    else item["handler_alias"] = ""
    if descriptor~abilityId = "query" then do
      item["invoke_uri"] = "/v1/queries"
      item["result_mode"] = "materialized-query"
    end
    else if descriptor~abilityId = "evaluate" then do
      item["invoke_uri"] = "/v1/evaluations"
      item["result_mode"] = "materialized-evaluation"
    end
    else do
      item["invoke_uri"] = "/v1/abilities/" || descriptor~abilityId
      item["result_mode"] = "inline"
    end
    item["http_method"] = "POST"
    item["input_schema"] = descriptor~inputSchema~document
    item["output_schema"] = descriptor~outputSchema~document
    managed = .false
    if wluBridge \== .nil then managed = wluBridge~managed(descriptor~abilityId)
    item["wlu_admission"] = self~jsonBoolean(managed)
    if managed then do
      if wluBridge~hasMethod("APIVERSION") then item["wlu_api_version"] = wluBridge~apiVersion
    end
    items~append(item)
  end
  object["abilities"] = items
  return .AbilityHttpResponse~json(200, object)

::method resources private
  use arg session
  profile = session~profile
  object = self~sessionEnvelope(session)
  items = .array~new
  names = profile~dataBindingNames
  do i = 1 to names~items
    binding = profile~dataBinding(names~at(i))
    item = .directory~new
    item["name"] = binding~logicalName
    item["resource"] = binding~resourceName
    item["access"] = binding~accessMode
    item["runtime_alias"] = binding~runtimeAlias
    item["runtime_generation"] = session~runtimeGenerationId(binding~runtimeAlias)
    item["runtime_artifact"] = session~runtimeArtifactId(binding~runtimeAlias)
    items~append(item)
  end
  object["resources"] = items
  return .AbilityHttpResponse~json(200, object)

::method rules private
  use arg session
  profile = session~profile
  object = self~sessionEnvelope(session)
  items = .array~new
  names = profile~ruleBindingNames
  do i = 1 to names~items
    binding = profile~ruleBinding(names~at(i))
    item = .directory~new
    item["name"] = binding~logicalName
    item["rule_set"] = binding~ruleSetName
    item["runtime_alias"] = binding~runtimeAlias
    item["runtime_generation"] = session~runtimeGenerationId(binding~runtimeAlias)
    item["runtime_artifact"] = session~runtimeArtifactId(binding~runtimeAlias)
    items~append(item)
  end
  object["rules"] = items
  return .AbilityHttpResponse~json(200, object)

::method invoke private
  expose resultStore wluBridge
  use arg session, abilityId, request, materializedKind = ""
  descriptor = session~ability(abilityId)
  if descriptor == .nil then return .AbilityRouteOutcome~new(.AbilityHttpResponse~problem(403, "/problems/ability-not-granted", "Ability not granted", abilityId))
  contentType = request~header("content-type")
  if contentType == .nil then return .AbilityRouteOutcome~new(.AbilityHttpResponse~problem(415, "/problems/content-type", "Content-Type application/json required"))
  mediaType = contentType
  semicolon = pos(";", mediaType)
  if semicolon > 0 then mediaType = left(mediaType, semicolon - 1)
  if mediaType~strip~lower <> "application/json" then return .AbilityRouteOutcome~new(.AbilityHttpResponse~problem(415, "/problems/content-type", "Content-Type application/json required"))

  bodyResult = self~parseJson(request~body)
  if \bodyResult~ok then return .AbilityRouteOutcome~new(.AbilityHttpResponse~problem(400, "/problems/json", "Invalid JSON request body", bodyResult~detail))
  bodyObject = bodyResult~value
  if \bodyObject~isa(.Directory) then return .AbilityRouteOutcome~new(.AbilityHttpResponse~problem(422, "/problems/json-object", "JSON request body must be an object"))

  schemaCheck = descriptor~validateInput(bodyObject)
  if \schemaCheck~ok then return .AbilityRouteOutcome~new(.AbilityHttpResponse~problem(422, "/problems/ability-input-schema", "Request does not conform to ability input schema", schemaCheck~code || ": " || schemaCheck~detail))

  /* Resolve handler before reserving WLU. Configuration faults must not hold
   * account/capacity state. */
  context = .AbilityInvocationContext~new(session, descriptor, bodyObject)
  handlerAlias = context~handlerAlias
  if handlerAlias = "" then return .AbilityRouteOutcome~new(.AbilityHttpResponse~problem(500, "/problems/ability-handler", "Ability has no handler alias", abilityId))
  handler = context~module(handlerAlias)
  if handler == .nil then return .AbilityRouteOutcome~new(.AbilityHttpResponse~problem(500, "/problems/ability-handler", "Ability handler is unavailable", handlerAlias))
  if \handler~hasMethod("runtimeInvokeAbility") then return .AbilityRouteOutcome~new(.AbilityHttpResponse~problem(501, "/problems/ability-handler", "Ability handler does not implement runtimeInvokeAbility", handlerAlias))

  wluInvocation = .nil
  if wluBridge \== .nil then do
    admission = wluBridge~begin(session, descriptor, bodyObject, "")
    if \admission~ok then return .AbilityRouteOutcome~new(self~wluProblem(admission))
    wluInvocation = admission~value
  end
  context = .AbilityInvocationContext~new(session, descriptor, bodyObject, wluInvocation)

  signal on syntax name abilityInvokeSyntax
  invocation = handler~runtimeInvokeAbility(abilityId, context)
  signal off syntax

  finishOutcome = self~finishWlu(wluInvocation)
  if \finishOutcome~ok then return .AbilityRouteOutcome~new(.AbilityHttpResponse~problem(500, "/problems/wlu-settlement", "Work Load Unit settlement failed", finishOutcome~code || ": " || finishOutcome~detail))
  executionMetadata = self~wluMetadata(finishOutcome~value)

  if invocation~isa(.RuntimeResult) then do
    if \invocation~ok then do
      extras = .nil
      if executionMetadata \== .nil then do
        extras = .directory~new
        extras["execution"] = executionMetadata
      end
      return .AbilityRouteOutcome~new(.AbilityHttpResponse~problem(422, "/problems/ability-invocation", "Ability invocation rejected", invocation~code || ": " || invocation~detail, extras))
    end
    value = invocation~value
  end
  else value = invocation

  if \descriptor~outputSchema~isAny then do
    outputCheck = self~validateOutputSchema(descriptor, value)
    if \outputCheck~ok then do
      extras = .nil
      if executionMetadata \== .nil then do
        extras = .directory~new
        extras["execution"] = executionMetadata
      end
      return .AbilityRouteOutcome~new(.AbilityHttpResponse~problem(500, "/problems/ability-output-schema", "Ability output violated its declared schema", outputCheck~code || ": " || outputCheck~detail, extras))
    end
  end

  if materializedKind <> "" then do
    created = resultStore~create(materializedKind, session, abilityId, value, .nil, executionMetadata)
    if \created~ok then do
      extras = .nil
      if executionMetadata \== .nil then do
        extras = .directory~new
        extras["execution"] = executionMetadata
      end
      return .AbilityRouteOutcome~new(.AbilityHttpResponse~problem(503, "/problems/result-store", "Unable to materialise result", created~code || ": " || created~detail, extras))
    end
    item = created~value
    response = .AbilityHttpResponse~json(201, item~descriptor)
    if materializedKind = "query" then response~headers["location"] = "/v1/queries/" || item~resultId
    else response~headers["location"] = "/v1/evaluations/" || item~resultId
    return .AbilityRouteOutcome~new(response, .true)
  end

  object = self~sessionEnvelope(session)
  object["ability"] = abilityId
  object["result"] = value
  if executionMetadata \== .nil then object["execution"] = executionMetadata
  return .AbilityRouteOutcome~new(.AbilityHttpResponse~json(200, object))

abilityInvokeSyntax:
  info = condition("O")
  signal off syntax
  finishOutcome = self~finishWlu(wluInvocation)
  detail = "ability invocation raised a condition"
  if info \== .nil then do
    message = info~at("MESSAGE")
    if message \== .nil then do
      if message <> "" then detail = message
    end
  end
  extras = .nil
  if \finishOutcome~ok then detail = detail || "; WLU=" || finishOutcome~code || ":" || finishOutcome~detail
  else do
    executionMetadata = self~wluMetadata(finishOutcome~value)
    if executionMetadata \== .nil then do
      extras = .directory~new
      extras["execution"] = executionMetadata
    end
  end
  return .AbilityRouteOutcome~new(.AbilityHttpResponse~problem(500, "/problems/ability-handler", "Ability invocation failed", detail, extras))

::method finishWlu private
  expose wluBridge
  use arg wluInvocation
  if wluInvocation == .nil then return .RuntimeResult~success(.nil)
  if wluBridge == .nil then return .RuntimeResult~failure("ABILITY_WLU_BRIDGE_MISSING", "")
  return wluBridge~finish(wluInvocation)

::method wluMetadata private
  use arg evidence
  if evidence == .nil then return .nil
  d = .directory~new
  if evidence~hasMethod("ASDIRECTORY") then d["wlu"] = evidence~asDirectory
  else d["wlu"] = evidence
  return d

::method wluProblem private
  use arg failure
  code = failure~code~string
  status = 503
  if code = "WLU_ENTITLEMENT_EXHAUSTED" then status = 429
  else if code = "WLU_CAPACITY_EXHAUSTED" then status = 429
  else if code = "WLU_THROUGHPUT_EXHAUSTED" then status = 429
  extras = .directory~new
  extras["wlu_code"] = code
  retryAfter = .nil
  if failure~hasMethod("RETRYAFTERSECONDS") then retryAfter = failure~retryAfterSeconds
  if retryAfter \== .nil then extras["retry_after_seconds"] = retryAfter
  response = .AbilityHttpResponse~problem(status, "/problems/wlu-admission", "Work Load Unit admission denied", failure~detail, extras)
  if retryAfter \== .nil then response~headers["retry-after"] = retryAfter
  return response

::method validateOutputSchema private
  use arg descriptor, value
  signal on syntax name outputProjectionError
  safeValue = .AbilityJson~safe(value)
  wireText = .JSON~toJSON(safeValue)
  projectedValue = .JSON~fromJSON(wireText)
  signal off syntax
  return descriptor~validateOutput(projectedValue)
outputProjectionError:
  info = condition("O")
  signal off syntax
  detail = "output could not be projected as JSON"
  if info \== .nil then do
    message = info~at("MESSAGE")
    if message \== .nil then do
      if message <> "" then detail = message
    end
  end
  return .RuntimeResult~failure("ABILITY_OUTPUT_JSON_INVALID", detail)

::method parseJson private
  use arg text
  signal on syntax name jsonError
  value = .JSON~fromJSON(text)
  signal off syntax
  return .RuntimeResult~success(value)
jsonError:
  info = condition("O")
  signal off syntax
  detail = "JSON parse failed"
  if info \== .nil then do
    description = info~at("MESSAGE")
    if description \== .nil then do
      if description <> "" then detail = description
    end
  end
  return .RuntimeResult~failure("JSON_INVALID", detail)

::method sessionEnvelope private
  use arg session
  object = .directory~new
  object["client_id"] = session~clientId
  object["profile_id"] = session~profileId
  object["profile_revision"] = session~revision
  object["ability_generation"] = session~generationId
  object["environment"] = session~environment
  return object

::method jsonBoolean private
  use arg value
  if value == .true then return .JSONBoolean~true
  return .JSONBoolean~false

::class AbilityHttpServer public
::attribute host get
::attribute port get
::attribute listening get
::attribute stopped get

::method init
  expose router host port listening stopped listenSocket reader backlog
  use arg router, host = "127.0.0.1", port = 0, limits = .nil, backlog = 128
  host = host~string~strip
  port = port~string~strip
  if port = "" then port = 0
  if \datatype(port, "W") then raise syntax 88.900 array("HTTP port must be a whole number")
  listening = .false
  stopped = .false
  listenSocket = .nil
  reader = .AbilityHttpConnectionReader~new(limits)

::method serve unguarded
  expose host port listening stopped listenSocket backlog
  stopped = .false
  listenSocket = .Socket~new
  listenSocket~setOption("SO_REUSEADDR", 1)
  address = .InetAddress~new(host, port)
  if listenSocket~bind(address) < 0 then do
    stopped = .true
    return .RuntimeResult~failure("HTTP_BIND_FAILED", listenSocket~errno)
  end
  bound = listenSocket~getSockName
  if bound \== .nil then port = bound~port
  if listenSocket~listen(backlog) < 0 then do
    listenSocket~close
    stopped = .true
    return .RuntimeResult~failure("HTTP_LISTEN_FAILED", listenSocket~errno)
  end
  listening = .true

  do while \stopped
    client = listenSocket~accept
    if client == .nil then leave
    if stopped then do
      client~close
      leave
    end
    self~start("serveConnection", client)
  end

  listening = .false
  if listenSocket \== .nil then listenSocket~close
  listenSocket = .nil
  stopped = .true
  return .RuntimeResult~success

::method serveConnection unguarded
  expose router reader
  use arg client
  response = .nil
  signal on syntax name connectionSyntax
  readResult = reader~readRequest(client)
  if readResult~ok then response = router~route(readResult~request)
  else response = readResult~response
  wireText = response~wire
  ignored = self~sendAll(client, wireText)
  signal off syntax
  client~close
  return

connectionSyntax:
  info = condition("O")
  signal off syntax
  detail = "connection processing failed"
  if info \== .nil then do
    description = info~at("MESSAGE")
    if description \== .nil then do
      if description <> "" then detail = description
    end
  end
  response = .AbilityHttpResponse~problem(500, "/problems/internal", "Internal server error", detail)
  wireText = response~wire
  ignored = self~sendAll(client, wireText)
  client~close
  return

::method sendAll private
  use arg socket, data
  offset = 1
  do while offset <= data~length
    sent = socket~send(substr(data, offset))
    if sent == .nil then return .false
    if sent <= 0 then return .false
    offset = offset + sent
  end
  return .true

::method stop
  expose host port stopped listenSocket
  stopped = .true
  if listenSocket \== .nil then do
    wake = .Socket~new
    address = .InetAddress~new(host, port)
    connectResult = wake~connect(address)
    wake~close
  end
  return .RuntimeResult~success

::requires "AbilityApiDescription.cls"
::requires "AbilityResultStore.cls"
::requires "AbilityRegistry.cls"
::requires "json.cls"
::requires "socket.cls"
