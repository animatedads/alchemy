/* Generic Algorithm Relation v0.4 contract, typing and content identity tests. */

say 'ALGORITHM RELATION CORE V0.4 START'

schema = .AlgorithmSchema~new('EXAMPLE')
call assertTrue 'add id column', schema~add('ID', 'INTEGER', .false)
call assertTrue 'add value column', schema~add('VALUE', 'TEXT', .true)
call assertTrue 'add bool column', schema~add('FLAG', 'BOOLEAN', .false)
call assertTrue 'add enum column', schema~addEnum('STATE', 'TEXT', .false, .array~of('A','B'))
call assertEqual 'column count', 4, schema~columns~items

relation = .AlgorithmRelation~new(schema)
row = relation~newRow
call assertTrue 'put id', row~put('ID', 1)
call assertTrue 'put value', row~put('VALUE', 'hello')
call assertTrue 'put flag', row~put('FLAG', .true)
call assertTrue 'put enum', row~put('STATE', 'A')
call assertEqual 'valid row errors', 0, row~validate~items
call assertTrue 'add valid row', relation~addRow(row)

nullableRow = relation~newRow
ok = nullableRow~put('ID', 2)
ok = nullableRow~put('VALUE', .nil)
ok = nullableRow~put('FLAG', .false)
ok = nullableRow~put('STATE', 'B')
call assertEqual 'explicit null accepted for nullable', 0, nullableRow~validate~items
call assertTrue 'add nullable row', relation~addRow(nullableRow)

omittedNullable = relation~newRow
ok = omittedNullable~put('ID', 3)
ok = omittedNullable~put('FLAG', .true)
ok = omittedNullable~put('STATE', 'A')
call assertContains 'omitted nullable is distinct from NULL', omittedNullable~validate, 'MISSING_COLUMN VALUE'

wrongType = relation~newRow
ok = wrongType~put('ID', 'not-an-integer')
ok = wrongType~put('VALUE', 'hello')
ok = wrongType~put('FLAG', .true)
ok = wrongType~put('STATE', 'A')
call assertContainsPrefix 'integer type enforced', wrongType~validate, 'ID:TYPE_MISMATCH'

wrongDomain = relation~newRow
ok = wrongDomain~put('ID', 4)
ok = wrongDomain~put('VALUE', 'hello')
ok = wrongDomain~put('FLAG', .true)
ok = wrongDomain~put('STATE', 'C')
call assertContainsPrefix 'domain enforced', wrongDomain~validate, 'STATE:DOMAIN_VIOLATION'

unknownColumnRow = relation~newRow
ok = unknownColumnRow~put('ID', 5)
ok = unknownColumnRow~put('VALUE', 'hello')
ok = unknownColumnRow~put('FLAG', .true)
ok = unknownColumnRow~put('STATE', 'A')
call assertTrue 'reject unknown column', \unknownColumnRow~put('NO_SUCH_COLUMN', 'x')
call assertContains 'unknown write remains sticky', unknownColumnRow~validate, 'UNKNOWN_COLUMN NO_SUCH_COLUMN'
call assertTrue 'relation rejects unknown-column row', \relation~addRow(unknownColumnRow)

invalidResultContext = .AlgorithmExecutionContext~new('INVALID-1', 'INPUT-X', 'WORLD-X')
invalidResultContext~bindIdentity(.AlgorithmDigest~sha256Text('bad'), .AlgorithmDigest~sha256Text('manifest'))
invalidAlgorithmResult = .AlgorithmRelationResult~new('INVALID_TEST', '1', 'TEST_COMPONENT', '1', 'TEST-FINGERPRINT-1', invalidResultContext~sourceManifestHash, invalidResultContext)
added = invalidAlgorithmResult~addRelation(relation)
call assertTrue 'result surfaces rejected relation rows', invalidAlgorithmResult~validate~items > 0

provider = .AlgorithmRelationTestProvider~new
engine = .AlgorithmRelationEngine~new
call assertTrue 'register provider', engine~addProvider(provider)

