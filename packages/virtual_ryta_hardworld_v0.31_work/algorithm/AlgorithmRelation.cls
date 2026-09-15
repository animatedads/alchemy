/*
 * AlgorithmRelation.cls
 * Generic typed relation envelope for deterministic algorithmic providers.
 * v0.4 content-addressed / typed-contract candidate.
 */

::class AlgorithmRelationConstant public
::constant MATERIALIZE_ONCE 'MATERIALIZE_ONCE'
::constant FRESH            'FRESH'
::constant DETERMINISTIC_GIVEN_MATERIALIZED_INPUT 'DETERMINISTIC_GIVEN_MATERIALIZED_INPUT'
::constant UNVERIFIED_SOURCE_IDENTITY 'UNVERIFIED_SOURCE_IDENTITY'


::class AlgorithmColumn public
::attribute name
::attribute typeName
::attribute nullable
::attribute allowedValues get

::method init
  expose allowedValues
  use arg name, typeName = 'TEXT', nullable = .true, allowedValues = .nil
  self~name = name~upper
  self~typeName = typeName~upper
  self~nullable = nullable
  if allowedValues == .nil then allowedValues = .array~new

::method domainText
  expose allowedValues
  if allowedValues~items == 0 then return ''
  rendered = ''
  firstValue = .true
  do allowedValue over allowedValues
    if firstValue then do
      rendered = allowedValue
      firstValue = .false
    end
    else rendered = rendered || ',' || allowedValue
  end
  return rendered

::method validateValue
  expose allowedValues
  use arg value
  errors = .array~new

  if value == .nil then do
    if \self~nullable then errors~append('NULL_NOT_ALLOWED')
    return errors
  end

  typeName = self~typeName
  typeOk = .false
  select
    when typeName == 'TEXT' then typeOk = value~class == .String
    when typeName == 'OID' then do
      if value~class == .String then typeOk = value~strip \== ''
    end
    when typeName == 'INTEGER' then typeOk = datatype(value, 'W') == 1
    when typeName == 'NUMBER' then typeOk = datatype(value, 'N') == 1
    when typeName == 'BOOLEAN' then typeOk = value == .true | value == .false
    when typeName == 'RICH_OBJECT' then do
      typeOk = value~hasMethod('ALGORITHMCANONICALTEXT') & value~hasMethod('NATIVEOBJECT')
    end
    otherwise errors~append('UNKNOWN_DECLARED_TYPE ' || typeName)
  end

  if \typeOk then errors~append('TYPE_MISMATCH expected=' || typeName || ' actual=' || value)

  if typeOk then do
    if allowedValues~items > 0 then do
      domainMatch = .false
      do allowedValue over allowedValues
        if value == allowedValue then domainMatch = .true
      end
      if \domainMatch then errors~append('DOMAIN_VIOLATION value=' || value || ' allowed=' || self~domainText)
    end
  end

  return errors

::method render
  nullText = 'NOT_NULL'
  if self~nullable then nullText = 'NULLABLE'
  rendered = self~name || ':' || self~typeName || ':' || nullText
  if self~allowedValues~items > 0 then rendered = rendered || ':DOMAIN[' || self~domainText || ']'
  return rendered


::class AlgorithmSchema public
::attribute relationName
::attribute columns get

::method init
  expose columns columnIndex
  use arg relationName
  self~relationName = relationName~upper
  columns = .array~new
  columnIndex = .directory~new

::method addColumn
  expose columns columnIndex
  use arg column
  key = column~name~upper
  if columnIndex~hasIndex(key) then return .false
  columns~append(column)
  columnIndex[key] = column
  return .true

::method add
  use arg name, typeName = 'TEXT', nullable = .true
  return self~addColumn(.AlgorithmColumn~new(name, typeName, nullable))

::method addEnum
  use arg name, typeName, nullable, allowedValues
  return self~addColumn(.AlgorithmColumn~new(name, typeName, nullable, allowedValues))

::method hasColumn
  expose columnIndex
  use arg name
  return columnIndex~hasIndex(name~upper)

::method column
  expose columnIndex
  use arg name
  key = name~upper
  if columnIndex~hasIndex(key) then return columnIndex[key]
  return .nil

