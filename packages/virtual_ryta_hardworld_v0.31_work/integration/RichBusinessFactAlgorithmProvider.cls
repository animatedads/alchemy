/*
 * RichBusinessFactAlgorithmProvider.cls
 *
 * Generic evidence provider. It consumes object-valued evidence and emits
 * explicit scalar evidence/provenance relations. It does not create HardWorld
 * authority dispositions and never stringifies the native source object.
 */

::class RichBusinessFactAlgorithmProvider public
::attribute invocationCount
::attribute sourceManifest get

::method init
  expose sourceManifest
  use arg packageRoot = ''
  self~invocationCount = 0
  sourceManifest = .AlgorithmSourceManifest~new
  if packageRoot == '' then do
    sourceManifest~mode = 'LOGICAL_UNBOUND'
    sourceManifest~add('PROVIDER_VERSION', self~algorithmVersion)
    sourceManifest~add('RICH_EVIDENCE_CONTRACT', self~sourceFingerprint)
  end
  else do
    self~addSourceFile(sourceManifest, packageRoot, 'ALGREL_ENGINE', 'algorithm/AlgorithmRelation.cls')
    self~addSourceFile(sourceManifest, packageRoot, 'ALGREL_INPUT', 'algorithm/AlgorithmInputRelation.cls')
    self~addSourceFile(sourceManifest, packageRoot, 'ALGREL_CONSISTENCY', 'algorithm/AlgorithmInputConsistency.cls')
    self~addSourceFile(sourceManifest, packageRoot, 'RICH_EVIDENCE', 'algorithm/RichEvidence.cls')
    self~addSourceFile(sourceManifest, packageRoot, 'RICH_FACT_PROVIDER', 'integration/RichBusinessFactAlgorithmProvider.cls')
  end

::method addSourceFile private
  use arg manifest, packageRoot, label, relativePath
  if packageRoot~right(1) == '/' then filePath = packageRoot || relativePath
  else filePath = packageRoot || '/' || relativePath
  return manifest~addFile(label, filePath)

::method algorithmId
  return 'RICH_BUSINESS_FACTS'
::method algorithmVersion
  return 'RICH-FACT-ALGREL-0.16'
::method sourceComponent
  return 'HARDWORLD_RICH_EVIDENCE'
::method sourceVersion
  return '0.16'
::method sourceFingerprint
  return 'RICH-EVIDENCE-CONTRACT-V0.16'
::method sourceManifestHash
  return self~sourceManifest~hash
::method sourceManifestMode
  return self~sourceManifest~mode
::method determinism
  if self~sourceManifestMode == 'FILE_HASHED' then return .AlgorithmRelationConstant~DETERMINISTIC_GIVEN_MATERIALIZED_INPUT
  return .AlgorithmRelationConstant~UNVERIFIED_SOURCE_IDENTITY
::method sideEffectClass
  return 'NONE'
::method defaultMaterializePolicy
  return .AlgorithmRelationConstant~MATERIALIZE_ONCE
::method inputContract
  return 'AlgorithmInputRelationSnapshot:RICH_BUSINESS_FACT_SOURCE_V2;RICH_OBJECT=EXPLICIT;AUTHORITY=EVIDENCE_ONLY'

::method canonicalInput
  use arg inputSnapshot, context
  canonical = inputSnapshot~algorithmCanonicalText
  canonical = canonical || 'CONSUMER_CONTRACT=RICH_BUSINESS_FACT_SOURCE_V2' || '0a'x
  canonical = canonical || 'AUTHORITY=EVIDENCE_ONLY' || '0a'x
  return canonical

::method declaredSchemas
  return .array~of(self~summarySchema, self~sourceSchema, self~traceSchema)

/* Compatibility alias for direct callers; AlgorithmRelationEngine uses declaredSchemas. */
::method schemas
  return self~declaredSchemas

