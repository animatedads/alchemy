/*
 * CivicNotamJournal.cls - CivicPort v0.14 durable-journal NOTAM projection.
 *
 * This layer scans already-journalled CivicQueueDocument evidence.  It does not
 * claim Queue Fabric packages, acknowledge JMS messages, or connect to a broker.
 * Projection failures remain explicit diagnostics beside successful projections.
 */

::class CivicNotamJournalBuild public
::constant RELEASE "0.14"


::class CivicNotamJournalDiagnostic subclass CivicAlchemyObject public
::attribute recordId get
::attribute sourceIdentity get
::attribute stage get
::attribute errorCode get
::attribute message get

::method init
  expose recordId sourceIdentity stage errorCode message
  use arg recordIdArg, sourceIdentityArg, stageArg, codeArg, messageArg = ""
  ignore = self~initCivicAlchemy
  recordId = recordIdArg~string
  sourceIdentity = sourceIdentityArg~string
  stage = stageArg~string~translate
  errorCode = codeArg~string
  message = messageArg~string


::class CivicNotamJournalProjection subclass CivicAlchemyObject public
::attribute journalRecord get
::attribute projection get
::attribute recordId get
::attribute sourceIdentity get
::attribute queueDocument get

::method init
  expose journalRecord projection recordId sourceIdentity queueDocument
  use arg recordArg, projectionArg
  ignore = self~initCivicAlchemy
  if recordArg == .nil | projectionArg == .nil then raise syntax 93.900 additional("CivicNotamJournalProjection requires journal record and NOTAM projection")
  journalRecord = recordArg
  projection = projectionArg
  recordId = recordArg~recordId
  queueDocument = recordArg~document
  sourceIdentity = queueDocument~sourceIdentity

::method provenance
  expose projection recordId
  p = projection~provenance
  p["queueJournalRecordId"] = recordId
  return p


::class CivicNotamJournalProjectionOutcome subclass CivicAlchemyObject public
::attribute ok get
::attribute journalProjection get
::attribute stage get
::attribute errorCode get
::attribute message get

::method success class
  use arg journalProjection
  return self~new(.true, journalProjection, "", "", "")

::method failure class
  use arg stage, code, message = ""
  return self~new(.false, .nil, stage, code, message)

::method init
  expose ok journalProjection stage errorCode message
  use arg okArg, projectionArg, stageArg, codeArg, messageArg
  ignore = self~initCivicAlchemy
  ok = okArg
  journalProjection = projectionArg
  stage = stageArg~string~translate
  errorCode = codeArg~string
  message = messageArg~string


::class CivicNotamJournalScan subclass CivicAlchemyObject public
::method init
  expose projectionItems diagnosticItems
  use arg projectionsArg = .nil, diagnosticsArg = .nil
  ignore = self~initCivicAlchemy
  projectionItems = .array~new
  diagnosticItems = .array~new
  if projectionsArg \== .nil then do item over projectionsArg
    projectionItems~append(item)
  end
  if diagnosticsArg \== .nil then do item over diagnosticsArg
    diagnosticItems~append(item)
  end

::method projections
  expose projectionItems
  copied = .array~new
  do item over projectionItems
    copied~append(item)
  end
  return copied

::method diagnostics
  expose diagnosticItems
  copied = .array~new
  do item over diagnosticItems
    copied~append(item)
  end
  return copied

::method projectedCount
  expose projectionItems
  return projectionItems~items

::method diagnosticCount
  expose diagnosticItems
  return diagnosticItems~items


::class CivicNotamJournalProjector subclass CivicAlchemyObject public
::method init
  ignore = self~initCivicAlchemy
  self~registerMethodContract("PROJECTRECORD", "Project one already-journalled SWIM record to narrow NOTAM evidence", .array~of("CivicQueueJournalRecord"), "CIVICNOTAMJOURNALPROJECTIONOUTCOME", .false, "AUTO", "PUBLIC", "NORMAL", "READ", "NONE")
  self~registerMethodContract("PROJECTSOURCE", "Project one exact source identity from an existing Civic queue journal", .array~of("CivicQueueJournal", "sourceIdentity"), "CIVICNOTAMJOURNALPROJECTIONOUTCOME", .false, "AUTO", "PUBLIC", "NORMAL", "READ", "NONE")
  self~registerMethodContract("SCAN", "Project all current journal records and retain explicit diagnostics", .array~of("CivicQueueJournal"), "CIVICNOTAMJOURNALSCAN", .false, "AUTO", "PUBLIC", "NORMAL", "READ", "NONE")

::method projectRecord
  use arg record
  if record == .nil then return .CivicNotamJournalProjectionOutcome~failure("JOURNAL", "QUEUE_JOURNAL_RECORD_REQUIRED")
  queueDocument = record~document
  if queueDocument == .nil then return .CivicNotamJournalProjectionOutcome~failure("JOURNAL", "QUEUE_JOURNAL_DOCUMENT_REQUIRED")

  swimOutcome = .CivicSwimXmlAdapter~new~parse(queueDocument)
  if \swimOutcome~ok then return .CivicNotamJournalProjectionOutcome~failure("SWIM_XML", swimOutcome~errorCode, swimOutcome~message)

  simpleOutcome = .CivicAimFnsSimpleTextAdapter~new~project(swimOutcome~document)
  if \simpleOutcome~ok then return .CivicNotamJournalProjectionOutcome~failure("AIM_FNS_SIMPLE_TEXT", simpleOutcome~errorCode, simpleOutcome~message)

  notamOutcome = .CivicNotamRunwayClosureAdapter~new~project(simpleOutcome~projection)
  if \notamOutcome~ok then return .CivicNotamJournalProjectionOutcome~failure("NOTAM_RUNWAY_CLOSURE", notamOutcome~errorCode, notamOutcome~message)

  return .CivicNotamJournalProjectionOutcome~success(.CivicNotamJournalProjection~new(record, notamOutcome~projection))

::method projectSource
  use arg journal, sourceIdentity
  if journal == .nil then return .CivicNotamJournalProjectionOutcome~failure("JOURNAL", "QUEUE_JOURNAL_REQUIRED")
  sourceText = sourceIdentity~string
  if sourceText = "" then return .CivicNotamJournalProjectionOutcome~failure("JOURNAL", "SOURCE_IDENTITY_REQUIRED")
  record = journal~recordForSource(sourceText)
  if record == .nil then return .CivicNotamJournalProjectionOutcome~failure("JOURNAL", "SOURCE_IDENTITY_NOT_FOUND", sourceText)
  return self~projectRecord(record)

::method scan
  use arg journal
  if journal == .nil then raise syntax 93.900 additional("CivicNotamJournalProjector scan requires CivicQueueJournal")
  projections = .array~new
  diagnostics = .array~new
  do record over journal~all
    projectionOutcome = self~projectRecord(record)
    if projectionOutcome~ok then projections~append(projectionOutcome~journalProjection)
    else diagnostics~append(.CivicNotamJournalDiagnostic~new(record~recordId, record~document~sourceIdentity, projectionOutcome~stage, projectionOutcome~errorCode, projectionOutcome~message))
  end
  return .CivicNotamJournalScan~new(projections, diagnostics)

::requires "CivicNotam.cls"
::requires "CivicQueueEvidence.cls"