catalog = engine~catalog
call assertEqual 'catalog row count', 1, catalog~rows~items
call assertEqual 'catalog algorithm id', 'TEST_ALGORITHM', catalog~rows[1]~value('ALGORITHM_ID')
call assertEqual 'catalog determinism', 'DETERMINISTIC_GIVEN_MATERIALIZED_INPUT', catalog~rows[1]~value('DETERMINISM')
call assertTrue 'catalog manifest hash populated', catalog~rows[1]~value('SOURCE_MANIFEST_HASH')~length == 64
call assertEqual 'catalog discovery does not execute provider', 0, provider~invocationCount
schemaCatalog = engine~schemaCatalog
call assertEqual 'schema catalog columns', 2, schemaCatalog~rows~items
call assertEqual 'schema discovery does not execute provider', 0, provider~invocationCount

context = .AlgorithmExecutionContext~new('INV-1', 'INPUT-1', 'WORLD-1')
firstResult = engine~execute('TEST_ALGORITHM', 'payload-A', context)
call assertTrue 'first result returned', firstResult \== .nil
call assertEqual 'provider invoked once', 1, provider~invocationCount
call assertEqual 'engine execution count', 1, engine~executions
call assertEqual 'first result valid', 0, firstResult~validationErrors~items
call assertTrue 'canonical input hash populated', firstResult~canonicalInputHash~length == 64
call assertTrue 'materialization id populated', firstResult~materializationId~length == 64
call assertTrue 'provider execution id populated', firstResult~providerExecutionId~length > 0

secondResult = engine~execute('TEST_ALGORITHM', 'payload-A', context)
call assertTrue 'same logical rescan returns same object', firstResult == secondResult
call assertEqual 'provider still invoked once', 1, provider~invocationCount

changedContent = engine~execute('TEST_ALGORITHM', 'payload-B', context)
call assertTrue 'changed actual content is different materialization', changedContent \== firstResult
call assertEqual 'changed content reruns provider despite same caller ids', 2, provider~invocationCount
call assertTrue 'changed content changes canonical hash', changedContent~canonicalInputHash \== firstResult~canonicalInputHash
call assertTrue 'changed content changes materialization key', changedContent~materializationKey \== firstResult~materializationKey

newInvocation = .AlgorithmExecutionContext~new('INV-2', 'DIFFERENT-CALLER-OID', 'WORLD-1')
replayedResult = engine~execute('TEST_ALGORITHM', 'payload-A', newInvocation)
call assertEqual 'new audit invocation reuses content materialization', 2, provider~invocationCount
call assertTrue 'audit replay is a distinct view', replayedResult \== firstResult
call assertEqual 'audit replay shares materialization identity', firstResult~materializationKey, replayedResult~materializationKey
call assertEqual 'audit replay carries new invocation id', 'INV-2', replayedResult~invocationId
call assertEqual 'audit replay preserves original provider execution id', firstResult~providerExecutionId, replayedResult~providerExecutionId
call assertEqual 'audit replay preserves materialization id', firstResult~materializationId, replayedResult~materializationId
call assertEqual 'row invocation id rebound', 'INV-2', replayedResult~relation('TEST_ROWS')~rows[1]~value('INVOCATION_ID')
replayedAgain = engine~execute('TEST_ALGORITHM', 'payload-A', newInvocation)
call assertTrue 'repeated audit rescan returns same replay view', replayedAgain == replayedResult
call assertEqual 'provider still not rerun', 2, provider~invocationCount

freshContext = .AlgorithmExecutionContext~new('INV-FRESH', 'INPUT-1', 'WORLD-1', 'TESTBED', 'DEFAULT', .AlgorithmRelationConstant~FRESH)
freshResult = engine~execute('TEST_ALGORITHM', 'payload-A', freshContext)
call assertTrue 'fresh execution returns result', freshResult \== .nil
call assertEqual 'fresh invokes provider again', 3, provider~invocationCount
call assertEqual 'fresh has same content materialization identity', firstResult~materializationKey, freshResult~materializationKey
call assertTrue 'fresh result object distinct', freshResult \== firstResult
call assertEqual 'fresh identical content has same materialization id', firstResult~materializationId, freshResult~materializationId
call assertTrue 'fresh execution has different provider execution id', freshResult~providerExecutionId \== firstResult~providerExecutionId

