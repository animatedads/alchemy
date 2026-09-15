/*
 * RichEvidence.cls
 *
 * Information-preserving bridge for object-valued evidence.
 * A RichEvidenceValue keeps the native source object reachable while freezing
 * the semantic/provenance fields used by deterministic Algorithm Relations.
 * Scalar presentation is explicit and may be refused.
 */

::class RichEvidenceProjectionState public
::constant SCALAR_AVAILABLE    'SCALAR_AVAILABLE'
::constant SCALAR_REFUSED      'SCALAR_REFUSED'
::constant CARDINALITY_ERROR   'CARDINALITY_ERROR'
::constant INVALID_SOURCE      'INVALID_SOURCE'
::constant ABSENT              'ABSENT'

::class RichEvidenceSourceRef public
::attribute nativeObject get
::attribute sourceIdentity get
::attribute sourceFormat get
::attribute sourceKind get
::attribute sourcePath get
::attribute sourceDocumentIdentity get
::attribute sourceLine get
::attribute sourceColumn get
::attribute transformationIdentity get
::attribute lexicalValue get
::attribute typedValue get
::attribute validationState get

::method init
  expose nativeObject sourceIdentity sourceFormat sourceKind sourcePath sourceDocumentIdentity sourceLine sourceColumn transformationIdentity lexicalValue typedValue validationState
  use arg nativeObjectArg, sourceIdentityArg, sourceFormatArg, sourceKindArg, sourcePathArg, lexicalValueArg = .nil, typedValueArg = .nil, validationStateArg = 'UNKNOWN', sourceDocumentIdentityArg = '', sourceLineArg = .nil, sourceColumnArg = .nil, transformationIdentityArg = ''
  nativeObject = nativeObjectArg
  sourceIdentity = sourceIdentityArg~string
  sourceFormat = sourceFormatArg~string~upper
  sourceKind = sourceKindArg~string~upper
  sourcePath = sourcePathArg~string
  sourceDocumentIdentity = sourceDocumentIdentityArg~string
  sourceLine = sourceLineArg
  sourceColumn = sourceColumnArg
  transformationIdentity = transformationIdentityArg~string
  lexicalValue = lexicalValueArg
  typedValue = typedValueArg
  validationState = validationStateArg~string~upper

::method canonicalText
  text = 'RICH_EVIDENCE_SOURCE_V1' || '0a'x
  text = text || self~field('IDENTITY', self~sourceIdentity)
  text = text || self~field('FORMAT', self~sourceFormat)
  text = text || self~field('KIND', self~sourceKind)
  text = text || self~field('PATH', self~sourcePath)
  text = text || self~field('DOCUMENT_IDENTITY', self~sourceDocumentIdentity)
  text = text || self~nullableField('LINE', self~sourceLine)
  text = text || self~nullableField('COLUMN', self~sourceColumn)
  text = text || self~field('TRANSFORM', self~transformationIdentity)
  text = text || self~nullableField('LEXICAL', self~lexicalValue)
  text = text || self~nullableField('TYPED', self~typedValue)
  text = text || self~field('VALIDATION', self~validationState)
  return text

::method field private
  use arg name, value
  rendered = value~string
  return name || '=' || rendered~length || ':' || rendered || '0a'x

::method nullableField private
  use arg name, value
  if value == .nil then return name || '=NULL' || '0a'x
  return self~field(name, value)


::class RichEvidenceValue public
::attribute nativeObject get
::attribute canonicalIdentity get
::attribute semanticRole get
::attribute evidenceState get
::attribute projectionState get
::attribute presentationValue get
::attribute consistencyGrade get
::attribute consistencyHash get

