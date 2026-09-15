/*
 * StructuredRelationRichEvidenceAdapter v0.16
 *
 * Bridges structured_relation_plugin RichBusinessFact objects into the
 * HardWorld RichEvidence contract without copying or stringifying the native
 * XML / EDIFACT / X12 / Git source object.
 *
 * The adapter is deliberately duck-typed: it does not ::requires the
 * structured-source package. The source lane owns those classes; this lane
 * consumes their public evidence contract.
 */

::class StructuredEvidenceHistoryRecord public
::attribute nativeObject get
::attribute phase get
::attribute operation get
::attribute detail get
::attribute timestamp get

::method init
  expose nativeObject phase operation detail timestamp
  use arg nativeObjectArg, phaseArg, operationArg, detailArg = '', timestampArg = ''
  nativeObject = nativeObjectArg
  phase = phaseArg~string
  operation = operationArg~string
  detail = detailArg
  timestamp = timestampArg~string

::method algorithmCanonicalText
  expose phase operation detail
  text = 'STRUCTURED_HISTORY_V1' || '0a'x
  text = text || self~field('PHASE', phase)
  text = text || self~field('OPERATION', operation)
  if detail == .nil then text = text || 'DETAIL=NULL' || '0a'x
  else if detail~isA(.String) then text = text || self~field('DETAIL', detail)
  else if detail~hasMethod('ALGORITHMCANONICALTEXT') then text = text || self~field('DETAIL_CANONICAL', detail~algorithmCanonicalText)
  else raise syntax 93.900 additional('Structured processing history detail has no explicit canonical contract')
  /* Timestamp is retained provenance, but temporal observation quality belongs
   * in the consistency descriptor. Re-parsing identical bytes at a later wall
   * clock time must not silently change semantic content identity. */
  return text

::method field private
  use arg name, value
  rendered = value~string
  return name || '=' || rendered~length || ':' || rendered || '0a'x


::class StructuredEvidenceDiagnosticRecord public
::attribute nativeObject get
::attribute severity get
::attribute code get
::attribute message get
::attribute validator get
::attribute timestamp get
::attribute details get

::method init
  expose nativeObject severity code message validator timestamp details
  use arg nativeObjectArg, severityArg, codeArg, messageArg, validatorArg = '', timestampArg = '', detailsArg = .nil
  nativeObject = nativeObjectArg
  severity = severityArg~string~upper
  code = codeArg~string
  message = messageArg~string
  validator = validatorArg~string
  timestamp = timestampArg~string
  if detailsArg == .nil then details = .table~new
  else details = detailsArg

::method algorithmCanonicalText
  expose severity code message validator details
  text = 'STRUCTURED_DIAGNOSTIC_V2' || '0a'x
  text = text || self~field('SEVERITY', severity)
  text = text || self~field('CODE', code)
  text = text || self~field('MESSAGE', message)
  text = text || self~field('VALIDATOR', validator)
  if details \== .nil then do
    if \details~isA(.MapCollection) then raise syntax 93.900 additional('Structured diagnostic details must be a map collection')
    keys = details~allIndexes
    keys~sort
    stableCount = 0
    do key over keys
      if self~volatileDetailKey(key) then iterate
      stableCount += 1
    end
    text = text || 'DETAIL_COUNT=' || stableCount || '0a'x
    do key over keys
      if self~volatileDetailKey(key) then iterate
      rendered = self~canonicalDetailValue(details[key])
      text = text || self~field('DETAIL_KEY', key)
      text = text || self~field('DETAIL_VALUE', rendered)
    end
  end
  return text

/* Source-analysis findings carry arrays and revision-bound semantic objects in
 * their diagnostic detail maps.  Do not stringify them implicitly.  Canonical
 * identity is built from explicit public source/provenance surfaces while the
 * untouched native diagnostic remains available through nativeObject/details. */
