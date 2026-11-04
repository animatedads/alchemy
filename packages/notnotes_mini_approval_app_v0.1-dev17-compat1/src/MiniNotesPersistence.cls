/* MiniNotesPersistence.cls
 * Durable Mini NotNotes application persistence over NoSQLServer's file engine.
 * This is an application-store adapter: NotNotes remains the document authority.
 */

::class MiniNotesPersistence public

::method init
  expose root db
  use strict arg requestedRoot = ""
  root = requestedRoot~strip
  if root = "" then root = value("MININOTES_DB_ROOT",, "ENVIRONMENT")
  if root = "" then root = "data/mininotes"
  db = .FileDatabaseEngine~new(root)
  self~ensureSchema

::method root
  expose root
  return root

::method database
  expose db
  return db

::method ensureSchema
  expose db
  if db~table("formats") == .nil then do
    resultObject = self~createFormatsTable
    if resultObject~status \= .Error~SUCCESS then raise syntax 93.900 array("cannot create Mini Notes formats table:" resultObject~message)
  end
  if db~table("documents") == .nil then do
    resultObject = self~createDocumentsTable
    if resultObject~status \= .Error~SUCCESS then raise syntax 93.900 array("cannot create Mini Notes documents table:" resultObject~message)
  end
  if db~table("reports") == .nil then do
    resultObject = self~createReportsTable
    if resultObject~status \= .Error~SUCCESS then raise syntax 93.900 array("cannot create Mini Notes reports table:" resultObject~message)
  end
  if db~table("subviews") == .nil then do
    resultObject = self~createSubviewsTable
    if resultObject~status \= .Error~SUCCESS then raise syntax 93.900 array("cannot create Mini Notes subviews table:" resultObject~message)
  end
  if db~table("relationships") == .nil then do
    resultObject = self~createRelationshipsTable
    if resultObject~status \= .Error~SUCCESS then raise syntax 93.900 array("cannot create Mini Notes relationships table:" resultObject~message)
  end
  if db~table("temporal_evidence") == .nil then do
    resultObject = self~createTemporalEvidenceTable
    if resultObject~status \= .Error~SUCCESS then raise syntax 93.900 array("cannot create Mini Notes temporal evidence table:" resultObject~message)
  end
  return self

::method createFormatsTable
  expose db
  columns = .array~of( -
    .DatabaseColumn~new("format_name", "VARCHAR", .false, .true, .true), -
    .DatabaseColumn~new("fields_hex", "TEXT", .false))
  return db~createTable("formats", columns, .array~of("format_name"))

::method createReportsTable
  expose db
  columns = .array~of( -
    .DatabaseColumn~new("report_name", "VARCHAR", .false, .true, .true), -
    .DatabaseColumn~new("source_form", "VARCHAR", .false), -
    .DatabaseColumn~new("columns_hex", "TEXT", .false), -
    .DatabaseColumn~new("totals_hex", "TEXT", .false))
  return db~createTable("reports", columns, .array~of("report_name"))

::method createSubviewsTable
  expose db
  columns = .array~of( -
    .DatabaseColumn~new("identity", "VARCHAR", .false, .true, .true), -
    .DatabaseColumn~new("parent_form", "VARCHAR", .false), -
    .DatabaseColumn~new("subview_name", "VARCHAR", .false), -
    .DatabaseColumn~new("source_form", "VARCHAR", .false), -
    .DatabaseColumn~new("link_field", "VARCHAR", .false), -
    .DatabaseColumn~new("columns_hex", "TEXT", .false), -
    .DatabaseColumn~new("row_calcs_hex", "TEXT", .false), -
    .DatabaseColumn~new("column_calcs_hex", "TEXT", .false))
  return db~createTable("subviews", columns, .array~of("identity"))

::method createRelationshipsTable
  expose db
  columns = .array~of( -
    .DatabaseColumn~new("source_form", "VARCHAR", .false), -
    .DatabaseColumn~new("field_name", "VARCHAR", .false), -
    .DatabaseColumn~new("target_form", "VARCHAR", .false), -
    .DatabaseColumn~new("cardinality", "VARCHAR", .false), -
    .DatabaseColumn~new("target_key_field", "VARCHAR", .false))
  return db~createTable("relationships", columns, .array~of("source_form", "field_name"))

