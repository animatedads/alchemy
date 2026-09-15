/*
 * CivicQueueEvidence.cls - CivicPort v0.12 durable message evidence.
 *
 * Queue Fabric is transport.  CivicPort acknowledges a claimed work package
 * only after the Java-free message has been durably journalled here.  The
 * persisted body is the exact ooRexx String delivered by the JMS bridge's
 * TextMessage boundary; it is not represented as the broker's wire bytes.
 */

::class CivicQueueMapCodec subclass CivicAlchemyObject public
::method encode class
  use arg source = .nil
  text = "CIVICPORT-QUEUE-MAP-1" || '0a'x
  if source == .nil then return text
  names = source~allIndexes
  names~sort
  do name over names
    value = source[name]
    if value == .nil then value = ""
    text = text || c2x(name~string) || "|" || c2x(value~string) || '0a'x
  end
  return text

::method decode class
  use arg bytes
  normalized = bytes~changestr('0d0a'x, '0a'x)~changestr('0d'x, '0a'x)
  lines = normalized~makeArray
  if lines~items = 0 | lines[1] \= "CIVICPORT-QUEUE-MAP-1" then -
    raise syntax 93.900 additional("Civic queue map format is unsupported")
  decoded = .directory~new
  do i = 2 to lines~items
    line = lines[i]
    if line = "" then iterate
    bar = line~pos("|")
    if bar <= 0 | line~pos("|", bar + 1) > 0 then -
      raise syntax 93.900 additional("Civic queue map record malformed")
    nameHex = line~left(bar - 1)
    valueHex = line~substr(bar + 1)
    if (nameHex \= "" & \datatype(nameHex, "X")) | (valueHex \= "" & \datatype(valueHex, "X")) then -
      raise syntax 93.900 additional("Civic queue map record contains invalid hex")
    decoded[x2c(nameHex)] = x2c(valueHex)
  end
  return decoded

::method copy class
  use arg source = .nil
  copied = .directory~new
  if source == .nil then return copied
  do name over source~allIndexes
    value = source[name]
    if value == .nil then copied[name~string] = ""
    else copied[name~string] = value~string
  end
  return copied


::class CivicQueueDocument subclass CivicAlchemyObject public
::attribute sourceIdentity get
::attribute evidenceIdentity get
::attribute localQueue get
::attribute packageId get
::attribute messageId get
::attribute provider get
::attribute source get
::attribute bodyType get
::attribute bodyText get
::attribute bodyDigest get
::attribute headerDigest get
::attribute propertyDigest get
::attribute messageReceivedAt get
::attribute acceptedAt get
::attribute queueCreatedAt get
::attribute correlationId get
::attribute replyTo get
::attribute priority get
::attribute useClassification get

::method init
  expose sourceIdentity evidenceIdentity localQueue packageId messageId provider source bodyType bodyText bodyDigest headerDigest propertyDigest messageReceivedAt acceptedAt queueCreatedAt correlationId replyTo priority useClassification storedHeaders storedProperties
  use arg sourceIdentityArg, localQueueArg, packageIdArg, messageIdArg, providerArg, sourceArg, bodyTypeArg, bodyTextArg, bodyDigestArg, headersArg = .nil, propertiesArg = .nil, headerDigestArg = "", propertyDigestArg = "", messageReceivedAtArg = "", acceptedAtArg = "", queueCreatedAtArg = "", correlationIdArg = "", replyToArg = "", priorityArg = 0, useClassificationArg = ""
  ignore = self~initCivicAlchemy
  sourceIdentity = sourceIdentityArg~string
  if sourceIdentity = "" then raise syntax 93.900 additional("CivicQueueDocument requires a source identity")
  localQueue = localQueueArg~string
  packageId = packageIdArg~string
  messageId = messageIdArg~string
  provider = providerArg~string
  source = sourceArg~string
  bodyType = bodyTypeArg~string~translate
  bodyText = bodyTextArg
  bodyDigest = bodyDigestArg~string~lower
  storedHeaders = .CivicQueueMapCodec~copy(headersArg)
  storedProperties = .CivicQueueMapCodec~copy(propertiesArg)
  headerDigest = headerDigestArg~string~lower
  propertyDigest = propertyDigestArg~string~lower
  if messageReceivedAtArg~string = "" then messageReceivedAt = .DateTime~new~utcIsoDate
  else messageReceivedAt = messageReceivedAtArg~string
  if acceptedAtArg~string = "" then acceptedAt = .DateTime~new~utcIsoDate
  else acceptedAt = acceptedAtArg~string
  queueCreatedAt = queueCreatedAtArg~string
  correlationId = correlationIdArg~string
  replyTo = replyToArg~string
  priority = priorityArg
  useClassification = useClassificationArg~string~translate
  evidenceIdentity = "CIVICQUEUE-V1:" || c2x(sourceIdentity) || ":" || bodyDigest || ":" || headerDigest || ":" || propertyDigest

