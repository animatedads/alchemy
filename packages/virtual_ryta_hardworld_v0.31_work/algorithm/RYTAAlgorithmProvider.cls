/* Adapter exposing Virtual RYTA as typed Algorithm Relations. v0.4. */

::class RYTAAlgorithmProvider public
::attribute invocationCount
::attribute sourceManifest get

::method init
  expose actor packageRoot sourceManifest
  use arg actor = .nil, packageRoot = ''
  if actor == .nil then actor = .VirtualRYTA~new
  self~invocationCount = 0
  sourceManifest = .AlgorithmSourceManifest~new

  if packageRoot == '' then do
    sourceManifest~mode = 'LOGICAL_UNBOUND'
    sourceManifest~add('ALGORITHM_VERSION', self~algorithmVersion)
    sourceManifest~add('MODEL_HASH', actor~stateRules~modelHash)
    sourceManifest~add('SOURCE_VERSION', actor~stateRules~modelVersion)
  end
  else do
    self~addSourceFile(sourceManifest, packageRoot, 'ALGREL_ENGINE', 'algorithm/AlgorithmRelation.cls')
    self~addSourceFile(sourceManifest, packageRoot, 'ALGREL_INTEGRITY', 'algorithm/AlgorithmIntegrity.cls')
    self~addSourceFile(sourceManifest, packageRoot, 'RYTA_ADAPTER', 'algorithm/RYTAAlgorithmProvider.cls')
    self~addSourceFile(sourceManifest, packageRoot, 'VIRTUAL_RYTA', 'VirtualRYTA.cls')
    self~addSourceFile(sourceManifest, packageRoot, 'HARDWORLD', 'HardWorld.cls')
    self~addSourceFile(sourceManifest, packageRoot, 'STATE_RULES', 'RYTAStateRules.cls')
    self~addSourceFile(sourceManifest, packageRoot, 'BASIC_SCORING', 'plugins/RYTABasicScoring.cls')
    self~addSourceFile(sourceManifest, packageRoot, 'TEST_EXTREME_SCORING', 'plugins/RYTATestExtremeScoring.cls')
    self~addSourceFile(sourceManifest, packageRoot, 'TEST_FACT_PLUGIN', 'plugins/RYTATestFact.cls')
    sourceManifest~add('MODEL_HASH', actor~stateRules~modelHash)
    sourceManifest~add('MODEL_VERSION', actor~stateRules~modelVersion)
  end

::method addSourceFile private
  use arg manifest, packageRoot, label, relativePath
  separator = '/'
  if packageRoot~right(1) == '/' then filePath = packageRoot || relativePath
  else filePath = packageRoot || separator || relativePath
  return manifest~addFile(label, filePath)

::method algorithmId
  return 'VIRTUAL_RYTA'

::method algorithmVersion
  return 'RYTA-ALGREL-0.4'

::method sourceComponent
  return 'HARDWORLD_RYTA'

::method sourceVersion
  expose actor
  return actor~stateRules~modelVersion

::method sourceFingerprint
  expose actor
  return actor~stateRules~modelHash

::method sourceManifestHash
  expose sourceManifest
  self~refreshPluginManifest
  return sourceManifest~hash

::method sourceManifestMode
  expose sourceManifest
  self~refreshPluginManifest
  return sourceManifest~mode

::method refreshPluginManifest private
  expose actor sourceManifest
  do plugin over actor~factPlugins
    self~addPluginManifestEntry(sourceManifest, plugin)
  end
  do plugin over actor~scorePlugins
    self~addPluginManifestEntry(sourceManifest, plugin)
  end
  return sourceManifest~mode