::method createTemporalEvidenceTable
  expose db
  columns = .array~of( -
    .DatabaseColumn~new("doc_key", "VARCHAR", .false), -
    .DatabaseColumn~new("field_name", "VARCHAR", .false), -
    .DatabaseColumn~new("kind", "VARCHAR", .false), -
    .DatabaseColumn~new("canonical_value", "TEXT", .false), -
    .DatabaseColumn~new("zone", "VARCHAR", .false), -
    .DatabaseColumn~new("instant_posix_seconds", "VARCHAR", .false), -
    .DatabaseColumn~new("tzdb_edition", "VARCHAR", .false), -
    .DatabaseColumn~new("resolution", "VARCHAR", .false))
  return db~createTable("temporal_evidence", columns, .array~of("doc_key", "field_name"))

::method createDocumentsTable
  expose db
  columns = .array~of( -
    .DatabaseColumn~new("doc_key", "VARCHAR", .false, .true, .true), -
    .DatabaseColumn~new("form_name", "VARCHAR", .false), -
    .DatabaseColumn~new("title", "TEXT", .false), -
    .DatabaseColumn~new("amount", "DECIMAL", .false), -
    .DatabaseColumn~new("risk", "VARCHAR", .false), -
    .DatabaseColumn~new("depends_on", "TEXT", .false), -
    .DatabaseColumn~new("workflow", "TEXT", .false), -
    .DatabaseColumn~new("status", "VARCHAR", .false), -
    .DatabaseColumn~new("fields_hex", "TEXT", .false))
  return db~createTable("documents", columns, .array~of("doc_key"))