::method canonicalDetailValue private
  use arg value
  if value == .nil then return 'NULL'
  if value == .true then return 'BOOLEAN:TRUE'
  if value == .false then return 'BOOLEAN:FALSE'
  if value~isA(.String) then return 'TEXT:' || value~length || ':' || value
  if value~isA(.Array) then do
    out = 'ARRAY_COUNT=' || value~items || '|'
    ordinal = 0
    do item over value
      ordinal += 1
      itemText = self~canonicalDetailValue(item)
      out = out || 'ITEM[' || ordinal || ']=' || itemText~length || ':' || itemText || '|'
    end
    return out
  end
  if value~isA(.MapCollection) then do
    keys = value~allIndexes
    keys~sort
    out = 'MAP_COUNT=' || keys~items || '|'
    do key over keys
      if self~volatileDetailKey(key) then iterate
      keyText = key~string
      valueText = self~canonicalDetailValue(value[key])
      out = out || 'KEY=' || keyText~length || ':' || keyText || '|'
      out = out || 'VALUE=' || valueText~length || ':' || valueText || '|'
    end
    return out
  end
  if value~hasMethod('ALGORITHMCANONICALTEXT') then do
    rendered = value~algorithmCanonicalText
    return 'ALGORITHM:' || rendered~length || ':' || rendered
  end
  if value~hasMethod('EVIDENCEIDENTITY') then do
    rendered = value~evidenceIdentity
    return 'EVIDENCE_ID:' || rendered~length || ':' || rendered
  end
  if value~hasMethod('PROVENANCE') then return self~canonicalProvenanceObject(value)
  raise syntax 93.900 additional('Structured diagnostic detail object has no explicit canonical contract')

::method canonicalProvenanceObject private
  use arg object
  className = object~class~id
  text = 'PROVENANCE_OBJECT|' || self~inlineField('CLASS', className)
  recognized = .false

  /* Exact remote Git object identity.  A claimed SHA and a verified SHA are
   * deliberately different identities. */
  if object~hasMethod('REPOSITORYSLUG') then do
    text = text || self~inlineField('REPOSITORY', object~repositorySlug)
    recognized = .true
  end
  if object~hasMethod('REVISION') then do
    text = text || self~inlineField('REVISION', object~revision)
    recognized = .true
  end
  if object~hasMethod('SOURCEPATH') then do
    text = text || self~inlineField('SOURCE_PATH', object~sourcePath)
    recognized = .true
  end
  if object~hasMethod('BLOBSHA') then do
    text = text || self~inlineField('BLOB_SHA', object~blobSha)
    recognized = .true
  end
  if object~hasMethod('COMPUTEDBLOBSHA') then do
    text = text || self~inlineField('COMPUTED_BLOB_SHA', object~computedBlobSha)
    recognized = .true
  end
  if object~hasMethod('BLOBVERIFICATIONSTATE') then do
    text = text || self~inlineField('BLOB_STATE', object~blobVerificationState)
    recognized = .true
  end

  if object~hasMethod('PATH') then do
    text = text || self~inlineField('PATH', object~path)
    recognized = .true
  end
  if object~hasMethod('SOURCESPAN') then do
    span = object~sourceSpan
    if span \== .nil then do
      text = text || self~inlineField('SOURCE_SPAN', self~sourceSpanIdentity(span))
      recognized = .true
    end
  end

  /* Semantic/value-flow discriminators. */
  methodNames = .array~of('KIND','QUALIFIEDNAME','SIGNATURE','OPERATIONKIND','CALLEE','CONDITION','SUBJECT','OPERATOR','BOUNDEXPRESSION','FROMNAME','TONAME','FLOWKIND','EXPRESSION','DESTINATION','DESTINATIONEXTENT','LENGTHEXPRESSION')
  do methodName over methodNames
    if object~hasMethod(methodName) then do
      item = object~sendWith(methodName, .array~new)
      if item \== .nil then do
        if item~isA(.String) then text = text || self~inlineField(methodName, item)
        else if datatype(item, 'N') == 1 then text = text || self~inlineField(methodName, item)
      end
      recognized = .true
    end
  end

  /* A semantic change is identified by the two revision-bound symbols and the
   * before/after operation spans rather than by recursive object traversal. */
  if object~hasMethod('BEFORESYMBOL') then do
    beforeSymbol = object~beforeSymbol
    if beforeSymbol \== .nil then text = text || self~inlineField('BEFORE_SYMBOL', self~symbolIdentity(beforeSymbol))
    recognized = .true
  end
  if object~hasMethod('AFTERSYMBOL') then do
    afterSymbol = object~afterSymbol
    if afterSymbol \== .nil then text = text || self~inlineField('AFTER_SYMBOL', self~symbolIdentity(afterSymbol))
    recognized = .true
  end
  if object~hasMethod('BEFOREOPERATION') then do
    beforeOp = object~beforeOperation
    if beforeOp \== .nil then text = text || self~inlineField('BEFORE_OPERATION', self~operationIdentity(beforeOp))
    recognized = .true
  end
  if object~hasMethod('AFTEROPERATION') then do
    afterOp = object~afterOperation
    if afterOp \== .nil then text = text || self~inlineField('AFTER_OPERATION', self~operationIdentity(afterOp))
    recognized = .true
  end

  if \recognized then raise syntax 93.900 additional('Provenance-bearing diagnostic object lacks a supported explicit identity surface:' className)
  return text