newWorld = .AlgorithmExecutionContext~new('INV-3', 'INPUT-1', 'WORLD-2')
worldResult = engine~execute('TEST_ALGORITHM', 'payload-A', newWorld)
call assertEqual 'different world snapshot forces new materialization', 4, provider~invocationCount
call assertTrue 'world snapshot changes key', worldResult~materializationKey \== firstResult~materializationKey

oldManifestHash = provider~sourceManifestHash
provider~mutateManifest('EXTRA', 'different-source')
call assertTrue 'source manifest mutation changes manifest hash', provider~sourceManifestHash \== oldManifestHash
manifestContext = .AlgorithmExecutionContext~new('INV-4', 'INPUT-1', 'WORLD-1')
manifestResult = engine~execute('TEST_ALGORITHM', 'payload-A', manifestContext)
call assertEqual 'source manifest change forces provider execution', 5, provider~invocationCount
call assertTrue 'source manifest changes materialization key', manifestResult~materializationKey \== firstResult~materializationKey

say 'ALGORITHM RELATION CORE V0.4: OK'
exit 0

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

assertContains: procedure
  use arg label, values, expected
  do value over values
    if value == expected then return .true
  end
  say 'ASSERT FAILED:' label
  say '  missing:' expected
  exit 1

assertContainsPrefix: procedure
  use arg label, values, expectedPrefix
  do value over values
    if value~left(expectedPrefix~length) == expectedPrefix then return .true
  end
  say 'ASSERT FAILED:' label
  say '  missing prefix:' expectedPrefix
  do value over values
    say '  saw:' value
  end
  exit 1

::class AlgorithmRelationTestProvider public
::attribute invocationCount
::attribute sourceManifest get

::method init
  expose sourceManifest
  self~invocationCount = 0
  sourceManifest = .AlgorithmSourceManifest~new
  sourceManifest~mode = 'TEST_MANIFEST'
  sourceManifest~add('PROVIDER', 'TEST_PROVIDER_V0.4')
  sourceManifest~add('MODEL', 'TEST_MODEL_V1')

::method mutateManifest
  expose sourceManifest
  use arg name, fingerprint
  return sourceManifest~add(name, fingerprint)

::method algorithmId
  return 'TEST_ALGORITHM'

::method algorithmVersion
  return '0.4'

::method sourceComponent
  return 'TEST_COMPONENT'

::method sourceVersion
  return '1'

::method sourceFingerprint
  return 'TEST-FINGERPRINT-1'

::method sourceManifestHash
  expose sourceManifest
  return sourceManifest~hash

::method sourceManifestMode
  expose sourceManifest
  return sourceManifest~mode

::method determinism
  return .AlgorithmRelationConstant~DETERMINISTIC_GIVEN_MATERIALIZED_INPUT

::method sideEffectClass
  return 'NONE'

::method defaultMaterializePolicy
  return .AlgorithmRelationConstant~MATERIALIZE_ONCE

::method inputContract
  return 'TEXT'

::method canonicalInput
  use arg inputObject, context
  return 'TEXT_PAYLOAD=' || inputObject

::method declaredSchemas
  schemas = .array~new
  schema = .AlgorithmSchema~new('TEST_ROWS')
  schema~add('INVOCATION_ID', 'TEXT', .false)
  schema~add('PAYLOAD', 'TEXT', .false)
  schemas~append(schema)
  return schemas

::method evaluate
  use arg inputObject, context
  self~invocationCount = self~invocationCount + 1
  algorithmResult = .AlgorithmRelationResult~new(self~algorithmId, self~algorithmVersion, self~sourceComponent, self~sourceVersion, self~sourceFingerprint, self~sourceManifestHash, context)
  schema = .AlgorithmSchema~new('TEST_ROWS')
  schema~add('INVOCATION_ID', 'TEXT', .false)
  schema~add('PAYLOAD', 'TEXT', .false)
  relation = .AlgorithmRelation~new(schema)
  row = relation~newRow
  ok = row~put('INVOCATION_ID', context~invocationId)
  ok = row~put('PAYLOAD', inputObject)
  added = relation~addRow(row)
  added = algorithmResult~addRelation(relation)
  algorithmResult~addTrace('TEST_PROVIDER invocation=' || self~invocationCount)
  return algorithmResult

::requires '../algorithm/AlgorithmRelation.cls'
