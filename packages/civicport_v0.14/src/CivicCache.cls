/*
 * CivicPort v0.7 cache journal and operational access evidence.
 *
 * The journal records HTTP observations.  A 304 is a new CivicDocument whose
 * body is the actual (usually empty) 304 body.  Cache resolution separately
 * links that observation to the earlier body-bearing record it validates.
 * Nothing rewrites the earlier document's fetchedAt, bytes, digest, or headers.
 */

::class CivicCacheKey subclass CivicAlchemyObject public
::method forRequest class
  use arg request
  if request == .nil then raise syntax 93.900 additional("CivicCacheKey requires a CivicRequest")
  parts = .CivicUrlParts~parse(request~url)
  if parts == .nil then raise syntax 93.900 additional("CivicCacheKey requires a valid Civic URL")

  canonicalUrl = parts~scheme || "://" || parts~host
  port = parts~port
  if port \= "" then do
    if \(parts~scheme = "https" & port = "443") & \(parts~scheme = "http" & port = "80") then -
      canonicalUrl = canonicalUrl || ":" || port
  end
  canonicalUrl = canonicalUrl || parts~path
  /*
   * Query ordering and percent-encoding are preserved exactly.  CivicPort is
   * generic and cannot assume that a source treats reordered duplicate query
   * parameters as equivalent.  Canonicalisation here is structural only.
   */
  if parts~query \= "" then canonicalUrl = canonicalUrl || "?" || parts~query
  key = request~method~translate || " " || canonicalUrl
  if request~credentialRef \= "" then key = key || " CRED[" || c2x(request~credentialRef) || "]"
  userAgents = request~headers~all("User-Agent")
  if userAgents~items > 0 then do
    key = key || " UA["
    do i = 1 to userAgents~items
      if i > 1 then key = key || ","
      key = key || c2x(userAgents[i])
    end
    key = key || "]"
  end
  return key


::class CivicJournalRecord subclass CivicAlchemyObject public
::attribute recordId get
::attribute cacheKey get
::attribute bodySourceRecordId get
::attribute document get

::method init
  expose recordId cacheKey bodySourceRecordId document
  use arg recordIdArg, cacheKeyArg, bodySourceArg, documentArg
  ignore = self~initCivicAlchemy
  recordId = recordIdArg~string
  cacheKey = cacheKeyArg~string
  bodySourceRecordId = bodySourceArg~string
  document = documentArg


::class CivicJournal subclass CivicAlchemyObject public
::attribute root get
::attribute journalPath get
::attribute recordsDirectory get

::method init
  expose root journalPath recordsDirectory digestPort jsonDecoder records byId
  use arg rootArg, digestPortArg = .nil, jsonDecoderArg = .nil
  ignore = self~initCivicAlchemy
  root = rootArg~string
  if root = "" then raise syntax 93.900 additional("CivicJournal requires a root directory")
  if digestPortArg == .nil then digestPort = .CivicDigestPort~new
  else digestPort = digestPortArg
  if jsonDecoderArg == .nil then jsonDecoder = .CivicJsonDecoder~new
  else jsonDecoder = jsonDecoderArg
  call SysFileTree root, "rootMatches.", "DO"
  if rootMatches.0 = 0 then do
    mkdirRc = SysMkDir(root)
    if mkdirRc \= 0 then raise syntax 93.900 additional("Cannot create CivicJournal root: " || root)
  end
  recordsDirectory = root || "/records"
  call SysFileTree recordsDirectory, "recordDirMatches.", "DO"
  if recordDirMatches.0 = 0 then do
    mkdirRc = SysMkDir(recordsDirectory)
    if mkdirRc \= 0 then raise syntax 93.900 additional("Cannot create CivicJournal records directory: " || recordsDirectory)
  end
  journalPath = root || "/civic.journal"
  records = .array~new
  byId = .directory~new
  self~loadJournal

::method count
  expose records
  return records~items

::method all
  expose records
  copied = .array~new
  do record over records
    copied~append(record)
  end
  return copied

::method record
  expose byId
  use arg recordId
  return byId[recordId~string]

