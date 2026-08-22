/*
 * NoSQLServerAlgorithmRelationExternalEngine.cls
 *
 * v0.7 native NoSQLServer v0.68 external-engine integration.
 *
 * The external engine exposes declared Algorithm Relation schemas to
 * FederatedDatabaseEngine without executing the provider.  The first actual
 * row read crosses the Algorithm Relation materialisation boundary exactly
 * once.  No predicate, projection, LIMIT, join, metadata request, row-count
 * estimate, or catalog request is pushed into the provider.
 *
 * The input and provider source identity are captured at engine construction.
 * If either changes before first materialisation, execution fails closed rather
 * than silently evaluating a different world than the one catalogued.
 */

::class NoSQLAlgorithmRelationExternalTable public
::attribute parentEngine
::attribute relationName
::attribute definition
::attribute generation

::method init
  use arg parentEngine, relationName, definition
  self~parentEngine = parentEngine
  self~relationName = relationName~upper
  self~definition = definition
  self~generation = 0

::method readRows
  return self~parentEngine~rowsFor(self~relationName)

/* Metadata/planner row-count requests MUST NOT execute the algorithm. */
::method rowCount
  count = self~parentEngine~materializedRowCount(self~relationName)
  if count == .nil then return .nil
  return count


::class NoSQLAlgorithmRelationExternalEngine public
::attribute algorithmEngine
::attribute algorithmId
::attribute inputObject
::attribute context get
::attribute lastError
::attribute algorithmResult get
::attribute tables get
::attribute initialCanonicalInputHash get
::attribute initialSourceManifestHash get
::attribute nosqlClasses get

::method integrationVersion
  return 'NOSQL-ALGREL-EXTERNAL-0.7'

::method init
  expose tables tableByRelation rowsCache initialCanonicalInputHash initialSourceManifestHash materialized context algorithmResult nosqlClasses
  use arg algorithmEngine, algorithmId, inputObject, context, nosqlClassSet, relationBindings = .nil

  self~algorithmEngine = algorithmEngine
  self~algorithmId = algorithmId~upper
  self~inputObject = inputObject
  self~lastError = ''
  algorithmResult = .nil
  /* NoSQLServer class objects are supplied by the host package. */
  nosqlClasses = nosqlClassSet
  materialized = .false
  tables = .table~new
  tableByRelation = .directory~new
  rowsCache = .directory~new

  providerObject = algorithmEngine~provider(self~algorithmId)
  if providerObject == .nil then do
    self~lastError = 'UNKNOWN_ALGORITHM ' || self~algorithmId
    return
  end

  /* Freeze the execution identity without invoking the provider. */
  frozenContext = .AlgorithmExecutionContext~new(context~invocationId, context~inputOid, context~worldSnapshotOid, context~requestedBy, context~approvalScope, context~materializePolicy)
  context = frozenContext

  initialSourceManifestHash = providerObject~sourceManifestHash
  canonicalInput = providerObject~canonicalInput(inputObject, frozenContext)
  initialCanonicalInputHash = .AlgorithmDigest~sha256Text(canonicalInput)

  readOperator = .AlgorithmRelationReadOperator~new(algorithmEngine)
  do declaredSchema over providerObject~declaredSchemas
    plan = .AlgorithmRelationReadPlan~new(self~algorithmId, declaredSchema~relationName)
    describedSchema = readOperator~describe(plan)
    if describedSchema == .nil then do
      self~lastError = readOperator~lastError
      tables = .table~new
      tableByRelation = .directory~new
      return
    end

    sqlTableName = self~boundTableName(declaredSchema~relationName, relationBindings)
    if tables[sqlTableName~upper] \== .nil then do
      self~lastError = 'DUPLICATE_SQL_TABLE_NAME ' || sqlTableName
      tables = .table~new
      tableByRelation = .directory~new
      return
    end

    definition = self~tableDefinitionFor(describedSchema, sqlTableName)
    if definition == .nil then do
      tables = .table~new
      tableByRelation = .directory~new
      return
    end

    tableObject = .NoSQLAlgorithmRelationExternalTable~new(self, declaredSchema~relationName, definition)
    tables[sqlTableName~upper] = tableObject
    tableByRelation[declaredSchema~relationName~upper] = tableObject
  end

