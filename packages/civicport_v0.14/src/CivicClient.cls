/* CivicPort v0.3 public client. */

::class CivicClient subclass CivicAlchemyObject public
::attribute transport get
::attribute allowList get
::attribute digestPort get
::attribute jsonDecoder get

::method init
  expose transport allowList digestPort jsonDecoder
  use arg transportArg, allowListArg, digestPortArg = .nil, jsonDecoderArg = .nil
  ignore = self~initCivicAlchemy
  if transportArg == .nil then raise syntax 93.900 additional("CivicClient requires a transport")
  if allowListArg == .nil then raise syntax 93.900 additional("CivicClient requires an explicit allow-list")
  transport = transportArg
  allowList = allowListArg~sealedCopy
  if digestPortArg == .nil then digestPort = .CivicDigestPort~new
  else digestPort = digestPortArg
  if jsonDecoderArg == .nil then jsonDecoder = .CivicJsonDecoder~new
  else jsonDecoder = jsonDecoderArg

::method get
  use arg url, headers = .nil, timeout = 10, idempotencyKey = "", credentialRef = ""
  request = .CivicRequest~new(url, "GET", headers, "", timeout, idempotencyKey, credentialRef)
  return self~execute(request)

::method execute
  expose transport allowList digestPort jsonDecoder
  use arg request
  if request == .nil then return .CivicFetchResult~failure("REQUEST_MISSING", "CivicRequest is required")
  if request~method \= "GET" then return .CivicFetchResult~failure("METHOD_UNSUPPORTED", "CivicPort v0.3 only supports GET")
  if \allowList~permits(request~url) then return .CivicFetchResult~failure("URL_NOT_ALLOWED", "URL does not match an explicit CivicPort host/path template")

  transportResult = transport~execute(request)
  if \transportResult~ok then return .CivicFetchResult~failure(transportResult~errorCode, transportResult~message)

  digest = digestPort~sha512Bytes(transportResult~bodyBytes)
  if digest~left(10) = "HASH_ERROR" then return .CivicFetchResult~failure("BODY_DIGEST_FAILED", digest)

  decodeResult = jsonDecoder~decode(transportResult~headerMap, transportResult~bodyBytes)
  document = .CivicDocument~new(request, transportResult~status, transportResult~reason, -
    transportResult~headerMap, transportResult~bodyBytes, digest, decodeResult~parsed, decodeResult~status, -
    .DateTime~new~utcIsoDate, "MISS", transportResult~rawHeaderBytes, transportResult~transportName)
  return .CivicFetchResult~success(document)

::requires "CivicPolicy.cls"
::requires "CivicHttpPort.cls"
::requires "CivicJson.cls"

::requires "CivicAlchemy.cls"