::method append
  expose records byId digestPort recordsDirectory journalPath
  use arg cacheKey, document, bodySourceRecordId = ""
  if document == .nil then raise syntax 93.900 additional("CivicJournal append requires a CivicDocument")
  recordId = self~allocateRecordId
  if bodySourceRecordId~string \= "" & \byId~hasIndex(bodySourceRecordId~string) then -
    raise syntax 93.900 additional("CivicJournal body source is not an earlier record: " || bodySourceRecordId)

  bodyPath = recordsDirectory || "/" || recordId || ".body"
  headerPath = recordsDirectory || "/" || recordId || ".headers"
  requestHeaderPath = recordsDirectory || "/" || recordId || ".request_headers"
  metaPath = recordsDirectory || "/" || recordId || ".meta"
  if stream(bodyPath, "c", "query exists") \= "" | stream(metaPath, "c", "query exists") \= "" then -
    raise syntax 93.900 additional("CivicJournal refuses to overwrite record files: " || recordId)

  requestHeaderBytes = self~encodeRequestHeaders(document~request~headers)
  headerDigest = digestPort~sha512Bytes(document~rawHeaderBytes)
  requestHeaderDigest = digestPort~sha512Bytes(requestHeaderBytes)
  if headerDigest~left(10) = "HASH_ERROR" | requestHeaderDigest~left(10) = "HASH_ERROR" then -
    raise syntax 93.900 additional("CivicJournal could not digest record metadata bytes")

  fields = .array~of(cacheKey~string, bodySourceRecordId~string, document~request~url, document~request~method, -
    document~request~issuedAt, document~request~timeout~string, document~request~idempotencyKey, document~status~string, -
    document~reason, document~bodyDigest, document~parseStatus, document~fetchedAt, document~cacheState, -
    document~transportName, headerDigest, requestHeaderDigest, document~request~credentialRef)
  metaBytes = self~encodeMeta(fields)
  metaDigest = digestPort~sha512Bytes(metaBytes)
  if metaDigest~left(10) = "HASH_ERROR" then raise syntax 93.900 additional("CivicJournal could not digest metadata")

  self~writeAtomic(bodyPath, document~bodyBytes)
  self~writeAtomic(headerPath, document~rawHeaderBytes)
  self~writeAtomic(requestHeaderPath, requestHeaderBytes)
  self~writeAtomic(metaPath, metaBytes)
  self~appendJournalLine(recordId || "|" || metaDigest)

  recordObject = .CivicJournalRecord~new(recordId, cacheKey, bodySourceRecordId, document)
  records~append(recordObject)
  byId[recordId] = recordObject
  return recordObject

::method allocateRecordId private
  expose records byId recordsDirectory
  candidateNumber = records~items + 1
  do forever
    candidate = "CIVICDOC" || ("000000000000" || candidateNumber)~right(12)
    bodyPath = recordsDirectory || "/" || candidate || ".body"
    headerPath = recordsDirectory || "/" || candidate || ".headers"
    requestHeaderPath = recordsDirectory || "/" || candidate || ".request_headers"
    metaPath = recordsDirectory || "/" || candidate || ".meta"
    if \byId~hasIndex(candidate) & stream(bodyPath, "c", "query exists") = "" & -
       stream(headerPath, "c", "query exists") = "" & stream(requestHeaderPath, "c", "query exists") = "" & -
       stream(metaPath, "c", "query exists") = "" then return candidate
    candidateNumber = candidateNumber + 1
  end

