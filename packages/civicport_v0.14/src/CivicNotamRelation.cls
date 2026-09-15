/*
 * CivicNotamRelation.cls - CivicPort v0.14 read-only SQL projection of durable
 * SWIM/NOTAM journal evidence.  The first read freezes a snapshot of the
 * journal's current records; later scans do not absorb subsequently appended
 * records into the same relation instance.
 */

::class CivicNotamRelationBuild public
::constant RELEASE "0.14"


::class CivicNotamProjectedRow subclass CivicAlchemyObject public
::attribute values get
::attribute rawValues get
::attribute typeNames get
::attribute journalProjection get

::method init
  expose values rawValues typeNames journalProjection
  use arg valuesArg, rawValuesArg, typeNamesArg, journalProjectionArg
  ignore = self~initCivicAlchemy
  values = valuesArg
  rawValues = rawValuesArg
  typeNames = typeNamesArg
  journalProjection = journalProjectionArg

::method "[]"
  expose values
  use arg name
  return values[name]

::method at
  expose values
  use arg name
  return values[name]

::method rawAt
  expose rawValues
  use arg name
  return rawValues[name]

::method sourceFor
  expose journalProjection
  use arg name
  return journalProjection~projection

::method copy
  expose values rawValues typeNames journalProjection
  return .CivicNotamProjectedRow~new(values~copy, rawValues~copy, typeNames~copy, journalProjection)

::method provenance
  expose journalProjection
  return journalProjection~provenance


::class CivicNotamRelationProvider subclass CivicAlchemyObject public
::attribute journal get
::attribute tables get
::attribute lastError get

::method init
  expose journal tables rowsCache materialized resultClass tableDefinitionClass projector lastError scanDiagnostics
  use arg journalArg, resultClassArg, tableDefinitionClassArg, projectorArg = .nil
  ignore = self~initCivicAlchemy
  if journalArg == .nil then raise syntax 93.900 additional("CivicNotamRelationProvider requires CivicQueueJournal")
  if resultClassArg == .nil then raise syntax 93.900 additional("CivicNotamRelationProvider requires host DatabaseResult class")
  if tableDefinitionClassArg == .nil then raise syntax 93.900 additional("CivicNotamRelationProvider requires host TableDefinition class")
  journal = journalArg
  resultClass = resultClassArg
  tableDefinitionClass = tableDefinitionClassArg
  if projectorArg == .nil then projector = .CivicNotamJournalProjector~new
  else projector = projectorArg
  tables = .table~new
  rowsCache = .directory~new
  materialized = .directory~new
  lastError = ""
  scanDiagnostics = .directory~new

::method defineRunwayClosureRelation
  expose tables tableDefinitionClass
  use arg tableName = "civic_notam_runway_closure"
  name = tableName~string
  if name~strip = "" then raise syntax 93.900 additional("Civic NOTAM relation requires a table name")
  raw = .table~new
  raw["name"] = name
  raw["generation"] = 0
  raw["columns"] = .array~new
  do column over .array~of( -
      "source_identity", "queue_journal_record_id", "queue_evidence_identity", "local_queue", "message_id", "provider", "source", "body_sha512", "accepted_at", -
      "mapping_generation", "evidence_identity", "raw_text", "accountable_location", "notam_number", "affected_location", "keyword", "runway_designator", "condition", -
      "effective_start_token", "effective_end_token", "end_qualifier", "raw_time_range", "source_path", "source_line", "use_classification", "release_classification", "operational_disposition")
    nullable = .false
    if column = "message_id" | column = "accepted_at" | column = "source_line" then nullable = .true
    self~appendColumn(raw, column, "VARCHAR", nullable)
  end
  definition = tableDefinitionClass~new(raw)
  key = name~translate
  tables[key] = .CivicRelationTable~new(self, name, definition)
  return definition

::method appendColumn private
  use arg raw, name, type, nullable
  c = .table~new
  c["name"] = name
  c["type"] = type
  c["nullable"] = nullable
  raw["columns"]~append(c)
  return .true

::method table
  expose tables
  use arg tableName
  return tables[tableName~string~translate]

::method tableNames
  expose tables
  names = .array~new
  do key over tables~allIndexes
    names~append(tables[key]~definition~name)
  end
  names~sort
  return names

::method readCatalog
  raw = .table~new
  raw["name"] = "CIVIC_PORT_QUEUE_EVIDENCE"
  raw["formatVersion"] = 1
  raw["tables"] = self~tableNames
  raw["projectionModel"] = "CIVIC_NOTAM_JOURNAL_SNAPSHOT_READONLY_V1"
  return raw

::method tableRowCount
  use arg tableName
  t = self~table(tableName)
  if t == .nil then return .nil
  return t~rowCount

::method materializedRowCount
  expose rowsCache materialized
  use arg tableName
  key = tableName~string~translate
  state = materialized[key]
  if state == .nil | state \== .true then return .nil
  if \rowsCache~hasIndex(key) then return 0
  return rowsCache[key]~items

::method diagnostics
  expose scanDiagnostics
  use arg tableName
  key = tableName~string~translate
  items = scanDiagnostics[key]
  copied = .array~new
  if items == .nil then return copied
  do item over items
    copied~append(item)
  end
  return copied

