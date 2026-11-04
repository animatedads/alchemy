/* Run with:
 * REXX_PATH=tests/fixtures:. rexx tests/test_rexxsql_adapter_mock.rex
 * This is a real r13196 ooRexx test with FAKE SQL, not a database I/O test.
 */
engine = .MiniNotesRexxSqlEngine~new("/tmp/notnotes-adapter-fake.sqlite")
if engine~backendId \= "rexxsql-sqlite" then raise syntax 93.900 array("wrong backend")
cols = .Array~of(.MockColumn~new("doc_key"), .MockColumn~new("title"))
r = engine~createTable("documents", cols, .Array~of("doc_key"))
if r~status \= "SUCCESS" then raise syntax 93.900 array("create")
row = .Table~new
row["doc_key"] = "A1"
row["title"] = ""
r = engine~insert("documents", row)
if r~status \= "SUCCESS" then raise syntax 93.900 array("insert")
if engine~session~lastSql~pos("''") = 0 then -
  raise syntax 93.900 array("empty text became SQL NULL")
row["title"] = "A" || x2c("00") || "B"
r = engine~insert("documents", row)
if engine~session~lastBinds~items \= 2 then raise syntax 93.900 array("bind count")
found = .false
do pair over engine~session~lastBinds
  if pair[2] == row["title"] then found = .true
end
if \found then raise syntax 93.900 array("bound NUL-containing text lost")
r = engine~selectPageAfter("documents", 101, 100)
if engine~session~lastSql~pos("WHERE rowid > 101 ORDER BY rowid LIMIT 100") = 0 then -
  raise syntax 93.900 array("keyset pagination")
say "REXXSQL_ADAPTER_NATIVE_CONTRACT_PASS (mock SQL, not live SQLite)"
exit 0

::class MockColumn
::method init
  expose name
  use arg name
::attribute name get
::method nullable
  return .false
::requires 'src/MiniNotesRexxSqlEngine.cls'
