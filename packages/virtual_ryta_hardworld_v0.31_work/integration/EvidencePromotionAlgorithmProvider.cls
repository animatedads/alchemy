/*
 * EvidencePromotionAlgorithmProvider.cls
 *
 * SQL-visible audit projection of a sealed EvidencePromotionSet.
 * It exposes why a fact may be promoted; it never applies the promotion.
 */

::class EvidencePromotionAlgorithmProvider public
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
    sourceManifest~add('PROMOTION_CONTRACT', self~sourceFingerprint)
  end
  else do
    self~addSourceFile(sourceManifest, packageRoot, 'ALGREL_ENGINE', 'algorithm/AlgorithmRelation.cls')
    self~addSourceFile(sourceManifest, packageRoot, 'PROMOTION_CONTRACT', 'algorithm/EvidencePromotion.cls')
    self~addSourceFile(sourceManifest, packageRoot, 'PROMOTION_PROVIDER', 'integration/EvidencePromotionAlgorithmProvider.cls')
  end

::method addSourceFile private
  use arg manifest, packageRoot, label, relativePath
  if packageRoot~right(1) == '/' then filePath = packageRoot || relativePath
  else filePath = packageRoot || '/' || relativePath
  return manifest~addFile(label, filePath)

::method algorithmId
  return 'EVIDENCE_PROMOTIONS'
::method algorithmVersion
  return 'EVIDENCE-PROMOTION-ALGREL-0.17'
::method sourceComponent
  return 'HARDWORLD_EVIDENCE_PROMOTION'
::method sourceVersion
  return '0.17'
::method sourceFingerprint
  return 'EVIDENCE-PROMOTION-CONTRACT-V1'
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
  return 'EvidencePromotionSet:SEALED;APPLICATION=OUT_OF_BAND;SQL=INSPECTION_ONLY'

::method canonicalInput
  use arg promotionSet, context
  return promotionSet~algorithmCanonicalText

::method declaredSchemas
  return .array~of(self~promotionSchema, self~basisSchema, self~traceSchema)

::method promotionSchema
  schema = .AlgorithmSchema~new('EVIDENCE_PROMOTIONS')
  schema~add('INVOCATION_ID','TEXT',.false)
  schema~add('PROMOTION_ID','TEXT',.false)
  schema~add('SOURCE_KIND','TEXT',.false)
  schema~add('SOURCE_IDENTITY','TEXT',.false)
  schema~add('TARGET_FACT','TEXT',.false)
  schema~add('PROPOSED_KNOWLEDGE_STATE','TEXT',.false)
  schema~add('VALUE_TYPE','TEXT',.false)
  schema~add('VALUE_BOOLEAN','BOOLEAN',.true)
  schema~add('VALUE_NUMBER','NUMBER',.true)
  schema~add('VALUE_TEXT','TEXT',.true)
  schema~add('SCALAR_PROJECTION_STATE','TEXT',.false)
  schema~add('AUTHORITY','TEXT',.false)
  schema~add('POLICY_ID','TEXT',.false)
  schema~add('RULE_ID','TEXT',.false)
  schema~add('DISPOSITION','TEXT',.false)
  schema~add('PROMOTION_STATUS','TEXT',.false)
  schema~add('REASON','TEXT',.false)
  schema~add('MINIMUM_CONSISTENCY','TEXT',.false)
  schema~add('ACTUAL_CONSISTENCY','TEXT',.false)
  schema~add('NATIVE_SOURCE_PRESERVED','BOOLEAN',.false)
  return schema

::method basisSchema
  schema = .AlgorithmSchema~new('EVIDENCE_PROMOTION_BASIS')
  schema~add('INVOCATION_ID','TEXT',.false)
  schema~add('PROMOTION_ID','TEXT',.false)
  schema~add('BASIS_ORDINAL','INTEGER',.false)
  schema~add('BASIS_KIND','TEXT',.false)
  schema~add('BASIS_ID','TEXT',.false)
  schema~add('DETAIL','TEXT',.false)
  schema~add('NATIVE_OBJECT_PRESERVED','BOOLEAN',.false)
  return schema

::method traceSchema
  schema = .AlgorithmSchema~new('EVIDENCE_PROMOTION_TRACE')
  schema~add('INVOCATION_ID','TEXT',.false)
  schema~add('SEQUENCE','INTEGER',.false)
  schema~add('EVENT_TEXT','TEXT',.false)
  return schema

