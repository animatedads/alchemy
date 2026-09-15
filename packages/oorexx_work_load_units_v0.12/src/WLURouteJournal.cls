/*
 * WLURouteJournal v0.1
 *
 * Durable, append-only route-evidence archive for logical WLU jobs.  This is
 * deliberately separate from the accounting ledger: route evidence explains
 * implementation choices and observed execution/handoff outcomes, but replay
 * never grants WLU entitlement, reconstructs active reservations, or executes
 * a provider.
 */

::options digits 30

::class WLUJobRouteJournalBuild public
::constant VERSION "0.1"
::constant API_VERSION "work.load.units.route-journal/0.1"
::constant RECORD_FORMAT "wlu.job.route.journal/1"
::constant GENESIS_TAG "00000000000000000000000000000000"

::class WLUJobRouteArchiveReport public
::attribute appendedCount get
::attribute existingCount get
::attribute eventCount get
::attribute journalSequence get

::method init
  expose appendedCount existingCount eventCount journalSequence
  use strict arg appendedCount, existingCount, eventCount, journalSequence

::class WLUJobRouteFileJournal subclass AlchemyObject public
::attribute path get
::attribute sequence get
::attribute previousTag get
::attribute keyRing get

::method init
  expose path sequence previousTag keyRing eventKeys routeMaxRevision
  use strict arg path, keyRing
  path = path~string~strip
  if path = "" then raise syntax 88.900 array("WLU route journal path must not be empty")
  if keyRing == .nil | \keyRing~isA(.WLUFastMacKeyRing) then raise syntax 88.900 array("WLU route journal requires WLUFastMacKeyRing")
  sequence = 0
  previousTag = .WLUJobRouteJournalBuild~GENESIS_TAG
  eventKeys = .table~new
  routeMaxRevision = .table~new
  stream = .Stream~new(path)
  if stream~query("exists") \= "" then do
    if stream~query("size") \= "0" then do
      recovered = self~recover
      if \recovered~ok then raise syntax 88.900 array("Cannot recover WLU route journal: " || recovered~code || " " || recovered~detail)
    end
  end
  alchemyConstruction = .WLUAlchemySupport~construction(keyRing, "WLUJobRouteFileJournal", "Durable MAC-chained non-entitling logical-job route evidence archive")
  self~init:super(alchemyConstruction[1], alchemyConstruction[2], alchemyConstruction[3])
  ignore = .WLUAlchemySupport~finishConstruction(self)
  self~registerStateVariable("path", "INTERNAL", "route-evidence journal file path")
  self~registerStateVariable("sequence", "CUSTOMER", "last authenticated route-journal sequence")
  self~registerMethodContract("APPENDEVENT", "Append one authenticated logical-job route event idempotently", .array~of("EVENT"), "WLURESULT", .true, "AUTO", "INTERNAL", "AUTHORITY", "EXTERNAL", "USE")
  self~registerMethodContract("ARCHIVEEVENTS", "Archive a route-history batch without changing WLU authority state", .array~of("EVENTS"), "WLURESULT", .true, "AUTO", "INTERNAL", "AUTHORITY", "EXTERNAL", "USE")
  self~registerMethodContract("READVERIFIED", "Read and verify the complete chained route archive", .array~new, "WLURESULT", .false, "AUTO", "INTERNAL", "SENSITIVE", "READ", "NONE")
  self~registerMethodContract("HISTORY", "Read verified durable route evidence for one logical job", .array~of("JOBID"), "WLURESULT", .false, "AUTO", "CUSTOMER", "NORMAL", "READ", "NONE")
  self~registerMethodContract("SUMMARY", "Derive a route summary from verified durable evidence only", .array~of("JOBID"), "WLURESULT", .false, "AUTO", "CUSTOMER", "NORMAL", "READ", "NONE")
  self~registerMethodContract("RECOVER", "Recover route-journal sequence and indexes only after full verification", .array~new, "WLURESULT", .true, "AUTO", "INTERNAL", "AUTHORITY", "MUTATE", "USE")
  self~registerInstrumentationPoint("WLU.JOB.ROUTE.ARCHIVE", "durable non-entitling route-evidence archival boundary", .true, "ALL", "INTERNAL")

