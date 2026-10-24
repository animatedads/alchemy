/* Rexx/SQL 2.6B3 + Alchemy patches, SQLite 3, ooRexx 5.x: driver-level acceptance.
 * Author: Claude (Opus 5.5), 2026-10-24. Architecture: Tom Dyer. Rexx/SQL: Mark Hessling.
 * Needs librexxsql.so on LD_LIBRARY_PATH. Arg: scratch directory.
 * Never read result values through compound symbols whose tail is a variable name in this
 * program: Rexx substitutes the variable's value into the tail. Use the stem object.
 */
signal on syntax name onSyntax
parse arg work
if work = "" then work = directory()
call rxfuncadd "SQLLoadFuncs", "rexxsql", "SQLLoadFuncs"
call check SQLLoadFuncs() = 0, "SQLLoadFuncs"
call check SQLVariable("VERSION")~pos("2.6B3") > 0, "version" SQLVariable("VERSION")
db = work || "/driver.sqlite"
call SysFileDelete db
call check SQLConnect("c1", , , db) = 0, "connect file database"
call check SQLCommand("d", "create table t (k varchar primary key, v text)") = 0, "create table"

nl = "0a"x
big = copies("::method m" || nl || "  return 'x|y'" || nl, 4000)
cases = .array~of("plain", "crlf" || "0d0a"x || "x", "nul" || "00"x || "inside", "café 日本", "", big, "3*4", "12-34", "NULL")
do i = 1 to cases~items
  val = cases[i]
  call check SQLCommand("i", "insert into t (k,v) values (?,?)", "CHAR", "k" || i, "TEXT", val) = 0, "bound insert" i
  call check SQLCommand("q", "select v from t where k='k" || i || "'") = 0, "select" i
  s = q.
  call check s["V.0"] = 1 & s["V.1"] == val, "round trip byte-exact case" i "length" val~length
end
call check SQLCommand("i", "insert into t (k,v) values ('lit','it''s 3*4')") = 0, "literal insert"
call check SQLCommand("q", "select v from t where k='lit'") = 0 & q.~at("V.1") == "it's 3*4", "quoted literal stored as written"

call SQLCommand "i", "insert into t (k,v) values ('nul', NULL)"
call SQLCommand "q", "select v from t where k='nul'"
call check q.~at("V.1") == "", "NULL returned as NULLSTRINGOUT (empty)"

call check SQLCommand("d", "create table b (k integer primary key, g blob)") = 0, "create blob table"
call SQLCommand "i", "insert into b values (1, X'00FF41420043')"
call SQLCommand "q", "select g from b where k=1"
call check q.~at("G.1") == "00FF41420043"x, "BLOB bytes returned"

expr = "'a'" || copies(" || 'a'", 60)
rc = SQLCommand("q", "select" expr)
call check rc < 0, "long unaliased expression returns an error instead of aborting (rc=" || rc || ")"
call check SQLCommand("q", "select" expr "as joined") = 0 & q.~at("JOINED.1")~length = 61, "aliased expression works"

call SQLCommand "b", "begin transaction"
call SQLCommand "i", "insert into t (k,v) values ('tx','x')"
call SQLRollback
call SQLCommand "q", "select k from t where k='tx'"
call check q.~at("K.0") = 0, "rollback discards"

call SQLCommand "b", "begin transaction"
do i = 1 to 20000
  call SQLCommand "i", "insert into t (k,v) values ('r" || i || "','" || copies("x", 200) || "')"
end
call SQLCommand "c", "commit"
call time "R"
do i = 1 to 2000
  call SQLCommand "q", "select v from t where k='r" || random(1, 20000) || "'"
end
perCall = time("E") / 2000
say "      keyed select at 20,009 rows:" format(perCall * 1000000, , 0) "us per call"
call check perCall < 0.005, "keyed lookup is indexed (< 5 ms per call)"
call check SQLCommand("q", "select k from t where k in ('k1','k2','zz') order by k") = 0 & q.~at("K.0") = 2, "IN list"
call check SQLCommand("q", "with w(n) as (select 1 union all select 2) select n from w order by n") = 0 & q.~at("N.0") = 2, "WITH ... SELECT returns rows"
call check SQLCommand("q", "pragma journal_mode=wal") = 0 & q.~at("JOURNAL_MODE.1") = "wal", "PRAGMA returns rows (journal_mode=wal)"
call check SQLCommand("q", "explain query plan select v from t where k='r1'") = 0 & q.~at("DETAIL.1")~upper~pos("SEARCH") > 0, "EXPLAIN QUERY PLAN returns rows; keyed lookup is a SEARCH"
call check SQLCommand("q", "insert into t (k,v) values ('ret','x') returning k") = 0 & q.~at("K.1") = "ret", "INSERT ... RETURNING returns rows"
call check SQLPrepare("p1", "insert into t (k,v) values ('ret2','x') returning k") = 0 & SQLExecute("p1") = 0, "SQLEXECUTE runs INSERT ... RETURNING"
call check SQLCommand("q", "select count(*) as n from t where k='ret2'") = 0 & q.~at("N.1") = 1, "... and the row exists exactly once"
call check SQLPrepare("p2", "pragma user_version=7") = 0 & SQLExecute("p2") = 0, "SQLEXECUTE runs a PRAGMA"
call check SQLCommand("q", "pragma user_version") = 0 & q.~at("USER_VERSION.1") = 7, "... and it took effect"
call check SQLDisconnect("c1") = 0, "disconnect"

call check SQLConnect("c2", , , db) = 0, "reconnect"
call SQLCommand "q", "select v from t where k='k6'"
call check q.~at("V.1") == big, "data persisted across connections"
call SQLDisconnect "c2"
call SQLDropFuncs
say "REXXSQL DRIVER TEST: PASS (" || checks || " checks)"
exit 0

check:
  use arg ok, label
  if symbol("checks") = "LIT" then checks = 0
  checks += 1
  if ok == 1 then do; say "PASS " label; return; end
  say "FAIL " label
  if symbol("SQLCA.SQLERRM") = "VAR" then say "      sqlerrm:" sqlca.sqlerrm
  if symbol("SQLCA.INTERRM") = "VAR" then say "      interrm:" sqlca.interrm
  exit 1

onSyntax:
  say "SYNTAX rc=" || rc "line" sigl condition("D")
  exit 1
