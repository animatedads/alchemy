/*
 * CivicPort v0.7
 * Native public-data HTTP evidence objects.
 *
 * The boundary is deliberately narrow:
 *   request -> allow-list -> transport -> immutable CivicDocument
 *
 * v0.4 adds a read-only external relation projection for NoSQLServer.
 * v0.5 adds a separate explicit HardWorld evidence/promotion bridge; HTTP evidence
 * never becomes world authority merely by being fetched or mapped.
 */

::class CivicHeaderMap subclass CivicAlchemyObject public
::method init
  expose values
  use arg source = .nil
  ignore = self~initCivicAlchemy
  values = .directory~new
  if source == .nil then return
  if source~isA(.CivicHeaderMap) then do
    names = source~names
    do name over names
      vals = source~all(name)
      copyVals = .array~new
      do value over vals
        copyVals~append(value)
      end
      values[name~string~translate] = copyVals
    end
    return
  end
  do name over source~allIndexes
    key = name~string~translate
    raw = source[name]
    vals = .array~new
    if raw == .nil then nop
    else if raw~isA(.Array) then do value over raw
      vals~append(value~string)
    end
    else vals~append(raw~string)
    values[key] = vals
  end

::method empty class
  return .CivicHeaderMap~new

::method names
  expose values
  nameList = values~allIndexes
  nameList~sort
  return nameList

::method all
  expose values
  use arg name
  raw = values[name~string~translate]
  valueList = .array~new
  if raw == .nil then return valueList
  do value over raw
    valueList~append(value)
  end
  return valueList

::method first
  use arg name
  vals = self~all(name)
  if vals~items = 0 then return .nil
  return vals[1]

::method has
  expose values
  use arg name
  return values~hasIndex(name~string~translate)

::method asDirectory
  expose values
  mapCopy = .directory~new
  do name over values~allIndexes
    vals = .array~new
    do value over values[name]
      vals~append(value)
    end
    mapCopy[name] = vals
  end
  return mapCopy


::class CivicRequest subclass CivicAlchemyObject public
::attribute url get
::attribute method get
::attribute headers get
::attribute issuedAt get
::attribute timeout get
::attribute idempotencyKey get
::attribute credentialRef get

::method init
  expose url method headers issuedAt timeout idempotencyKey credentialRef
  use arg urlArg, methodArg = "GET", headersArg = .nil, issuedAtArg = "", timeoutArg = 10, idempotencyArg = "", credentialRefArg = ""
  ignore = self~initCivicAlchemy
  url = urlArg~string
  method = methodArg~string~translate
  if headersArg == .nil then headers = .CivicHeaderMap~empty
  else headers = .CivicHeaderMap~new(headersArg)
  if issuedAtArg~string = "" then issuedAt = .DateTime~new~utcIsoDate
  else issuedAt = issuedAtArg~string
  timeout = timeoutArg
  idempotencyKey = idempotencyArg~string
  credentialRef = credentialRefArg~string
  if credentialRef \= "" then do
    if credentialRef~length > 128 then raise syntax 93.900 additional("Civic credential reference is too long")
    do i = 1 to credentialRef~length
      ch = credentialRef~substr(i, 1)
      if \datatype(ch, "A") & \datatype(ch, "N") & ch \= "." & ch \= "_" & ch \= "-" & ch \= ":" then -
        raise syntax 93.900 additional("Civic credential reference contains unsupported characters")
    end
  end


::class CivicDocument subclass CivicAlchemyObject public
::attribute request get
::attribute status get
::attribute reason get
::attribute headerMap get
::attribute bodyBytes get
::attribute bodyDigest get
::attribute parseStatus get
::attribute fetchedAt get
::attribute cacheState get
::attribute rawHeaderBytes get
::attribute transportName get

::method init
  expose request status reason headerMap bodyBytes bodyDigest parsedTree parseStatus fetchedAt cacheState rawHeaderBytes transportName
  use arg requestArg, statusArg, reasonArg, headerMapArg, bodyArg, digestArg, parsedArg = .nil, parseStatusArg = "UNSUPPORTED", fetchedAtArg = "", cacheStateArg = "MISS", rawHeadersArg = "", transportArg = ""
  ignore = self~initCivicAlchemy
  request = requestArg
  status = statusArg
  reason = reasonArg~string
  if headerMapArg == .nil then headerMap = .CivicHeaderMap~empty
  else headerMap = .CivicHeaderMap~new(headerMapArg)
  bodyBytes = bodyArg
  bodyDigest = digestArg~string~lower
  parsedTree = self~copyJsonValue(parsedArg)
  parseStatus = parseStatusArg~string~translate
  if fetchedAtArg~string = "" then fetchedAt = .DateTime~new~utcIsoDate
  else fetchedAt = fetchedAtArg~string
  cacheState = cacheStateArg~string~translate
  rawHeaderBytes = rawHeadersArg
  transportName = transportArg~string

::method parsed
  expose parsedTree
  return self~copyJsonValue(parsedTree)

::method withCacheState
  expose request status reason headerMap bodyBytes bodyDigest parsedTree parseStatus fetchedAt rawHeaderBytes transportName
  use arg newState
  return .CivicDocument~new(request, status, reason, headerMap, bodyBytes, bodyDigest, -
    parsedTree, parseStatus, fetchedAt, newState, rawHeaderBytes, transportName)

::method copyJsonValue private
  use arg value
  if value == .nil then return .nil
  if value~isA(.Directory) then do
    copyObject = .directory~new
    do key over value~allIndexes
      copyObject[key] = self~copyJsonValue(value[key])
    end
    return copyObject
  end
  if value~isA(.Array) then do
    copyArray = .array~new
    do item over value
      copyArray~append(self~copyJsonValue(item))
    end
    return copyArray
  end
  return value