::method evaluate
  use arg promotionSet, context
  self~invocationCount = self~invocationCount + 1
  algorithmResult = .AlgorithmRelationResult~new(self~algorithmId,self~algorithmVersion,self~sourceComponent,self~sourceVersion,self~sourceFingerprint,self~sourceManifestHash,context)
  promotionsRelation = .AlgorithmRelation~new(self~promotionSchema)
  basisRelation = .AlgorithmRelation~new(self~basisSchema)
  traceRelation = .AlgorithmRelation~new(self~traceSchema)
  sequence = 0

  do promotion over promotionSet~promotions
    valueBoolean = .nil
    valueNumber = .nil
    valueText = .nil
    projectionState = 'SCALAR_AVAILABLE'
    valueType = promotion~valueType
    select
      when valueType == 'NULL' then nop
      when valueType == 'BOOLEAN' then valueBoolean = promotion~proposedValue
      when valueType == 'NUMBER' then valueNumber = promotion~proposedValue
      when valueType == 'TEXT' then valueText = promotion~proposedValue
      otherwise projectionState = 'SCALAR_REFUSED'
    end

    row = promotionsRelation~newRow
    ok=row~put('INVOCATION_ID',context~invocationId)
    ok=row~put('PROMOTION_ID',promotion~promotionId)
    ok=row~put('SOURCE_KIND',promotion~sourceKind)
    ok=row~put('SOURCE_IDENTITY',promotion~sourceIdentity)
    ok=row~put('TARGET_FACT',promotion~targetFactName)
    ok=row~put('PROPOSED_KNOWLEDGE_STATE',promotion~proposedKnowledgeState)
    ok=row~put('VALUE_TYPE',valueType)
    ok=row~put('VALUE_BOOLEAN',valueBoolean)
    ok=row~put('VALUE_NUMBER',valueNumber)
    ok=row~put('VALUE_TEXT',valueText)
    ok=row~put('SCALAR_PROJECTION_STATE',projectionState)
    ok=row~put('AUTHORITY',promotion~authority)
    ok=row~put('POLICY_ID',promotion~policyId)
    ok=row~put('RULE_ID',promotion~ruleId)
    ok=row~put('DISPOSITION',promotion~disposition)
    ok=row~put('PROMOTION_STATUS',promotion~promotionStatus)
    ok=row~put('REASON',promotion~reason)
    ok=row~put('MINIMUM_CONSISTENCY',promotion~minimumConsistency)
    ok=row~put('ACTUAL_CONSISTENCY',promotion~actualConsistency)
    ok=row~put('NATIVE_SOURCE_PRESERVED',promotion~sourceObject \== .nil)
    added=promotionsRelation~addRow(row)

    ordinal = 0
    do basisItem over promotion~basis
      ordinal = ordinal + 1
      basisRow = basisRelation~newRow
      ok=basisRow~put('INVOCATION_ID',context~invocationId)
      ok=basisRow~put('PROMOTION_ID',promotion~promotionId)
      ok=basisRow~put('BASIS_ORDINAL',ordinal)
      ok=basisRow~put('BASIS_KIND',basisItem~basisKind)
      ok=basisRow~put('BASIS_ID',basisItem~basisId)
      ok=basisRow~put('DETAIL',basisItem~detail)
      ok=basisRow~put('NATIVE_OBJECT_PRESERVED',basisItem~nativeObject \== .nil)
      added=basisRelation~addRow(basisRow)
    end

    sequence = sequence + 1
    traceRow = traceRelation~newRow
    ok=traceRow~put('INVOCATION_ID',context~invocationId)
    ok=traceRow~put('SEQUENCE',sequence)
    ok=traceRow~put('EVENT_TEXT','PROMOTION ' || promotion~promotionId || ' target=' || promotion~targetFactName || ' status=' || promotion~promotionStatus || ' application=OUT_OF_BAND')
    added=traceRelation~addRow(traceRow)
  end

  added=algorithmResult~addRelation(promotionsRelation)
  added=algorithmResult~addRelation(basisRelation)
  added=algorithmResult~addRelation(traceRelation)
  return algorithmResult

::requires '../algorithm/AlgorithmRelation.cls'
::requires '../algorithm/EvidencePromotion.cls'
