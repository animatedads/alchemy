root = .NoSQLServerTestSupport~createBlankDatabase("v0271")
db = .FileDatabaseEngine~new(root)
sql = .NoSQLServerSQL~new(db)
call ok sql~execute("CREATE TABLE diag (id INTEGER PRIMARY KEY, name VARCHAR UNIQUE);")
call ok sql~execute("INSERT INTO diag (id,name) VALUES (1,'alpha');")

r = sql~execute("SELECT * FROM diag WHERE (id = 1;")
call assert r~status=.Error~NOTEXECUTED, "parser failure not executed"
call assert r~error=.Error~SQLPARSEERROR, "parser error classification"
call assert r~message~pos("Missing ')' in WHERE predicate") > 0, "parser additional diagnostic preserved"

r = sql~execute("INSERT INTO diag (id,name) VALUES (2,'alpha');")
call assert r~status=.Error~NOTEXECUTED, "constraint failure not executed"
call assert r~error=.Error~CONSTRAINT, "constraint error classification"
call assert r~message~pos("UNIQUE constraint failed") > 0, "constraint diagnostic preserved"

call assert db~version~release \= "", "version release available"
x=.NoSQLServerTestSupport~removeDatabase(root)
say "NOSQLSERVER V0.27.1 DIAGNOSTIC PRESERVATION SMOKE: OK"
exit 0
ok: procedure
 use arg r
 call assert r~status=.Error~SUCCESS, "setup SQL"
 return
assert: procedure
 use arg condition, message
 if \condition then do; say "ASSERT FAILED:" message; exit 1; end
 return
::requires "TestSupport.cls"
::requires "../src/NoSQLServer.cls"