::method saveFrom
  expose db
  use strict arg app
  dropResult = db~dropTable("formats")
  if dropResult~status \= .Error~SUCCESS then raise syntax 93.900 array("cannot reset formats table:" dropResult~message)
  createResult = self~createFormatsTable
  if createResult~status \= .Error~SUCCESS then raise syntax 93.900 array("cannot recreate formats table:" createResult~message)
  do formatName over app~userFormatNames
    row = .table~new
    row["format_name"] = formatName
    row["fields_hex"] = self~encodeFieldSpecs(app~userFormatFields(formatName))
    resultObject = db~insert("formats", row)
    if resultObject~status \= .Error~SUCCESS then raise syntax 93.900 array("cannot save document format:" formatName)
  end

  dropResult = db~dropTable("reports")
  if dropResult~status \= .Error~SUCCESS then raise syntax 93.900 array("cannot reset reports table:" dropResult~message)
  createResult = self~createReportsTable
  if createResult~status \= .Error~SUCCESS then raise syntax 93.900 array("cannot recreate reports table:" createResult~message)
  do reportName over app~reportDefinitionNames
    report = app~reportDefinition(reportName)
    row = .table~new
    row["report_name"] = report["NAME"]
    row["source_form"] = report["SOURCE_FORM"]
    row["columns_hex"] = self~encodeReportColumns(report["COLUMNS"])
    row["totals_hex"] = self~encodeStringArray(report["TOTALS"])
    resultObject = db~insert("reports", row)
    if resultObject~status \= .Error~SUCCESS then raise syntax 93.900 array("cannot save report definition:" report["NAME"])
  end

  dropResult = db~dropTable("relationships")
  if dropResult~status \= .Error~SUCCESS then raise syntax 93.900 array("cannot reset relationships table:" dropResult~message)
  createResult = self~createRelationshipsTable
  if createResult~status \= .Error~SUCCESS then raise syntax 93.900 array("cannot recreate relationships table:" createResult~message)
  do formatName over app~userFormatNames
    do spec over app~userFormatFields(formatName)
      specType = spec["TYPE"]~upper
      if specType \= "DOCUMENT_REFERENCE" then iterate
      if \spec~hasIndex("REF_TARGET") then iterate
      targetForm = spec["REF_TARGET"]~string~strip
      if targetForm = "" then iterate
      row = .table~new
      row["source_form"] = formatName
      row["field_name"] = spec["NAME"]
      row["target_form"] = targetForm
      cardinality = "ONE"
      if spec~hasIndex("CARDINALITY") then cardinality = spec["CARDINALITY"]~string~upper
      row["cardinality"] = cardinality
      row["target_key_field"] = "DocKey"
      resultObject = db~insert("relationships", row)
      if resultObject~status \= .Error~SUCCESS then raise syntax 93.900 array("cannot save relationship:" formatName || "." || spec["NAME"])
    end
  end

  dropResult = db~dropTable("subviews")
  if dropResult~status \= .Error~SUCCESS then raise syntax 93.900 array("cannot reset subviews table:" dropResult~message)
  createResult = self~createSubviewsTable
  if createResult~status \= .Error~SUCCESS then raise syntax 93.900 array("cannot recreate subviews table:" createResult~message)
  do identity over app~subviewDefinitionNames
    definition = app~subviewDefinitionByIdentity(identity)
    row = .table~new
    row["identity"] = identity
    row["parent_form"] = definition["PARENT_FORM"]
    row["subview_name"] = definition["NAME"]
    row["source_form"] = definition["SOURCE_FORM"]
    row["link_field"] = definition["LINK_FIELD"]
    row["columns_hex"] = self~encodeNamedSpecs(definition["COLUMNS"])
    row["row_calcs_hex"] = self~encodeNamedSpecs(definition["ROW_CALCS"])
    row["column_calcs_hex"] = self~encodeNamedSpecs(definition["COLUMN_CALCS"])
    resultObject = db~insert("subviews", row)
    if resultObject~status \= .Error~SUCCESS then raise syntax 93.900 array("cannot save subview definition:" identity)
  end

  /* Documents are append/update persisted in place. Rebuilding this table on
   * every save destroys the journal for a large imported dataset and can leave
   * the table directory half removed if a filesystem handle is still active. */
  existingResult = db~selectAll("documents")
  if existingResult~status \= .Error~SUCCESS then raise syntax 93.900 array("cannot read Mini Notes documents table:" existingResult~message)
  existingKeys = .Directory~new
  do oldRow over existingResult~rows
    existingKeys[oldRow["doc_key"]~string~upper] = oldRow
  end
  do document over app~allDocuments
    row = .table~new
    row["doc_key"] = document~DocKey
    row["form_name"] = document~formName
    row["title"] = document~Title
    row["amount"] = document~Amount
    row["risk"] = document~Risk
    row["depends_on"] = document~DependsOn
    row["workflow"] = document~Workflow
    row["status"] = document~ApprovalStatus
    row["fields_hex"] = self~encodeCustomFields(document)
    key = document~DocKey~string~upper
    if existingKeys~hasIndex(key) then do
      oldRow = existingKeys[key]
      changed = .false
      assignments = .table~new
      do column over .array~of("form_name", "title", "amount", "risk", "depends_on", "workflow", "status", "fields_hex")
        oldValue = oldRow[column]
        newValue = row[column]
        if oldValue == .nil then oldValue = ""
        if newValue == .nil then newValue = ""
        if oldValue~string \= newValue~string then do
          changed = .true
          assignments[column] = row[column]
        end
      end
      if changed then resultObject = db~updateWhereEquals("documents", "doc_key", document~DocKey, assignments)
      else iterate
    end
    else resultObject = db~insert("documents", row)
    if resultObject~status \= .Error~SUCCESS then raise syntax 93.900 array("cannot save document:" document~DocKey || " status=" || resultObject~status || " message=" || resultObject~message)
  end
  dropResult = db~dropTable("temporal_evidence")
  if dropResult~status \= .Error~SUCCESS then raise syntax 93.900 array("cannot reset temporal evidence table:" dropResult~message)
  createResult = self~createTemporalEvidenceTable
  if createResult~status \= .Error~SUCCESS then raise syntax 93.900 array("cannot recreate temporal evidence table:" createResult~message)
  do evidence over app~temporalEvidenceRecords
    row = .table~new
    row["doc_key"] = evidence["DOC_KEY"]
    row["field_name"] = evidence["FIELD_NAME"]
    row["kind"] = self~evidenceValue(evidence, "KIND")
    row["canonical_value"] = self~evidenceValue(evidence, "VALUE")
    row["zone"] = self~evidenceValue(evidence, "ZONE")
    row["instant_posix_seconds"] = self~evidenceValue(evidence, "INSTANT_POSIX_SECONDS")
    row["tzdb_edition"] = self~evidenceValue(evidence, "TZDB_EDITION")
    row["resolution"] = self~evidenceValue(evidence, "RESOLUTION")
    resultObject = db~insert("temporal_evidence", row)
    if resultObject~status \= .Error~SUCCESS then raise syntax 93.900 array("cannot save temporal evidence:" evidence["DOC_KEY"] || "." || evidence["FIELD_NAME"])
  end
  return .true