::method symbolIdentity private
  use arg symbol
  text = 'SYMBOL|'
  if symbol~hasMethod('QUALIFIEDNAME') then text = text || self~inlineField('NAME', symbol~qualifiedName)
  if symbol~hasMethod('KIND') then text = text || self~inlineField('KIND', symbol~kind)
  if symbol~hasMethod('SOURCESPAN') then do
    span = symbol~sourceSpan
    if span \== .nil then text = text || self~inlineField('SPAN', self~sourceSpanIdentity(span))
  end
  return text

::method operationIdentity private
  use arg operation
  text = 'OPERATION|'
  if operation~hasMethod('OPERATIONKIND') then text = text || self~inlineField('KIND', operation~operationKind)
  if operation~hasMethod('CALLEE') then text = text || self~inlineField('CALLEE', operation~callee)
  if operation~hasMethod('SOURCESPAN') then do
    span = operation~sourceSpan
    if span \== .nil then text = text || self~inlineField('SPAN', self~sourceSpanIdentity(span))
  end
  return text

::method sourceSpanIdentity private
  use arg span
  text = 'SPAN|'
  if span~hasMethod('PATH') then text = text || self~inlineField('PATH', span~path)
  if span~hasMethod('FILERREVISION') then nop
  if span~hasMethod('FILEREVISION') then do
    revision = span~fileRevision
    if revision \== .nil then do
      if revision~hasMethod('REPOSITORYSLUG') then text = text || self~inlineField('REPOSITORY', revision~repositorySlug)
      if revision~hasMethod('REVISION') then text = text || self~inlineField('REVISION', revision~revision)
      if revision~hasMethod('SOURCEPATH') then text = text || self~inlineField('SOURCE_PATH', revision~sourcePath)
      if revision~hasMethod('BLOBSHA') then text = text || self~inlineField('BLOB_SHA', revision~blobSha)
      if revision~hasMethod('COMPUTEDBLOBSHA') then text = text || self~inlineField('COMPUTED_BLOB_SHA', revision~computedBlobSha)
      if revision~hasMethod('BLOBVERIFICATIONSTATE') then text = text || self~inlineField('BLOB_STATE', revision~blobVerificationState)
    end
  end
  if span~hasMethod('STARTLINE') then text = text || self~inlineField('START_LINE', span~startLine)
  if span~hasMethod('ENDLINE') then text = text || self~inlineField('END_LINE', span~endLine)
  if span~hasMethod('LEXICALVALUE') then text = text || self~inlineField('LEXICAL', span~lexicalValue)
  return text

::method volatileDetailKey private
  use arg key
  name = key~string~translate
  return name == 'CREATEDAT' | name == 'TIMESTAMP' | name == 'RETRIEVEDAT'

::method inlineField private
  use arg name, value
  rendered = value~string
  return name || '=' || rendered~length || ':' || rendered || '|'

::method field private
  use arg name, value
  rendered = value~string
  return name || '=' || rendered~length || ':' || rendered || '0a'x



::class StructuredEvidenceContextRecord public
::attribute nativeFact get
::attribute nativeRow get
::attribute factName get
::attribute semanticType get
::attribute evidenceState get
::attribute relationName get
::attribute createdAt get