::method rowsFor
  expose rowsCache materialized lastError
  use arg tableName
  key = tableName~string~translate
  state = materialized[key]
  if state \== .nil then do
    if state == .true then return self~copyRows(rowsCache[key])
  end
  guard on
  state = materialized[key]
  if state \== .nil then do
    if state == .true then do
      guard off
      return self~copyRows(rowsCache[key])
    end
  end
  lastError = ""
  built = self~materialize(key)
  if built == .nil then do
    guard off
    return .array~new
  end
  rowsCache[key] = built
  materialized[key] = .true
  t = self~table(tableName)
  if t \== .nil then t~definition~rowCount = built~items
  guard off
  return self~copyRows(built)

::method materialize private
  expose tables journal projector scanDiagnostics lastError
  use arg key
  if tables[key] == .nil then do
    lastError = "CIVIC_NOTAM_RELATION_NOT_FOUND " || key
    return .nil
  end
  scan = projector~scan(journal)
  scanDiagnostics[key] = scan~diagnostics
  rows = .array~new
  do journalProjection over scan~projections
    rows~append(self~projectRow(journalProjection))
  end
  return rows

::method projectRow private
  use arg journalProjection
  projection = journalProjection~projection
  queueDocument = journalProjection~queueDocument
  values = .table~new
  rawValues = .table~new
  typeNames = .table~new
  ignore = self~putScalar(values, rawValues, typeNames, "source_identity", journalProjection~sourceIdentity)
  ignore = self~putScalar(values, rawValues, typeNames, "queue_journal_record_id", journalProjection~recordId)
  ignore = self~putScalar(values, rawValues, typeNames, "queue_evidence_identity", queueDocument~evidenceIdentity)
  ignore = self~putScalar(values, rawValues, typeNames, "local_queue", queueDocument~localQueue)
  ignore = self~putScalar(values, rawValues, typeNames, "message_id", self~nullableString(queueDocument~messageId))
  ignore = self~putScalar(values, rawValues, typeNames, "provider", queueDocument~provider)
  ignore = self~putScalar(values, rawValues, typeNames, "source", queueDocument~source)
  ignore = self~putScalar(values, rawValues, typeNames, "body_sha512", queueDocument~bodyDigest)
  ignore = self~putScalar(values, rawValues, typeNames, "accepted_at", self~nullableString(queueDocument~acceptedAt))
  ignore = self~putScalar(values, rawValues, typeNames, "mapping_generation", projection~generation)
  ignore = self~putScalar(values, rawValues, typeNames, "evidence_identity", projection~identity)
  ignore = self~putScalar(values, rawValues, typeNames, "raw_text", projection~rawText)
  ignore = self~putScalar(values, rawValues, typeNames, "accountable_location", projection~accountableLocation)
  ignore = self~putScalar(values, rawValues, typeNames, "notam_number", projection~notamNumber)
  ignore = self~putScalar(values, rawValues, typeNames, "affected_location", projection~affectedLocation)
  ignore = self~putScalar(values, rawValues, typeNames, "keyword", projection~keyword)
  ignore = self~putScalar(values, rawValues, typeNames, "runway_designator", projection~runwayDesignator)
  ignore = self~putScalar(values, rawValues, typeNames, "condition", projection~condition)
  ignore = self~putScalar(values, rawValues, typeNames, "effective_start_token", projection~effectiveStartToken)
  ignore = self~putScalar(values, rawValues, typeNames, "effective_end_token", projection~effectiveEndToken)
  ignore = self~putScalar(values, rawValues, typeNames, "end_qualifier", projection~endQualifier)
  ignore = self~putScalar(values, rawValues, typeNames, "raw_time_range", projection~rawTimeRange)
  ignore = self~putScalar(values, rawValues, typeNames, "source_path", projection~sourcePath)
  lineValue = projection~sourceLine
  if lineValue == .nil | lineValue~string = "" | lineValue~string = "0" then lineValue = .nil
  else lineValue = lineValue~string
  ignore = self~putScalar(values, rawValues, typeNames, "source_line", lineValue)
  ignore = self~putScalar(values, rawValues, typeNames, "use_classification", projection~useClassification)
  ignore = self~putScalar(values, rawValues, typeNames, "release_classification", projection~releaseClassification)
  ignore = self~putScalar(values, rawValues, typeNames, "operational_disposition", projection~operationalDisposition)
  return .CivicNotamProjectedRow~new(values, rawValues, typeNames, journalProjection)

::method nullableString private
  use arg value
  if value == .nil then return .nil
  text = value~string
  if text = "" then return .nil
  return text

::method putScalar private
  use arg values, rawValues, typeNames, name, value
  values[name] = value
  rawValues[name] = value
  typeNames[name] = "VARCHAR"
  return .true

::method copyRows private
  use arg sourceRows
  out = .array~new
  do row over sourceRows
    out~append(row~copy)
  end
  return out

::method selectWhere
  expose resultClass lastError
  use arg tableName, predicate
  rs = resultClass~new("SELECT")
  relation = self~table(tableName)
  if relation == .nil then return rs~fail("NOTFOUND", "Civic NOTAM relation not found:" tableName)
  allRows = relation~readRows
  if lastError \= "" then return rs~fail("SQLERROR", lastError)
  found = .array~new
  do row over allRows
    if predicate == .nil then found~append(row)
    else if predicate~evaluate(row, relation~definition) then found~append(row)
  end
  rs~rows = found
  rs~affectedRows = found~items
  rs~rowsScanned = allRows~items
  rs~accessPath = "CIVIC_QUEUE_EVIDENCE_SNAPSHOT_SCAN"
  return rs

::method selectAll
  use arg tableName
  return self~selectWhere(tableName, .nil)

::requires "CivicNotamJournal.cls"
::requires "CivicRelation.cls"
