/* v0.13 host class-set contract: metadata ownership belongs to federation. */
say 'NOSQLSERVER EXTERNAL CLASSSET CONTRACT START'

world = .RYTAWorldState~new('WORLD-CLASSSET-CONTRACT')
provider = .RYTAAlgorithmProvider~new(.nil, '..')
algorithmEngine = .AlgorithmRelationEngine~new
call assert algorithmEngine~addProvider(provider), 'provider registration'
ctx = .AlgorithmExecutionContext~new('CLASSSET-INV-1', world~snapshotOid, world~snapshotOid)

/* A missing class set fails before provider invocation or schema construction. */
externalNil = .NoSQLAlgorithmRelationExternalEngine~new(algorithmEngine, 'VIRTUAL_RYTA', world, ctx, .nil)
call assert \externalNil~isReady, 'nil class set rejected'
call assert externalNil~lastError = 'NOSQL_CLASSSET_MISSING CLASS_SET', 'nil class-set reason' externalNil~lastError
call assert provider~invocationCount = 0, 'nil class set does not execute provider'

/* v0.70 requires only construction classes actually used by Algorithm Relation. */
classes = .directory~new
classes['TABLE_DEFINITION'] = .V013TestTableDefinition
classes['DATABASE_ROW'] = .V013TestDatabaseRow
classes['DATABASE_RESULT'] = .V013TestDatabaseResult
externalThree = .NoSQLAlgorithmRelationExternalEngine~new(algorithmEngine, 'VIRTUAL_RYTA', world, ctx, classes)
call assert externalThree~isReady, 'three-class v0.70 binding accepted' externalThree~lastError
call assert provider~invocationCount = 0, 'three-class binding stays metadata-only'
call assert externalThree~metadataFactoryCalls = 0, 'legacy metadata factory untouched'
legacyMeta = externalThree~tableMetadata('ryta_action_decisions')
call assert legacyMeta == .nil, 'optional metadata callback unavailable without class'
call assert externalThree~metadataFactoryCalls = 1, 'explicit legacy callback counted'
call assert externalThree~isReady, 'optional legacy callback does not poison v0.70 readiness' externalThree~lastError

/* Each genuinely required transport class is still mandatory. */
missingRow = .directory~new
missingRow['TABLE_DEFINITION'] = .V013TestTableDefinition
missingRow['DATABASE_RESULT'] = .V013TestDatabaseResult
externalMissingRow = .NoSQLAlgorithmRelationExternalEngine~new(algorithmEngine, 'VIRTUAL_RYTA', world, ctx, missingRow)
call assert \externalMissingRow~isReady, 'missing DATABASE_ROW rejected'
call assert externalMissingRow~lastError = 'NOSQL_CLASSSET_MISSING DATABASE_ROW', 'row class-set reason' externalMissingRow~lastError
call assert provider~invocationCount = 0, 'missing row class does not execute provider'

say 'NOSQLSERVER EXTERNAL CLASSSET CONTRACT: OK'
exit 0

assert: procedure
  use arg condition, message, detail = ''
  if condition then return .true
  raise syntax 93.900 additional('ASSERT FAILED: ' || message || ' ' || detail)

::class V013TestTableDefinition
::attribute name
::attribute rowCount
::method init
  use arg raw
  self~name = raw['name']
  self~rowCount = 0

::class V013TestDatabaseRow
::method init
  use arg values = .nil, rawValues = .nil, typeNames = .nil

::class V013TestDatabaseResult
::method init
  use arg status = .nil

::requires '../integration/NoSQLServerAlgorithmRelationExternalEngine.cls'
::requires '../algorithm/RYTAAlgorithmProvider.cls'
::requires '../HardWorld.cls'
