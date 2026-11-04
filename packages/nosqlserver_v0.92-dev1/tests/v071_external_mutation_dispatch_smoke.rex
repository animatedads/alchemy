root = .NoSQLServerTestSupport~createBlankDatabase('v071_external_mutation')
fed = .FederatedDatabaseEngine~new(root)
sql = .NoSQLServerSQL~new(fed)

/* Read-only external relation: it has a table contract but no mutation API. */
raw = .table~new
raw['name'] = 'external_readonly'
raw['rowCount'] = 0
raw['generation'] = 0
raw['columns'] = .array~new
idCol = .table~new
idCol['name'] = 'id'
idCol['type'] = 'INTEGER'
idCol['nullable'] = .false
idCol['primaryKey'] = .true
raw['columns']~append(idCol)
valueCol = .table~new
valueCol['name'] = 'value'
valueCol['type'] = 'VARCHAR'
valueCol['nullable'] = .true
raw['columns']~append(valueCol)

readonlyRelation = .V071ExternalRelation~new(raw)
readonlyProvider = .V071ReadOnlyProvider~new(readonlyRelation)
ignore = fed~addEngine(readonlyProvider)

bad = sql~execute("UPDATE external_readonly SET value='changed' WHERE id=1")
call assert bad~status \= .Error~SUCCESS, 'read-only external UPDATE rejected'
call assert bad~error = .Error~SQLUNSUPPORTED, 'read-only external UPDATE is unsupported, not not-found'
call assert bad~message~pos('external_readonly') > 0, 'read-only diagnostic names table'

/* Writable external relation: federation must delegate by ownership. */
raw2 = raw~copy
raw2['name'] = 'external_writable'
writableRelation = .V071ExternalRelation~new(raw2)
writableProvider = .V071ExternalMutationProvider~new(writableRelation, .DatabaseResult)
ignore = fed~addEngine(writableProvider)

rs = sql~execute("UPDATE external_writable SET value='changed' WHERE id=1")
call ok rs
call assert writableProvider~updateCalls = 1, 'external UPDATE delegated exactly once'
call assert rs~message = 'EXTERNAL_UPDATE', 'external UPDATE result preserved'

rs = sql~execute("DELETE FROM external_writable WHERE id=1")
call ok rs
call assert writableProvider~deleteCalls = 1, 'external DELETE delegated exactly once'
call assert rs~message = 'EXTERNAL_DELETE', 'external DELETE result preserved'

rs = sql~execute("INSERT INTO external_writable VALUES (2,'new')")
call ok rs
call assert writableProvider~insertCalls = 1, 'external INSERT delegated exactly once'
call assert rs~message = 'EXTERNAL_INSERT', 'external INSERT result preserved'

rs = sql~execute("INSERT INTO external_writable VALUES (3,'a'),(4,'b')")
call ok rs
call assert writableProvider~insertManyCalls = 1, 'external multi-row INSERT delegated exactly once'
call assert rs~affectedRows = 2, 'external multi-row affected count preserved'

call assert fed~version~supports('FEDERATED_PROVIDER_NEUTRAL_MUTATION_DISPATCH'), 'v0.71 mutation dispatch feature advertised'

ignore = .NoSQLServerTestSupport~removeDatabase(root)
say 'NOSQLSERVER V0.71 EXTERNAL MUTATION DISPATCH SMOKE: OK'
exit 0

ok: procedure
  use arg rs
  if rs~status = .Error~SUCCESS then return .true
  say 'FAILED:' rs~status rs~error rs~message
  exit 1

assert: procedure
  use arg condition, message
  if condition then return .true
  say 'ASSERT FAILED:' message
  exit 1

::class V071ExternalRelation
::attribute definition
::method init
  use arg rawDefinition
  self~definition = .TableDefinition~new(rawDefinition)

::class V071ReadOnlyProvider
::attribute relation
::method init
  use arg relation
  self~relation = relation
::method table
  use arg tableName
  if self~relation == .nil then return .nil
  if self~relation~definition~name~caselessEquals(tableName) then return self~relation
  return .nil

::requires '../src/NoSQLServer.cls'
::requires 'TestSupport.cls'
::requires 'V071ExternalMutationProvider.cls'
