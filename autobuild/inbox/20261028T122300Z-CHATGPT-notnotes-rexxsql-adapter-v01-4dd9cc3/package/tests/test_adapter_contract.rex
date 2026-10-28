/* Test on real ooRexx r13196. Native Rexx/SQL ABI NOT represented by this fake. */
call SysFileTree '.', 'dummy.', 'F'
call value 'MININOTES_DATABASE_PROVIDER', 'unknown-provider', 'ENVIRONMENT'
signal on syntax name wrongProvider
x = .MiniNotesDatabaseSelector~open('/tmp/unused-sqlite')
say 'FAIL selector accepted unknown provider'; exit 1
wrongProvider:
signal off syntax
call value 'MININOTES_DATABASE_PROVIDER', 'rexxsql-sqlite', 'ENVIRONMENT'
-- Can test the adapter via injected command executor; no live DB is claimed.
session = .FakeSession~new
engine = .MiniNotesIndexedSqliteEngine~new('/tmp/test-only-unique-unused',session)
if engine~providerId \== 'rexxsql-sqlite' then do; say 'FAIL id'; exit 1; end
cols = .array~of(.DatabaseColumn~new('doc_key','VARCHAR',.false), .DatabaseColumn~new('fields_hex','TEXT',.false))
r = engine~createTable('documents',cols,.array~of('doc_key'))
if r~status \== 'SUCCESS' then do; say 'FAIL create'; exit 1; end
row = .table~new
row['doc_key'] = 'X-0001'; row['fields_hex'] = ''
r = engine~insert('documents',row)
if r~status \== 'SUCCESS' then do; say 'FAIL insert'; exit 1; end
if session~lastSql~pos("COALESCE(?, '')") = 0 then do; say 'FAIL empty bind protection'; exit 1; end
if session~lastBinds~items \= 2 then do; say 'FAIL bind count'; exit 1; end
r = engine~selectWindow('documents','doc_key',0,50)
if r~status \== 'SUCCESS' then do; say 'FAIL window'; exit 1; end
if session~lastSql~pos('LIMIT 50 OFFSET 0') = 0 then do; say 'FAIL query boundedness'; exit 1; end
r = engine~beginSave
r = engine~finishSave
if r~status \== 'SUCCESS' then do; say 'FAIL transaction'; exit 1; end
say 'MININOTES_SQL_ADAPTER_CONTRACT_PASS (FAKE executor, native ooRexx)'
exit 0
::class FakeSession
::attribute lastSql get
::attribute lastBinds get
::method execute
  expose lastSql lastBinds
  use strict arg sql
  lastSql = sql; lastBinds = .array~new
  return .FakeSqlResult~new
::method executeBound
  expose lastSql lastBinds
  use strict arg sql, binds
  lastSql = sql; lastBinds = binds
  return .FakeSqlResult~new
::method close
  return .true
::class FakeSqlResult
::method status
  return 'SUCCESS'
::method message
  return ''
::method rows
  return .array~new
::method rowCount
  return 1
::requires 'src/MiniNotesIndexedSqliteEngine.cls'
