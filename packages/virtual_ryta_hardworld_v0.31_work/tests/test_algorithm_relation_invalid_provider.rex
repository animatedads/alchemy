/* Invalid typed provider output must remain visible and must never enter cache. */

say 'ALGORITHM RELATION INVALID PROVIDER V0.4 START'

provider = .InvalidTypedProvider~new
engine = .AlgorithmRelationEngine~new
ok = engine~addProvider(provider)
context = .AlgorithmExecutionContext~new('BAD-INV-1', 'BAD-OID', 'BAD-WORLD')

firstBad = engine~execute('INVALID_TYPED_PROVIDER', 'same-input', context)
call assertTrue 'invalid result returned for audit', firstBad \== .nil
call assertTrue 'validation errors surfaced', firstBad~validationErrors~items > 0
call assertEqual 'invalid result counter', 1, engine~invalidResults
call assertEqual 'provider invoked once', 1, provider~invocationCount

secondBad = engine~execute('INVALID_TYPED_PROVIDER', 'same-input', context)
call assertTrue 'second invalid result returned', secondBad \== .nil
call assertEqual 'invalid result is not cached', 2, provider~invocationCount
call assertEqual 'invalid result counter increments', 2, engine~invalidResults
call assertEqual 'no cache hit for invalid output', 0, engine~cacheHits

say 'ALGORITHM RELATION INVALID PROVIDER V0.4: OK'
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

::class InvalidTypedProvider public
::attribute invocationCount
::attribute sourceManifest get

::method init
  expose sourceManifest
  self~invocationCount = 0
  sourceManifest = .AlgorithmSourceManifest~new
  sourceManifest~mode = 'FILE_HASHED'
  sourceManifest~add('TEST', 'INVALID_PROVIDER_V0.4')

::method algorithmId
  return 'INVALID_TYPED_PROVIDER'
::method algorithmVersion
  return '0.4'
::method sourceComponent
  return 'TEST'
::method sourceVersion
  return '1'
::method sourceFingerprint
  return 'INVALID-TEST'
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
  return 'INPUT=' || inputObject
::method declaredSchemas
  schemas = .array~new
  schema = .AlgorithmSchema~new('BAD_ROWS')
  schema~add('INVOCATION_ID', 'TEXT', .false)
  schema~add('COUNT_VALUE', 'INTEGER', .false)
  schemas~append(schema)
  return schemas
::method evaluate
  use arg inputObject, context
  self~invocationCount = self~invocationCount + 1
  algorithmResult = .AlgorithmRelationResult~new(self~algorithmId, self~algorithmVersion, self~sourceComponent, self~sourceVersion, self~sourceFingerprint, self~sourceManifestHash, context)
  schema = .AlgorithmSchema~new('BAD_ROWS')
  schema~add('INVOCATION_ID', 'TEXT', .false)
  schema~add('COUNT_VALUE', 'INTEGER', .false)
  relation = .AlgorithmRelation~new(schema)
  row = relation~newRow
  ok = row~put('INVOCATION_ID', context~invocationId)
  ok = row~put('COUNT_VALUE', 'not-an-integer')
  added = relation~addRow(row)
  added = algorithmResult~addRelation(relation)
  return algorithmResult

::requires '../algorithm/AlgorithmRelation.cls'