::method render
  expose columns
  lines = .array~new
  lines~append('RELATION ' || self~relationName)
  do column over columns
    lines~append('  ' || column~render)
  end
  return lines


::class AlgorithmRow public
::attribute schema
::attribute values get
::attribute writeErrors get

::method init
  expose values writeErrors
  use arg schema
  self~schema = schema
  values = .directory~new
  writeErrors = .array~new

::method put
  expose values writeErrors
  use arg name, value
  key = name~upper
  if \self~schema~hasColumn(key) then do
    writeErrors~append('UNKNOWN_COLUMN ' || key)
    return .false
  end
  values[key] = value
  return .true

::method value
  expose values
  use arg name
  key = name~upper
  if values~hasIndex(key) then return values[key]
  return .nil

::method hasValue
  expose values
  use arg name
  return values~hasIndex(name~upper)

::method validate
  expose values writeErrors
  errors = .array~new
  do writeError over writeErrors
    errors~append(writeError)
  end

  do column over self~schema~columns
    if \values~hasIndex(column~name) then do
      errors~append('MISSING_COLUMN ' || column~name)
      iterate
    end

    columnErrors = column~validateValue(values[column~name])
    do columnError over columnErrors
      errors~append(column~name || ':' || columnError)
    end
  end
  return errors

::method render
  expose values
  rendered = ''
  firstColumn = .true
  do column over self~schema~columns
    valueText = '<OMITTED>'
    if values~hasIndex(column~name) then do
      fieldValue = values[column~name]
      if fieldValue == .nil then valueText = '<NULL>'
      else valueText = fieldValue
    end
    if firstColumn then do
      rendered = column~name || '=' || valueText
      firstColumn = .false
    end
    else rendered = rendered || '|' || column~name || '=' || valueText
  end
  return rendered


::class AlgorithmRelation public
::attribute schema
::attribute rows get
::attribute rejectedRowErrors get

::method init
  expose rows rejectedRowErrors
  use arg schema
  self~schema = schema
  rows = .array~new
  rejectedRowErrors = .array~new

::method relationName
  return self~schema~relationName

::method newRow
  return .AlgorithmRow~new(self~schema)

::method addRow
  expose rows rejectedRowErrors
  use arg row
  errors = row~validate
  if errors~items > 0 then do
    do validationError over errors
      rejectedRowErrors~append(validationError)
    end
    return .false
  end
  rows~append(row)
  return .true

::method cloneForInvocation
  expose rows
  use arg invocationId
  clonedRelation = .AlgorithmRelation~new(self~schema)
  do sourceRow over rows
    targetRow = clonedRelation~newRow
    do column over self~schema~columns
      if sourceRow~hasValue(column~name) then do
        fieldValue = sourceRow~value(column~name)
        if column~name == 'INVOCATION_ID' then fieldValue = invocationId
        ok = targetRow~put(column~name, fieldValue)
      end
    end
    added = clonedRelation~addRow(targetRow)
  end
  return clonedRelation

::method render
  expose rows
  lines = .array~new
  lines~append('RELATION ' || self~relationName || ' rows=' || rows~items)
  do row over rows
    lines~append('  ' || row~render)
  end
  return lines


::class AlgorithmExecutionContext public
::attribute invocationId
::attribute inputOid
::attribute worldSnapshotOid
::attribute requestedBy
::attribute approvalScope
::attribute materializePolicy
::attribute canonicalInputHash
::attribute sourceManifestHash
::attribute providerExecutionId

::method init
  use arg invocationId, inputOid, worldSnapshotOid = '', requestedBy = 'TESTBED', approvalScope = 'DEFAULT', materializePolicy = 'MATERIALIZE_ONCE'
  self~invocationId = invocationId
  self~inputOid = inputOid
  self~worldSnapshotOid = worldSnapshotOid
  self~requestedBy = requestedBy
  self~approvalScope = approvalScope
  self~materializePolicy = materializePolicy~upper
  self~canonicalInputHash = ''
  self~sourceManifestHash = ''
  self~providerExecutionId = ''

::method bindIdentity
  use arg canonicalInputHash, sourceManifestHash
  self~canonicalInputHash = canonicalInputHash
  self~sourceManifestHash = sourceManifestHash
  return self~materializationKey