::method appendEvent public protected
  expose path sequence previousTag keyRing eventKeys routeMaxRevision
  use strict arg event
  guard on
  if event == .nil | \event~isA(.WLUJobRouteEvidence) then return .WLUResult~failure("WLU_ROUTE_JOURNAL_EVENT_REQUIRED", "WLUJobRouteEvidence required")
  if \event~verify(keyRing) then return .WLUResult~failure("WLU_ROUTE_JOURNAL_EVENT_PROOF_INVALID", event~jobId || ":" || event~routeRevision)
  key = self~eventKey(event)
  existing = eventKeys[key]
  if existing \== .nil then do
    if \self~sameEvidence(existing, event) then return .WLUResult~failure("WLU_ROUTE_JOURNAL_EVENT_CONFLICT", key)
    return .WLUResult~success(existing, "idempotent route archive replay")
  end
  maxRevision = routeMaxRevision[event~jobId]
  if maxRevision \== .nil then do
    if event~routeRevision <= maxRevision then return .WLUResult~failure("WLU_ROUTE_JOURNAL_ROUTE_ORDER", "job=" || event~jobId || " latest=" || maxRevision || " incoming=" || event~routeRevision)
  end
  nextSequence = sequence + 1
  authText = self~authText(previousTag, nextSequence, event)
  chainProof = keyRing~sign(authText)
  line = self~encodeLine(previousTag, nextSequence, event, chainProof)
  stream = .Stream~new(path)
  status = stream~open("write append")
  if status \= "READY:" then return .WLUResult~failure("WLU_ROUTE_JOURNAL_OPEN_FAILED", status)
  ignore = stream~lineOut(line)
  ignore = stream~close
  sequence = nextSequence
  previousTag = chainProof~tag
  eventKeys[key] = event
  routeMaxRevision[event~jobId] = event~routeRevision
  meta = .directory~new
  meta["job_id"] = event~jobId
  meta["route_revision"] = event~routeRevision
  meta["journal_sequence"] = sequence
  self~alchemyInstrument("WLU.JOB.ROUTE.ARCHIVE", meta)
  return .WLUResult~success(event)

::method archiveEvents public protected
  expose sequence
  use strict arg events
  guard on
  if events == .nil then return .WLUResult~failure("WLU_ROUTE_JOURNAL_EVENTS_REQUIRED", "route event collection required")
  appended = 0
  existing = 0
  total = 0
  do event over events
    total += 1
    before = sequence
    result = self~appendEvent(event)
    if \result~ok then return result
    if sequence > before then appended += 1
    else existing += 1
  end
  return .WLUResult~success(.WLUJobRouteArchiveReport~new(appended, existing, total, sequence))

::method readVerified
  expose path keyRing
  guard on
  events = .array~new
  stream = .Stream~new(path)
  if stream~query("exists") = "" then return .WLUResult~success(.array~of(events, .WLUJobRouteJournalBuild~GENESIS_TAG))
  status = stream~open("read")
  if status \= "READY:" then return .WLUResult~failure("WLU_ROUTE_JOURNAL_OPEN_FAILED", status)
  expectedSequence = 1
  expectedPrevious = .WLUJobRouteJournalBuild~GENESIS_TAG
  seen = .table~new
  routeMax = .table~new
  do while stream~lines > 0
    line = stream~lineIn
    decoded = self~decodeLine(line)
    if \decoded~ok then do
      ignore = stream~close
      return decoded
    end
    row = decoded~value
    journalSequence = row[1]
    previous = row[2]
    chainProof = row[3]
    event = row[4]
    if journalSequence \= expectedSequence then do
      ignore = stream~close
      return .WLUResult~failure("WLU_ROUTE_JOURNAL_SEQUENCE_BROKEN", "expected=" || expectedSequence || " actual=" || journalSequence)
    end
    if previous \= expectedPrevious then do
      ignore = stream~close
      return .WLUResult~failure("WLU_ROUTE_JOURNAL_CHAIN_BROKEN", "record=" || journalSequence)
    end
    if \event~verify(keyRing) then do
      ignore = stream~close
      return .WLUResult~failure("WLU_ROUTE_JOURNAL_EVENT_PROOF_INVALID", "record=" || journalSequence)
    end
    if \keyRing~verify(self~authText(previous, journalSequence, event), chainProof) then do
      ignore = stream~close
      return .WLUResult~failure("WLU_ROUTE_JOURNAL_MAC_INVALID", "record=" || journalSequence)
    end
    key = self~eventKey(event)
    if seen~hasIndex(key) then do
      ignore = stream~close
      return .WLUResult~failure("WLU_ROUTE_JOURNAL_DUPLICATE_EVENT", key)
    end
    maxRevision = routeMax[event~jobId]
    if maxRevision \== .nil then do
      if event~routeRevision <= maxRevision then do
        ignore = stream~close
        return .WLUResult~failure("WLU_ROUTE_JOURNAL_ROUTE_ORDER", "job=" || event~jobId || " record=" || journalSequence)
      end
    end
    seen[key] = event
    routeMax[event~jobId] = event~routeRevision
    events~append(event)
    expectedPrevious = chainProof~tag
    expectedSequence += 1
  end
  ignore = stream~close
  return .WLUResult~success(.array~of(events, expectedPrevious))