::method loadJournal private
  expose journalPath records byId
  if stream(journalPath, "c", "query exists") = "" then return .true
  tailProbe = .Stream~new(journalPath)
  tailStatus = tailProbe~open("READ")
  if \tailStatus~caselessEquals("READY:") then raise syntax 93.900 additional("Cannot inspect CivicJournal index: " || journalPath)
  journalBytes = tailProbe~chars
  if journalBytes > 0 then do
    terminalByte = tailProbe~charIn(journalBytes, 1)
    if terminalByte \= '0a'x then do
      ignore = tailProbe~close
      raise syntax 93.900 additional("CivicJournal has an unterminated/torn index tail")
    end
  end
  ignore = tailProbe~close
  journalStream = .Stream~new(journalPath)
  openStatus = journalStream~open("READ")
  if \openStatus~caselessEquals("READY:") then raise syntax 93.900 additional("Cannot open CivicJournal index: " || journalPath)
  lineNumber = 0
  do while journalStream~lines > 0
    line = journalStream~lineIn
    lineNumber = lineNumber + 1
    if line = "" then do
      ignore = journalStream~close
      raise syntax 93.900 additional("CivicJournal contains an empty/torn index record at line " || lineNumber)
    end
    bar = line~pos("|")
    if bar <= 1 | line~pos("|", bar + 1) > 0 then do
      ignore = journalStream~close
      raise syntax 93.900 additional("CivicJournal index record malformed at line " || lineNumber)
    end
    recordId = line~left(bar - 1)
    expectedMetaDigest = line~substr(bar + 1)
    if byId~hasIndex(recordId) then do
      ignore = journalStream~close
      raise syntax 93.900 additional("CivicJournal duplicate record id: " || recordId)
    end
    recordObject = self~loadRecord(recordId, expectedMetaDigest)
    sourceId = recordObject~bodySourceRecordId
    if sourceId \= "" & \byId~hasIndex(sourceId) then do
      ignore = journalStream~close
      raise syntax 93.900 additional("CivicJournal record references a non-earlier body source: " || sourceId)
    end
    records~append(recordObject)
    byId[recordId] = recordObject
  end
  ignore = journalStream~close
  return .true

::method loadRecord private
  expose recordsDirectory digestPort jsonDecoder
  use arg recordId, expectedMetaDigest
  bodyPath = recordsDirectory || "/" || recordId || ".body"
  headerPath = recordsDirectory || "/" || recordId || ".headers"
  requestHeaderPath = recordsDirectory || "/" || recordId || ".request_headers"
  metaPath = recordsDirectory || "/" || recordId || ".meta"
  if stream(bodyPath, "c", "query exists") = "" | stream(headerPath, "c", "query exists") = "" | -
     stream(requestHeaderPath, "c", "query exists") = "" | stream(metaPath, "c", "query exists") = "" then -
    raise syntax 93.900 additional("CivicJournal record files missing: " || recordId)

  metaBytes = self~readAll(metaPath)
  actualMetaDigest = digestPort~sha512Bytes(metaBytes)
  if actualMetaDigest \== expectedMetaDigest then raise syntax 93.900 additional("CivicJournal metadata digest mismatch: " || recordId)
  fields = self~decodeMeta(metaBytes)
  if fields~items < 16 | fields~items > 17 then raise syntax 93.900 additional("CivicJournal metadata field count invalid: " || recordId)

  cacheKey = fields[1]
  bodySourceRecordId = fields[2]
  requestUrl = fields[3]
  requestMethod = fields[4]
  issuedAt = fields[5]
  timeout = fields[6]
  idempotencyKey = fields[7]
  status = fields[8]
  reason = fields[9]
  bodyDigest = fields[10]
  parseStatus = fields[11]
  fetchedAt = fields[12]
  cacheState = fields[13]
  transportName = fields[14]
  expectedHeaderDigest = fields[15]
  expectedRequestHeaderDigest = fields[16]
  if fields~items >= 17 then credentialRef = fields[17]
  else credentialRef = ""

  bodyBytes = self~readAll(bodyPath)
  rawHeaderBytes = self~readAll(headerPath)
  requestHeaderBytes = self~readAll(requestHeaderPath)
  if digestPort~sha512Bytes(bodyBytes) \== bodyDigest then raise syntax 93.900 additional("CivicJournal body digest mismatch: " || recordId)
  if digestPort~sha512Bytes(rawHeaderBytes) \== expectedHeaderDigest then raise syntax 93.900 additional("CivicJournal response-header digest mismatch: " || recordId)
  if digestPort~sha512Bytes(requestHeaderBytes) \== expectedRequestHeaderDigest then raise syntax 93.900 additional("CivicJournal request-header digest mismatch: " || recordId)

  requestHeaders = self~decodeRequestHeaders(requestHeaderBytes)
  request = .CivicRequest~new(requestUrl, requestMethod, requestHeaders, issuedAt, timeout, idempotencyKey, credentialRef)
  parsedHeaders = .CivicHeaderParser~parse(rawHeaderBytes)
  decodeState = jsonDecoder~decode(parsedHeaders~headerMap, bodyBytes)
  if decodeState~status \== parseStatus then -
    raise syntax 93.900 additional("CivicJournal parser disposition changed for stored bytes: " || recordId || " stored=" || parseStatus || " current=" || decodeState~status)
  document = .CivicDocument~new(request, status, reason, parsedHeaders~headerMap, bodyBytes, bodyDigest, -
    decodeState~parsed, parseStatus, fetchedAt, cacheState, rawHeaderBytes, transportName)
  return .CivicJournalRecord~new(recordId, cacheKey, bodySourceRecordId, document)

