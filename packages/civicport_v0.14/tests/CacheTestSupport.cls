::class CivicTestSequenceTransport public
::attribute name get

::method init
  expose responses requests nextIndex name
  responses = .array~new
  requests = .array~new
  nextIndex = 1
  name = "TEST_SEQUENCE"

::method addHttp
  expose responses name
  use arg status, reason, rawHeaders, bodyBytes
  parsed = .CivicHeaderParser~parse(rawHeaders)
  responses~append(.CivicTransportResponse~success(status, reason, parsed~headerMap, rawHeaders, bodyBytes, name))
  return self

::method addFailure
  expose responses name
  use arg code, message
  responses~append(.CivicTransportResponse~failure(code, message, name))
  return self

::method execute
  expose responses requests nextIndex name
  use arg request
  requests~append(request)
  if nextIndex > responses~items then return .CivicTransportResponse~failure("TEST_SEQUENCE_EXHAUSTED", "No scripted response remains", name)
  responseObject = responses[nextIndex]
  nextIndex = nextIndex + 1
  return responseObject

::method requestCount
  expose requests
  return requests~items

::method request
  expose requests
  use arg index
  return requests[index]

::routine civicTestTempDir public
  use arg prefix = "civicport"
  path = SysTempFileName(.File~new(prefix || ".????????", .File~temporaryPath)~string)
  if path = "" then raise syntax 93.900 additional("Cannot allocate test temporary directory")
  if SysMkDir(path) \= 0 then raise syntax 93.900 additional("Cannot create test temporary directory: " || path)
  return path

::routine civicTestRemoveTree public
  use arg path
  commandText = "rm -rf -- " || civicShellQuote(path)
  address system commandText
  return rc = 0

::routine civicShellQuote public
  use arg value
  text = value~string~changestr("'", "'\\''")
  return "'" || text || "'"

::requires "CivicCache.cls"