::method recover public protected
  expose sequence previousTag eventKeys routeMaxRevision
  guard on
  result = self~readVerified
  if \result~ok then return result
  events = result~value[1]
  sequence = events~items
  previousTag = result~value[2]
  eventKeys = .table~new
  routeMaxRevision = .table~new
  do event over events
    eventKeys[self~eventKey(event)] = event
    routeMaxRevision[event~jobId] = event~routeRevision
  end
  return .WLUResult~success(events)

::method history
  use strict arg jobId = ""
  guard on
  jobId = jobId~string~strip
  result = self~readVerified
  if \result~ok then return result
  out = .array~new
  do event over result~value[1]
    if jobId = "" | event~jobId = jobId then out~append(event)
  end
  return .WLUResult~success(out)

::method summary
  use strict arg jobId
  guard on
  jobId = jobId~string~strip
  if jobId = "" then return .WLUResult~failure("WLU_ROUTE_JOURNAL_JOB_REQUIRED", "job id required")
  result = self~history(jobId)
  if \result~ok then return result
  return .WLUResult~success(.WLUJobRouteSummary~fromEvents(jobId, result~value))

::method authText private
  use strict arg previousTag, journalSequence, event
  proof = event~proof
  text = .WLUJobRouteJournalBuild~RECORD_FORMAT || "0a"x
  text ||= self~field("journal-sequence", journalSequence)
  text ||= self~field("previous-tag", previousTag)
  text ||= self~field("event-proof-algorithm", proof~algorithm)
  text ||= self~field("event-proof-key-id", proof~keyId)
  text ||= self~field("event-proof-tag", proof~tag)
  text ||= event~canonicalText
  return text

::method encodeLine private
  use strict arg previousTag, journalSequence, event, chainProof
  eventProof = event~proof
  if event~breakdownKnown then breakdownFlag = 1
  else breakdownFlag = 0
  fields = .array~of(.WLUJobRouteJournalBuild~RECORD_FORMAT, journalSequence, previousTag, c2x(chainProof~algorithm)~lower, c2x(chainProof~keyId)~lower, chainProof~tag, c2x(eventProof~algorithm)~lower, c2x(eventProof~keyId)~lower, eventProof~tag, c2x(event~jobId)~lower, event~routeRevision, event~observedTick, c2x(event~eventType)~lower, c2x(event~stageId)~lower, c2x(event~fromStageId)~lower, c2x(event~reservationId)~lower, event~actualWorkMicroWlu, event~actualHandoffMicroWlu, breakdownFlag, event~stageExpectedMicroWlu, event~stageCeilingMicroWlu, event~forecastRevision, c2x(event~forecastStatus)~lower, c2x(event~standbyId)~lower, c2x(event~reasonCode)~lower, c2x(event~evidenceRef)~lower, c2x(event~rateCardId)~lower, c2x(event~rateCardVersion)~lower)
  line = ""
  do i = 1 to fields~items
    if i > 1 then line ||= "|"
    line ||= fields[i]
  end
  return line