::method addPluginManifestEntry private
  use arg manifest, plugin
  pluginId = plugin~pluginId~upper
  if \plugin~hasMethod('canonicalConfiguration') then manifest~mode = 'INCOMPLETE'
  select
    when pluginId == 'BASIC_SCORING' then fingerprint = 'SHIPPED_FILE_HASHED'
    when pluginId == 'TEST_EXTREME_SCORING' then fingerprint = 'SHIPPED_FILE_HASHED'
    when pluginId == 'TEST_FACT_PLUGIN' then fingerprint = 'SHIPPED_FILE_HASHED'
    otherwise do
      if plugin~hasMethod('sourceManifestHash') then fingerprint = plugin~sourceManifestHash
      else do
        fingerprint = 'UNBOUND_EXTERNAL_PLUGIN'
        manifest~mode = 'INCOMPLETE'
      end
    end
  end
  manifest~add('PLUGIN:' || pluginId, fingerprint)
  return fingerprint

::method determinism
  if self~sourceManifestMode == 'FILE_HASHED' then return .AlgorithmRelationConstant~DETERMINISTIC_GIVEN_MATERIALIZED_INPUT
  return .AlgorithmRelationConstant~UNVERIFIED_SOURCE_IDENTITY

::method sideEffectClass
  return 'NONE'

::method defaultMaterializePolicy
  return .AlgorithmRelationConstant~MATERIALIZE_ONCE

::method inputContract
  return 'RYTAWorldState'

::method canonicalInput
  expose actor
  use arg world, context
  lines = .array~new
  lines~append('INPUT_CONTRACT=RYTAWorldState')
  lines~append('WORLD_OBJECT_SNAPSHOT=' || world~snapshotOid)
  lines~append('APPROVAL_SCOPE=' || context~approvalScope~upper)

  worldLines = world~render
  do worldLine over worldLines
    lines~append('FACT=' || worldLine)
  end

  /* Evidence is not part of rule truth, but it is part of deterministic input
     identity.  Never use an object's presentation string as evidence identity. */
  evidenceFactNames = world~facts~allIndexes
  evidenceFactNames~sort
  do evidenceFactName over evidenceFactNames
    evidenceFact = world~facts[evidenceFactName]
    evidenceObject = evidenceFact~evidence
    if evidenceObject == .nil then iterate
    if \evidenceObject~hasMethod('ALGORITHMCANONICALTEXT') then raise syntax 93.900 additional('Fact evidence lacks ALGORITHMCANONICALTEXT:' evidenceFactName)
    evidenceText = evidenceObject~algorithmCanonicalText
    lines~append('FACT_EVIDENCE=' || evidenceFactName~length || ':' || evidenceFactName || '|' || evidenceText~length || ':' || evidenceText)
  end

  pluginOrdinal = 0
  do plugin over actor~factPlugins
    pluginOrdinal = pluginOrdinal + 1
    lines~append('FACT_PLUGIN[' || pluginOrdinal || ']=' || self~pluginCanonicalConfiguration(plugin))
  end

  pluginOrdinal = 0
  do plugin over actor~scorePlugins
    pluginOrdinal = pluginOrdinal + 1
    lines~append('SCORE_PLUGIN[' || pluginOrdinal || ']=' || self~pluginCanonicalConfiguration(plugin))
  end

  policyIds = actor~approvalPolicies~policies~allIndexes
  policyIds~sort
  do policyId over policyIds
    policy = actor~approvalPolicies~policies[policyId]
    lines~append('APPROVAL_POLICY=' || policy~policyId || '|authority=' || policy~requiredAuthority || '|quorum=' || policy~quorum)
  end

  approvalOrdinal = 0
  do approval over actor~approvals~approvals
    approvalOrdinal = approvalOrdinal + 1
    expiresText = '<NONE>'
    if approval~expiresAt \== .nil then expiresText = approval~expiresAt~string
    lines~append('APPROVAL[' || approvalOrdinal || ']=' || approval~approvalId || '|authority=' || approval~authority || '|action=' || approval~actionCode || '|model=' || approval~modelId || '|version=' || approval~modelVersion || '|world=' || approval~worldSnapshotOid || '|scope=' || approval~scope || '|expires=' || expiresText || '|revoked=' || approval~revoked || '|decision=' || approval~decision || '|source=' || approval~source)
  end

  lines~append('CAPABILITY_DEFAULT_POLICY=DEFAULT_TRUE_IF_ABSENT:v1')
  return lines~makeString('L')


