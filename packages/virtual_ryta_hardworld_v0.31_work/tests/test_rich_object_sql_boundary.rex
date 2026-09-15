say 'RICH OBJECT SQL BOUNDARY START'

provider = .RichOutputBoundaryProbeProvider~new
engine = .AlgorithmRelationEngine~new
call Assert engine~addProvider(provider), 'probe provider registered'
classSet = .directory~new
/* The RICH_OBJECT rejection happens before any constructor is used; non-nil
   class objects are sufficient to prove the adapter boundary. */
classSet['TABLE_DEFINITION'] = .Object
classSet['DATABASE_ROW'] = .Object
classSet['DATABASE_RESULT'] = .Object
context = .AlgorithmExecutionContext~new('RICH-SQL-BOUNDARY-1','INPUT-1','WORLD-1')
external = .NoSQLAlgorithmRelationExternalEngine~new(engine,'RICH_OUTPUT_BOUNDARY','INPUT',context,classSet)
call Assert \external~isReady, 'SQL external engine refuses RICH_OBJECT relation'
call Assert external~lastError~pos('UNSUPPORTED_NOSQL_TYPE RICH_OBJECT') > 0, 'failure explicitly names unsupported rich type'
call Assert provider~invocationCount = 0, 'SQL bind refusal does not execute provider'

say 'RICH OBJECT SQL BOUNDARY: OK'
exit 0

Assert: procedure
  use arg condition, message
  if \condition then raise syntax 93.900 additional('ASSERT FAILED: ' || message)
  return

::class RichOutputBoundaryProbeProvider public
::attribute invocationCount
::method init
  self~invocationCount = 0
::method algorithmId
  return 'RICH_OUTPUT_BOUNDARY'
::method algorithmVersion
  return '0.15'
::method sourceComponent
  return 'BOUNDARY_TEST'
::method sourceVersion
  return '0.15'
::method sourceFingerprint
  return 'BOUNDARY-RICH-OBJECT'
::method sourceManifestHash
  return 'BOUNDARY-MANIFEST-HASH'
::method sourceManifestMode
  return 'FILE_HASHED'
::method determinism
  return .AlgorithmRelationConstant~DETERMINISTIC_GIVEN_MATERIALIZED_INPUT
::method sideEffectClass
  return 'NONE'
::method defaultMaterializePolicy
  return .AlgorithmRelationConstant~MATERIALIZE_ONCE
::method inputContract
  return 'BOUNDARY_TEST'
::method canonicalInput
  use arg inputObject, context
  return 'BOUNDARY_INPUT=' || inputObject~string
::method declaredSchemas
  s=.AlgorithmSchema~new('RICH_NATIVE_RELATION')
  s~add('ID','TEXT',.false)
  s~add('EVIDENCE','RICH_OBJECT',.false)
  return .array~of(s)
::method evaluate
  use arg inputObject, context
  self~invocationCount = self~invocationCount + 1
  return .nil

::requires '../algorithm/AlgorithmRelation.cls'
::requires '../algorithm/AlgorithmReadOperator.cls'
::requires '../integration/NoSQLServerAlgorithmRelationExternalEngine.cls'