::method encodeMeta private
  use arg fields
  text = "CIVICPORT-JOURNAL-RECORD-2"
  do field over fields
    text = text || "|" || c2x(field~string)
  end
  return text

::method decodeMeta private
  use arg bytes
  pieces = self~split(bytes, "|")
  if pieces~items < 1 then raise syntax 93.900 additional("CivicJournal metadata version is unsupported")
  if pieces[1] \= "CIVICPORT-JOURNAL-RECORD-1" & pieces[1] \= "CIVICPORT-JOURNAL-RECORD-2" then -
    raise syntax 93.900 additional("CivicJournal metadata version is unsupported")
  fields = .array~new
  do i = 2 to pieces~items
    hex = pieces[i]
    if hex \= "" & \datatype(hex, "X") then raise syntax 93.900 additional("CivicJournal metadata contains invalid hex")
    fields~append(x2c(hex))
  end
  return fields

::method encodeRequestHeaders private
  use arg headerMap
  text = "CIVICPORT-REQUEST-HEADERS-1" || '0a'x
  do name over headerMap~names
    do value over headerMap~all(name)
      text = text || c2x(name) || "|" || c2x(value) || '0a'x
    end
  end
  return text

::method decodeRequestHeaders private
  use arg bytes
  normalized = bytes~changestr('0d0a'x, '0a'x)~changestr('0d'x, '0a'x)
  lines = normalized~makeArray
  if lines~items = 0 | lines[1] \= "CIVICPORT-REQUEST-HEADERS-1" then -
    raise syntax 93.900 additional("CivicJournal request-header format is unsupported")
  directory = .directory~new
  do i = 2 to lines~items
    line = lines[i]
    if line = "" then iterate
    bar = line~pos("|")
    if bar <= 0 | line~pos("|", bar + 1) > 0 then raise syntax 93.900 additional("CivicJournal request-header record malformed")
    nameHex = line~left(bar - 1)
    valueHex = line~substr(bar + 1)
    if (nameHex \= "" & \datatype(nameHex, "X")) | (valueHex \= "" & \datatype(valueHex, "X")) then -
      raise syntax 93.900 additional("CivicJournal request-header record contains invalid hex")
    name = x2c(nameHex)
    value = x2c(valueHex)
    values = directory[name]
    if values == .nil then do
      values = .array~new
      directory[name] = values
    end
    values~append(value)
  end
  return .CivicHeaderMap~new(directory)

::method split private
  use arg text, separator
  pieces = .array~new
  start = 1
  do forever
    at = text~pos(separator, start)
    if at = 0 then do
      pieces~append(text~substr(start))
      leave
    end
    pieces~append(text~substr(start, at - start))
    start = at + separator~length
  end
  return pieces

::method writeAtomic private
  use arg finalPath, bytes
  tempPath = SysTempFileName(finalPath || ".tmp.????????")
  if tempPath = "" then raise syntax 93.900 additional("CivicJournal could not allocate temporary path")
  fileStream = .Stream~new(tempPath)
  openStatus = fileStream~open("WRITE REPLACE")
  if \openStatus~caselessEquals("READY:") then raise syntax 93.900 additional("CivicJournal cannot open temporary file: " || tempPath)
  if bytes~length > 0 then written = fileStream~charOut(bytes)
  ignore = fileStream~close
  moveRc = SysFileMove(tempPath, finalPath)
  if moveRc \= 0 then do
    ignore = SysFileDelete(tempPath)
    raise syntax 93.900 additional("CivicJournal cannot publish file: " || finalPath)
  end
  return .true