::method header
  expose headerMap
  use arg name
  return headerMap~first(name)

::method headers
  expose headerMap
  use arg name
  return headerMap~all(name)

::method isHttpSuccess
  expose status
  return datatype(status, "W") & status >= 200 & status < 300

::method provenance
  expose request status reason bodyDigest parseStatus fetchedAt cacheState transportName
  provenanceMap = .directory~new
  provenanceMap["kind"] = "CIVIC_HTTP_DOCUMENT"
  provenanceMap["url"] = request~url
  provenanceMap["method"] = request~method
  provenanceMap["issuedAt"] = request~issuedAt
  provenanceMap["status"] = status
  provenanceMap["reason"] = reason
  provenanceMap["bodyDigestAlgorithm"] = "SHA-512"
  provenanceMap["bodyDigest"] = bodyDigest
  provenanceMap["parseStatus"] = parseStatus
  provenanceMap["fetchedAt"] = fetchedAt
  provenanceMap["cacheState"] = cacheState
  provenanceMap["transport"] = transportName
  provenanceMap["credentialReference"] = request~credentialRef
  return provenanceMap

::method string
  expose request status bodyDigest fetchedAt cacheState
  use arg conversionOption = ""
  return "CivicDocument(" || request~method || " " || request~url || "," || status || ",sha512=" || bodyDigest || "," || cacheState || "," || fetchedAt || ")"


::class CivicFetchResult subclass CivicAlchemyObject public
::attribute ok get
::attribute document get
::attribute errorCode get
::attribute message get

::method success class
  use arg document
  return .CivicFetchResult~new(.true, document, "", "")

::method failure class
  use arg code, message
  return .CivicFetchResult~new(.false, .nil, code, message)

::method init
  expose ok document errorCode message
  use arg okArg, documentArg, codeArg, messageArg
  ignore = self~initCivicAlchemy
  ok = okArg
  document = documentArg
  errorCode = codeArg~string
  message = messageArg~string


::class CivicTransportResponse subclass CivicAlchemyObject public
::attribute ok get
::attribute status get
::attribute reason get
::attribute headerMap get
::attribute rawHeaderBytes get
::attribute bodyBytes get
::attribute errorCode get
::attribute message get
::attribute transportName get

::method success class
  use arg status, reason, headerMap, rawHeaders, bodyBytes, transportName
  return .CivicTransportResponse~new(.true, status, reason, headerMap, rawHeaders, bodyBytes, "", "", transportName)

::method failure class
  use arg code, message, transportName = ""
  return .CivicTransportResponse~new(.false, 0, "", .CivicHeaderMap~empty, "", "", code, message, transportName)

::method init
  expose ok status reason headerMap rawHeaderBytes bodyBytes errorCode message transportName
  use arg okArg, statusArg, reasonArg, headersArg, rawHeadersArg, bodyArg, codeArg, messageArg, transportArg
  ignore = self~initCivicAlchemy
  ok = okArg
  status = statusArg
  reason = reasonArg~string
  if headersArg == .nil then headerMap = .CivicHeaderMap~empty
  else headerMap = .CivicHeaderMap~new(headersArg)
  rawHeaderBytes = rawHeadersArg
  bodyBytes = bodyArg
  errorCode = codeArg~string
  message = messageArg~string
  transportName = transportArg~string


::class CivicCapabilities subclass CivicAlchemyObject public
::method v01 class
  capabilities = .array~new
  capabilities~append("CIVIC_HTTP")
  return capabilities

::method v02 class
  capabilities = self~v01
  capabilities~append("CIVIC_JSON")
  return capabilities

::method v03 class
  capabilities = self~v02
  capabilities~append("CIVIC_ETAG_CACHE")
  return capabilities

::method v04 class
  capabilities = self~v03
  capabilities~append("CIVIC_READONLY_RELATION")
  return capabilities

::method v05 class
  capabilities = self~v04
  capabilities~append("CIVIC_PROMOTION")
  return capabilities

::method v06 class
  /* v0.6 adopted the AlchemyObject house base without inventing a civic capability. */
  return self~v05

::method v07 class
  capabilities = self~v06
  capabilities~append("CIVIC_ACCESS_STATE")
  return capabilities

::method v08 class
  capabilities = self~v07
  capabilities~append("CIVIC_API_CONTRACT")
  return capabilities

::method v09 class
  capabilities = self~v08
  capabilities~append("CIVIC_CREDENTIAL_PORT")
  capabilities~append("CIVIC_COMPANY_PROFILE")
  return capabilities

::method v10 class
  capabilities = self~v09
  capabilities~append("CIVIC_JSON_COLLECTION")
  capabilities~append("CIVIC_METAR_OBSERVATION")
  return capabilities

::method v11 class
  capabilities = self~v10
  capabilities~append("CIVIC_SOURCE_CATALOG")
  capabilities~append("CIVIC_GENERATION_NEGOTIATION")
  return capabilities

::method v12 class
  capabilities = self~v11
  capabilities~append("CIVIC_QUEUE_EVIDENCE")
  capabilities~append("CIVIC_SWIM_XML")
  return capabilities

::method v13 class
  capabilities = self~v12
  capabilities~append("CIVIC_NOTAM_RUNWAY_CLOSURE")
  return capabilities

::method v14 class
  capabilities = self~v13
  capabilities~append("CIVIC_NOTAM_READONLY_RELATION")
  capabilities~append("CIVIC_NOTAM_API_CONTRACT")
  return capabilities

::requires "CivicAlchemy.cls"