::method isReady
  expose tables
  return self~lastError == '' & tables~items > 0

::method boundTableName private
  use arg relationName, relationBindings
  if relationBindings \== .nil then do
    if relationBindings~hasIndex(relationName~upper) then return relationBindings[relationName~upper]~string
    if relationBindings~hasIndex(relationName) then return relationBindings[relationName]~string
  end
  return relationName~lower

::method tableDefinitionFor private
  use arg algorithmSchema, sqlTableName
  raw = .table~new
  raw['name'] = sqlTableName
  rawColumns = .array~new

  do algorithmColumn over algorithmSchema~columns
    sqlType = self~nosqlTypeFor(algorithmColumn~typeName)
    if sqlType == '' then do
      self~lastError = 'UNSUPPORTED_NOSQL_TYPE ' || algorithmColumn~typeName || ' column=' || algorithmColumn~name
      return .nil
    end
    rawColumn = .table~new
    rawColumn['name'] = algorithmColumn~name~lower
    rawColumn['type'] = sqlType
    rawColumn['nullable'] = algorithmColumn~nullable
    rawColumns~append(rawColumn)
  end
  raw['columns'] = rawColumns
  classSet = self~nosqlClasses
  tableDefinitionClass = classSet['TABLE_DEFINITION']
  if tableDefinitionClass == .nil then do
    self~lastError = 'NOSQL_CLASSSET_MISSING TABLE_DEFINITION'
    return .nil
  end
  return tableDefinitionClass~new(raw)

::method table
  expose tables
  use arg tableName
  key = tableName~upper
  if tables[key] \== .nil then return tables[key]
  return .nil

::method tableNames
  expose tables
  names = .array~new
  do key over tables~allIndexes
    names~append(tables[key]~definition~name)
  end
  names~sort
  return names

/* Catalog/schema discovery is observational only. */
::method readCatalog
  raw = .table~new
  raw['name'] = 'algorithm:' || self~algorithmId
  raw['formatVersion'] = 1
  raw['tables'] = self~tableNames
  return raw

::method tableMetadata
  expose nosqlClasses
  use arg tableName
  t = self~table(tableName)
  if t == .nil then return .nil
  metadataClass = nosqlClasses['TABLE_METADATA']
  if metadataClass == .nil then do
    self~lastError = 'NOSQL_CLASSSET_MISSING TABLE_METADATA'
    return .nil
  end
  return metadataClass~new(t~definition)

::method tableRowCount
  use arg tableName
  t = self~table(tableName)
  if t == .nil then return .nil
  return t~rowCount

::method materializedRowCount
  expose rowsCache materialized
  use arg relationName
  if \materialized then return .nil
  key = relationName~upper
  if \rowsCache~hasIndex(key) then return 0
  return rowsCache[key]~items

::method ensureMaterialized private
  expose initialCanonicalInputHash initialSourceManifestHash materialized algorithmResult

  /*
   * Lazy materialisation is a one-time state transition.  Hold the ooRexx
   * object guard across that transition so simultaneous first readers cannot
   * both enter the provider.  Providers in this read-only contract must not
   * callback into this external-engine object.
   */
  guard on
  if materialized then do
    guard off
    return algorithmResult
  end
  self~lastError = ''

  providerObject = self~algorithmEngine~provider(self~algorithmId)
  if providerObject == .nil then do
    self~lastError = 'UNKNOWN_ALGORITHM ' || self~algorithmId
    guard off
    return .nil
  end

  currentManifestHash = providerObject~sourceManifestHash
  if currentManifestHash \== initialSourceManifestHash then do
    self~lastError = 'SOURCE_MANIFEST_CHANGED_BEFORE_MATERIALIZATION'
    guard off
    return .nil
  end

  currentCanonicalInput = providerObject~canonicalInput(self~inputObject, self~context)
  currentInputHash = .AlgorithmDigest~sha256Text(currentCanonicalInput)
  if currentInputHash \== initialCanonicalInputHash then do
    self~lastError = 'INPUT_CHANGED_BEFORE_MATERIALIZATION'
    guard off
    return .nil
  end

  computedResult = self~algorithmEngine~execute(self~algorithmId, self~inputObject, self~context)
  if computedResult == .nil then do
    self~lastError = 'ALGORITHM_EXECUTION_RETURNED_NIL'
    guard off
    return .nil
  end
  validationErrors = computedResult~validate
  if validationErrors~items > 0 then do
    self~lastError = 'INVALID_ALGORITHM_RESULT ' || validationErrors[1]
    guard off
    return .nil
  end

  algorithmResult = computedResult
  materialized = .true
  guard off
  return computedResult

