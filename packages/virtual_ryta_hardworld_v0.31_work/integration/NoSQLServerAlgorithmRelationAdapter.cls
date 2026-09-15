/*
 * NoSQLServerAlgorithmRelationAdapter.cls
 *
 * v0.6 native-snapshot SQL-facing Algorithm Relation bridge.
 *
 * The Algorithm Relation engine performs and owns the computation.  This
 * adapter exposes an already-materialized typed relation to NoSQLServer's
 * existing federated object-table path.  NoSQLServer therefore sees an
 * ordinary read-only object collection; it never calls the algorithm
 * provider during SQL rescans.
 *
 * Expected NoSQLServer v0.65+ surface (not required to load this class):
 *   .ObjectTableMapping~new(tableName)
 *   mapping~column(sqlName, sqlType, getterMessage)
 *   federatedEngine~registerSnapshot(tableName, collection, mapping)
 */

::class NoSQLAlgorithmFederatedRow public
::method init
  expose values sourceRow
  use arg sourceRowArg
  sourceRow = sourceRowArg
  values = .directory~new

  do column over sourceRow~schema~columns
    key = column~name~upper
    if sourceRow~hasValue(key) then values[key] = sourceRow~value(key)
  end

::method hasColumn
  expose values
  use arg name
  return values~hasIndex(name~upper)

::method value
  expose values
  use arg name
  key = name~upper
  if values~hasIndex(key) then return values[key]
  return .nil

/*
 * ObjectTableMapping reads mapped values by sending a zero-argument message
 * to each object.  UNKNOWN lets one generic immutable wrapper expose any
 * declared Algorithm Relation column without manufacturing a class per schema.
 *
 * Any message carrying arguments is rejected: these rows are a frozen SQL
 * read snapshot, never a writable object table.
 */
::method unknown
  expose values
  use arg messageName, messageArguments
  if messageArguments == .nil then messageArguments = .array~new
  if messageArguments~items > 0 then do
    raise syntax 93.900 array('Algorithm Relation federated row is read-only: ' || messageName)
  end

  key = messageName~upper
  prefix = 'ALGREL_COLUMN__'
  if key~left(prefix~length) == prefix then key = key~substr(prefix~length + 1)
  if values~hasIndex(key) then return values[key]
  raise syntax 93.900 array('Unknown Algorithm Relation column message: ' || messageName)


::class NoSQLAlgorithmRelationRegistration public
::attribute bridgeVersion get
::attribute transportClass get
::attribute tableName get
::attribute algorithmId get
::attribute algorithmVersion get
::attribute relationName get
::attribute materializationId get
::attribute providerExecutionId get
::attribute auditInvocationId get
::attribute inputOid get
::attribute worldSnapshotOid get
::attribute sourceManifestHash get

::method init
  expose bridgeVersion transportClass tableName algorithmId algorithmVersion relationName materializationId providerExecutionId auditInvocationId inputOid worldSnapshotOid sourceManifestHash rows
  use arg tableNameArg, providerObject, relationNameArg, algorithmResult, mappingObject, rowCollection
  bridgeVersion = 'NOSQL-ALGREL-BRIDGE-0.6'
  transportClass = 'FEDERATED_OBJECT_NATIVE_SNAPSHOT'
  tableName = tableNameArg
  algorithmId = providerObject~algorithmId
  algorithmVersion = providerObject~algorithmVersion
  relationName = relationNameArg
  materializationId = algorithmResult~materializationId
  providerExecutionId = algorithmResult~providerExecutionId
  auditInvocationId = algorithmResult~invocationId
  inputOid = algorithmResult~inputOid
  worldSnapshotOid = algorithmResult~worldSnapshotOid
  sourceManifestHash = algorithmResult~sourceManifestHash
  rows = rowCollection

::method rowCount
  expose rows
  return rows~items

::method rowAt
  expose rows
  use arg index
  if index < 1 | index > rows~items then return .nil
  return rows[index]


::class NoSQLServerAlgorithmRelationAdapter public
::attribute federatedEngine
::attribute algorithmEngine
::attribute readOperator
::attribute lastError
::attribute mappingFactory

::method bridgeVersion
  return 'NOSQL-ALGREL-BRIDGE-0.6'

::method transportClass
  return 'FEDERATED_OBJECT_NATIVE_SNAPSHOT'

::method init
  expose registrations
  use arg federatedEngine, algorithmEngine, mappingFactory = .nil
  self~federatedEngine = federatedEngine
  self~algorithmEngine = algorithmEngine
  self~readOperator = .AlgorithmRelationReadOperator~new(algorithmEngine)
  self~mappingFactory = mappingFactory
  self~lastError = ''
  registrations = .directory~new

/* Metadata-only bind/describe.  This MUST NOT execute the provider. */
::method describe
  use arg algorithmId, relationName
  self~lastError = ''
  plan = .AlgorithmRelationReadPlan~new(algorithmId, relationName)
  schema = self~readOperator~describe(plan)
  if schema == .nil then self~lastError = self~readOperator~lastError
  return schema

/*
 * Build the NoSQLServer ObjectTableMapping from declared Algorithm Relation
 * schema only.  Metadata discovery remains execution-free.
 */