::method init
  expose nativeFact nativeRow factName semanticType evidenceState relationName createdAt storedAnnotations
  use arg nativeFactArg, nativeRowArg, factNameArg, semanticTypeArg, evidenceStateArg, relationNameArg = '', createdAtArg = '', annotationsArg = .nil
  nativeFact = nativeFactArg
  nativeRow = nativeRowArg
  factName = factNameArg~string
  semanticType = semanticTypeArg~string~upper
  evidenceState = evidenceStateArg~string~upper
  relationName = relationNameArg~string
  createdAt = createdAtArg~string
  storedAnnotations = .directory~new
  if annotationsArg \== .nil then do key over annotationsArg~allIndexes
    value = annotationsArg[key]
    if value == .nil then storedAnnotations[key~string] = .nil
    else if value~isA(.String) then storedAnnotations[key~string] = value
    else if value~hasMethod('ALGORITHMCANONICALTEXT') then storedAnnotations[key~string] = value~algorithmCanonicalText
    else raise syntax 93.900 additional('Structured fact annotation ' || key || ' lacks explicit canonical contract')
  end

::method annotations
  expose storedAnnotations
  copy = .directory~new
  do key over storedAnnotations~allIndexes; copy[key] = storedAnnotations[key]; end
  return copy

::method algorithmCanonicalText
  expose factName semanticType evidenceState relationName storedAnnotations
  text = 'STRUCTURED_CONTEXT_V1' || '0a'x
  text = text || self~field('FACT_NAME',factName)
  text = text || self~field('SEMANTIC_TYPE',semanticType)
  text = text || self~field('EVIDENCE_STATE',evidenceState)
  text = text || self~field('RELATION_NAME',relationName)
  keys = storedAnnotations~allIndexes
  keys~sort
  text = text || 'ANNOTATION_COUNT=' || keys~items || '0a'x
  do key over keys
    value = storedAnnotations[key]
    text = text || self~field('ANNOTATION_KEY',key)
    if value == .nil then text = text || 'ANNOTATION_VALUE=NULL' || '0a'x
    else text = text || self~field('ANNOTATION_VALUE',value)
  end
  /* createdAt is retained as provenance but, like parser event timestamps, is
   * excluded from semantic identity. */
  return text

::method field private
  use arg name, value
  rendered = value~string
  return name || '=' || rendered~length || ':' || rendered || '0a'x

::class StructuredRelationRichEvidenceAdapter public

::method adapterVersion class
  return 'STRUCTURED-RELATION-RICH-EVIDENCE-0.16'

::method contractVersion class
  return 'STRUCTURED_RELATION_RICH_EVIDENCE_V1'

::method adaptFact class
  use arg fact, consistencyGrade = 'FROZEN_OBSERVATION', consistencyHash = ''
  self~requireFactContract(fact)

  sourceObject = fact~source
  provenance = fact~sourceProvenance
  document = fact~sourceDocument
  sourcePath = fact~sourcePath
  sourceFormat = self~sourceFormat(document, provenance)
  sourceKind = self~provenanceValue(provenance, 'kind', 'UNKNOWN')~string~upper
  documentIdentity = self~documentIdentity(document, sourceFormat)
  sourceIdentity = sourceFormat || ':' || documentIdentity || ':' || sourcePath

  line = self~provenanceValue(provenance, 'line', .nil)
  column = .nil
  span = self~provenanceValue(provenance, 'span', .nil)
  if span \== .nil then do
    if span~hasMethod('STARTCOLUMN') then column = span~startColumn
  end

  transformIdentity = 'STRUCTURED_RELATION_BRIDGE_V0.16'
  if document \== .nil then do
    if document~hasMethod('TRANSFORMNAME') then do
      documentTransform = document~transformName
      if documentTransform \= '' then transformIdentity = transformIdentity || ':' || documentTransform
    end
  end

  lexical = fact~lexicalValue
  typed = fact~value
  projectionState = self~projectionState(fact)
  if projectionState \= .RichEvidenceProjectionState~SCALAR_AVAILABLE then typed = .nil
  else if typed \== .nil then do
    if \typed~isA(.String) then do
      projectionState = .RichEvidenceProjectionState~SCALAR_REFUSED
      typed = .nil
    end
  end

  validationState = self~validationState(fact)
  sourceRef = .RichEvidenceSourceRef~new(sourceObject, sourceIdentity, sourceFormat, sourceKind, sourcePath, lexical, typed, validationState, documentIdentity, line, column, transformIdentity)

  history = .array~new
  do event over fact~processingHistory
    history~append(self~historyRecord(event))
  end

  diagnostics = .array~new
  do finding over fact~diagnostics
    diagnostics~append(self~diagnosticRecord(finding))
  end

  relationName = ''
  nativeRow = fact~row
  if nativeRow \== .nil then do
    if nativeRow~hasMethod('PROJECTION') then do
      projection = nativeRow~projection
      if projection \== .nil then do
        if projection~hasMethod('NAME') then relationName = projection~name
      end
    end
  end
  contextRecord = .StructuredEvidenceContextRecord~new(fact,nativeRow,fact~name,fact~semanticType,fact~state,relationName,fact~createdAt,fact~annotations)

  canonicalIdentity = 'STRUCTURED_RELATION_FACT_V1:' || sourceIdentity || ':' || fact~name
  presentation = .nil
  if projectionState = .RichEvidenceProjectionState~SCALAR_AVAILABLE then presentation = fact~value

  return .RichEvidenceValue~new(sourceObject, canonicalIdentity, fact~name, fact~state, projectionState, presentation, .array~of(sourceRef), history, consistencyGrade, consistencyHash, diagnostics, .array~of(contextRecord))