::method rowsFor
  expose rowsCache tableByRelation
  use arg relationName
  key = relationName~upper

  if rowsCache~hasIndex(key) then return self~copyRows(rowsCache[key])

  computedResult = self~ensureMaterialized
  if computedResult == .nil then return .array~new

  relationObject = computedResult~relation(key)
  if relationObject == .nil then do
    self~lastError = 'RESULT_MISSING_RELATION ' || key
    return .array~new
  end

  convertedRows = .array~new
  do sourceRow over relationObject~rows
    values = .table~new
    rawValues = .table~new
    typeNames = .table~new
    do algorithmColumn over relationObject~schema~columns
      sqlName = algorithmColumn~name~lower
      fieldValue = sourceRow~value(algorithmColumn~name)
      values[sqlName] = fieldValue
      rawValues[sqlName] = fieldValue
      typeNames[sqlName] = self~nosqlTypeFor(algorithmColumn~typeName)
    end
    classSet = self~nosqlClasses
    databaseRowClass = classSet['DATABASE_ROW']
    if databaseRowClass == .nil then do
      self~lastError = 'NOSQL_CLASSSET_MISSING DATABASE_ROW'
      return .array~new
    end
    convertedRows~append(databaseRowClass~new(values, rawValues, typeNames))
  end
  rowsCache[key] = convertedRows

  t = tableByRelation[key]
  if t \== .nil then t~definition~rowCount = convertedRows~items
  return self~copyRows(convertedRows)

::method copyRows private
  use arg sourceRows
  copiedRows = .array~new
  do sourceRow over sourceRows
    copiedRows~append(sourceRow~copy)
  end
  return copiedRows

/* Full materialisation precedes every SQL predicate.  No provider pushdown. */
::method selectWhere
  use arg tableName, predicate
  classSet = self~nosqlClasses
  databaseResultClass = classSet['DATABASE_RESULT']
  if databaseResultClass == .nil then do
    self~lastError = 'NOSQL_CLASSSET_MISSING DATABASE_RESULT'
    return .nil
  end
  rs = databaseResultClass~new('SELECT')
  t = self~table(tableName)
  if t == .nil then return rs~fail('NOTFOUND', 'Algorithm Relation table not found:' tableName)

  allRows = t~readRows
  if self~lastError \== '' then return rs~fail('SQLERROR', self~lastError)

  found = .array~new
  do row over allRows
    if predicate == .nil then found~append(row)
    else if predicate~evaluate(row, t~definition) then found~append(row)
  end
  rs~rows = found
  rs~affectedRows = found~items
  rs~rowsScanned = allRows~items
  rs~accessPath = 'ALGORITHM_RELATION_MATERIALIZED_SCAN'
  return rs

::method selectAll
  use arg tableName
  return self~selectWhere(tableName, .nil)

::method nosqlTypeFor private
  use arg algorithmType
  select
    when algorithmType~upper == 'TEXT' then return 'VARCHAR'
    when algorithmType~upper == 'OID' then return 'VARCHAR'
    when algorithmType~upper == 'INTEGER' then return 'INTEGER'
    when algorithmType~upper == 'NUMBER' then return 'DECIMAL'
    when algorithmType~upper == 'BOOLEAN' then return 'BOOLEAN'
    otherwise return ''
  end

::requires '../algorithm/AlgorithmRelation.cls'
::requires '../algorithm/AlgorithmReadOperator.cls'