::method pluginCanonicalConfiguration private
  use arg plugin
  if plugin~hasMethod('canonicalConfiguration') then return plugin~canonicalConfiguration
  return 'UNBOUND_PLUGIN_CONFIGURATION|plugin=' || plugin~pluginId

::method cloneWorld private
  use arg world
  clonedWorld = .RYTAWorldState~new(world~snapshotOid)
  factNames = world~facts~allIndexes
  factNames~sort
  do factName over factNames
    sourceFact = world~facts[factName]
    select
      when sourceFact~knowledgeState == .RYTAConstant~KNOWLEDGE_KNOWN then copiedFact = clonedWorld~putKnown(sourceFact~name, sourceFact~value, sourceFact~source, sourceFact~authority, sourceFact~evidence)
      when sourceFact~knowledgeState == .RYTAConstant~KNOWLEDGE_UNKNOWN then copiedFact = clonedWorld~putUnknown(sourceFact~name, sourceFact~source, sourceFact~authority, sourceFact~evidence)
      when sourceFact~knowledgeState == .RYTAConstant~KNOWLEDGE_CONFLICT then copiedFact = clonedWorld~putConflict(sourceFact~name, sourceFact~source, sourceFact~authority, sourceFact~evidence)
      otherwise copiedFact = clonedWorld~putUnknown(sourceFact~name, 'INVALID_KNOWLEDGE_STATE', sourceFact~authority)
    end
  end
  return clonedWorld

::method declaredSchemas
  schemas = .array~new
  schemas~append(self~actionSchema)
  schemas~append(self~traceSchema)
  return schemas

::method actionSchema
  actionSchema = .AlgorithmSchema~new('RYTA_ACTION_DECISIONS')
  actionSchema~add('INVOCATION_ID', 'TEXT', .false)
  actionSchema~add('WORLD_SNAPSHOT_OID', 'OID', .false)
  actionSchema~add('MODEL_ID', 'TEXT', .false)
  actionSchema~add('MODEL_VERSION', 'TEXT', .false)
  actionSchema~add('MODEL_HASH', 'TEXT', .false)
  actionSchema~addEnum('STATE', 'TEXT', .false, .array~of('NORMAL','NEEDS_INFORMATION','REMEDIATION_REQUIRED','ESCALATE','RULE_CONFLICT','UNRESOLVED'))
  actionSchema~add('WINNING_RULE', 'TEXT', .false)
  actionSchema~addEnum('WINNING_TIER', 'TEXT', .false, .array~of('SAFETY_CRITICAL','SAFETY_NORMAL','OPERATIONAL','COMMERCIAL','NONE'))
  actionSchema~addEnum('EXECUTION_STATUS', 'TEXT', .false, .array~of('READY','REQUIRED_ACTION_UNAVAILABLE','CONFLICTING_REQUIREMENTS'))
  actionSchema~addEnum('ACTION_CODE', 'TEXT', .false, .array~of('ANSWER_QUERY','SELL_PRODUCT','WARNING','UPSELL','BIG_UPSELL','ASK_INFORMATION','ESCALATE'))
  actionSchema~add('METHOD_NAME', 'TEXT', .false)
  actionSchema~add('SCORE', 'NUMBER', .false)
  actionSchema~add('PROVISIONAL_SELECTED', 'BOOLEAN', .false)
  actionSchema~addEnum('DISPOSITION', 'TEXT', .false, .array~of('UNRESOLVED','PERMITTED','REQUIRED','SUPPRESSED','PROHIBITED','REQUIRES_APPROVAL'))
  actionSchema~add('FINAL_SELECTED', 'BOOLEAN', .false)
  actionSchema~add('REQUIREMENT_SATISFIED', 'BOOLEAN', .false)
  actionSchema~addEnum('CAPABILITY_STATUS', 'TEXT', .false, .array~of('CAPABLE','UNAVAILABLE','UNKNOWN','CONFLICT'))
  actionSchema~add('APPROVAL_STATUS', 'TEXT', .false)
  actionSchema~addEnum('OVERRIDE_POLICY', 'TEXT', .false, .array~of('NON_OVERRIDEABLE','CONTEXTUAL','APPROVAL_GATE'))
  actionSchema~add('OUTPUT_TEXT', 'TEXT', .true)
  return actionSchema

