/* ooRexx LLM Personal Assistant v0.1-dev9-candidate1
 * Async PA request/reply contract plus durable operator memory.
 * Queue payloads are detached data only and carry no execution authority.
 */

::class LlmPaBuild public
::constant VERSION "0.1-dev9-candidate1"
::constant API "llm.pa/0.1"

::class LlmPaStatus public
::constant QUEUED "QUEUED"
::constant PROCESSING "PROCESSING"
::constant REPLIED "REPLIED"
::constant FAILED "FAILED"

::class LlmPaKinds public
::constant MEMORY "MEMORY"
::constant REMINDER "REMINDER"
::constant REMINDER_SCHEDULED "REMINDER_SCHEDULED"
::constant CALENDAR "CALENDAR"
::constant KNOWLEDGE "KNOWLEDGE"
::constant GOPHER "GOPHER"
::constant CHAT "CHAT"
::constant ERROR "ERROR"

::class LlmPaUtil public
::method requestId class
  return "pa-" || date("S") || "-" || time("L")~changestr(":", "")~changestr(".", "") || "-" || random(100000, 999999)

::method timestamp class
  return date("S") || "T" || time("L")

::method copyDirectory class
  use arg source
  target = .directory~new
  if source == .nil then return target
  do key over source~allIndexes
    target[key~string] = source~at(key)
  end
  return target

::method stringOrEmpty class
  use arg value
  if value == .nil then return ""
  return value~string

/* DateTime~microseconds is only the fractional part of the current second.
 * Keep absolute wall time in one PA-owned clock helper so accounting and
 * countdown code do not confuse it with a duration. */
::class LlmPaClock public
::method absoluteMicroseconds class
  return (time("S") * 1000000) + .DateTime~new~microseconds
::method fixedHourId class
  return trunc(self~absoluteMicroseconds / 3600000000)
::method timestamp class
  return .LlmPaUtil~timestamp

/* Append-only durable memory. Fields are hex encoded so tabs/newlines and
 * arbitrary operator text remain data rather than record syntax. */
::class LlmPaMemoryStore public
::attribute path get

::method init
  expose path
  use arg pathArg
  path = pathArg~string~strip
  if path = "" then raise syntax 88.900 array("LLM PA memory path is required")

::method remember
  expose path
  use arg keyArg, valueArg, sourceArg = "codex", requestIdArg = "", lookupKeysArg = .nil, lookupKeysSourceArg = "operator"
  key = keyArg~string~strip
  value = valueArg~string
  source = sourceArg~string~strip
  requestId = requestIdArg~string~strip
  lookupKeysSource = lookupKeysSourceArg~string~strip
  if lookupKeysSource = "" then lookupKeysSource = "operator"
  if key = "" then return .LlmPaResult~failure("MEMORY_KEY_REQUIRED")
  lookupKeys = self~normaliseLookupKeys(lookupKeysArg)
  timestamp = .LlmPaUtil~timestamp
  packedKeys = self~packLookupKeys(lookupKeys)
  row = timestamp || "09"x || c2x(key) || "09"x || c2x(value) || "09"x || c2x(source) || "09"x || c2x(requestId) || "09"x || c2x(packedKeys) || "09"x || c2x(lookupKeysSource)
  call lineout path, row
  call lineout path
  return .LlmPaResult~success(self~record(key, value, source, timestamp, requestId, lookupKeys, lookupKeysSource))

::method fallbackLookupKeys public
  use arg keyArg, valueArg = ""
  text = keyArg~string || " " || valueArg~string
  keys = .array~new
  seen = .directory~new
  ignore = self~appendLookupKey(keys, seen, keyArg)
  cleaned = text
  do ch over .array~of(",", ";", ":", "(", ")", "[", "]", "{", "}", '"', "'", "?", "!", "=")
    cleaned = cleaned~changestr(ch, " ")
  end
  do i = 1 to words(cleaned)
    token = word(cleaned, i)~strip
    if token = "" then iterate
    if token~left(2) = "./" then token = token~substr(3)
    slash = token~lastPos("/")
    if slash > 0 then token = token~substr(slash + 1)
    ignore = self~appendLookupKey(keys, seen, token)
    dot = token~lastPos(".")
    if dot > 1 then ignore = self~appendLookupKey(keys, seen, token~left(dot - 1))
  end
  return keys