::method headers
  expose storedHeaders
  return .CivicQueueMapCodec~copy(storedHeaders)

::method properties
  expose storedProperties
  return .CivicQueueMapCodec~copy(storedProperties)

::method header
  expose storedHeaders
  use arg name
  return storedHeaders[name~string~translate]

::method property
  expose storedProperties
  use arg name
  return storedProperties[name~string]

::method provenance
  d = .directory~new
  d["kind"] = "CIVIC_QUEUE_DOCUMENT"
  d["transport"] = "ALCHEMY_QUEUE"
  d["sourceIdentity"] = self~sourceIdentity
  d["evidenceIdentity"] = self~evidenceIdentity
  d["localQueue"] = self~localQueue
  d["packageId"] = self~packageId
  d["messageId"] = self~messageId
  d["provider"] = self~provider
  d["source"] = self~source
  d["bodyType"] = self~bodyType
  d["storedBodyDigestAlgorithm"] = "SHA-512"
  d["storedBodyDigest"] = self~bodyDigest
  d["messageReceivedAt"] = self~messageReceivedAt
  d["acceptedAt"] = self~acceptedAt
  d["useClassification"] = self~useClassification
  return d

::method string
  return "CivicQueueDocument(" || self~localQueue || "," || self~messageId || ",sha512=" || self~bodyDigest || ")"


::class CivicQueueJournalRecord subclass CivicAlchemyObject public
::attribute recordId get
::attribute document get

::method init
  expose recordId document
  use arg recordIdArg, documentArg
  ignore = self~initCivicAlchemy
  recordId = recordIdArg~string
  document = documentArg


::class CivicQueueJournalAppendResult subclass CivicAlchemyObject public
::attribute ok get
::attribute record get
::attribute duplicate get
::attribute errorCode get
::attribute message get

::method success class
  use arg record, duplicate = .false
  return self~new(.true, record, duplicate, "", "")

::method failure class
  use arg code, message = ""
  return self~new(.false, .nil, .false, code, message)

::method init
  expose ok record duplicate errorCode message
  use arg okArg, recordArg, duplicateArg, codeArg, messageArg
  ignore = self~initCivicAlchemy
  ok = okArg
  record = recordArg
  duplicate = duplicateArg
  errorCode = codeArg~string
  message = messageArg~string


::class CivicQueueJournal subclass CivicAlchemyObject public
::attribute root get
::attribute recordsDirectory get
::attribute journalPath get

::method init
  expose root recordsDirectory journalPath digestPort records byId bySource
  use arg rootArg, digestPortArg = .nil
  ignore = self~initCivicAlchemy
  root = rootArg~string
  if root = "" then raise syntax 93.900 additional("CivicQueueJournal requires a root directory")
  if digestPortArg == .nil then digestPort = .CivicDigestPort~new
  else digestPort = digestPortArg
  call SysFileTree root, "rootMatches.", "DO"
  if rootMatches.0 = 0 then do
    mkdirRc = SysMkDir(root)
    if mkdirRc \= 0 then raise syntax 93.900 additional("Cannot create CivicQueueJournal root: " || root)
  end
  recordsDirectory = root || "/records"
  call SysFileTree recordsDirectory, "recordDirMatches.", "DO"
  if recordDirMatches.0 = 0 then do
    mkdirRc = SysMkDir(recordsDirectory)
    if mkdirRc \= 0 then raise syntax 93.900 additional("Cannot create CivicQueueJournal records directory: " || recordsDirectory)
  end
  journalPath = root || "/civic.queue.journal"
  records = .array~new
  byId = .directory~new
  bySource = .directory~new
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