::method buildMapping
  use arg algorithmId, relationName, tableName
  self~lastError = ''
  schema = self~describe(algorithmId, relationName)
  if schema == .nil then return .nil

  if self~mappingFactory == .nil then mapping = .ObjectTableMapping~new(tableName)
  else do
    if self~mappingFactory~hasMethod('newMapping') then mapping = self~mappingFactory~newMapping(tableName)
    else mapping = self~mappingFactory~new(tableName)
  end
  do column over schema~columns
    sqlName = column~name~lower
    sqlType = self~nosqlTypeFor(column~typeName)
    if sqlType == '' then do
      self~lastError = 'UNSUPPORTED_NOSQL_TYPE ' || column~typeName || ' column=' || column~name
      return .nil
    end
    getterMessage = self~getterMessageFor(column~name)
    mapped = mapping~column(sqlName, sqlType, getterMessage)
    if \self~truthValue(mapped) then do
      self~lastError = 'NOSQL_MAPPING_COLUMN_REJECTED ' || sqlName
      return .nil
    end
  end
  return mapping

/*
 * Materialize the full provider result exactly once under AlgorithmRelationEngine
 * semantics.  No projection/predicate/LIMIT is supplied here: the complete
 * provider result is the object registered into NoSQLServer.
 */
::method materialize
  use arg algorithmId, inputObject, context
  self~lastError = ''
  providerObject = self~algorithmEngine~provider(algorithmId)
  if providerObject == .nil then do
    self~lastError = 'UNKNOWN_ALGORITHM ' || algorithmId
    return .nil
  end

  /* Bind every declared relation without execution before crossing boundary. */
  do declaredSchema over providerObject~declaredSchemas
    schema = self~describe(algorithmId, declaredSchema~relationName)
    if schema == .nil then return .nil
  end

  algorithmResult = self~algorithmEngine~execute(algorithmId, inputObject, context)
  if algorithmResult == .nil then do
    self~lastError = 'ALGORITHM_EXECUTION_RETURNED_NIL ' || algorithmId
    return .nil
  end
  validationErrors = algorithmResult~validate
  if validationErrors~items > 0 then do
    self~lastError = 'INVALID_ALGORITHM_RESULT ' || validationErrors[1]
    return .nil
  end
  return algorithmResult

/* Register one already-materialized relation as a frozen read-only table. */
::method registerMaterialized
  expose registrations
  use arg algorithmResult, relationName, tableName
  self~lastError = ''
  if algorithmResult == .nil then do
    self~lastError = 'NIL_ALGORITHM_RESULT'
    return .nil
  end

  registrationKey = tableName~upper
  if registrations~hasIndex(registrationKey) then do
    self~lastError = 'TABLE_ALREADY_REGISTERED ' || tableName
    return .nil
  end

  providerObject = self~algorithmEngine~provider(algorithmResult~algorithmId)
  if providerObject == .nil then do
    self~lastError = 'UNKNOWN_ALGORITHM ' || algorithmResult~algorithmId
    return .nil
  end

  relationObject = algorithmResult~relation(relationName)
  if relationObject == .nil then do
    self~lastError = 'UNKNOWN_MATERIALIZED_RELATION ' || relationName
    return .nil
  end

  mapping = self~buildMapping(providerObject~algorithmId, relationName, tableName)
  if mapping == .nil then return .nil

  frozenRows = .array~new
  do sourceRow over relationObject~rows
    frozenRows~append(.NoSQLAlgorithmFederatedRow~new(sourceRow))
  end

  if \self~federatedEngine~hasMethod('registerSnapshot') then do
    self~lastError = 'NOSQL_SNAPSHOT_REGISTRATION_REQUIRED ' || tableName
    return .nil
  end
  registered = self~federatedEngine~registerSnapshot(tableName, frozenRows, mapping)
  if \self~truthValue(registered) then do
    self~lastError = 'NOSQL_SNAPSHOT_REGISTER_FAILED ' || tableName
    return .nil
  end

  registration = .NoSQLAlgorithmRelationRegistration~new(tableName, providerObject, relationName~upper, algorithmResult, mapping, frozenRows)
  registrations[tableName~upper] = registration
  return registration

/* Convenience: materialize once, then register one relation. */
::method materializeAndRegister
  use arg algorithmId, relationName, tableName, inputObject, context
  algorithmResult = self~materialize(algorithmId, inputObject, context)
  if algorithmResult == .nil then return .nil
  return self~registerMaterialized(algorithmResult, relationName, tableName)

/*
 * Register multiple relations from the SAME provider result.  This is the
 * preferred shape for providers such as RYTA which publish decisions + trace.
 * relationBindings is a Directory: RELATION_NAME -> SQL_TABLE_NAME.
 */
::method registerMaterializedSet
  use arg algorithmResult, relationBindings
  created = .array~new
  relationNames = relationBindings~allIndexes
  relationNames~sort
  do relationName over relationNames
    registration = self~registerMaterialized(algorithmResult, relationName, relationBindings[relationName])
    if registration == .nil then return .nil
    created~append(registration)
  end
  return created

::method registrationCount
  expose registrations
  return registrations~items

::method registration
  expose registrations
  use arg tableName
  key = tableName~upper
  if registrations~hasIndex(key) then return registrations[key]
  return .nil

::method getterMessageFor
  use arg columnName
  return 'ALGREL_COLUMN__' || columnName~upper

::method nosqlTypeFor
  use arg algorithmType
  select
    when algorithmType~upper == 'TEXT' then return 'VARCHAR'
    when algorithmType~upper == 'OID' then return 'VARCHAR'
    when algorithmType~upper == 'INTEGER' then return 'INTEGER'
    when algorithmType~upper == 'NUMBER' then return 'DECIMAL'
    when algorithmType~upper == 'BOOLEAN' then return 'BOOLEAN'
    otherwise return ''
  end

/* Cope with NoSQLServer register/mapping methods returning Rexx truth values. */
::method truthValue private
  use arg value
  if value == .true then return .true
  if value == .false then return .false
  if datatype(value, 'N') then return value \= 0
  return value \== ''

::requires '../algorithm/AlgorithmRelation.cls'
::requires '../algorithm/AlgorithmReadOperator.cls'