::method evidenceValue
  use strict arg evidence, key
  if evidence~hasIndex(key) then return evidence[key]
  return ""

::method loadInto
  expose db
  use strict arg app
  relationships = .Directory~new
  relationshipsResult = db~selectAll("relationships")
  if relationshipsResult~status = .Error~SUCCESS then do relationshipRow over relationshipsResult~rows
    relationshipKey = relationshipRow["source_form"]~string~upper || ":" || relationshipRow["field_name"]~string~upper
    relationship = .Directory~new
    relationship["TARGET_FORM"] = relationshipRow["target_form"]
    relationship["CARDINALITY"] = relationshipRow["cardinality"]
    relationship["TARGET_KEY_FIELD"] = relationshipRow["target_key_field"]
    relationships[relationshipKey] = relationship
  end

  formatsResult = db~selectAll("formats")
  if formatsResult~status = .Error~SUCCESS then do row over formatsResult~rows
    formatName = row["format_name"]
    fields = self~decodeFieldSpecs(row["fields_hex"])
    do spec over fields
      if spec["TYPE"]~upper \= "DOCUMENT_REFERENCE" then iterate
      relationshipKey = formatName~string~upper || ":" || spec["NAME"]~string~upper
      if relationships~hasIndex(relationshipKey) = 0 then iterate
      if \spec~hasIndex("REF_TARGET") then spec["REF_TARGET"] = relationships[relationshipKey]["TARGET_FORM"]
      if \spec~hasIndex("CARDINALITY") then spec["CARDINALITY"] = relationships[relationshipKey]["CARDINALITY"]
    end
    app~installUserFormat(formatName, fields)
  end

  reportsResult = db~selectAll("reports")
  if reportsResult~status = .Error~SUCCESS then do row over reportsResult~rows
    columns = self~decodeReportColumns(row["columns_hex"])
    totals = self~decodeStringArray(row["totals_hex"])
    app~installReportDefinition(row["report_name"], row["source_form"], columns, totals)
  end

  subviewsResult = db~selectAll("subviews")
  if subviewsResult~status = .Error~SUCCESS then do row over subviewsResult~rows
    columns = self~decodeNamedSpecs(row["columns_hex"])
    rowCalcs = self~decodeNamedSpecs(row["row_calcs_hex"])
    columnCalcs = self~decodeNamedSpecs(row["column_calcs_hex"])
    app~installSubviewDefinition(row["parent_form"], row["subview_name"], row["source_form"], row["link_field"], columns, rowCalcs, columnCalcs)
  end

  documentsResult = db~selectAll("documents")
  if documentsResult~status \= .Error~SUCCESS then return 0
  records = .array~new
  do row over documentsResult~rows
    record = .Directory~new
    record["DOC_KEY"] = row["doc_key"]
    record["FORM_NAME"] = row["form_name"]
    record["TITLE"] = row["title"]
    record["AMOUNT"] = row["amount"]
    record["RISK"] = row["risk"]
    record["DEPENDS_ON"] = row["depends_on"]
    record["WORKFLOW"] = row["workflow"]
    record["STATUS"] = row["status"]
    record["FIELDS"] = self~decodeCustomFields(row["fields_hex"])
    app~restoreDocumentRecord(record)
    records~append(record)
  end
  do record over records
    app~restoreDocumentState(record)
  end
  temporalResult = db~selectAll("temporal_evidence")
  if temporalResult~status = .Error~SUCCESS then do row over temporalResult~rows
    evidence = .Directory~new
    evidence["DOC_KEY"] = row["doc_key"]
    evidence["FIELD_NAME"] = row["field_name"]
    evidence["STATUS"] = "VALID"
    evidence["KIND"] = row["kind"]
    evidence["VALUE"] = row["canonical_value"]
    if row["zone"]~string <> "" then evidence["ZONE"] = row["zone"]
    if row["instant_posix_seconds"]~string <> "" then evidence["INSTANT_POSIX_SECONDS"] = row["instant_posix_seconds"]
    if row["tzdb_edition"]~string <> "" then evidence["TZDB_EDITION"] = row["tzdb_edition"]
    if row["resolution"]~string <> "" then evidence["RESOLUTION"] = row["resolution"]
    ignore = app~restoreTemporalEvidence(evidence)
  end
  return records~items