::method recordForSource
  expose bySource
  use arg sourceIdentity
  return bySource[sourceIdentity~string]

::method append
  expose records byId bySource recordsDirectory journalPath digestPort
  use arg document
  if document == .nil then return .CivicQueueJournalAppendResult~failure("DOCUMENT_REQUIRED")
  existing = bySource[document~sourceIdentity]
  if existing \== .nil then do
    if existing~document~evidenceIdentity = document~evidenceIdentity then -
      return .CivicQueueJournalAppendResult~success(existing, .true)
    return .CivicQueueJournalAppendResult~failure("SOURCE_IDENTITY_CONFLICT", document~sourceIdentity)
  end

  recordId = self~allocateRecordId
  bodyPath = recordsDirectory || "/" || recordId || ".body"
  headerPath = recordsDirectory || "/" || recordId || ".headers"
  propertyPath = recordsDirectory || "/" || recordId || ".properties"
  metaPath = recordsDirectory || "/" || recordId || ".meta"
  if stream(bodyPath, "c", "query exists") \= "" | stream(metaPath, "c", "query exists") \= "" then -
    raise syntax 93.900 additional("CivicQueueJournal refuses to overwrite record files: " || recordId)

  headerBytes = .CivicQueueMapCodec~encode(document~headers)
  propertyBytes = .CivicQueueMapCodec~encode(document~properties)
  if digestPort~sha512Bytes(document~bodyText) \== document~bodyDigest then -
    return .CivicQueueJournalAppendResult~failure("BODY_DIGEST_MISMATCH", document~sourceIdentity)
  if digestPort~sha512Bytes(headerBytes) \== document~headerDigest then -
    return .CivicQueueJournalAppendResult~failure("HEADER_DIGEST_MISMATCH", document~sourceIdentity)
  if digestPort~sha512Bytes(propertyBytes) \== document~propertyDigest then -
    return .CivicQueueJournalAppendResult~failure("PROPERTY_DIGEST_MISMATCH", document~sourceIdentity)

  fields = .array~of(document~sourceIdentity, document~evidenceIdentity, document~localQueue, document~packageId, -
    document~messageId, document~provider, document~source, document~bodyType, document~bodyDigest, document~headerDigest, -
    document~propertyDigest, document~messageReceivedAt, document~acceptedAt, document~queueCreatedAt, document~correlationId, -
    document~replyTo, document~priority~string, document~useClassification)
  metaBytes = self~encodeMeta(fields)
  metaDigest = digestPort~sha512Bytes(metaBytes)
  if metaDigest~left(10) = "HASH_ERROR" then raise syntax 93.900 additional("CivicQueueJournal could not digest metadata")

  self~writeAtomic(bodyPath, document~bodyText)
  self~writeAtomic(headerPath, headerBytes)
  self~writeAtomic(propertyPath, propertyBytes)
  self~writeAtomic(metaPath, metaBytes)
  self~appendJournalLine(recordId || "|" || metaDigest)

  recordObject = .CivicQueueJournalRecord~new(recordId, document)
  records~append(recordObject)
  byId[recordId] = recordObject
  bySource[document~sourceIdentity] = recordObject
  return .CivicQueueJournalAppendResult~success(recordObject, .false)

::method allocateRecordId private
  expose records byId recordsDirectory
  candidateNumber = records~items + 1
  do forever
    candidate = "CIVICMSG" || ("000000000000" || candidateNumber)~right(12)
    if \byId~hasIndex(candidate) & -
       stream(recordsDirectory || "/" || candidate || ".body", "c", "query exists") = "" & -
       stream(recordsDirectory || "/" || candidate || ".meta", "c", "query exists") = "" then return candidate
    candidateNumber += 1
  end

