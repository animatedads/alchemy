/* CivicPort v0.3 transport + digest ports. */

::class CivicDigestPort subclass CivicAlchemyObject public
::attribute executable get

::method init
  expose executable
  use arg executableArg = "sha512sum"
  ignore = self~initCivicAlchemy
  executable = executableArg~string

::method sha512Bytes
  expose executable
  use arg bytes
  path = SysTempFileName(.File~new("civicport_sha512.????????", .File~temporaryPath)~string)
  s = .Stream~new(path)
  opened = s~open("WRITE REPLACE")
  if \opened~caselessEquals("READY:") then return "HASH_ERROR_OPEN"
  ignore = s~charout(bytes)
  ignore = s~close
  output = .array~new
  errors = .array~new
  commandText = self~quote(executable) || " -- " || self~quote(path)
  address system commandText with output using (output) error using (errors)
  commandRc = rc
  ignore = SysFileDelete(path)
  if commandRc \= 0 | output~items = 0 then return "HASH_ERROR_COMMAND"
  hashLine = output[1]
  parse var hashLine digest .
  if digest~length \= 128 then return "HASH_ERROR_FORMAT"
  return digest~lower

::method quote private
  use arg value
  text = value~string
  text = text~changestr("'", "'\\''")
  return "'" || text || "'"


::class CivicHeaderParseResult subclass CivicAlchemyObject public
::attribute status get
::attribute reason get
::attribute headerMap get
::attribute statusLine get

::method init
  expose status reason headerMap statusLine
  use arg statusArg, reasonArg, headerMapArg, statusLineArg
  ignore = self~initCivicAlchemy
  status = statusArg
  reason = reasonArg
  headerMap = headerMapArg
  statusLine = statusLineArg


::class CivicHeaderParser subclass CivicAlchemyObject public
::method parse class
  use arg raw
  text = raw~changestr('0d0a'x, '0a'x)~changestr('0d'x, '0a'x)
  lines = text~makeArray
  current = .directory~new
  status = 0
  reason = ""
  statusLine = ""
  inBlock = .false
  do line over lines
    if line~left(5)~translate = "HTTP/" then do
      current = .directory~new
      statusLine = line
      parse var line . code rest
      if datatype(code, "W") then status = code
      else status = 0
      reason = rest~strip
      inBlock = .true
      iterate
    end
    if \inBlock then iterate
    if line = "" then do
      inBlock = .false
      iterate
    end
    colon = line~pos(":")
    if colon <= 1 then iterate
    name = line~left(colon - 1)~strip~translate
    value = line~substr(colon + 1)~strip
    vals = current[name]
    if vals == .nil then do
      vals = .array~new
      current[name] = vals
    end
    vals~append(value)
  end
  return .CivicHeaderParseResult~new(status, reason, .CivicHeaderMap~new(current), statusLine)


::class CivicFixture subclass CivicAlchemyObject public
::attribute method get
::attribute url get
::attribute status get
::attribute reason get
::attribute rawHeaderBytes get
::attribute bodyBytes get

::method init
  expose method url status reason rawHeaderBytes bodyBytes
  use arg methodArg, urlArg, statusArg, reasonArg, rawHeadersArg, bodyArg
  ignore = self~initCivicAlchemy
  method = methodArg~string~translate
  url = urlArg~string
  status = statusArg
  reason = reasonArg~string
  rawHeaderBytes = rawHeadersArg
  bodyBytes = bodyArg


::class CivicFixtureTransport subclass CivicAlchemyObject public
::attribute name get

::method init
  expose fixtures name
  fixtures = .directory~new
  name = "FIXTURE"

  ignore = self~initCivicAlchemy
::method add
  expose fixtures
  use arg fixture
  key = fixture~method || " " || fixture~url
  fixtures[key] = fixture
  return fixture

::method execute
  expose fixtures name
  use arg request
  key = request~method || " " || request~url
  fixture = fixtures[key]
  if fixture == .nil then return .CivicTransportResponse~failure("FIXTURE_NOT_FOUND", "No pinned fixture for request", name)
  parsed = .CivicHeaderParser~parse(fixture~rawHeaderBytes)
  status = fixture~status
  reason = fixture~reason
  if parsed~status \= 0 then status = parsed~status
  if parsed~reason \= "" then reason = parsed~reason
  return .CivicTransportResponse~success(status, reason, parsed~headerMap, fixture~rawHeaderBytes, fixture~bodyBytes, name)


::class CivicCurlTransport subclass CivicAlchemyObject public
::attribute name get
::attribute executable get

::method init
  expose name executable credentialProvider
  use arg executableArg = "curl", credentialProviderArg = .nil
  ignore = self~initCivicAlchemy
  executable = executableArg~string
  name = "CURL"
  if credentialProviderArg == .nil then credentialProvider = .nil
  else credentialProvider = credentialProviderArg~sealedCopy