::method combineFacts class
  use arg semanticRole, facts, consistencyGrade = 'FROZEN_OBSERVATION', consistencyHash = ''
  if facts == .nil then raise syntax 93.900 additional('Structured fact set is required')
  if facts~items = 0 then return .RichEvidenceValue~new(.array~new,'STRUCTURED_RELATION_SET:EMPTY:' || semanticRole,semanticRole,'ABSENT',.RichEvidenceProjectionState~ABSENT,.nil,.array~new,.array~new,consistencyGrade,consistencyHash,.array~new)

  /* Adapt each fact independently first, then canonicalise source order. */
  buckets = .directory~new
  keys = .array~new
  do fact over facts
    rich = self~adaptFact(fact, consistencyGrade, consistencyHash)
    key = rich~algorithmCanonicalText
    if buckets~hasIndex(key) then bucket = buckets[key]
    else do
      bucket = .array~new
      buckets[key] = bucket
      keys~append(key)
    end
    bucket~append(rich)
  end
  keys~sort

  nativeObjects = .array~new
  sources = .array~new
  history = .array~new
  diagnostics = .array~new
  contexts = .array~new
  values = .array~new
  allScalar = .true
  do key over keys
    bucket = buckets[key]
    do rich over bucket
      nativeObjects~append(rich~nativeObject)
      do sourceRef over rich~sources; sources~append(sourceRef); end
      do historyItem over rich~processingHistory; history~append(historyItem); end
      do diagnosticItem over rich~diagnostics; diagnostics~append(diagnosticItem); end
      do contextItem over rich~contexts; contexts~append(contextItem); end
      if rich~scalarProjectionAllowed then values~append(rich~scalarValue)
      else allScalar = .false
    end
  end

  projectionState = .RichEvidenceProjectionState~SCALAR_REFUSED
  evidenceState = 'UNRESOLVED'
  presentation = .nil
  if allScalar & values~items = facts~items then do
    firstValue = values[1]
    same = .true
    do i = 2 to values~items
      if values[i] \== firstValue then same = .false
    end
    if same then do
      evidenceState = 'PRESENT'
      projectionState = .RichEvidenceProjectionState~SCALAR_AVAILABLE
      presentation = firstValue
    end
    else evidenceState = 'CONFLICT'
  end

  canonicalIdentity = 'STRUCTURED_RELATION_SET_V1:' || semanticRole || ':SOURCES=' || sources~items
  return .RichEvidenceValue~new(nativeObjects,canonicalIdentity,semanticRole,evidenceState,projectionState,presentation,sources,history,consistencyGrade,consistencyHash,diagnostics,contexts)

::method requireFactContract class private
  use arg fact
  if fact == .nil then raise syntax 93.900 additional('Structured RichBusinessFact is required')
  required = .array~of('NAME','VALUE','STATE','SOURCE','SEMANTICTYPE','LEXICALVALUE','DIAGNOSTICS','ANNOTATIONS','ROW','CREATEDAT','SOURCEPROVENANCE','SOURCEDOCUMENT','SOURCEPATH','PROCESSINGHISTORY')
  do methodName over required
    if \fact~hasMethod(methodName) then raise syntax 93.900 additional('Structured fact missing method ' || methodName)
  end
  return .true

