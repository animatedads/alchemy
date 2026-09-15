/*
 * Contract test for the NoSQLServer v0.58 federated object-table bridge.
 * Uses tiny API-compatible stubs because the v0.58 source tree is external
 * to this package.  The separate external integration runner exercises the
 * real classes when NoSQLServer.cls is supplied.
 */

say 'NOSQLSERVER ALGORITHM ADAPTER CONTRACT V0.6 START'

world = .RYTAWorldState~new('WORLD-NOSQL-BRIDGE-1')
world~putKnown('HAS_QUERY', .true)
world~putKnown('PRODUCT_RELEVANT', .true)
world~putKnown('PRODUCT_VALUE_HIGH', .true)
world~putKnown('UPSELL_OPPORTUNITY', .true)
world~putKnown('ESSENTIAL_MEDICATION', .true)
world~putKnown('IMMEDIATE_ACCESS', .true)
world~putKnown('GUARANTEED_CUSTODY', .false)

provider = .RYTAAlgorithmProvider~new(.nil, '..')
algorithmEngine = .AlgorithmRelationEngine~new
call assertTrue 'provider registration', algorithmEngine~addProvider(provider)
federated = .FederatedEngineContractStub~new
adapter = .NoSQLServerAlgorithmRelationAdapter~new(federated, algorithmEngine, .ObjectTableMappingStub)

/* Metadata mapping is declaration-only and must not invoke provider. */
mapping = adapter~buildMapping('VIRTUAL_RYTA', 'RYTA_ACTION_DECISIONS', 'ryta_actions')
call assertTrue 'metadata mapping exists', mapping \== .nil
call assertEqual 'metadata does not invoke provider', 0, provider~invocationCount
call assertEqual 'twenty mapped action columns', 20, mapping~columns~items
call assertEqual 'TEXT maps to VARCHAR', 'VARCHAR', mapping~typeFor('action_code')
call assertEqual 'OID maps to VARCHAR', 'VARCHAR', mapping~typeFor('world_snapshot_oid')
call assertEqual 'NUMBER maps to DECIMAL', 'DECIMAL', mapping~typeFor('score')
call assertEqual 'BOOLEAN maps to BOOLEAN', 'BOOLEAN', mapping~typeFor('final_selected')
call assertEqual 'getter uses collision-safe transport namespace', 'ALGREL_COLUMN__ACTION_CODE', mapping~getterFor('action_code')
traceMapping = adapter~buildMapping('VIRTUAL_RYTA', 'RYTA_DECISION_TRACE', 'ryta_trace_probe')
call assertEqual 'INTEGER maps to INTEGER', 'INTEGER', traceMapping~typeFor('sequence')
call assertEqual 'second metadata mapping still does not invoke provider', 0, provider~invocationCount

context = .AlgorithmExecutionContext~new('NOSQL-INV-1', world~snapshotOid, world~snapshotOid)
algorithmResult = adapter~materialize('VIRTUAL_RYTA', world, context)
call assertTrue 'materialization succeeds', algorithmResult \== .nil
call assertEqual 'provider executes once', 1, provider~invocationCount

bindings = .directory~new
bindings['RYTA_ACTION_DECISIONS'] = 'ryta_actions'
bindings['RYTA_DECISION_TRACE'] = 'ryta_trace'
registrations = adapter~registerMaterializedSet(algorithmResult, bindings)
call assertTrue 'two registrations returned', registrations \== .nil
call assertEqual 'two relations registered', 2, registrations~items
call assertEqual 'federated register called twice', 2, federated~registerCount
call assertEqual 'registering result never reruns provider', 1, provider~invocationCount
duplicateRegistration = adapter~registerMaterialized(algorithmResult, 'RYTA_ACTION_DECISIONS', 'ryta_actions')
call assertTrue 'duplicate table registration refused', duplicateRegistration == .nil
call assertEqual 'duplicate refusal happens before federated register', 2, federated~registerCount

reg = adapter~registration('RYTA_ACTIONS')
call assertTrue 'action registration lookup', reg \== .nil
call assertEqual 'seven immutable action rows', 7, reg~rowCount
call assertEqual 'registration keeps materialization id', algorithmResult~materializationId, reg~materializationId
call assertEqual 'registration keeps provider execution id', algorithmResult~providerExecutionId, reg~providerExecutionId
call assertEqual 'bridge version recorded', 'NOSQL-ALGREL-BRIDGE-0.6', reg~bridgeVersion
call assertEqual 'transport class recorded', 'FEDERATED_OBJECT_NATIVE_SNAPSHOT', reg~transportClass
call assertTrue 'registration provenance setters not exposed', \reg~hasMethod('materializationId=')
call assertTrue 'registration backing row array not exposed', \reg~hasMethod('rows')