::method traceSchema
  traceSchema = .AlgorithmSchema~new('RYTA_DECISION_TRACE')
  traceSchema~add('INVOCATION_ID', 'TEXT', .false)
  traceSchema~add('SEQUENCE', 'INTEGER', .false)
  traceSchema~add('EVENT_TEXT', 'TEXT', .false)
  return traceSchema

::method evaluate
  expose actor
  use arg world, context
  self~invocationCount = self~invocationCount + 1

  workingWorld = self~cloneWorld(world)
  decisionRun = actor~evaluate(workingWorld, context~approvalScope)
  algorithmResult = .AlgorithmRelationResult~new(self~algorithmId, self~algorithmVersion, self~sourceComponent, self~sourceVersion, self~sourceFingerprint, self~sourceManifestHash, context)
  algorithmResult~addTrace('PROVIDER VIRTUAL_RYTA invocation=' || self~invocationCount)
  algorithmResult~addTrace('WORLD snapshot=' || workingWorld~snapshotOid || ' input_immutable=1')
  algorithmResult~addTrace('DECISION state=' || decisionRun~state || ' rule=' || decisionRun~winningRule || ' execution=' || decisionRun~executionStatus)

  actionSchema = self~actionSchema
  actionsRelation = .AlgorithmRelation~new(actionSchema)

  outputIndex = 0
  do action over decisionRun~actions
    outputText = .nil
    if action~finalSelected then do
      outputIndex = outputIndex + 1
      if outputIndex <= decisionRun~outputs~items then outputText = decisionRun~outputs[outputIndex]
    end

    row = actionsRelation~newRow
    ok = row~put('INVOCATION_ID', context~invocationId)
    ok = row~put('WORLD_SNAPSHOT_OID', workingWorld~snapshotOid)
    ok = row~put('MODEL_ID', decisionRun~context~modelId)
    ok = row~put('MODEL_VERSION', decisionRun~context~modelVersion)
    ok = row~put('MODEL_HASH', decisionRun~context~modelHash)
    ok = row~put('STATE', decisionRun~state)
    ok = row~put('WINNING_RULE', decisionRun~winningRule)
    winningTier = decisionRun~winningTier
    if winningTier == '' then winningTier = 'NONE'
    ok = row~put('WINNING_TIER', winningTier)
    ok = row~put('EXECUTION_STATUS', decisionRun~executionStatus)
    ok = row~put('ACTION_CODE', action~actionCode)
    ok = row~put('METHOD_NAME', action~methodName)
    ok = row~put('SCORE', action~score)
    ok = row~put('PROVISIONAL_SELECTED', action~provisionalSelected)
    ok = row~put('DISPOSITION', action~disposition)
    ok = row~put('FINAL_SELECTED', action~finalSelected)
    ok = row~put('REQUIREMENT_SATISFIED', action~requirementSatisfied)
    ok = row~put('CAPABILITY_STATUS', action~capabilityStatus)
    ok = row~put('APPROVAL_STATUS', action~approvalStatus)
    ok = row~put('OVERRIDE_POLICY', action~overridePolicy)
    ok = row~put('OUTPUT_TEXT', outputText)
    added = actionsRelation~addRow(row)
  end
  added = algorithmResult~addRelation(actionsRelation)

  traceSchema = self~traceSchema
  traceRelation = .AlgorithmRelation~new(traceSchema)
  sequence = 0
  do traceLine over decisionRun~trace
    sequence = sequence + 1
    traceRow = traceRelation~newRow
    ok = traceRow~put('INVOCATION_ID', context~invocationId)
    ok = traceRow~put('SEQUENCE', sequence)
    ok = traceRow~put('EVENT_TEXT', traceLine)
    added = traceRelation~addRow(traceRow)
  end
  added = algorithmResult~addRelation(traceRelation)

  return algorithmResult

::requires 'AlgorithmRelation.cls'
::requires '../VirtualRYTA.cls'