::method appendJournalLine private
  expose journalPath
  if stream(journalPath, "c", "query exists") \= "" then do
    inspect = .Stream~new(journalPath)
    openStatus = inspect~open("READ")
    if \openStatus~caselessEquals("READY:") then raise syntax 93.900 additional("Cannot inspect CivicJournal before append")
    byteCount = inspect~chars
    if byteCount > 0 then do
      lastByte = inspect~charIn(byteCount, 1)
      if lastByte \= '0a'x then do
        ignore = inspect~close
        raise syntax 93.900 additional("CivicJournal has an unterminated/torn tail; refusing append")
      end
    end
    ignore = inspect~close
  end
  out = .Stream~new(journalPath)
  openStatus = out~open("WRITE APPEND")
  if \openStatus~caselessEquals("READY:") then raise syntax 93.900 additional("Cannot append CivicJournal index")
  ignore = out~lineOut(arg(1))
  ignore = out~close
  return .true

::method readAll private
  use arg path
  s = .Stream~new(path)
  opened = s~open("READ")
  if \opened~caselessEquals("READY:") then raise syntax 93.900 additional("Cannot read CivicJournal record file: " || path)
  available = s~chars
  if available > 0 then data = s~charIn(1, available)
  else data = ""
  ignore = s~close
  return data


::class CivicCacheEntry subclass CivicAlchemyObject public
::attribute key get
::attribute bodyRecordId get
::attribute validationRecordId get
::attribute etag get
::attribute lastModified get

::method init
  expose key bodyRecordId validationRecordId etag lastModified
  use arg keyArg
  ignore = self~initCivicAlchemy
  key = keyArg~string
  bodyRecordId = ""
  validationRecordId = ""
  etag = .nil
  lastModified = .nil

::method acceptBody
  expose bodyRecordId validationRecordId etag lastModified
  use arg record
  bodyRecordId = record~recordId
  validationRecordId = record~recordId
  doc = record~document
  etag = doc~header("ETag")
  lastModified = doc~header("Last-Modified")
  return self

::method acceptRevalidation
  expose validationRecordId etag lastModified
  use arg record
  validationRecordId = record~recordId
  doc = record~document
  newEtag = doc~header("ETag")
  newLastModified = doc~header("Last-Modified")
  if newEtag \== .nil then etag = newEtag
  if newLastModified \== .nil then lastModified = newLastModified
  return self


::class CivicCacheFetchResult subclass CivicAlchemyObject public
::attribute ok get
::attribute document get
::attribute observation get
::attribute cacheState get
::attribute bodyRecordId get
::attribute observationRecordId get
::attribute errorCode get
::attribute message get
::attribute staleReasonCode get
::attribute staleReasonMessage get

::method success class
  use arg document, observation, cacheState, bodyRecordId, observationRecordId, staleCode = "", staleMessage = ""
  return .CivicCacheFetchResult~new(.true, document, observation, cacheState, bodyRecordId, observationRecordId, "", "", staleCode, staleMessage)

::method failure class
  use arg code, message, observation = .nil, observationRecordId = ""
  return .CivicCacheFetchResult~new(.false, .nil, observation, "", "", observationRecordId, code, message, "", "")

::method init
  expose ok document observation cacheState bodyRecordId observationRecordId errorCode message staleReasonCode staleReasonMessage
  use arg okArg, documentArg, observationArg, stateArg, bodyRecordArg, observationRecordArg, codeArg, messageArg, staleCodeArg, staleMessageArg
  ignore = self~initCivicAlchemy
  ok = okArg
  document = documentArg
  observation = observationArg
  cacheState = stateArg~string~translate
  bodyRecordId = bodyRecordArg~string
  observationRecordId = observationRecordArg~string
  errorCode = codeArg~string
  message = messageArg~string
  staleReasonCode = staleCodeArg~string
  staleReasonMessage = staleMessageArg~string

::method accessState
  return .CivicAccessState~fromCacheResult(self)


::class CivicAccessState subclass CivicAlchemyObject public
::attribute state get
::attribute cause get
::attribute cacheState get
::attribute bodyStatus get
::attribute observationStatus get
::attribute retryAfter get
::attribute staleReasonCode get
::attribute staleReasonMessage get
::attribute bodyRecordId get
::attribute observationRecordId get
::attribute hasBody get
::attribute hasObservation get
::attribute identity get