firstRow = reg~rowAt(1)
call assertTrue 'transport action_code getter exists through UNKNOWN', firstRow~send('ALGREL_COLUMN__ACTION_CODE') \== ''
call assertEqual 'transport state getter', 'REMEDIATION_REQUIRED', firstRow~send('ALGREL_COLUMN__STATE')
call assertTrue 'read-only setter rejected', setterRejected(firstRow)
call assertTrue 'backing values directory is not exposed', \firstRow~hasMethod('values')
call assertTrue 'source AlgorithmRow is not exposed', \firstRow~hasMethod('sourceRow')

/* Collision proof: SQL transport getter cannot alias inherited Object~string. */
collisionSchema = .AlgorithmSchema~new('COLLISION_TEST')
collisionSchema~add('STRING', 'TEXT', .false)
collisionRow = .AlgorithmRow~new(collisionSchema)
ignore = collisionRow~put('STRING', 'domain-string-value')
collisionWrapper = .NoSQLAlgorithmFederatedRow~new(collisionRow)
call assertEqual 'collision-safe STRING transport getter', 'domain-string-value', collisionWrapper~send('ALGREL_COLUMN__STRING')
call assertTrue 'ordinary Object string method remains distinct', collisionWrapper~string \== 'domain-string-value'

/* Re-materializing the same logical content returns cache, no provider rerun. */
sameResult = adapter~materialize('VIRTUAL_RYTA', world, context)
call assertTrue 'same audit invocation returns same result object', sameResult == algorithmResult
call assertEqual 'provider remains single execution', 1, provider~invocationCount

/* Changed audit invocation, same content: replay view, same provider execution. */
context2 = .AlgorithmExecutionContext~new('NOSQL-INV-2', world~snapshotOid, world~snapshotOid)
replay = adapter~materialize('VIRTUAL_RYTA', world, context2)
call assertTrue 'new audit invocation gets replay view', replay \== algorithmResult
call assertEqual 'provider still one execution after replay', 1, provider~invocationCount
call assertEqual 'materialization identity preserved', algorithmResult~materializationId, replay~materializationId
call assertEqual 'provider execution identity preserved', algorithmResult~providerExecutionId, replay~providerExecutionId
call assertEqual 'audit invocation rebound', 'NOSQL-INV-2', replay~invocationId

say 'NOSQLSERVER ALGORITHM ADAPTER CONTRACT V0.6: OK'
exit 0

setterRejected: procedure
  use arg row
  signal on syntax name setterFailed
  ignore = row~send('ACTION_CODE=', 'MUTATED')
  signal off syntax
  return .false
setterFailed:
  signal off syntax
  return .true

assertEqual: procedure
  use arg label, expected, actual
  if expected == actual then return .true
  say 'ASSERT FAILED:' label
  say '  expected:' expected
  say '  actual:  ' actual
  exit 1

assertTrue: procedure
  use arg label, actual
  if actual then return .true
  say 'ASSERT FAILED:' label
  say '  actual:' actual
  exit 1

/* API-compatible metadata stub for .ObjectTableMapping from NoSQLServer v0.58. */
::class ObjectTableMappingStub public
::attribute tableName
::attribute columns get

::method init
  expose columns typeIndex getterIndex
  use arg tableName
  self~tableName = tableName
  columns = .array~new
  typeIndex = .directory~new
  getterIndex = .directory~new

::method column
  expose columns typeIndex getterIndex
  use arg sqlName, sqlType, getterMessage
  key = sqlName~lower
  columns~append(key)
  typeIndex[key] = sqlType~upper
  getterIndex[key] = getterMessage
  return .true

::method getterFor
  expose getterIndex
  use arg sqlName
  return getterIndex[sqlName~lower]

::method typeFor
  expose typeIndex
  use arg sqlName
  return typeIndex[sqlName~lower]

::class FederatedEngineContractStub public
::attribute registerCount
::attribute tables get
::attribute mappings get

::method init
  expose tables mappings
  self~registerCount = 0
  tables = .directory~new
  mappings = .directory~new

::method register
  expose tables mappings
  use arg tableName, rows, mapping
  self~registerCount = self~registerCount + 1
  tables[tableName~upper] = rows
  mappings[tableName~upper] = mapping
  return .true

::method registerSnapshot
  expose tables mappings
  use arg tableName, rows, mapping
  self~registerCount = self~registerCount + 1
  tables[tableName~upper] = rows
  mappings[tableName~upper] = mapping
  return .true

::requires '../integration/NoSQLServerAlgorithmRelationAdapter.cls'
::requires '../algorithm/RYTAAlgorithmProvider.cls'
::requires '../HardWorld.cls'
