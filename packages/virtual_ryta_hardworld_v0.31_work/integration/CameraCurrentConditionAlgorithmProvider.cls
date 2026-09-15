/*
 * CameraCurrentCondition Algorithm Relation adapter, v0.4.
 * CameraCore is intentionally not required here; the owning component supplies
 * the object and its component root for manifest fingerprinting.
 */

::class CameraCurrentConditionAlgorithmProvider public
::attribute invocationCount
::attribute sourceManifest get

::method init
  expose componentVersion componentFingerprint sourceManifest
  use arg sourceVersion = '0.20', componentRoot = '', adapterPackageRoot = ''
  componentVersion = sourceVersion
  self~invocationCount = 0
  sourceManifest = .AlgorithmSourceManifest~new

  if componentRoot == '' | adapterPackageRoot == '' then do
    sourceManifest~mode = 'LOGICAL_UNBOUND'
    componentFingerprint = 'UNBOUND'
    sourceManifest~add('CAMERA_SOURCE_VERSION', componentVersion)
    sourceManifest~add('ADAPTER_VERSION', self~algorithmVersion)
  end
  else do
    cameraPath = self~joinPath(componentRoot, 'CameraCore.cls')
    componentFingerprint = .AlgorithmDigest~sha256File(cameraPath)
    sourceManifest~addFile('CAMERA_CORE', cameraPath)
    sourceManifest~addFile('CAMERA_ADAPTER', self~joinPath(adapterPackageRoot, 'integration/CameraCurrentConditionAlgorithmProvider.cls'))
    sourceManifest~addFile('ALGREL_ENGINE', self~joinPath(adapterPackageRoot, 'algorithm/AlgorithmRelation.cls'))
    sourceManifest~addFile('ALGREL_INTEGRITY', self~joinPath(adapterPackageRoot, 'algorithm/AlgorithmIntegrity.cls'))
    sourceManifest~add('CAMERA_SOURCE_VERSION', componentVersion)
  end

::method joinPath private
  use arg root, relativePath
  if root~right(1) == '/' then return root || relativePath
  return root || '/' || relativePath

::method algorithmId
  return 'CAMERA_CURRENT_CONDITION'

::method algorithmVersion
  return 'CAMERA-ALGREL-0.4'

::method sourceComponent
  return 'CAMERA_CORE'

::method sourceVersion
  expose componentVersion
  return componentVersion

::method sourceFingerprint
  expose componentFingerprint
  return componentFingerprint

::method sourceManifestHash
  expose sourceManifest
  return sourceManifest~hash

::method sourceManifestMode
  expose sourceManifest
  return sourceManifest~mode

::method determinism
  if self~sourceManifestMode == 'FILE_HASHED' then return .AlgorithmRelationConstant~DETERMINISTIC_GIVEN_MATERIALIZED_INPUT
  return .AlgorithmRelationConstant~UNVERIFIED_SOURCE_IDENTITY

::method sideEffectClass
  return 'NONE'

::method defaultMaterializePolicy
  return .AlgorithmRelationConstant~MATERIALIZE_ONCE

::method inputContract
  return 'CameraCurrentCondition'