::method materializationKey
  use arg algorithmId = '', algorithmVersion = ''
  snapshotToken = self~worldSnapshotOid
  if snapshotToken == '' then snapshotToken = '<NO_WORLD_SNAPSHOT>'
  return algorithmId~upper || '|' || algorithmVersion || '|' || self~sourceManifestHash || '|' || self~canonicalInputHash || '|' || snapshotToken


::class AlgorithmRelationResult public
::attribute algorithmId
::attribute algorithmVersion
::attribute sourceComponent
::attribute sourceVersion
::attribute sourceFingerprint
::attribute sourceManifestHash
::attribute invocationId
::attribute inputOid
::attribute worldSnapshotOid
::attribute canonicalInputHash
::attribute materializationKey
::attribute materializationId
::attribute providerExecutionId
::attribute relations get
::attribute trace get
::attribute validationErrors get

::method init
  expose relations relationIndex trace validationErrors
  use arg algorithmId, algorithmVersion, sourceComponent, sourceVersion, sourceFingerprint, sourceManifestHash, context
  self~algorithmId = algorithmId~upper
  self~algorithmVersion = algorithmVersion
  self~sourceComponent = sourceComponent
  self~sourceVersion = sourceVersion
  self~sourceFingerprint = sourceFingerprint
  self~sourceManifestHash = sourceManifestHash
  self~invocationId = context~invocationId
  self~inputOid = context~inputOid
  self~worldSnapshotOid = context~worldSnapshotOid
  self~canonicalInputHash = context~canonicalInputHash
  self~materializationKey = context~materializationKey(self~algorithmId, self~algorithmVersion)
  self~materializationId = .AlgorithmDigest~sha256Text(self~materializationKey)
  self~providerExecutionId = context~providerExecutionId
  relations = .array~new
  relationIndex = .directory~new
  trace = .array~new
  validationErrors = .array~new

::method addRelation
  expose relations relationIndex
  use arg relation
  key = relation~relationName~upper
  if relationIndex~hasIndex(key) then return .false
  relations~append(relation)
  relationIndex[key] = relation
  return .true

::method relation
  expose relationIndex
  use arg relationName
  key = relationName~upper
  if relationIndex~hasIndex(key) then return relationIndex[key]
  return .nil

::method addTrace
  expose trace
  use arg line
  trace~append(line)
  return line

::method validate
  expose relations validationErrors
  validationErrors = .array~new
  if relations~items == 0 then validationErrors~append('NO_RELATIONS')
  do relation over relations
    do rejectedError over relation~rejectedRowErrors
      validationErrors~append(relation~relationName || ':REJECTED_ROW:' || rejectedError)
    end
    do row over relation~rows
      rowErrors = row~validate
      do rowError over rowErrors
        validationErrors~append(relation~relationName || ':' || rowError)
      end
    end
  end
  return validationErrors

::method cloneForContext
  expose relations trace
  use arg context
  clonedResult = .AlgorithmRelationResult~new(self~algorithmId, self~algorithmVersion, self~sourceComponent, self~sourceVersion, self~sourceFingerprint, self~sourceManifestHash, context)
  clonedResult~providerExecutionId = self~providerExecutionId
  do relation over relations
    added = clonedResult~addRelation(relation~cloneForInvocation(context~invocationId))
  end
  do traceLine over trace
    clonedResult~addTrace(traceLine)
  end
  clonedResult~addTrace('CACHE_REPLAY provider_execution_id=' || self~providerExecutionId || ' original_invocation=' || self~invocationId || ' current_invocation=' || context~invocationId)
  validationErrors = clonedResult~validate
  return clonedResult

::method render
  expose relations trace validationErrors
  lines = .array~new
  lines~append('ALGORITHM_RESULT id=' || self~algorithmId || '|version=' || self~algorithmVersion || '|source=' || self~sourceComponent || '|source_version=' || self~sourceVersion || '|source_fingerprint=' || self~sourceFingerprint || '|source_manifest_hash=' || self~sourceManifestHash || '|invocation=' || self~invocationId || '|input=' || self~inputOid || '|canonical_input_hash=' || self~canonicalInputHash || '|materialization_id=' || self~materializationId || '|provider_execution_id=' || self~providerExecutionId)
  lines~append('materialization_key=' || self~materializationKey)
  do relation over relations
    relationLines = relation~render
    do line over relationLines
      lines~append(line)
    end
  end
  if validationErrors~items > 0 then do
    lines~append('validation_errors:')
    do validationError over validationErrors
      lines~append('  ' || validationError)
    end
  end
  lines~append('trace:')
  do line over trace
    lines~append('  ' || line)
  end
  return lines