::method summarySchema
  schema = .AlgorithmSchema~new('RICH_FACT_SUMMARY')
  schema~add('INVOCATION_ID','TEXT',.false)
  schema~add('INPUT_CONTENT_HASH','TEXT',.false)
  schema~add('FACT_ID','TEXT',.false)
  schema~add('SEMANTIC_ROLE','TEXT',.false)
  schema~add('EVIDENCE_STATE','TEXT',.false)
  schema~add('PROJECTION_STATE','TEXT',.false)
  schema~add('SCALAR_VALUE','TEXT',.true)
  schema~add('SOURCE_COUNT','INTEGER',.false)
  schema~add('RICH_IDENTITY','TEXT',.false)
  schema~add('SOURCE_CONSISTENCY_GRADE','TEXT',.false)
  schema~add('SOURCE_CONSISTENCY_HASH','TEXT',.false)
  schema~add('INPUT_CONSISTENCY_GRADE','TEXT',.false)
  schema~add('INPUT_CONSISTENCY_HASH','TEXT',.false)
  schema~add('AUTHORITY_DISPOSITION','TEXT',.false)
  schema~add('EVIDENCE_CODE','TEXT',.false)
  return schema

::method sourceSchema
  schema = .AlgorithmSchema~new('RICH_FACT_SOURCES')
  schema~add('INVOCATION_ID','TEXT',.false)
  schema~add('FACT_ID','TEXT',.false)
  schema~add('SOURCE_ORDINAL','INTEGER',.false)
  schema~add('SOURCE_IDENTITY','TEXT',.false)
  schema~add('SOURCE_FORMAT','TEXT',.false)
  schema~add('SOURCE_KIND','TEXT',.false)
  schema~add('SOURCE_PATH','TEXT',.false)
  schema~add('SOURCE_DOCUMENT_IDENTITY','TEXT',.false)
  schema~add('SOURCE_LINE','INTEGER',.true)
  schema~add('SOURCE_COLUMN','INTEGER',.true)
  schema~add('TRANSFORMATION_IDENTITY','TEXT',.false)
  schema~add('LEXICAL_VALUE','TEXT',.true)
  schema~add('TYPED_VALUE','TEXT',.true)
  schema~add('VALIDATION_STATE','TEXT',.false)
  schema~add('NATIVE_OBJECT_PRESERVED','BOOLEAN',.false)
  return schema

::method traceSchema
  schema = .AlgorithmSchema~new('RICH_FACT_TRACE')
  schema~add('INVOCATION_ID','TEXT',.false)
  schema~add('SEQUENCE','INTEGER',.false)
  schema~add('EVENT_TEXT','TEXT',.false)
  return schema