::method normaliseLookupKeys private
  use arg keysArg
  out = .array~new
  seen = .directory~new
  if keysArg == .nil then return out
  if keysArg~isa(.Array) then do item over keysArg
    ignore = self~appendLookupKey(out, seen, item)
  end
  else ignore = self~appendLookupKey(out, seen, keysArg)
  return out

::method appendLookupKey private
  use arg out, seen, itemArg
  if itemArg == .nil then return .false
  item = itemArg~string~strip
  if item = "" then return .false
  if item~length > 96 then return .false
  canonical = item~lower
  if seen~hasIndex(canonical) then return .false
  seen[canonical] = .true
  out~append(item)
  return .true

::method packLookupKeys private
  use arg keys
  packed = ""
  do key over keys
    if packed \= "" then packed = packed || "1f"x
    packed = packed || key~string
  end
  return packed

::method unpackLookupKeys private
  use arg packedArg
  packed = packedArg~string
  if packed = "" then return .array~new
  raw = packed~makeArray("1f"x)
  if raw == .nil then return .array~of(packed)
  return self~normaliseLookupKeys(raw)

::method remind
  expose path
  use arg queryArg, limitArg = 8
  query = queryArg~string~strip
  limit = limitArg
  if datatype(limit, "W") = 0 | limit < 1 then limit = 8
  latest = self~latestTable
  exact = .array~new
  indexed = .array~new
  partial = .array~new
  q = query~lower
  supplier = latest~supplier
  do while supplier~available
    rec = supplier~item
    supplier~next
    keyLower = rec["key"]~lower
    valueLower = rec["value"]~lower
    if q = "" then partial~append(rec)
    else if keyLower = q then exact~append(rec)
    else do
      keyHit = .false
      do lookupKey over rec["lookup_keys"]
        lookupLower = lookupKey~string~lower
        if lookupLower = q then keyHit = .true
        else if q~pos(lookupLower) > 0 & lookupLower~length >= 3 then keyHit = .true
        else if lookupLower~pos(q) > 0 & q~length >= 3 then keyHit = .true
      end
      if keyHit then indexed~append(rec)
      else if keyLower~pos(q) > 0 | valueLower~pos(q) > 0 then partial~append(rec)
      else do
        tokenMatched = .false
        do tokenIndex = 1 to words(query)
          token = word(query, tokenIndex)~lower
          if token~length < 2 then iterate
          if keyLower~pos(token) > 0 | valueLower~pos(token) > 0 then tokenMatched = .true
          do lookupKey over rec["lookup_keys"]
            if lookupKey~string~lower~pos(token) > 0 then tokenMatched = .true
          end
        end
        if tokenMatched then partial~append(rec)
      end
    end
  end
  out = .array~new
  seen = .directory~new
  do rec over exact
    if out~items >= limit then leave
    ignore = self~appendUnique(out, seen, rec, limit)
  end
  do rec over indexed
    if out~items >= limit then leave
    ignore = self~appendUnique(out, seen, rec, limit)
  end
  do rec over partial
    if out~items >= limit then leave
    ignore = self~appendUnique(out, seen, rec, limit)
  end
  return .LlmPaResult~success(out)

/* Prompt context retrieval is deliberately richer than ordinary remind().
 * remind() remains a narrow lexical operator query. context() may expand a
 * fleet/group question and follow explicit key references found in remembered
 * values, but it never invents facts or consults live machine state. */
