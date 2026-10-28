/* Real Rexx/SQL + SQLite integration test; requires built librexxsql.so.
 * REXX_PATH must include the provider sources (RexxSqlBackend.cls and
 * NativeDatabaseBackend.cls) as well as the Mini NotNotes package root.
 * Not a mock, and not run in the source-submission environment.
 */
testPath = "test_notnotes_rexxsql_" || random(100000, 999999) || ".sqlite"
engine = .MiniNotesRexxSqlEngine~new(testPath)
columns = .Array~of(.LiveColumn~new("doc_key"), .LiveColumn~new("title"))
r = engine~createTable("documents", columns, .Array~of("doc_key"))
call check r, "create"
r = engine~beginTransaction
call check r, "begin"
row = .Table~new
row["doc_key"] = "key-1"
row["title"] = ""
r = engine~insert("documents", row)
call check r, "insert empty"
row["doc_key"] = "key-2"
row["title"] = "CR" || x2c("0d0a") || "LF" || x2c("00") || "END"
r = engine~insert("documents", row)
call check r, "insert byte-exact"
r = engine~commitTransaction
call check r, "commit"
r = engine~selectPageAfter("documents", 0, 1)
call check r, "page1"
if r~rows~items \= 1 then raise syntax 93.900 array("page1 count")
if r~rows[1]["TITLE"] \== "" then raise syntax 93.900 array("empty text/NULL mismatch")
cursor = r~rows[1]["NN_CURSOR"]
r = engine~selectPageAfter("documents", cursor, 1)
call check r, "page2"
if r~rows~items \= 1 then raise syntax 93.900 array("page2 count")
if r~rows[1]["TITLE"] \== row["title"] then raise syntax 93.900 array("byte exact mismatch")
r = engine~beginTransaction
call check r, "begin rollback"
assignments = .Table~new
assignments["title"] = "SHOULD ROLLBACK"
r = engine~updateWhereEquals("documents", "doc_key", "key-2", assignments)
call check r, "update"
r = engine~rollbackTransaction
call check r, "rollback"
r = engine~selectWhereEquals("documents", "doc_key", "key-2")
call check r, "select after rollback"
if r~rows~items \= 1 then raise syntax 93.900 array("lookup count")
if r~rows[1]["TITLE"] \== row["title"] then raise syntax 93.900 array("rollback mismatch")
ignore = engine~close
engine = .MiniNotesRexxSqlEngine~new(testPath)
r = engine~selectWhereEquals("documents", "doc_key", "key-2")
call check r, "reopen"
if r~rows~items \= 1 then raise syntax 93.900 array("reopen count")
if r~rows[1]["TITLE"] \== row["title"] then raise syntax 93.900 array("reopen mismatch")
ignore = engine~close
call SysFileDelete testPath
call SysFileDelete testPath || "-wal"
call SysFileDelete testPath || "-shm"
say "NOTNOTES_REXXSQL_LIVE_PASS"
exit 0

check:
  use arg result, label
  if result~status \= "SUCCESS" then raise syntax 93.900 array("SQL failure:" label result~message)
  return

::class LiveColumn
::method init
  expose name
  use arg name
::attribute name get
::method nullable
  return .false
::requires 'src/MiniNotesRexxSqlEngine.cls'