::method loadJournal private
  expose journalPath records byId bySource
  if stream(journalPath, "c", "query exists") = "" then return .true
  inspect = .Stream~new(journalPath)
  opened = inspect~open("READ")
  if \opened~caselessEquals("READY:") then raise syntax 93.900 additional("Cannot inspect CivicQueueJournal index")
  byteCount = inspect~chars
  if byteCount > 0 then do
    lastByte = inspect~charIn(byteCount, 1)
    if lastByte \= '0a'x then do
      ignore = inspect~close
      raise syntax 93.900 additional("CivicQueueJournal has an unterminated/torn index tail")
    end
  end
  ignore = inspect~close

  input = .Stream~new(journalPath)
  opened = input~open("READ")
  if \opened~caselessEquals("READY:") then raise syntax 93.900 additional("Cannot open CivicQueueJournal index")
  lineNumber = 0
  do while input~lines > 0
    line = input~lineIn
    lineNumber += 1
    if line = "" then do
      ignore = input~close
      raise syntax 93.900 additional("CivicQueueJournal contains empty index record at line " || lineNumber)
    end
    bar = line~pos("|")
    if bar <= 1 | line~pos("|", bar + 1) > 0 then do
      ignore = input~close
      raise syntax 93.900 additional("CivicQueueJournal index record malformed at line " || lineNumber)
    end
    recordId = line~left(bar - 1)
    expectedMetaDigest = line~substr(bar + 1)
    if byId~hasIndex(recordId) then do
      ignore = input~close
      raise syntax 93.900 additional("CivicQueueJournal duplicate record id: " || recordId)
    end
    recordObject = self~loadRecord(recordId, expectedMetaDigest)
    if bySource~hasIndex(recordObject~document~sourceIdentity) then do
      ignore = input~close
      raise syntax 93.900 additional("CivicQueueJournal duplicate source identity: " || recordObject~document~sourceIdentity)
    end
    records~append(recordObject)
    byId[recordId] = recordObject
    bySource[recordObject~document~sourceIdentity] = recordObject
  end
  ignore = input~close
  return .true

::method loadRecord private
  expose recordsDirectory digestPort
  use arg recordId, expectedMetaDigest
  bodyPath = recordsDirectory || "/" || recordId || ".body"
  headerPath = recordsDirectory || "/" || recordId || ".headers"
  propertyPath = recordsDirectory || "/" || recordId || ".properties"
  metaPath = recordsDirectory || "/" || recordId || ".meta"
  if stream(bodyPath, "c", "query exists") = "" | stream(headerPath, "c", "query exists") = "" | -
     stream(propertyPath, "c", "query exists") = "" | stream(metaPath, "c", "query exists") = "" then -
    raise syntax 93.900 additional("CivicQueueJournal record files are incomplete: " || recordId)

  bodyText = self~readAll(bodyPath)
  headerBytes = self~readAll(headerPath)
  propertyBytes = self~readAll(propertyPath)
  metaBytes = self~readAll(metaPath)
  if digestPort~sha512Bytes(metaBytes) \== expectedMetaDigest then -
    raise syntax 93.900 additional("CivicQueueJournal metadata digest mismatch: " || recordId)
  fields = self~decodeMeta(metaBytes)
  if fields~items \= 18 then raise syntax 93.900 additional("CivicQueueJournal metadata field count unsupported: " || recordId)

  sourceIdentity = fields[1]
  evidenceIdentity = fields[2]
  localQueue = fields[3]
  packageId = fields[4]
  messageId = fields[5]
  provider = fields[6]
  source = fields[7]
  bodyType = fields[8]
  bodyDigest = fields[9]
  headerDigest = fields[10]
  propertyDigest = fields[11]
  messageReceivedAt = fields[12]
  acceptedAt = fields[13]
  queueCreatedAt = fields[14]
  correlationId = fields[15]
  replyTo = fields[16]
  priority = fields[17]
  useClassification = fields[18]

  if digestPort~sha512Bytes(bodyText) \== bodyDigest then raise syntax 93.900 additional("CivicQueueJournal body digest mismatch: " || recordId)
  if digestPort~sha512Bytes(headerBytes) \== headerDigest then raise syntax 93.900 additional("CivicQueueJournal header digest mismatch: " || recordId)
  if digestPort~sha512Bytes(propertyBytes) \== propertyDigest then raise syntax 93.900 additional("CivicQueueJournal property digest mismatch: " || recordId)
  headers = .CivicQueueMapCodec~decode(headerBytes)
  properties = .CivicQueueMapCodec~decode(propertyBytes)
  document = .CivicQueueDocument~new(sourceIdentity, localQueue, packageId, messageId, provider, source, bodyType, bodyText, bodyDigest, -
    headers, properties, headerDigest, propertyDigest, messageReceivedAt, acceptedAt, queueCreatedAt, correlationId, replyTo, priority, useClassification)
  if document~evidenceIdentity \== evidenceIdentity then raise syntax 93.900 additional("CivicQueueJournal evidence identity mismatch: " || recordId)
  return .CivicQueueJournalRecord~new(recordId, document)