::method encodeFieldSpecs
  use strict arg fieldSpecs
  out = ""
  do spec over fieldSpecs
    refTarget = ""
    calcExpr = ""
    resultType = ""
    cardinality = ""
    timeZone = ""
    ambiguityPolicy = ""
    if spec~hasIndex("REF_TARGET") then refTarget = spec["REF_TARGET"]
    if spec~hasIndex("CALC_EXPR") then calcExpr = spec["CALC_EXPR"]
    if spec~hasIndex("RESULT_TYPE") then resultType = spec["RESULT_TYPE"]
    if spec~hasIndex("CARDINALITY") then cardinality = spec["CARDINALITY"]
    if spec~hasIndex("TIME_ZONE") then timeZone = spec["TIME_ZONE"]
    if spec~hasIndex("AMBIGUITY_POLICY") then ambiguityPolicy = spec["AMBIGUITY_POLICY"]
    token = c2x(spec["NAME"]) || ":" || c2x(spec["LABEL"]) || ":" || c2x(spec["TYPE"]) || ":" || c2x(refTarget) || ":" || c2x(calcExpr) || ":" || c2x(resultType) || ":" || c2x(cardinality) || ":" || c2x(timeZone) || ":" || c2x(ambiguityPolicy)
    if out <> "" then out = out || ";"
    out = out || token
  end
  return out

::method decodeFieldSpecs
  use strict arg encoded
  out = .array~new
  if encoded == .nil then return out
  rest = encoded~string
  do while rest <> ""
    parse var rest token ";" rest
    if token = "" then iterate
    parts = self~splitFieldSpec(token)
    if parts~items < 3 then raise syntax 93.900 array("persisted field specification has fewer than three fields")
    if parts~items > 10 then raise syntax 93.900 array("persisted field specification has unsupported trailing fields")
    if parts~items = 10 then do
      if parts[10] <> "" then raise syntax 93.900 array("persisted field specification has non-empty legacy trailing field")
    end
    spec = .Directory~new
    spec["NAME"] = self~decodeFieldSpecHex(parts, 1, "NAME")
    spec["LABEL"] = self~decodeFieldSpecHex(parts, 2, "LABEL")
    spec["TYPE"] = self~decodeFieldSpecHex(parts, 3, "TYPE")
    fieldValue = self~decodeFieldSpecHex(parts, 4, "REF_TARGET")
    if fieldValue <> "" then spec["REF_TARGET"] = fieldValue
    fieldValue = self~decodeFieldSpecHex(parts, 5, "CALC_EXPR")
    if fieldValue <> "" then spec["CALC_EXPR"] = fieldValue
    fieldValue = self~decodeFieldSpecHex(parts, 6, "RESULT_TYPE")
    if fieldValue <> "" then spec["RESULT_TYPE"] = fieldValue
    fieldValue = self~decodeFieldSpecHex(parts, 7, "CARDINALITY")
    if fieldValue <> "" then spec["CARDINALITY"] = fieldValue
    fieldValue = self~decodeFieldSpecHex(parts, 8, "TIME_ZONE")
    if fieldValue <> "" then spec["TIME_ZONE"] = fieldValue
    fieldValue = self~decodeFieldSpecHex(parts, 9, "AMBIGUITY_POLICY")
    if fieldValue <> "" then spec["AMBIGUITY_POLICY"] = fieldValue
    out~append(spec)
  end
  return out