::method context
  use arg queryArg, limitArg = 16
  query = queryArg~string~strip
  limit = limitArg
  if datatype(limit, "W") = 0 | limit < 1 then limit = 16
  primary = self~remind(query, limit)
  if \primary~ok then return primary

  latest = self~latestTable
  out = .array~new
  seen = .directory~new
  q = query~lower
  fleetQuery = q~pos("fleet") > 0 | q~pos("machines") > 0 | q~pos("nodes") > 0

  /* Fleet questions reserve context space for the actual node/group records
   * before broad lexical hits. This prevents generic procedure records from
   * crowding ED209 identities out of a bounded model prompt. */
  if fleetQuery then do
    supplier = latest~supplier
    do while supplier~available
      rec = supplier~item
      supplier~next
      keyLower = rec["key"]~lower
      if keyLower~left(5) = "ed209" | keyLower~left(6) = "fleet_" then do
        ignore = self~appendUnique(out, seen, rec, limit)
        if out~items >= limit then leave
      end
    end
  end

  do rec over primary~value
    ignore = self~appendUnique(out, seen, rec, limit)
  end

  /* Follow remembered cross references by key name. Example: an ED209E fact
   * that mentions GCloud pulls the separately remembered GCloud procedure. */
  changed = .true
  do while changed & out~items < limit
    changed = .false
    supplier = latest~supplier
    do while supplier~available
      candidate = supplier~item
      supplier~next
      candidateKey = candidate["key"]~string
      candidateLower = candidateKey~lower
      if candidateKey~length < 3 then iterate
      if seen~hasIndex(candidateLower) then iterate
      referenced = .false
      do rec over out
        if rec["value"]~lower~pos(candidateLower) > 0 then referenced = .true
      end
      if referenced then do
        ignore = self~appendUnique(out, seen, candidate, limit)
        changed = .true
        if out~items >= limit then leave
      end
    end
  end
  return .LlmPaResult~success(out)

::method appendUnique private
  use arg out, seen, rec, limit
  if out~items >= limit then return .false
  key = rec["key"]~string~lower
  if seen~hasIndex(key) then return .false
  seen[key] = .true
  out~append(rec)
  return .true

::method latest
  use arg keyArg
  key = keyArg~string~strip~lower
  latest = self~latestTable
  supplier = latest~supplier
  do while supplier~available
    rec = supplier~item
    supplier~next
    if rec["key"]~lower = key then return .LlmPaResult~success(rec)
  end
  return .LlmPaResult~failure("MEMORY_NOT_FOUND", keyArg)

::method count
  return self~latestTable~items

::method latestTable private
  expose path
  latest = .table~new
  if stream(path, "c", "query exists") = "" then return latest
  call stream path, "c", "open read"
  do while lines(path) > 0
    line = linein(path)
    if line = "" then iterate
    parse var line timestamp "09"x keyHex "09"x valueHex "09"x sourceHex "09"x requestHex "09"x lookupHex "09"x lookupSourceHex
    if keyHex = "" then iterate
    signal on syntax name malformed
    key = x2c(keyHex)
    value = x2c(valueHex)
    source = x2c(sourceHex)
    requestId = x2c(requestHex)
    if lookupHex = "" then lookupKeys = self~fallbackLookupKeys(key, value)
    else lookupKeys = self~unpackLookupKeys(x2c(lookupHex))
    if lookupSourceHex = "" then lookupKeysSource = "legacy"
    else lookupKeysSource = x2c(lookupSourceHex)
    signal off syntax
    latest[key~lower] = self~record(key, value, source, timestamp, requestId, lookupKeys, lookupKeysSource)
  end
  call stream path, "c", "close"
  return latest
malformed:
  signal off syntax
  call stream path, "c", "close"
  raise syntax 88.900 array("Malformed LLM PA memory journal record")

::method record private
  use arg key, value, source, timestamp, requestId, lookupKeys = .nil, lookupKeysSource = "legacy"
  rec = .directory~new
  rec["key"] = key
  rec["value"] = value
  rec["source"] = source
  rec["timestamp"] = timestamp
  rec["request_id"] = requestId
  if lookupKeys == .nil then lookupKeys = self~fallbackLookupKeys(key, value)
  rec["lookup_keys"] = lookupKeys
  rec["lookup_keys_source"] = lookupKeysSource
  return rec