::class AlgorithmRelationEngine public
::attribute providers get
::attribute cacheHits
::attribute executions
::attribute invalidResults
::attribute providerExecutionSerial

::method init
  expose providers providerIndex cache viewCache
  providers = .array~new
  providerIndex = .directory~new
  cache = .directory~new
  viewCache = .directory~new
  self~cacheHits = 0
  self~executions = 0
  self~invalidResults = 0
  self~providerExecutionSerial = 0

::method addProvider
  expose providers providerIndex
  use arg provider
  key = provider~algorithmId~upper
  if providerIndex~hasIndex(key) then return .false
  providers~append(provider)
  providerIndex[key] = provider
  return .true

::method provider
  expose providerIndex
  use arg algorithmId
  key = algorithmId~upper
  if providerIndex~hasIndex(key) then return providerIndex[key]
  return .nil

::method catalog
  expose providers
  schema = .AlgorithmSchema~new('ALGORITHM_PROVIDER_CATALOG')
  schema~add('ALGORITHM_ID', 'TEXT', .false)
  schema~add('ALGORITHM_VERSION', 'TEXT', .false)
  schema~add('SOURCE_COMPONENT', 'TEXT', .false)
  schema~add('SOURCE_VERSION', 'TEXT', .false)
  schema~add('SOURCE_FINGERPRINT', 'TEXT', .false)
  schema~add('SOURCE_MANIFEST_HASH', 'TEXT', .false)
  schema~add('SOURCE_MANIFEST_MODE', 'TEXT', .false)
  schema~add('RELATION_NAME', 'TEXT', .false)
  schema~add('DETERMINISM', 'TEXT', .false)
  schema~add('SIDE_EFFECT_CLASS', 'TEXT', .false)
  schema~add('DEFAULT_MATERIALIZATION', 'TEXT', .false)
  schema~add('INPUT_CONTRACT', 'TEXT', .false)
  relation = .AlgorithmRelation~new(schema)
  do providerObject over providers
    declaredSchemas = providerObject~declaredSchemas
    do declaredSchema over declaredSchemas
      row = relation~newRow
      ok = row~put('ALGORITHM_ID', providerObject~algorithmId)
      ok = row~put('ALGORITHM_VERSION', providerObject~algorithmVersion)
      ok = row~put('SOURCE_COMPONENT', providerObject~sourceComponent)
      ok = row~put('SOURCE_VERSION', providerObject~sourceVersion)
      ok = row~put('SOURCE_FINGERPRINT', providerObject~sourceFingerprint)
      ok = row~put('SOURCE_MANIFEST_HASH', providerObject~sourceManifestHash)
      ok = row~put('SOURCE_MANIFEST_MODE', providerObject~sourceManifestMode)
      ok = row~put('RELATION_NAME', declaredSchema~relationName)
      ok = row~put('DETERMINISM', providerObject~determinism)
      ok = row~put('SIDE_EFFECT_CLASS', providerObject~sideEffectClass)
      ok = row~put('DEFAULT_MATERIALIZATION', providerObject~defaultMaterializePolicy)
      ok = row~put('INPUT_CONTRACT', providerObject~inputContract)
      added = relation~addRow(row)
    end
  end
  return relation

