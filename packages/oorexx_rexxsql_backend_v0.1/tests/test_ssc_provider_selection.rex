/* The SSC store selected purely by provider id, through the store's own composition seam.
 * No test rewrites the store's executor line: the provider package builds it.
 * Author: Claude (Opus 5.5), 2026-10-24. Architecture: Tom Dyer.
 * Needs librexxsql.so on LD_LIBRARY_PATH; the SSC store + native-backends + this package on REXX_PATH.
 * Arg: scratch directory.
 */
signal on syntax name onSyntax
parse arg work
if work = "" then work = directory()

id = .SemanticSourceRexxSqlProvider~PROVIDER_ID
call check id = "rexxsql-sqlite", "provider id" id
call check .SemanticSourceRexxSqlProvider~handles("rexxsql-sqlite") = 1, "handles its own id"
call check .SemanticSourceRexxSqlProvider~handles("REXXSQL-SQLITE") = 1, "handles case-insensitively"
call check .SemanticSourceRexxSqlProvider~handles("nosqlserver") = 0, "does not claim another provider's id"

root = work || "/sel"
call SysMkDir root

/* The composition seam the store declares: executor injected, store stays neutral. */
comp = .SemanticSourceRexxSqlProvider~composition(root)
call check comp~isA(.SemanticSourceDatabaseComposition), "composition() returns the store's composition boundary"
call check comp~backendId = id, "composition records the provider id as backendId"

/* The whole point: a bootstrapped, working store chosen by id alone. */
store = .SemanticSourceRexxSqlProvider~newStore(root)
call check store~isA(.SemanticSourceStore), "newStore returns a SemanticSourceStore"
call check store~backendId = id, "store backendId is the provider id"

/* Bootstrap recorded the backend, and the executor behind the store answers. */
rs = store~sql~execute("SELECT meta_value FROM ssc_repository_meta WHERE meta_key='storage_backend'")
call check rs~status = "SUCCESS" & rs~rows~items = 1, "storage_backend meta row exists"
call check rs~rows[1]["meta_value"] = id, "recorded storage_backend is the provider id, not NoSQLServer"

/* The store is on SQLite through Rexx/SQL: a keyed lookup plans as a SEARCH, not a scan. */
plan = store~sql~execute("EXPLAIN QUERY PLAN SELECT meta_value FROM ssc_repository_meta WHERE meta_key='storage_backend'")
call check plan~status = "SUCCESS" & plan~rows[1]["detail"]~upper~pos("SEARCH") > 0, "keyed lookup uses an index (SEARCH), proving the SQLite backend"

say "SSC PROVIDER SELECTION TEST: PASS (" || checks || " checks)"
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

::requires "SemanticSourceRexxSqlProvider.cls"
