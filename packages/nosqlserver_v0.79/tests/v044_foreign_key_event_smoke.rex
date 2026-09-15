root=.NoSQLServerTestSupport~createBlankDatabase("v044")
db=.FileDatabaseEngine~new(root)
sql=.NoSQLServerSQL~new(db)

call ok sql~execute("CREATE TABLE parent (id INTEGER PRIMARY KEY, name VARCHAR)")
call ok sql~execute("CREATE TABLE child (id INTEGER PRIMARY KEY, parent_id INTEGER REFERENCES parent(id), note VARCHAR)")

call ok sql~execute("INSERT INTO parent VALUES (1,'p1'),(2,'p2')")
call ok sql~execute("INSERT INTO child VALUES (10,1,'ok')")
call ok sql~execute("INSERT INTO child VALUES (11,NULL,'nullable')")

bad=sql~execute("INSERT INTO child VALUES (12,99,'missing parent')")
call assert bad~status=.Error~NOTEXECUTED, "missing parent rejected"
call assert bad~error=.Error~CONSTRAINT, "missing parent constraint"

bad=sql~execute("UPDATE child SET parent_id=99 WHERE id=10")
call assert bad~status=.Error~NOTEXECUTED, "bad child update rejected"
call assert bad~error=.Error~CONSTRAINT, "bad child update constraint"

bad=sql~execute("DELETE FROM parent WHERE id=1")
call assert bad~status=.Error~NOTEXECUTED, "parent delete restricted"
call assert bad~error=.Error~CONSTRAINT, "parent delete constraint"

bad=sql~execute("UPDATE parent SET id=3 WHERE id=1")
call assert bad~status=.Error~NOTEXECUTED, "parent key update restricted"
call assert bad~error=.Error~CONSTRAINT, "parent update constraint"

call ok sql~execute("DELETE FROM child WHERE id=10")
call ok sql~execute("DELETE FROM parent WHERE id=1")

q=sql~execute("SELECT id FROM parent ORDER BY id")
call assert q~rows~items=1, "one parent remains"
call assert q~rows[1]["id"]=2, "remaining parent"

-- FK metadata survives a new engine object and re-installs privileged rules.
db2=.FileDatabaseEngine~new(root)
sql2=.NoSQLServerSQL~new(db2)
bad=sql2~execute("INSERT INTO child VALUES (13,88,'reopen check')")
call assert bad~status=.Error~NOTEXECUTED, "reopened engine FK enforced"
call assert bad~error=.Error~CONSTRAINT, "reopened FK constraint"

-- Referenced target must be a key.
call ok sql~execute("CREATE TABLE nonkey (id INTEGER PRIMARY KEY, code INTEGER)")
bad=sql~execute("CREATE TABLE badchild (id INTEGER PRIMARY KEY, code INTEGER REFERENCES nonkey(code))")
call assert bad~status=.Error~NOTEXECUTED, "non-key reference rejected"
call assert db~table("badchild")==.nil, "invalid FK creates no table"

-- SET DEFAULT remains outside the delivered FK surface.
bad=sql~execute("CREATE TABLE default_child (id INTEGER PRIMARY KEY, parent_id INTEGER REFERENCES parent(id) ON DELETE SET DEFAULT)")
call assert bad~status=.Error~NOTEXECUTED, "SET DEFAULT cleanly rejected"
call assert bad~error=.Error~SQLUNSUPPORTED, "SET DEFAULT unsupported not parse corruption"

call assert db~version~product="NoSQLServer", "version product"
call assert db~version~supports("DATABASE_EVENTS"), "event substrate"
call assert db~version~supports("FOREIGN_KEYS"), "FK capability"
call assert db~version~supports("FOREIGN_KEY_RESTRICT"), "FK restrict capability"

ignore=.NoSQLServerTestSupport~removeDatabase(root)
say "NOSQLSERVER V0.44 FOREIGN KEY EVENT SMOKE: OK"
exit 0

ok: procedure
  use arg rs
  call assert rs~status=.Error~SUCCESS, "setup"
  return

assert: procedure
  use arg condition,message
  if \condition then do
    say "ASSERT FAILED:" message
    exit 1
  end
  return

::requires "../src/NoSQLServer.cls"
::requires "TestSupport.cls"
