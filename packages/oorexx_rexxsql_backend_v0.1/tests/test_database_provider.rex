/*
 * Generic DatabaseBackendSelector-facing Rexx/SQL SQLite provider contract.
 * Requires librexxsql.so on LD_LIBRARY_PATH.
 */
signal on syntax name onSyntax
parse arg work
if work = "" then work = directory()

path = work || "/generic-provider.sqlite"
opts = .directory~new
opts["databaseFile"] = path
opts["requiredCapabilities"] = .array~of("KEYED_LOOKUP_INDEXED", "TRANSACTIONS", "WAL", "ROLLBACK")

session = .RexxSqlDatabaseProvider~open(opts)
call check \session~isA(.RexxSqlDatabaseProviderError), "provider opens for supported requirements"
call check session~isA(.RexxSqlSqliteSession), "provider returns RexxSqlSqliteSession"
call check session~backend~supports("WAL"), "backend publishes WAL"
call check session~backend~supports("ROLLBACK"), "backend publishes rollback"
call check \session~backend~supports("NULL_EMPTY_DISTINCT"), "backend refuses NULL/empty distinct capability"
call check \session~backend~supports("BLOB_WRITE"), "backend refuses BLOB write capability"

r = session~execute("PRAGMA journal_mode")
call check r~status = "SUCCESS" & r~rows~items = 1, "journal mode query succeeds"
call check r~rows[1]["journal_mode"]~upper = "WAL", "provider defaults file database to WAL"
session~close

unsafe = .directory~new
unsafe["databaseFile"] = work || "/unsafe.sqlite"
unsafe["requiredCapabilities"] = .array~of("BLOB_WRITE")
unsafeResult = .RexxSqlDatabaseProvider~open(unsafe)
call check unsafeResult~isA(.RexxSqlDatabaseProviderError), "BLOB_WRITE requirement fails closed"

nullStrict = .directory~new
nullStrict["databaseFile"] = work || "/null-strict.sqlite"
nullStrict["requiredCapabilities"] = .array~of("NULL_EMPTY_DISTINCT")
nullResult = .RexxSqlDatabaseProvider~open(nullStrict)
call check nullResult~isA(.RexxSqlDatabaseProviderError), "NULL/empty distinction requirement fails closed"

say "REXXSQL GENERIC PROVIDER TEST: PASS (" || checks || " checks)"
exit 0

check:
  use arg ok, label
  if symbol("checks") = "LIT" then checks = 0
  checks += 1
  if ok == 1 then do; say "PASS " label; return; end
  say "FAIL " label
  exit 1

onSyntax:
  co = condition("O")
  say "SYNTAX rc=" || rc "line" sigl condition("D")
  if co~hasIndex("ADDITIONAL") then do e over co["ADDITIONAL"]; say "  A=" || e; end
  if co~hasIndex("TRACEBACK") then do t over co["TRACEBACK"]; say "  T=" || t; end
  exit 1

::requires "RexxSqlDatabaseProvider.cls"