::method canonicalInput
  use arg condition, context
  if condition == .nil then return 'CAMERA_CURRENT_CONDITION:<NIL>'

  lines = .array~new
  lines~append('INPUT_CONTRACT=CameraCurrentCondition')
  lines~append('TIMESTAMP=' || condition~timestamp)
  lines~append('DAY_CLASS=' || condition~dayClass)
  lines~append('WINDOW_SECONDS=' || condition~windowSeconds)
  lines~append('TRANSITION_COUNT=' || condition~transitionCount)
  lines~append('UNIQUE_TRANSITION_COUNT=' || condition~uniqueTransitionCount)
  lines~append('EMPIRICAL_ENTROPY_BITS=' || condition~empiricalEntropyBits)
  lines~append('BASELINE_ENTROPY_BITS=' || condition~baselineEntropyBits)
  lines~append('AVERAGE_CONTEXT_SURPRISE_BITS=' || condition~averageContextSurpriseBits)
  lines~append('EXCESS_SURPRISE_BITS=' || condition~excessSurpriseBits)
  lines~append('DOMINANT_TRANSITION_ID=' || self~canonicalNullable(condition~dominantTransitionId))
  lines~append('DOMINANT_TRANSITION_SHARE=' || condition~dominantTransitionShare)
  lines~append('BASELINE_CONTEXT=' || condition~baselineContext)
  lines~append('METRIC_ASSESSMENT_COUNT=' || condition~metricAssessmentCount)
  lines~append('USABLE_METRIC_COUNT=' || condition~usableMetricCount)
  lines~append('ELEVATED_METRIC_COUNT=' || condition~elevatedMetricCount)
  lines~append('STRONGEST_METRIC_NAME=' || self~canonicalNullable(condition~strongestMetricName))
  lines~append('STRONGEST_METRIC_Z=' || condition~strongestMetricZ)
  lines~append('CONDITION_STATE_CODE=' || condition~state)

  signalLines = .array~new
  signalSupplier = condition~metricSignals~supplier
  do while signalSupplier~available
    signal = signalSupplier~item
    signalSupplier~next
    signalLines~append('SIGNAL=' || signal~name || '|samples=' || signal~sampleCount || '|average_z=' || signal~averageZ || '|max_abs_z=' || signal~maximumAbsoluteZ || '|elevated=' || signal~elevated || '|baseline=' || signal~baselineContext)
  end
  signalLines~sort
  do signalLine over signalLines
    lines~append(signalLine)
  end
  return lines~makeString('L')

::method canonicalNullable private
  use arg value
  if value == .nil then return '<NULL>'
  return value

::method declaredSchemas
  schemas = .array~new
  schemas~append(self~conditionSchema)
  schemas~append(self~signalSchema)
  return schemas

::method conditionSchema
  conditionSchema = .AlgorithmSchema~new('CAMERA_CURRENT_CONDITION')
  conditionSchema~add('INVOCATION_ID', 'TEXT', .false)
  conditionSchema~add('INPUT_OID', 'OID', .false)
  conditionSchema~add('TIMESTAMP', 'INTEGER', .false)
  conditionSchema~add('DAY_CLASS', 'INTEGER', .false)
  conditionSchema~add('WINDOW_SECONDS', 'INTEGER', .false)
  conditionSchema~add('TRANSITION_COUNT', 'INTEGER', .false)
  conditionSchema~add('UNIQUE_TRANSITION_COUNT', 'INTEGER', .false)
  conditionSchema~add('EMPIRICAL_ENTROPY_BITS', 'NUMBER', .false)
  conditionSchema~add('BASELINE_ENTROPY_BITS', 'NUMBER', .false)
  conditionSchema~add('AVERAGE_CONTEXT_SURPRISE_BITS', 'NUMBER', .false)
  conditionSchema~add('EXCESS_SURPRISE_BITS', 'NUMBER', .false)
  conditionSchema~add('DOMINANT_TRANSITION_ID', 'TEXT', .true)
  conditionSchema~add('DOMINANT_TRANSITION_SHARE', 'NUMBER', .false)
  conditionSchema~add('BASELINE_CONTEXT', 'TEXT', .false)
  conditionSchema~add('METRIC_ASSESSMENT_COUNT', 'INTEGER', .false)
  conditionSchema~add('USABLE_METRIC_COUNT', 'INTEGER', .false)
  conditionSchema~add('ELEVATED_METRIC_COUNT', 'INTEGER', .false)
  conditionSchema~add('STRONGEST_METRIC_NAME', 'TEXT', .true)
  conditionSchema~add('STRONGEST_METRIC_Z', 'NUMBER', .false)
  conditionSchema~add('CONDITION_STATE_CODE', 'INTEGER', .false)
  conditionSchema~addEnum('CONDITION_STATE', 'TEXT', .false, .array~of('INSUFFICIENT','EXPECTED','SHIFTED'))
  return conditionSchema

::method signalSchema
  signalSchema = .AlgorithmSchema~new('CAMERA_METRIC_SIGNALS')
  signalSchema~add('INVOCATION_ID', 'TEXT', .false)
  signalSchema~add('INPUT_OID', 'OID', .false)
  signalSchema~add('METRIC_NAME', 'TEXT', .false)
  signalSchema~add('SAMPLE_COUNT', 'INTEGER', .false)
  signalSchema~add('AVERAGE_Z', 'NUMBER', .false)
  signalSchema~add('MAXIMUM_ABSOLUTE_Z', 'NUMBER', .false)
  signalSchema~add('ELEVATED', 'BOOLEAN', .false)
  signalSchema~add('BASELINE_CONTEXT', 'TEXT', .false)
  return signalSchema