::method execute
  expose name executable credentialProvider
  use arg request
  if request~method \= "GET" then return .CivicTransportResponse~failure("TRANSPORT_METHOD_UNSUPPORTED", "CivicCurlTransport only supports GET", name)
  if \datatype(request~timeout, "W") | request~timeout < 1 | request~timeout > 300 then -
    return .CivicTransportResponse~failure("INVALID_TIMEOUT", "timeout must be an integer from 1 to 300 seconds", name)

  validation = self~validateHeaders(request~headers)
  if validation \= "" then return .CivicTransportResponse~failure("INVALID_HEADER", validation, name)

  credentialPath = ""
  if request~credentialRef \= "" then do
    if credentialProvider == .nil then return .CivicTransportResponse~failure("CREDENTIAL_PROVIDER_MISSING", "CivicRequest names a credential reference but transport has no credential provider", name)
    credentialPath = SysTempFileName(.File~new("civicport_credential.????????", .File~temporaryPath)~string)
    credentialState = credentialProvider~materializeCurlConfig(request, credentialPath)
    if \credentialState~ok then do
      if stream(credentialPath, "c", "query exists") \= "" then ignore = SysFileDelete(credentialPath)
      return .CivicTransportResponse~failure(credentialState~errorCode, credentialState~message, name)
    end
  end

  bodyPath = SysTempFileName(.File~new("civicport_body.????????", .File~temporaryPath)~string)
  headerPath = SysTempFileName(.File~new("civicport_headers.????????", .File~temporaryPath)~string)
  errorPath = SysTempFileName(.File~new("civicport_error.????????", .File~temporaryPath)~string)

  commandText = self~quote(executable) || -
    " --disable --silent --show-error --proto '=https' --max-redirs 0" || -
    " --max-time " || request~timeout || -
    " --request GET" || -
    " --dump-header " || self~quote(headerPath) || -
    " --output " || self~quote(bodyPath)
  if credentialPath \= "" then commandText = commandText || " --config " || self~quote(credentialPath)

  do headerName over request~headers~names
    do headerValue over request~headers~all(headerName)
      commandText = commandText || " --header " || self~quote(headerName || ": " || headerValue)
    end
  end
  commandText = commandText || " " || self~quote(request~url) || " 2>" || self~quote(errorPath)
  address system commandText
  commandRc = rc

  rawHeaders = self~readAll(headerPath)
  body = self~readAll(bodyPath)
  errors = self~readAll(errorPath)
  ignore = self~cleanup(bodyPath, headerPath, errorPath, credentialPath)

  if commandRc \= 0 then do
    message = errors~strip
    if message = "" then message = "curl exited with rc=" || commandRc
    return .CivicTransportResponse~failure("HTTP_TRANSPORT_ERROR", message, name)
  end
  parsed = .CivicHeaderParser~parse(rawHeaders)
  if parsed~status = 0 then return .CivicTransportResponse~failure("HTTP_STATUS_MISSING", "Transport completed without an HTTP status line", name)
  return .CivicTransportResponse~success(parsed~status, parsed~reason, parsed~headerMap, rawHeaders, body, name)

::method validateHeaders private
  use arg headers
  do name over headers~names
    if name = "" then return "Header name is empty"
    upperName = name~translate
    if upperName = "AUTHORIZATION" | upperName = "PROXY-AUTHORIZATION" | upperName = "COOKIE" then -
      return "Credential-bearing header must be injected by the Civic credential provider inside transport, not stored in CivicRequest: " || name
    if upperName = "HOST" | upperName = "CONTENT-LENGTH" | upperName = "TRANSFER-ENCODING" | upperName = "CONNECTION" | upperName = "PROXY-CONNECTION" then -
      return "Routing/framing header is transport-owned: " || name
    do i = 1 to name~length
      ch = name~substr(i, 1)
      if \datatype(ch, "A") & \datatype(ch, "N") & ch \= "-" then return "Unsafe header name: " || name
    end
    do value over headers~all(name)
      if value~pos('0d'x) > 0 | value~pos('0a'x) > 0 | value~pos('00'x) > 0 then return "Header values may not contain CR, LF, or NUL"
    end
  end
  return ""

::method readAll private
  use arg path
  if stream(path, "c", "query exists") = "" then return ""
  s = .Stream~new(path)
  opened = s~open("READ")
  if \opened~caselessEquals("READY:") then return ""
  available = s~chars
  if available > 0 then data = s~charin(1, available)
  else data = ""
  ignore = s~close
  return data

::method cleanup private
  use arg bodyPath, headerPath, errorPath, credentialPath = ""
  if stream(bodyPath, "c", "query exists") \= "" then ignore = SysFileDelete(bodyPath)
  if stream(headerPath, "c", "query exists") \= "" then ignore = SysFileDelete(headerPath)
  if stream(errorPath, "c", "query exists") \= "" then ignore = SysFileDelete(errorPath)
  if credentialPath \= "" then do
    if stream(credentialPath, "c", "query exists") \= "" then ignore = SysFileDelete(credentialPath)
  end
  return .true

::method quote private
  use arg value
  text = value~string
  text = text~changestr("'", "'\\''")
  return "'" || text || "'"

::requires "CivicCore.cls"
::requires "CivicCredential.cls"

::requires "CivicAlchemy.cls"
