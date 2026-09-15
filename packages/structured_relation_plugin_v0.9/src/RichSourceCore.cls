/*
 * RichSourceCore v0.4
 *
 * Format-neutral provenance/value carriers for structured source adapters.
 * XML, EDI X12, EDIFACT and future adapters can project through these objects
 * without throwing away source identity, lexical form, diagnostics or history.
 */

::class RichProcessingEvent public
::attribute phase get
::attribute operation get
::attribute timestamp get
::attribute detail get
::attribute source get

::method init
  expose phase operation timestamp detail source
  use arg phaseArg, operationArg, detailArg = "", sourceArg = .nil
  phase = phaseArg~string
  operation = operationArg~string
  detail = detailArg
  source = sourceArg
  timestamp = .DateTime~new~utcIsoDate

::method string
  expose phase operation timestamp
  return timestamp || " " || phase || ":" || operation


::class RichSourceFinding public
::attribute severity get
::attribute code get
::attribute message get
::attribute source get
::attribute timestamp get
::attribute validator get
::attribute details get

::method init
  expose severity code message source timestamp validator details
  use arg severityArg, codeArg, messageArg, sourceArg = .nil, validatorArg = "", detailsArg = .nil
  severity = severityArg~string~translate
  code = codeArg~string
  message = messageArg~string
  source = sourceArg
  validator = validatorArg~string
  if detailsArg == .nil then details = .table~new
  else details = detailsArg
  timestamp = .DateTime~new~utcIsoDate

::method string
  expose severity code message
  return severity || " " || code || ": " || message


::class RichProjectionValue public
::attribute name get
::attribute semanticType get
::attribute value get
::attribute lexicalValue get
::attribute source get
::attribute state get
::attribute diagnostics get
::attribute createdAt get

::method init
  expose name semanticType value lexicalValue source state diagnostics createdAt
  use arg nameArg, semanticTypeArg, valueArg, lexicalValueArg, sourceArg, stateArg, diagnosticsArg = .nil
  name = nameArg~string
  semanticType = semanticTypeArg~string~translate
  value = valueArg
  lexicalValue = lexicalValueArg
  source = sourceArg
  state = stateArg~string~translate
  if diagnosticsArg == .nil then diagnostics = .array~new
  else diagnostics = diagnosticsArg
  createdAt = .DateTime~new~utcIsoDate

::method isUsable
  expose state
  if state = "PRESENT" then return .true
  if state = "PRESENT_EMPTY" then return .true
  if state = "MULTI" then return .true
  return .false

::method addDiagnostic
  expose diagnostics
  use arg finding
  diagnostics~append(finding)
  return finding

::method fact
  expose name semanticType value lexicalValue source state diagnostics
  use arg row = .nil
  return .RichBusinessFact~new(name, value, state, source, row, semanticType, lexicalValue, diagnostics)

::method sourceProvenance
  expose source
  if source == .nil then return .nil
  if source~hasMethod("PROVENANCE") then return source~provenance
  return .nil

::method isEvidenceBearing
  expose source
  return source \== .nil

::method sourceDocument
  expose source
  if source == .nil then return .nil
  if source~hasMethod("DOCUMENT") then return source~document
  p = self~sourceProvenance
  if p \== .nil then return p["document"]
  return .nil

::method sourcePath
  expose source
  if source == .nil then return ""
  if source~hasMethod("PATH") then return source~path
  p = self~sourceProvenance
  if p \== .nil then do
    v = p["path"]
    if v \== .nil then return v
  end
  return ""

::method processingHistory
  d = self~sourceDocument
  if d == .nil then return .array~new
  if d~hasMethod("HISTORY") then return d~history
  return .array~new

::method evidence
  expose name semanticType value lexicalValue source state diagnostics createdAt
  e = .table~new
  e["name"] = name
  e["semanticType"] = semanticType
  e["value"] = value
  e["lexicalValue"] = lexicalValue
  e["state"] = state
  e["source"] = source
  e["sourceProvenance"] = self~sourceProvenance
  e["sourceDocument"] = self~sourceDocument
  e["sourcePath"] = self~sourcePath
  e["diagnostics"] = diagnostics
  e["processingHistory"] = self~processingHistory
  e["createdAt"] = createdAt
  return e

::method string
  expose name state value
  if value == .nil then return "RICH-VALUE(" || name || "," || state || ")"
  return value~string


::class RichBusinessFact public
::attribute name get
::attribute value get
::attribute state get
::attribute source get
::attribute row get
::attribute semanticType get
::attribute lexicalValue get
::attribute diagnostics get
::attribute createdAt get
::attribute annotations get

::method init
  expose name value state source row semanticType lexicalValue diagnostics createdAt annotations
  use arg nameArg, valueArg, stateArg, sourceArg, rowArg = .nil, semanticTypeArg = "UNKNOWN", lexicalValueArg = .nil, diagnosticsArg = .nil
  name = nameArg~string
  value = valueArg
  state = stateArg~string~translate
  source = sourceArg
  row = rowArg
  semanticType = semanticTypeArg~string~translate
  lexicalValue = lexicalValueArg
  if diagnosticsArg == .nil then diagnostics = .array~new
  else diagnostics = diagnosticsArg
  annotations = .table~new
  createdAt = .DateTime~new~utcIsoDate

::method annotate
  expose annotations
  use arg key, value
  annotations[key~string] = value
  return self

::method annotation
  expose annotations
  use arg key
  return annotations[key~string]

::method provenance
  expose source row createdAt
  p = .table~new
  p["source"] = source
  p["row"] = row
  p["createdAt"] = createdAt
  p["sourceProvenance"] = self~sourceProvenance
  return p

::method sourceProvenance
  expose source
  if source == .nil then return .nil
  if source~hasMethod("PROVENANCE") then return source~provenance
  return .nil

::method isEvidenceBearing
  expose source
  return source \== .nil

::method sourceDocument
  expose source
  if source == .nil then return .nil
  if source~hasMethod("DOCUMENT") then return source~document
  p = self~sourceProvenance
  if p \== .nil then return p["document"]
  return .nil

::method sourcePath
  expose source
  if source == .nil then return ""
  if source~hasMethod("PATH") then return source~path
  p = self~sourceProvenance
  if p \== .nil then do
    v = p["path"]
    if v \== .nil then return v
  end
  return ""

::method processingHistory
  d = self~sourceDocument
  if d == .nil then return .array~new
  if d~hasMethod("HISTORY") then return d~history
  return .array~new

::method evidence
  expose name value state source row semanticType lexicalValue diagnostics createdAt annotations
  e = .table~new
  e["fact"] = self
  e["name"] = name
  e["semanticType"] = semanticType
  e["value"] = value
  e["lexicalValue"] = lexicalValue
  e["state"] = state
  e["source"] = source
  e["sourceProvenance"] = self~sourceProvenance
  e["sourceDocument"] = self~sourceDocument
  e["sourcePath"] = self~sourcePath
  e["diagnostics"] = diagnostics
  e["processingHistory"] = self~processingHistory
  e["row"] = row
  e["annotations"] = annotations
  e["createdAt"] = createdAt
  return e

::method hasDiagnosticCode
  expose diagnostics
  use arg wantedCode
  do finding over diagnostics
    if finding~code~caselessEquals(wantedCode~string) then return .true
  end
  return .false

::method string
  expose value state
  if value == .nil then return "RICH-FACT(" || state || ")"
  return value~string