::method schemaCatalog
  expose providers
  schema = .AlgorithmSchema~new('ALGORITHM_SCHEMA_CATALOG')
  schema~add('ALGORITHM_ID', 'TEXT', .false)
  schema~add('ALGORITHM_VERSION', 'TEXT', .false)
  schema~add('SOURCE_COMPONENT', 'TEXT', .false)
  schema~add('SOURCE_VERSION', 'TEXT', .false)
  schema~add('SOURCE_FINGERPRINT', 'TEXT', .false)
  schema~add('SOURCE_MANIFEST_HASH', 'TEXT', .false)
  schema~add('RELATION_NAME', 'TEXT', .false)
  schema~add('ORDINAL', 'INTEGER', .false)
  schema~add('COLUMN_NAME', 'TEXT', .false)
  schema~add('TYPE_NAME', 'TEXT', .false)
  schema~add('NULLABLE', 'BOOLEAN', .false)
  schema~add('DOMAIN_VALUES', 'TEXT', .true)
  relation = .AlgorithmRelation~new(schema)
  do providerObject over providers
    declaredSchemas = providerObject~declaredSchemas
    do declaredSchema over declaredSchemas
      ordinal = 0
      do column over declaredSchema~columns
        ordinal = ordinal + 1
        row = relation~newRow
        ok = row~put('ALGORITHM_ID', providerObject~algorithmId)
        ok = row~put('ALGORITHM_VERSION', providerObject~algorithmVersion)
        ok = row~put('SOURCE_COMPONENT', providerObject~sourceComponent)
        ok = row~put('SOURCE_VERSION', providerObject~sourceVersion)
        ok = row~put('SOURCE_FINGERPRINT', providerObject~sourceFingerprint)
        ok = row~put('SOURCE_MANIFEST_HASH', providerObject~sourceManifestHash)
        ok = row~put('RELATION_NAME', declaredSchema~relationName)
        ok = row~put('ORDINAL', ordinal)
        ok = row~put('COLUMN_NAME', column~name)
        ok = row~put('TYPE_NAME', column~typeName)
        ok = row~put('NULLABLE', column~nullable)
        domainText = column~domainText
        if domainText == '' then ok = row~put('DOMAIN_VALUES', .nil)
        else ok = row~put('DOMAIN_VALUES', domainText)
        added = relation~addRow(row)
      end
    end
  end
  return relation

::method declaredSchemas
  use arg algorithmId
  providerObject = self~provider(algorithmId)
  if providerObject == .nil then return .array~new
  return providerObject~declaredSchemas

::method execute
  expose cache viewCache
  use arg algorithmId, inputObject, context
  providerObject = self~provider(algorithmId)
  if providerObject == .nil then return .nil

  canonicalInput = providerObject~canonicalInput(inputObject, context)
  canonicalInputHash = .AlgorithmDigest~sha256Text(canonicalInput)
  sourceManifestHash = providerObject~sourceManifestHash
  boundKey = context~bindIdentity(canonicalInputHash, sourceManifestHash)
  key = context~materializationKey(providerObject~algorithmId, providerObject~algorithmVersion)
  viewKey = key || '|AUDIT|' || context~invocationId

  if context~materializePolicy == .AlgorithmRelationConstant~MATERIALIZE_ONCE then do
    if viewCache~hasIndex(viewKey) then do
      self~cacheHits = self~cacheHits + 1
      return viewCache[viewKey]
    end
    if cache~hasIndex(key) then do
      self~cacheHits = self~cacheHits + 1
      cachedResult = cache[key]
      if cachedResult~invocationId == context~invocationId then do
        viewCache[viewKey] = cachedResult
        return cachedResult
      end
      replayResult = cachedResult~cloneForContext(context)
      viewCache[viewKey] = replayResult
      return replayResult
    end
  end

  self~providerExecutionSerial = self~providerExecutionSerial + 1
  context~providerExecutionId = providerObject~algorithmId || '-EXEC-' || self~providerExecutionSerial
  algorithmResult = providerObject~evaluate(inputObject, context)
  if algorithmResult == .nil then return .nil
  validationErrors = algorithmResult~validate
  self~executions = self~executions + 1

  if validationErrors~items > 0 then do
    self~invalidResults = self~invalidResults + 1
    return algorithmResult
  end

  if context~materializePolicy == .AlgorithmRelationConstant~MATERIALIZE_ONCE then do
    cache[key] = algorithmResult
    viewCache[viewKey] = algorithmResult
  end
  return algorithmResult

::method clearCache
  expose cache viewCache
  cache = .directory~new
  viewCache = .directory~new
  self~cacheHits = 0
  return 0

::requires 'AlgorithmIntegrity.cls'