::method fromCacheResult class
  use arg cacheOutcome
  if cacheOutcome == .nil then raise syntax 93.900 additional("CivicAccessState requires a CivicCacheFetchResult")

  accessState = "HEALTHY"
  cause = "NONE"
  bodyStatus = ""
  observationStatus = ""
  retryAfter = ""
  hasBody = cacheOutcome~document \== .nil
  hasObservation = cacheOutcome~observation \== .nil

  if hasBody then bodyStatus = cacheOutcome~document~status~string
  if hasObservation then do
    observationStatus = cacheOutcome~observation~status~string
    retryHeader = cacheOutcome~observation~header("Retry-After")
    if retryHeader \== .nil then retryAfter = retryHeader~string
  end

  if \cacheOutcome~ok then do
    code = cacheOutcome~errorCode~string~translate
    if code = "URL_NOT_ALLOWED" | code = "CACHE_REQUEST_HEADERS_UNSUPPORTED" | code~startsWith("CREDENTIAL_") | code = "INVALID_HEADER" then do
      accessState = "BLOCKED"
      cause = "LOCAL_POLICY"
    end
    else if code = "CACHE_BODY_SOURCE_MISSING" | code = "CACHE_304_WITHOUT_ENTITY" then do
      accessState = "UNAVAILABLE"
      cause = "CACHE_INTEGRITY"
    end
    else do
      accessState = "UNAVAILABLE"
      cause = "TRANSPORT_FAILURE"
    end
  end
  else if cacheOutcome~staleReasonCode \= "" then do
    accessState = "DEGRADED"
    if cacheOutcome~staleReasonCode~caselessEquals("HTTP_429") then cause = "RATE_LIMIT"
    else if cacheOutcome~staleReasonCode~string~translate~startsWith("CREDENTIAL_") then cause = "LOCAL_POLICY"
    else cause = "TRANSPORT_FAILURE"
  end
  else if observationStatus = "429" then do
    accessState = "DEGRADED"
    cause = "RATE_LIMIT"
  end
  else if observationStatus \= "" then do
    if datatype(observationStatus, "W") & observationStatus >= 500 & observationStatus <= 599 then do
      accessState = "DEGRADED"
      cause = "HTTP_SERVER_ERROR"
    end
  end

  return .CivicAccessState~new(accessState, cause, cacheOutcome~cacheState, bodyStatus, observationStatus, retryAfter, -
    cacheOutcome~staleReasonCode, cacheOutcome~staleReasonMessage, cacheOutcome~bodyRecordId, cacheOutcome~observationRecordId, hasBody, hasObservation)

::method init
  expose state cause cacheState bodyStatus observationStatus retryAfter staleReasonCode staleReasonMessage bodyRecordId observationRecordId hasBody hasObservation identity
  use arg stateArg, causeArg, cacheStateArg, bodyStatusArg, observationStatusArg, retryAfterArg, staleCodeArg, staleMessageArg, bodyRecordArg, observationRecordArg, hasBodyArg, hasObservationArg
  ignore = self~initCivicAlchemy
  state = stateArg~string~translate
  cause = causeArg~string~translate
  cacheState = cacheStateArg~string~translate
  bodyStatus = bodyStatusArg~string
  observationStatus = observationStatusArg~string
  retryAfter = retryAfterArg~string
  staleReasonCode = staleCodeArg~string
  staleReasonMessage = staleMessageArg~string
  bodyRecordId = bodyRecordArg~string
  observationRecordId = observationRecordArg~string
  hasBody = hasBodyArg
  hasObservation = hasObservationArg
  identity = "CIVICACCESS-V1:" || self~identityField(state) || self~identityField(cause) || self~identityField(cacheState) || -
    self~identityField(bodyStatus) || self~identityField(observationStatus) || self~identityField(retryAfter) || -
    self~identityField(staleReasonCode) || self~identityField(staleReasonMessage) || self~identityField(bodyRecordId) || self~identityField(observationRecordId)

::method identityField private
  use arg value
  text = value~string
  return text~length || ":" || text || ":"