::method evaluate
  use arg inputSnapshot, context
  self~invocationCount = self~invocationCount + 1
  algorithmResult = .AlgorithmRelationResult~new(self~algorithmId,self~algorithmVersion,self~sourceComponent,self~sourceVersion,self~sourceFingerprint,self~sourceManifestHash,context)
  summary = .AlgorithmRelation~new(self~summarySchema)
  sources = .AlgorithmRelation~new(self~sourceSchema)
  trace = .AlgorithmRelation~new(self~traceSchema)
  sequence = 0

  do inputRow over inputSnapshot~rows
    factId = inputRow~value('FACT_ID')
    richValue = inputRow~value('RICH_VALUE')
    if richValue == .nil then iterate

    scalarValue = richValue~scalarValue
    evidenceCode = 'RICH_SOURCE_VALUE'
    if richValue~projectionState == .RichEvidenceProjectionState~CARDINALITY_ERROR then evidenceCode = 'RICH_SOURCE_CARDINALITY_ERROR'
    else if richValue~projectionState == .RichEvidenceProjectionState~SCALAR_REFUSED then evidenceCode = 'RICH_SOURCE_SCALAR_REFUSED'
    else if richValue~projectionState == .RichEvidenceProjectionState~INVALID_SOURCE then evidenceCode = 'RICH_SOURCE_INVALID'

    row = summary~newRow
    ok=row~put('INVOCATION_ID',context~invocationId)
    ok=row~put('INPUT_CONTENT_HASH',inputSnapshot~contentHash)
    ok=row~put('FACT_ID',factId)
    ok=row~put('SEMANTIC_ROLE',richValue~semanticRole)
    ok=row~put('EVIDENCE_STATE',richValue~evidenceState)
    ok=row~put('PROJECTION_STATE',richValue~projectionState)
    ok=row~put('SCALAR_VALUE',scalarValue)
    ok=row~put('SOURCE_COUNT',richValue~sourceCount)
    ok=row~put('RICH_IDENTITY',richValue~canonicalIdentity)
    ok=row~put('SOURCE_CONSISTENCY_GRADE',richValue~consistencyGrade)
    ok=row~put('SOURCE_CONSISTENCY_HASH',richValue~consistencyHash)
    ok=row~put('INPUT_CONSISTENCY_GRADE',inputSnapshot~consistencyGrade)
    ok=row~put('INPUT_CONSISTENCY_HASH',inputSnapshot~consistencyHash)
    ok=row~put('AUTHORITY_DISPOSITION','EVIDENCE_ONLY')
    ok=row~put('EVIDENCE_CODE',evidenceCode)
    added=summary~addRow(row)

    ordinal = 0
    do sourceRef over richValue~sources
      ordinal = ordinal + 1
      sourceRow = sources~newRow
      ok=sourceRow~put('INVOCATION_ID',context~invocationId)
      ok=sourceRow~put('FACT_ID',factId)
      ok=sourceRow~put('SOURCE_ORDINAL',ordinal)
      ok=sourceRow~put('SOURCE_IDENTITY',sourceRef~sourceIdentity)
      ok=sourceRow~put('SOURCE_FORMAT',sourceRef~sourceFormat)
      ok=sourceRow~put('SOURCE_KIND',sourceRef~sourceKind)
      ok=sourceRow~put('SOURCE_PATH',sourceRef~sourcePath)
      ok=sourceRow~put('SOURCE_DOCUMENT_IDENTITY',sourceRef~sourceDocumentIdentity)
      ok=sourceRow~put('SOURCE_LINE',sourceRef~sourceLine)
      ok=sourceRow~put('SOURCE_COLUMN',sourceRef~sourceColumn)
      ok=sourceRow~put('TRANSFORMATION_IDENTITY',sourceRef~transformationIdentity)
      lexical = sourceRef~lexicalValue
      if lexical \== .nil then lexical = lexical~string
      typed = sourceRef~typedValue
      if typed \== .nil then typed = typed~string
      ok=sourceRow~put('LEXICAL_VALUE',lexical)
      ok=sourceRow~put('TYPED_VALUE',typed)
      ok=sourceRow~put('VALIDATION_STATE',sourceRef~validationState)
      ok=sourceRow~put('NATIVE_OBJECT_PRESERVED',sourceRef~nativeObject \== .nil)
      added=sources~addRow(sourceRow)
    end

    sequence = sequence + 1
    traceRow = trace~newRow
    ok=traceRow~put('INVOCATION_ID',context~invocationId)
    ok=traceRow~put('SEQUENCE',sequence)
    ok=traceRow~put('EVENT_TEXT','FACT ' || factId || ' role=' || richValue~semanticRole || ' state=' || richValue~evidenceState || ' projection=' || richValue~projectionState || ' sources=' || richValue~sourceCount || ' authority=EVIDENCE_ONLY')
    added=trace~addRow(traceRow)
  end

  added=algorithmResult~addRelation(summary)
  added=algorithmResult~addRelation(sources)
  added=algorithmResult~addRelation(trace)
  return algorithmResult

::requires '../algorithm/AlgorithmRelation.cls'
::requires '../algorithm/AlgorithmInputRelation.cls'
::requires '../algorithm/RichEvidence.cls'