::method init
  expose nativeObject canonicalIdentity semanticRole evidenceState projectionState presentationValue storedSources storedHistory storedDiagnostics storedContexts consistencyGrade consistencyHash
  use arg nativeObjectArg, canonicalIdentityArg, semanticRoleArg, evidenceStateArg, projectionStateArg, presentationValueArg = .nil, sourcesArg = .nil, historyArg = .nil, consistencyGradeArg = 'FROZEN_OBSERVATION', consistencyHashArg = '', diagnosticsArg = .nil, contextsArg = .nil
  nativeObject = nativeObjectArg
  canonicalIdentity = canonicalIdentityArg~string
  semanticRole = semanticRoleArg~string~upper
  evidenceState = evidenceStateArg~string~upper
  projectionState = projectionStateArg~string~upper
  presentationValue = presentationValueArg
  consistencyGrade = consistencyGradeArg~string~upper
  consistencyHash = consistencyHashArg~string

  storedSources = .array~new
  if sourcesArg \== .nil then do sourceRef over sourcesArg
    storedSources~append(sourceRef)
  end
  storedHistory = .array~new
  if historyArg \== .nil then do historyItem over historyArg
    storedHistory~append(historyItem)
  end
  storedDiagnostics = .array~new
  if diagnosticsArg \== .nil then do diagnosticItem over diagnosticsArg
    storedDiagnostics~append(diagnosticItem)
  end
  storedContexts = .array~new
  if contextsArg \== .nil then do contextItem over contextsArg
    storedContexts~append(contextItem)
  end

::method sourceCount
  expose storedSources
  return storedSources~items

::method sources
  expose storedSources
  copied = .array~new
  do sourceRef over storedSources
    copied~append(sourceRef)
  end
  return copied

::method processingHistory
  expose storedHistory
  copied = .array~new
  do item over storedHistory
    copied~append(item)
  end
  return copied

::method diagnostics
  expose storedDiagnostics
  copied = .array~new
  do item over storedDiagnostics
    copied~append(item)
  end
  return copied

::method contexts
  expose storedContexts
  copied = .array~new
  do item over storedContexts
    copied~append(item)
  end
  return copied

::method scalarProjectionAllowed
  return self~projectionState == .RichEvidenceProjectionState~SCALAR_AVAILABLE

::method scalarValue
  if \self~scalarProjectionAllowed then return .nil
  return self~presentationValue

::method algorithmCanonicalText
  expose storedSources storedHistory storedDiagnostics storedContexts
  text = 'RICH_EVIDENCE_VALUE_V2' || '0a'x
  text = text || self~field('IDENTITY', self~canonicalIdentity)
  text = text || self~field('ROLE', self~semanticRole)
  text = text || self~field('EVIDENCE_STATE', self~evidenceState)
  text = text || self~field('PROJECTION_STATE', self~projectionState)
  text = text || self~nullableField('PRESENTATION', self~presentationValue)
  text = text || self~field('CONSISTENCY_GRADE', self~consistencyGrade)
  text = text || self~field('CONSISTENCY_HASH', self~consistencyHash)
  text = text || 'SOURCE_COUNT=' || storedSources~items || '0a'x
  do sourceRef over storedSources
    sourceText = sourceRef~canonicalText
    text = text || sourceText~length || ':' || sourceText || '0a'x
  end
  text = text || 'HISTORY_COUNT=' || storedHistory~items || '0a'x
  do item over storedHistory
    itemText = self~canonicalItem(item, 'HISTORY')
    text = text || itemText~length || ':' || itemText || '0a'x
  end
  text = text || 'DIAGNOSTIC_COUNT=' || storedDiagnostics~items || '0a'x
  do item over storedDiagnostics
    itemText = self~canonicalItem(item, 'DIAGNOSTIC')
    text = text || itemText~length || ':' || itemText || '0a'x
  end
  text = text || 'CONTEXT_COUNT=' || storedContexts~items || '0a'x
  do item over storedContexts
    itemText = self~canonicalItem(item, 'CONTEXT')
    text = text || itemText~length || ':' || itemText || '0a'x
  end
  return text

::method canonicalItem private
  use arg item, kind
  if item == .nil then return kind || '=NULL'
  if item~hasMethod('ALGORITHMCANONICALTEXT') then return item~algorithmCanonicalText
  if item~isA(.String) then return kind || '=TEXT:' || item~length || ':' || item
  raise syntax 93.900 additional('Rich evidence ' || kind || ' item lacks explicit canonical contract')

::method field private
  use arg name, value
  rendered = value~string
  return name || '=' || rendered~length || ':' || rendered || '0a'x

::method nullableField private
  use arg name, value
  if value == .nil then return name || '=NULL' || '0a'x
  return self~field(name, value)