::method sourceFormat class private
  use arg document, provenance
  kind = self~provenanceValue(provenance, 'kind', '')~string~upper
  if kind~left(8) = 'EDIFACT_' then return 'EDIFACT'
  if kind~left(4) = 'X12_' then return 'X12'
  if document \== .nil then do
    if document~hasMethod('PARSERNAME') then do
      parserName = document~parserName~string~upper
      if parserName~pos('EDIFACT') > 0 then return 'EDIFACT'
      if parserName~pos('X12') > 0 then return 'X12'
      if parserName~pos('XML') > 0 then return 'XML'
    end
  end
  /* XML provenance kinds are intentionally native names such as ELEMENT and
   * ATTRIBUTE rather than XML_* aliases. */
  if self~provenanceValue(provenance, 'qName', .nil) \== .nil then return 'XML'
  if self~provenanceValue(provenance, 'namespaceUri', .nil) \== .nil then return 'XML'
  return 'STRUCTURED'

::method documentIdentity class private
  use arg document, sourceFormat
  if document == .nil then return sourceFormat || ':NO_DOCUMENT'
  source = ''
  parser = ''
  sourceHash = ''
  if document~hasMethod('SOURCE') then source = document~source
  if document~hasMethod('PARSERNAME') then parser = document~parserName
  if document~hasMethod('SOURCETEXT') then do
    sourceText = document~sourceText
    if sourceText \== .nil then do
      if \sourceText~isA(.String) then raise syntax 93.900 additional('Structured source text is not scalar text')
      sourceHash = .AlgorithmDigest~sha256Text(sourceText)
    end
  end
  return sourceFormat || ':SOURCE=' || source || ':PARSER=' || parser || ':SHA256=' || sourceHash

::method projectionState class private
  use arg fact
  state = fact~state~string~upper
  select
    when state = 'PRESENT' then return .RichEvidenceProjectionState~SCALAR_AVAILABLE
    when state = 'PRESENT_EMPTY' then return .RichEvidenceProjectionState~SCALAR_AVAILABLE
    when state = 'MULTI' then return .RichEvidenceProjectionState~CARDINALITY_ERROR
    when state = 'ABSENT' then return .RichEvidenceProjectionState~ABSENT
    when state = 'INVALID' then return .RichEvidenceProjectionState~INVALID_SOURCE
    otherwise return .RichEvidenceProjectionState~SCALAR_REFUSED
  end

::method validationState class private
  use arg fact
  if fact~diagnostics~items = 0 then return 'UNVALIDATED'
  sawError = .false
  sawFinding = .false
  do finding over fact~diagnostics
    sawFinding = .true
    if finding~hasMethod('SEVERITY') then do
      if finding~severity~string~upper = 'ERROR' then sawError = .true
    end
  end
  if sawError then return 'INVALID'
  if sawFinding then return 'VALID_WITH_FINDINGS'
  return 'UNVALIDATED'

::method historyRecord class private
  use arg event
  if event == .nil then raise syntax 93.900 additional('Nil structured processing event')
  required = .array~of('PHASE','OPERATION','DETAIL','TIMESTAMP')
  do methodName over required
    if \event~hasMethod(methodName) then raise syntax 93.900 additional('Processing event missing method ' || methodName)
  end
  return .StructuredEvidenceHistoryRecord~new(event,event~phase,event~operation,event~detail,event~timestamp)

::method diagnosticRecord class private
  use arg finding
  if finding == .nil then raise syntax 93.900 additional('Nil structured diagnostic')
  required = .array~of('SEVERITY','CODE','MESSAGE','VALIDATOR','TIMESTAMP','DETAILS')
  do methodName over required
    if \finding~hasMethod(methodName) then raise syntax 93.900 additional('Diagnostic missing method ' || methodName)
  end
  return .StructuredEvidenceDiagnosticRecord~new(finding,finding~severity,finding~code,finding~message,finding~validator,finding~timestamp,finding~details)

::method provenanceValue class private
  use arg provenance, key, defaultValue = .nil
  if provenance == .nil then return defaultValue
  value = provenance[key]
  if value == .nil then return defaultValue
  return value

::requires '../algorithm/AlgorithmIntegrity.cls'
::requires '../algorithm/RichEvidence.cls'