::method rateLimited
  expose cause
  return cause = "RATE_LIMIT"

::method servedStale
  expose cacheState
  return cacheState = "STALE"

::method algorithmCanonicalText
  text = "CIVIC_ACCESS_STATE_V1" || '0a'x
  text = text || self~fieldText("STATE", self~state)
  text = text || self~fieldText("CAUSE", self~cause)
  text = text || self~fieldText("CACHE_STATE", self~cacheState)
  text = text || self~fieldText("BODY_STATUS", self~bodyStatus)
  text = text || self~fieldText("OBSERVATION_STATUS", self~observationStatus)
  text = text || self~fieldText("RETRY_AFTER", self~retryAfter)
  text = text || self~fieldText("STALE_REASON_CODE", self~staleReasonCode)
  text = text || self~fieldText("STALE_REASON_MESSAGE", self~staleReasonMessage)
  text = text || self~fieldText("BODY_RECORD_ID", self~bodyRecordId)
  text = text || self~fieldText("OBSERVATION_RECORD_ID", self~observationRecordId)
  return text

::method fieldText private
  use arg name, value
  rendered = value~string
  return name || "=" || rendered~length || ":" || rendered || '0a'x


::class CivicCache subclass CivicAlchemyObject public
::attribute client get
::attribute journal get

::method init
  expose client journal entries
  use arg clientArg, journalArg
  ignore = self~initCivicAlchemy
  if clientArg == .nil then raise syntax 93.900 additional("CivicCache requires a CivicClient")
  if journalArg == .nil then raise syntax 93.900 additional("CivicCache requires a CivicJournal")
  client = clientArg
  journal = journalArg
  entries = .directory~new
  self~rebuildIndex

::method entry
  expose entries
  use arg cacheKey
  return entries[cacheKey~string]

::method get
  expose client journal entries
  use arg url, headers = .nil, timeout = 10, idempotencyKey = "", allowStale = .false, credentialRef = ""
  suppliedHeaders = .CivicHeaderMap~new(headers)
  do headerName over suppliedHeaders~names
    if headerName \= "USER-AGENT" then -
      return .CivicCacheFetchResult~failure("CACHE_REQUEST_HEADERS_UNSUPPORTED", "Cached GET supports only cache-keyed User-Agent caller metadata; validators remain cache-owned")
    values = suppliedHeaders~all(headerName)
    if values~items \= 1 | values[1]~strip = "" then -
      return .CivicCacheFetchResult~failure("CACHE_REQUEST_HEADERS_UNSUPPORTED", "Cached User-Agent must contain exactly one non-empty value")
  end
  if \client~allowList~permits(url) then -
    return .CivicCacheFetchResult~failure("URL_NOT_ALLOWED", "URL does not match an explicit CivicPort host/path template")

  probeRequest = .CivicRequest~new(url, "GET", suppliedHeaders, "", timeout, idempotencyKey, credentialRef)
  key = .CivicCacheKey~forRequest(probeRequest)
  entry = entries[key]

  if entry == .nil then return self~fetchMiss(url, suppliedHeaders, timeout, idempotencyKey, key, credentialRef)

  conditional = suppliedHeaders~asDirectory
  if entry~etag \== .nil then conditional["If-None-Match"] = entry~etag
  if entry~lastModified \== .nil then conditional["If-Modified-Since"] = entry~lastModified
  fetch = client~get(url, conditional, timeout, idempotencyKey, credentialRef)
  if \fetch~ok then do
    if allowStale & self~staleEligibleFailure(fetch~errorCode) then do
      bodyRecord = journal~record(entry~bodyRecordId)
      if bodyRecord \== .nil then -
        return .CivicCacheFetchResult~success(bodyRecord~document, .nil, "STALE", entry~bodyRecordId, "", fetch~errorCode, fetch~message)
    end
    return .CivicCacheFetchResult~failure(fetch~errorCode, fetch~message)
  end

  networkDocument = fetch~document
  if networkDocument~status = 304 then do
    observation = networkDocument~withCacheState("REVALIDATED")
    observationRecord = journal~append(key, observation, entry~bodyRecordId)
    ignore = entry~acceptRevalidation(observationRecord)
    bodyRecord = journal~record(entry~bodyRecordId)
    if bodyRecord == .nil then -
      return .CivicCacheFetchResult~failure("CACHE_BODY_SOURCE_MISSING", "304 linked body record is unavailable", observation, observationRecord~recordId)
    return .CivicCacheFetchResult~success(bodyRecord~document, observation, "REVALIDATED", entry~bodyRecordId, observationRecord~recordId)
  end

  if networkDocument~status = 429 & allowStale then do
    rateObservation = networkDocument~withCacheState("STALE")
    rateRecord = journal~append(key, rateObservation, "")
    bodyRecord = journal~record(entry~bodyRecordId)
    if bodyRecord == .nil then -
      return .CivicCacheFetchResult~failure("CACHE_BODY_SOURCE_MISSING", "Stale body record is unavailable", rateObservation, rateRecord~recordId)
    return .CivicCacheFetchResult~success(bodyRecord~document, rateObservation, "STALE", entry~bodyRecordId, rateRecord~recordId, "HTTP_429", networkDocument~reason)
  end

  if networkDocument~status = 200 then do
    freshDocument = networkDocument~withCacheState("FRESH")
    freshRecord = journal~append(key, freshDocument, "")
    ignore = entry~acceptBody(freshRecord)
    return .CivicCacheFetchResult~success(freshDocument, freshDocument, "FRESH", freshRecord~recordId, freshRecord~recordId)
  end

  observation = networkDocument~withCacheState("MISS")
  observationRecord = journal~append(key, observation, "")
  return .CivicCacheFetchResult~success(observation, observation, "MISS", observationRecord~recordId, observationRecord~recordId)