::method evaluate
  use arg condition, context
  if condition == .nil then return .nil
  self~invocationCount = self~invocationCount + 1

  algorithmResult = .AlgorithmRelationResult~new(self~algorithmId, self~algorithmVersion, self~sourceComponent, self~sourceVersion, self~sourceFingerprint, self~sourceManifestHash, context)
  algorithmResult~addTrace('PROVIDER CAMERA_CURRENT_CONDITION invocation=' || self~invocationCount)
  algorithmResult~addTrace('INPUT oid=' || context~inputOid)

  conditionSchema = self~conditionSchema
  conditionRelation = .AlgorithmRelation~new(conditionSchema)

  row = conditionRelation~newRow
  ok = row~put('INVOCATION_ID', context~invocationId)
  ok = row~put('INPUT_OID', context~inputOid)
  ok = row~put('TIMESTAMP', condition~timestamp)
  ok = row~put('DAY_CLASS', condition~dayClass)
  ok = row~put('WINDOW_SECONDS', condition~windowSeconds)
  ok = row~put('TRANSITION_COUNT', condition~transitionCount)
  ok = row~put('UNIQUE_TRANSITION_COUNT', condition~uniqueTransitionCount)
  ok = row~put('EMPIRICAL_ENTROPY_BITS', condition~empiricalEntropyBits)
  ok = row~put('BASELINE_ENTROPY_BITS', condition~baselineEntropyBits)
  ok = row~put('AVERAGE_CONTEXT_SURPRISE_BITS', condition~averageContextSurpriseBits)
  ok = row~put('EXCESS_SURPRISE_BITS', condition~excessSurpriseBits)
  ok = row~put('DOMINANT_TRANSITION_ID', condition~dominantTransitionId)
  ok = row~put('DOMINANT_TRANSITION_SHARE', condition~dominantTransitionShare)
  ok = row~put('BASELINE_CONTEXT', condition~baselineContext)
  ok = row~put('METRIC_ASSESSMENT_COUNT', condition~metricAssessmentCount)
  ok = row~put('USABLE_METRIC_COUNT', condition~usableMetricCount)
  ok = row~put('ELEVATED_METRIC_COUNT', condition~elevatedMetricCount)
  ok = row~put('STRONGEST_METRIC_NAME', condition~strongestMetricName)
  ok = row~put('STRONGEST_METRIC_Z', condition~strongestMetricZ)
  ok = row~put('CONDITION_STATE_CODE', condition~state)
  ok = row~put('CONDITION_STATE', self~conditionStateName(condition~state))
  added = conditionRelation~addRow(row)
  added = algorithmResult~addRelation(conditionRelation)

  signalSchema = self~signalSchema
  signalRelation = .AlgorithmRelation~new(signalSchema)

  signalSupplier = condition~metricSignals~supplier
  do while signalSupplier~available
    signal = signalSupplier~item
    signalSupplier~next
    signalRow = signalRelation~newRow
    ok = signalRow~put('INVOCATION_ID', context~invocationId)
    ok = signalRow~put('INPUT_OID', context~inputOid)
    ok = signalRow~put('METRIC_NAME', signal~name)
    ok = signalRow~put('SAMPLE_COUNT', signal~sampleCount)
    ok = signalRow~put('AVERAGE_Z', signal~averageZ)
    ok = signalRow~put('MAXIMUM_ABSOLUTE_Z', signal~maximumAbsoluteZ)
    ok = signalRow~put('ELEVATED', signal~elevated)
    ok = signalRow~put('BASELINE_CONTEXT', signal~baselineContext)
    added = signalRelation~addRow(signalRow)
  end
  added = algorithmResult~addRelation(signalRelation)

  algorithmResult~addTrace('CONDITION state=' || self~conditionStateName(condition~state) || ' transitions=' || condition~transitionCount || ' metrics=' || condition~usableMetricCount)
  return algorithmResult

::method conditionStateName private
  use arg stateCode
  select
    when stateCode == 160 then return 'INSUFFICIENT'
    when stateCode == 161 then return 'EXPECTED'
    when stateCode == 162 then return 'SHIFTED'
    otherwise return 'UNKNOWN_STATE_' || stateCode
  end

::requires '../algorithm/AlgorithmRelation.cls'