::class LlmPaRequestFactory public
::method create class
  use arg commandArg, arg1 = "", arg2 = "", submittedBy = "codex", replyTo = "LLMPA.REPLY", requestIdArg = ""
  command = commandArg~string~strip~lower
  if command = "" then return .LlmPaResult~failure("COMMAND_REQUIRED")
  requestId = requestIdArg~string~strip
  if requestId = "" then requestId = .LlmPaUtil~requestId
  payload = .directory~new
  payload["schema"] = "llm.pa.request/0.1"
  payload["request_id"] = requestId
  payload["command"] = command
  payload["arg1"] = .LlmPaUtil~stringOrEmpty(arg1)
  payload["arg2"] = .LlmPaUtil~stringOrEmpty(arg2)
  payload["submitted_by"] = submittedBy~string
  payload["reply_to"] = replyTo~string
  payload["created_at"] = .LlmPaUtil~timestamp
  return .LlmPaResult~success(payload)

::class LlmPaResult public
::attribute ok get
::attribute code get
::attribute detail get
::attribute value get

::method init
  expose ok code detail value
  use arg okArg, codeArg = "OK", detailArg = "", valueArg = .nil
  ok = okArg == .true
  code = codeArg~string
  detail = detailArg~string
  value = valueArg

::method success class
  use arg value = .nil
  return self~new(.true, "OK", "", value)

::method failure class
  use arg code, detail = ""
  return self~new(.false, code, detail, .nil)

/* Queue binding. The ObjectQueueManager is injected so deployment retains
 * Queue Fabric lifecycle/transport authority. This class never opens a second
 * manager against a live durable store. */
::class LlmPaQueueBinding public
::attribute manager get
::attribute requestQueue get
::attribute replyQueue get
::attribute producerPrincipal get
::attribute workerPrincipal get
::attribute alarmPrincipal get

::method init
  expose manager adminPrincipal producerPrincipal workerPrincipal alarmPrincipal requestQueue replyQueue
  use arg managerArg, adminArg = "llmpa-admin", producerArg = "codex", workerArg = "gemma", requestArg = "LLMPA.REQUEST", replyArg = "LLMPA.REPLY", alarmArg = "llmpa-alarm"
  if managerArg == .nil then raise syntax 88.900 array("LLM PA requires an ObjectQueueManager")
  manager = managerArg
  adminPrincipal = adminArg~string
  producerPrincipal = producerArg~string
  workerPrincipal = workerArg~string
  alarmPrincipal = alarmArg~string
  requestQueue = requestArg~string~translate
  replyQueue = replyArg~string~translate

::method ensureQueues
  expose manager adminPrincipal producerPrincipal workerPrincipal alarmPrincipal requestQueue replyQueue
  if manager~queue(requestQueue) == .nil then do
    r = manager~createQueue(requestQueue, "PERMANENT", "LLMPA", 0, adminPrincipal)
    if \r~ok then return .LlmPaResult~failure(r~code, r~detail)
  end
  if manager~queue(replyQueue) == .nil then do
    r = manager~createQueue(replyQueue, "PERMANENT", "LLMPA", 0, adminPrincipal)
    if \r~ok then return .LlmPaResult~failure(r~code, r~detail)
  end
  grants = .array~of( -
    .array~of(requestQueue, producerPrincipal, .QueueAccess~PUT), -
    .array~of(requestQueue, producerPrincipal, .QueueAccess~BROWSE), -
    .array~of(requestQueue, workerPrincipal, .QueueAccess~GET), -
    .array~of(requestQueue, workerPrincipal, .QueueAccess~BROWSE), -
    .array~of(requestQueue, alarmPrincipal, .QueueAccess~PUT), -
    .array~of(requestQueue, alarmPrincipal, .QueueAccess~BROWSE), -
    .array~of(replyQueue, workerPrincipal, .QueueAccess~PUT), -
    .array~of(replyQueue, producerPrincipal, .QueueAccess~GET), -
    .array~of(replyQueue, producerPrincipal, .QueueAccess~BROWSE))
  do g over grants
    if \manager~accessAllowed(g[1], g[2], g[3]) then do
      r = manager~grant(g[1], g[2], g[3], adminPrincipal)
      if \r~ok then return .LlmPaResult~failure(r~code, r~detail)
    end
  end
  return .LlmPaResult~success(.true)

