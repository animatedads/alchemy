/* RexxSqlSqliteBackend inside the NativeDatabaseBackend contract.
 * Author: Claude (Opus 5.5), 2026-10-24. Architecture: Tom Dyer.
 * Needs librexxsql.so on LD_LIBRARY_PATH and NativeDatabaseBackend.cls on REXX_PATH. Arg: scratch dir.
 */
signal on syntax name onSyntax
parse arg work
if work = "" then work = directory()

backend = .RexxSqlSqliteBackend~new
call check backend~available, "backend available (Rexx/SQL loads)"
call check backend~implementationId = "SQLITE:rexxsql:2.6B3+alchemy.1", "implementation id" backend~implementationId
call check backend~supports("KEYED_LOOKUP_INDEXED") & backend~supports("SECONDARY_INDEXES"), "publishes indexed lookups"
call check \backend~supports("BLOB_WRITE"), "publishes BLOB_WRITE as unsupported"
call check backend~limitations~items >= 4, "publishes limitations"

-- Selection: a caller that needs indexed keyed lookup gets Rexx/SQL even if another backend has better priority but lacks it.
slow = .NativeDatabaseBackend~new("SQLITE", "scan-only", "0", "OOREXX_NATIVE", 1)
slow~addCapability("MUTATION", "SUPPORTED")
chosen = .NativeDatabaseBackendSelector~new~select(.array~of(slow, backend), .array~of("KEYED_LOOKUP_INDEXED"))
call check chosen == backend, "selector picks rexxsql for KEYED_LOOKUP_INDEXED"
lease = .NativeDatabaseBackendSelector~new~acquire(.array~of(slow, backend), work || "/lease.sqlite", .array~of("KEYED_LOOKUP_INDEXED"))
call check lease \== .nil, "lease acquired"
call check lease~session~isA(.RexxSqlSqliteSession), "lease pins a Rexx/SQL session"
lease~close
call check lease~session~closed, "lease close disconnects"

a = .RexxSqlSqliteSession~open(work || "/a.sqlite")
b = .RexxSqlSqliteSession~open(work || "/b.sqlite")
r = a~execute("CREATE TABLE IF NOT EXISTS t (object_id VARCHAR PRIMARY KEY, kind VARCHAR, source_text TEXT)")
call check r~status = "SUCCESS", "DDL through session"
r = b~execute("CREATE TABLE IF NOT EXISTS t (object_id VARCHAR PRIMARY KEY, kind VARCHAR, source_text TEXT)")
r = a~execute("DELETE FROM t"); r = b~execute("DELETE FROM t")
methodText = "::method a" || "0a"x || "  return 1"
r = a~execute("INSERT INTO t (object_id,kind,source_text) VALUES ('sso_1','METHOD','" || methodText || "')")
call check r~status = "SUCCESS" & r~rowCount = 1, "insert reports rowCount 1"
r = b~execute("INSERT INTO t (object_id,kind,source_text) VALUES ('sso_1','CLASS','other database')")
r = a~execute("SELECT object_id, kind, source_text FROM t WHERE object_id='sso_1'")
call check r~status = "SUCCESS" & r~rows~items = 1, "select returns one row"
row = r~rows[1]
call check row["kind"] = "METHOD" & row["KIND"] = "METHOD", "row lookup is case-insensitive"
call check row["source_text"] == methodText, "text exact"
call check row~values~hasIndex("OBJECT_ID"), "row~values exposes columns (MCP plainRows)"
r = b~execute("SELECT kind FROM t WHERE object_id='sso_1'")
call check r~rows[1]["kind"] = "CLASS", "two sessions keep separate connections (SQLDEFAULT switching)"
r = a~execute("SELECT kind FROM t WHERE object_id='missing'")
call check r~status = "SUCCESS" & r~rows~items = 0 & r~rowCount = 0, "empty result"
r = a~execute("SELECT nope FROM t")
call check r~status = "ERROR" & r~message~pos("no such column") > 0, "SQL error is a result, not a raise:" r~message
r = a~execute("UPDATE t SET kind='3*4' WHERE object_id='sso_1'")
call check a~execute("SELECT kind FROM t WHERE object_id='sso_1'")~rows[1]["kind"] == "3*4", "UPDATE literal stored as written"
r = a~executeBound("INSERT INTO t (object_id,kind,source_text) VALUES (?,?,?)", .array~of(.array~of("CHAR","sso_2"), .array~of("CHAR","METHOD"), .array~of("TEXT","a" || "00"x || "b")))
call check r~status = "SUCCESS", "bound insert"
call check a~execute("SELECT source_text FROM t WHERE object_id='sso_2'")~rows[1]["source_text"] == "a" || "00"x || "b", "bound NUL byte round trip"
r = a~execute("SELECT object_id FROM t WHERE object_id IN ('sso_1','sso_2') ORDER BY object_id")
call check r~rows~items = 2, "IN list"
r = a~execute("SELECT count(*) AS n FROM t")
call check r~rows[1]["n"] = 2, "aliased aggregate"
a~close; b~close
call check a~closed & b~closed, "sessions close"
say "REXXSQL BACKEND TEST: PASS (" || checks || " checks)"
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

::requires "RexxSqlBackend.cls"