::method decodeLine private
  use strict arg line
  parts = .WLURecordCodec~split(line, "|")
  if parts~items \= 28 then return .WLUResult~failure("WLU_ROUTE_JOURNAL_RECORD_MALFORMED", "field-count=" || parts~items)
  if parts[1] \= .WLUJobRouteJournalBuild~RECORD_FORMAT then return .WLUResult~failure("WLU_ROUTE_JOURNAL_RECORD_MALFORMED", "unexpected record format")
  if \datatype(parts[2], "W") | parts[2] < 1 then return .WLUResult~failure("WLU_ROUTE_JOURNAL_RECORD_MALFORMED", "invalid journal sequence")
  if parts[3]~length \= 32 | verify(parts[3]~lower, "0123456789abcdef") \= 0 then return .WLUResult~failure("WLU_ROUTE_JOURNAL_RECORD_MALFORMED", "invalid previous tag")
  if parts[6]~length \= 32 | verify(parts[6]~lower, "0123456789abcdef") \= 0 then return .WLUResult~failure("WLU_ROUTE_JOURNAL_RECORD_MALFORMED", "invalid chain MAC")
  if parts[9]~length \= 32 | verify(parts[9]~lower, "0123456789abcdef") \= 0 then return .WLUResult~failure("WLU_ROUTE_JOURNAL_RECORD_MALFORMED", "invalid event MAC")
  if \datatype(parts[11], "W") | parts[11] < 1 then return .WLUResult~failure("WLU_ROUTE_JOURNAL_RECORD_MALFORMED", "invalid route revision")
  if \datatype(parts[12], "W") then return .WLUResult~failure("WLU_ROUTE_JOURNAL_RECORD_MALFORMED", "invalid observed tick")
  if \datatype(parts[17], "W") | parts[17] < 0 then return .WLUResult~failure("WLU_ROUTE_JOURNAL_RECORD_MALFORMED", "invalid actual work")
  if \datatype(parts[18], "W") | parts[18] < 0 then return .WLUResult~failure("WLU_ROUTE_JOURNAL_RECORD_MALFORMED", "invalid actual handoff")
  if parts[19] \= "0" & parts[19] \= "1" then return .WLUResult~failure("WLU_ROUTE_JOURNAL_RECORD_MALFORMED", "invalid breakdown flag")
  if \datatype(parts[20], "W") | parts[20] < 0 then return .WLUResult~failure("WLU_ROUTE_JOURNAL_RECORD_MALFORMED", "invalid stage expected WLU")
  if \datatype(parts[21], "W") | parts[21] < 0 then return .WLUResult~failure("WLU_ROUTE_JOURNAL_RECORD_MALFORMED", "invalid stage ceiling WLU")
  if \datatype(parts[22], "W") | parts[22] < 0 then return .WLUResult~failure("WLU_ROUTE_JOURNAL_RECORD_MALFORMED", "invalid forecast revision")
  signal on syntax name decodeFailure
  chainAlgorithm = .WLURecordCodec~decodeHex(parts[4])
  chainKeyId = .WLURecordCodec~decodeHex(parts[5])
  eventAlgorithm = .WLURecordCodec~decodeHex(parts[7])
  eventKeyId = .WLURecordCodec~decodeHex(parts[8])
  if parts[19] = "1" then breakdownKnown = .true
  else breakdownKnown = .false
  eventProof = .WLUProof~new(eventAlgorithm, eventKeyId, parts[9])
  event = .WLUJobRouteEvidence~new(.WLURecordCodec~decodeHex(parts[10]), parts[11], parts[12], .WLURecordCodec~decodeHex(parts[13]), .WLURecordCodec~decodeHex(parts[14]), .WLURecordCodec~decodeHex(parts[15]), .WLURecordCodec~decodeHex(parts[16]), parts[17], parts[18], breakdownKnown, parts[20], parts[21], parts[22], .WLURecordCodec~decodeHex(parts[23]), .WLURecordCodec~decodeHex(parts[24]), .WLURecordCodec~decodeHex(parts[25]), .WLURecordCodec~decodeHex(parts[26]), .WLURecordCodec~decodeHex(parts[27]), .WLURecordCodec~decodeHex(parts[28]), eventProof)
  chainProof = .WLUProof~new(chainAlgorithm, chainKeyId, parts[6])
  signal off syntax
  return .WLUResult~success(.array~of(parts[2], parts[3], chainProof, event))
decodeFailure:
  signal off syntax
  return .WLUResult~failure("WLU_ROUTE_JOURNAL_RECORD_MALFORMED", condition("D"))

::method sameEvidence private
  use strict arg left, right
  if left~canonicalText \= right~canonicalText then return .false
  if left~proof == .nil | right~proof == .nil then return .false
  if left~proof~algorithm \= right~proof~algorithm then return .false
  if left~proof~keyId \= right~proof~keyId then return .false
  return left~proof~tag = right~proof~tag

::method eventKey private
  use strict arg event
  return event~jobId || ":" || event~routeRevision

::method field private
  use strict arg name, value
  value = value~string
  return name || ":" || value~length || ":" || value || "0a"x

::requires "WLUJobBudget.cls"
::requires "WLULedger.cls"