::method staleEligibleFailure private
  use arg errorCode
  code = errorCode~string~translate
  if code~startsWith("CREDENTIAL_") then return .false
  if code = "INVALID_HEADER" | code = "REQUEST_MISSING" | code = "METHOD_UNSUPPORTED" | code = "BODY_DIGEST_FAILED" then return .false
  return .true

::method fetchMiss private
  expose client journal entries
  use arg url, headers, timeout, idempotencyKey, key, credentialRef = ""
  fetch = client~get(url, headers, timeout, idempotencyKey, credentialRef)
  if \fetch~ok then return .CivicCacheFetchResult~failure(fetch~errorCode, fetch~message)
  networkDocument = fetch~document
  if networkDocument~status = 304 then do
    observation = networkDocument~withCacheState("REVALIDATED")
    observationRecord = journal~append(key, observation, "")
    return .CivicCacheFetchResult~failure("CACHE_304_WITHOUT_ENTITY", "Received 304 without a cached body-bearing document", observation, observationRecord~recordId)
  end
  missDocument = networkDocument~withCacheState("MISS")
  missRecord = journal~append(key, missDocument, "")
  if networkDocument~status = 200 then do
    entry = .CivicCacheEntry~new(key)
    ignore = entry~acceptBody(missRecord)
    entries[key] = entry
  end
  return .CivicCacheFetchResult~success(missDocument, missDocument, "MISS", missRecord~recordId, missRecord~recordId)

::method rebuildIndex private
  expose journal entries
  do record over journal~all
    key = record~cacheKey
    doc = record~document
    entry = entries[key]
    if doc~status = 200 then do
      if entry == .nil then do
        entry = .CivicCacheEntry~new(key)
        entries[key] = entry
      end
      ignore = entry~acceptBody(record)
    end
    else if doc~status = 304 & record~bodySourceRecordId \= "" then do
      if entry == .nil then do
        entry = .CivicCacheEntry~new(key)
        entries[key] = entry
        sourceRecord = journal~record(record~bodySourceRecordId)
        if sourceRecord == .nil | sourceRecord~document~status \= 200 then -
          raise syntax 93.900 additional("CivicCache journal 304 does not reference a cached 200 body")
        ignore = entry~acceptBody(sourceRecord)
      end
      if entry~bodyRecordId \= record~bodySourceRecordId then -
        raise syntax 93.900 additional("CivicCache journal 304 references a body that is not current for its cache key")
      ignore = entry~acceptRevalidation(record)
    end
  end
  return .true

::requires "CivicClient.cls"

::requires "CivicAlchemy.cls"