::method encodeMeta private
  use arg fields
  text = "CIVICPORT-QUEUE-JOURNAL-RECORD-1"
  do field over fields
    text = text || "|" || c2x(field~string)
  end
  return text

::method decodeMeta private
  use arg bytes
  pieces = self~split(bytes, "|")
  if pieces~items < 1 | pieces[1] \= "CIVICPORT-QUEUE-JOURNAL-RECORD-1" then -
    raise syntax 93.900 additional("CivicQueueJournal metadata version is unsupported")
  fields = .array~new
  do i = 2 to pieces~items
    hex = pieces[i]
    if hex \= "" & \datatype(hex, "X") then raise syntax 93.900 additional("CivicQueueJournal metadata contains invalid hex")
    fields~append(x2c(hex))
  end
  return fields

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
  if tempPath = "" then raise syntax 93.900 additional("CivicQueueJournal could not allocate temporary path")
  output = .Stream~new(tempPath)
  opened = output~open("WRITE REPLACE")
  if \opened~caselessEquals("READY:") then raise syntax 93.900 additional("CivicQueueJournal cannot open temporary file: " || tempPath)
  if bytes~length > 0 then written = output~charOut(bytes)
  ignore = output~close
  moveRc = SysFileMove(tempPath, finalPath)
  if moveRc \= 0 then do
    ignore = SysFileDelete(tempPath)
    raise syntax 93.900 additional("CivicQueueJournal cannot publish file: " || finalPath)
  end
  return .true

::method appendJournalLine private
  expose journalPath
  if stream(journalPath, "c", "query exists") \= "" then do
    inspect = .Stream~new(journalPath)
    opened = inspect~open("READ")
    if \opened~caselessEquals("READY:") then raise syntax 93.900 additional("Cannot inspect CivicQueueJournal before append")
    byteCount = inspect~chars
    if byteCount > 0 then do
      lastByte = inspect~charIn(byteCount, 1)
      if lastByte \= '0a'x then do
        ignore = inspect~close
        raise syntax 93.900 additional("CivicQueueJournal has an unterminated/torn tail; refusing append")
      end
    end
    ignore = inspect~close
  end
  output = .Stream~new(journalPath)
  opened = output~open("WRITE APPEND")
  if \opened~caselessEquals("READY:") then raise syntax 93.900 additional("Cannot append CivicQueueJournal index")
  ignore = output~lineOut(arg(1))
  ignore = output~close
  return .true

::method readAll private
  use arg path
  input = .Stream~new(path)
  opened = input~open("READ")
  if \opened~caselessEquals("READY:") then raise syntax 93.900 additional("Cannot read CivicQueueJournal record file: " || path)
  available = input~chars
  if available > 0 then data = input~charIn(1, available)
  else data = ""
  ignore = input~close
  return data

::requires "CivicHttpPort.cls"