::method splitFieldSpec private
  use strict arg token
  parts = .Array~new
  remaining = token
  do forever
    delimiter = pos(":", remaining)
    if delimiter = 0 then do
      parts~append(remaining)
      leave
    end
    parts~append(left(remaining, delimiter - 1))
    remaining = substr(remaining, delimiter + 1)
  end
  return parts

::method decodeFieldSpecHex private
  use strict arg parts, index, label
  if parts~items < index then return ""
  fieldValue = parts[index]~string
  if fieldValue = "" then return ""
  if fieldValue~length // 2 <> 0 then raise syntax 93.900 array("persisted field specification has odd-length hex for" label)
  if verify(fieldValue, "0123456789abcdefABCDEF") <> 0 then raise syntax 93.900 array("persisted field specification has invalid hex for" label)
  return x2c(fieldValue)

::method encodeCustomFields
  use strict arg document
  standardFields = "DOCKEY TITLE AMOUNT RISK DEPENDSON WORKFLOW APPROVALS REFERRALS"
  out = ""
  do fieldName over document~fieldNames
    if wordpos(fieldName~upper, standardFields) > 0 then iterate
    value = document~field(fieldName)
    if value == .nil then value = ""
    token = c2x(fieldName) || ":" || c2x(value~string)
    if out <> "" then out = out || ";"
    out = out || token
  end
  return out

::method decodeCustomFields
  use strict arg encoded
  out = .Directory~new
  if encoded == .nil then return out
  rest = encoded~string
  do while rest <> ""
    parse var rest token ";" rest
    if token = "" then iterate
    parse var token nameHex ":" valueHex
    out[x2c(nameHex)] = x2c(valueHex)
  end
  return out


::method encodeReportColumns
  use strict arg columns
  out = ""
  do column over columns
    token = c2x(column["LABEL"]) || ":" || c2x(column["BINDING"])
    if out <> "" then out = out || ";"
    out = out || token
  end
  return out

::method decodeReportColumns
  use strict arg encoded
  out = .Array~new
  if encoded == .nil then return out
  rest = encoded~string
  do while rest <> ""
    parse var rest token ";" rest
    if token = "" then iterate
    parse var token labelHex ":" bindingHex
    column = .Directory~new
    column["LABEL"] = x2c(labelHex)
    column["BINDING"] = x2c(bindingHex)
    out~append(column)
  end
  return out

::method encodeStringArray
  use strict arg values
  out = ""
  do value over values
    if out <> "" then out = out || ";"
    out = out || c2x(value~string)
  end
  return out

::method decodeStringArray
  use strict arg encoded
  out = .Array~new
  if encoded == .nil then return out
  rest = encoded~string
  do while rest <> ""
    parse var rest token ";" rest
    if token = "" then iterate
    out~append(x2c(token))
  end
  return out

::method encodeNamedSpecs
  use strict arg specs
  out = ""
  do spec over specs
    pairs = ""
    do key over spec
      pair = c2x(key~string) || "=" || c2x(spec[key]~string)
      if pairs <> "" then pairs = pairs || ","
      pairs = pairs || pair
    end
    if out <> "" then out = out || ";"
    out = out || pairs
  end
  return out

::method decodeNamedSpecs
  use strict arg encoded
  out = .Array~new
  if encoded == .nil then return out
  rest = encoded~string
  do while rest <> ""
    parse var rest token ";" rest
    if token = "" then iterate
    spec = .Directory~new
    pairs = token
    do while pairs <> ""
      parse var pairs pair "," pairs
      parse var pair keyHex "=" valueHex
      if keyHex <> "" then spec[x2c(keyHex)] = x2c(valueHex)
    end
    out~append(spec)
  end
  return out

::requires 'vendor/nosql/NoSQLServer.cls'