::method submit
  expose manager producerPrincipal requestQueue
  use arg commandArg, arg1 = "", arg2 = "", submittedBy = "codex", replyTo = "", requestIdArg = ""
  if replyTo = "" then replyTo = self~replyQueue
  made = .LlmPaRequestFactory~create(commandArg, arg1, arg2, submittedBy, replyTo, requestIdArg)
  if \made~ok then return made
  payload = made~value
  requestId = payload["request_id"]
  options = .table~new
  options["persistent"] = .true
  options["securityDomain"] = "LLMPA"
  options["correlationId"] = requestId
  options["replyTo"] = replyTo~string
  put = manager~put(requestQueue, payload, options, producerPrincipal)
  if \put~ok then return .LlmPaResult~failure(put~code, put~detail)
  submitData = .directory~new
  submitData["request_id"] = requestId
  submitData["package_id"] = put~value~packageId
  submitData["status"] = .LlmPaStatus~QUEUED
  return .LlmPaResult~success(submitData)

::method submitAlarm
  expose manager alarmPrincipal requestQueue
  use arg commandArg, arg1 = "", arg2 = "", submittedBy = "alarm", replyTo = "", requestIdArg = ""
  if replyTo = "" then replyTo = self~replyQueue
  made = .LlmPaRequestFactory~create(commandArg, arg1, arg2, submittedBy, replyTo, requestIdArg)
  if \made~ok then return made
  payload = made~value
  requestId = payload["request_id"]
  options = .table~new
  options["persistent"] = .true
  options["securityDomain"] = "LLMPA"
  options["correlationId"] = requestId
  options["replyTo"] = replyTo~string
  put = manager~put(requestQueue, payload, options, alarmPrincipal)
  if \put~ok then return .LlmPaResult~failure(put~code, put~detail)
  submitData = .directory~new
  submitData["request_id"] = requestId
  submitData["package_id"] = put~value~packageId
  submitData["status"] = .LlmPaStatus~QUEUED
  return .LlmPaResult~success(submitData)

::method claimRequest
  expose manager workerPrincipal requestQueue
  r = manager~claim(requestQueue, workerPrincipal)
  if \r~ok then return .LlmPaResult~failure(r~code, r~detail)
  return .LlmPaResult~success(r~value)

::method completeRequest
  expose manager workerPrincipal requestQueue
  use arg requestPackage, replyPayload
  if requestPackage == .nil then return .LlmPaResult~failure("REQUEST_PACKAGE_REQUIRED")
  request = requestPackage~payload
  replyQueueName = request["reply_to"]~string
  options = .table~new
  options["persistent"] = .true
  options["securityDomain"] = "LLMPA"
  options["correlationId"] = request["request_id"]
  put = manager~put(replyQueueName, replyPayload, options, workerPrincipal)
  if \put~ok then do
    ignore = manager~release(requestQueue, requestPackage~packageId, requestPackage~claimToken, workerPrincipal)
    return .LlmPaResult~failure(put~code, put~detail)
  end
  ack = manager~ack(requestQueue, requestPackage~packageId, requestPackage~claimToken, workerPrincipal)
  if \ack~ok then return .LlmPaResult~failure(ack~code, ack~detail)
  return .LlmPaResult~success(put~value)

::method collectReply
  expose manager producerPrincipal replyQueue
  use arg expectedRequestId = ""
  /* First cut claims FIFO/highest-priority reply. Correlation is validated by
   * caller; deployment may dedicate per-Codex reply queues if needed. */
  r = manager~claim(replyQueue, producerPrincipal)
  if \r~ok then return .LlmPaResult~failure(r~code, r~detail)
  p = r~value
  if expectedRequestId \= "" & p~payload["request_id"] \= expectedRequestId then do
    ignore = manager~release(replyQueue, p~packageId, p~claimToken, producerPrincipal)
    return .LlmPaResult~failure("REPLY_NOT_READY", expectedRequestId)
  end
  ack = manager~ack(replyQueue, p~packageId, p~claimToken, producerPrincipal)
  if \ack~ok then return .LlmPaResult~failure(ack~code, ack~detail)
  return .LlmPaResult~success(p~payload)

::requires "ObjectQueueFabric.cls"
