root=.NoSQLServerTestSupport~createBlankDatabase("v045")
db=.FileDatabaseEngine~new(root)
sql=.NoSQLServerSQL~new(db)

call ok sql~execute("CREATE TABLE parent (id INTEGER PRIMARY KEY, name VARCHAR)")
call ok sql~execute("CREATE TABLE child (id INTEGER PRIMARY KEY, parent_id INTEGER REFERENCES parent(id) ON DELETE CASCADE ON UPDATE CASCADE, note VARCHAR)")
call ok sql~execute("CREATE TABLE grand (id INTEGER PRIMARY KEY, child_id INTEGER REFERENCES child(id) ON DELETE CASCADE, note VARCHAR)")
call ok sql~execute("CREATE TABLE optional_child (id INTEGER PRIMARY KEY, parent_id INTEGER REFERENCES parent(id) ON DELETE SET NULL ON UPDATE SET NULL, note VARCHAR)")
call ok sql~execute("CREATE TABLE audit (id INTEGER PRIMARY KEY, note VARCHAR)")

call ok sql~execute("INSERT INTO parent VALUES (1,'p1'),(2,'p2'),(3,'p3')")
call ok sql~execute("INSERT INTO child VALUES (10,1,'c1'),(20,2,'c2'),(30,3,'c3')")
call ok sql~execute("INSERT INTO grand VALUES (100,10,'g1'),(200,20,'g2'),(300,30,'g3')")
call ok sql~execute("INSERT INTO optional_child VALUES (1000,1,'o1'),(2000,2,'o2'),(3000,3,'o3')")

audit=.CascadeAudit~new
reg=db~events~on(.DatabaseEventType~BEFORE_DELETE,"parent",audit)
commitProbe=.CommitProbe~new
commitReg=db~events~on(.DatabaseEventType~AFTER_COMMIT,"*",commitProbe)

-- Successful graph: audit insertion, grandchild cascade, child cascade,
-- SET NULL and parent delete must publish as one tree replacement.
r=sql~execute("DELETE FROM parent WHERE id=1")
call assert r~status=.Error~SUCCESS, "cascade delete succeeds"
call assert r~affectedRows=1, "primary affected count"

call rows sql,"SELECT id FROM parent WHERE id=1",0,"parent deleted"
call rows sql,"SELECT id FROM child WHERE id=10",0,"child cascaded"
call rows sql,"SELECT id FROM grand WHERE id=100",0,"grandchild cascaded"
q=sql~execute("SELECT parent_id FROM optional_child WHERE id=1000")
call assert q~rows~items=1, "optional child remains"
call assert q~rows[1]["parent_id"]==.nil, "SET NULL applied"
call rows sql,"SELECT id FROM audit WHERE id=1",1,"object-staged audit published"
call assert commitProbe~count=1, "after commit observed for cascade delete"

-- Parent key update publishes with child FK cascade.
r=sql~execute("UPDATE parent SET id=22 WHERE id=2")
call assert r~status=.Error~SUCCESS, "update cascade succeeds"
q=sql~execute("SELECT parent_id FROM child WHERE id=20")
call assert q~rows[1]["parent_id"]=22, "child key cascaded"
q=sql~execute("SELECT parent_id FROM optional_child WHERE id=2000")
call assert q~rows[1]["parent_id"]==.nil, "SET NULL on update"
call assert commitProbe~count=2, "after commit observed for update graph"

-- A deep veto must discard the entire graph, including the user-staged audit.
blocker=.GrandDeleteBlocker~new
reg2=db~events~on(.DatabaseEventType~BEFORE_DELETE,"grand",blocker)
audit~nextId=3
r=sql~execute("DELETE FROM parent WHERE id=3")
call assert r~status=.Error~NOTEXECUTED, "deep veto rejects graph"
call assert r~error=.Error~CONSTRAINT | r~error=.Error~TRANSACTIONFAILED, "deep veto error"
call rows sql,"SELECT id FROM parent WHERE id=3",1,"parent survives rollback"
call rows sql,"SELECT id FROM child WHERE id=30",1,"child survives rollback"
call rows sql,"SELECT id FROM grand WHERE id=300",1,"grand survives rollback"
q=sql~execute("SELECT parent_id FROM optional_child WHERE id=3000")
call assert q~rows[1]["parent_id"]=3, "SET NULL rolled back"
call rows sql,"SELECT id FROM audit WHERE id=3",0,"staged audit rolled back"
call assert commitProbe~count=2, "failed graph emits no after commit"

-- Explicit graph API: object code can stage ordinary SQL and commit atomically.
graph=db~stagedMutationGraph
call ok graph~execute("INSERT INTO audit VALUES (9,'explicit graph')")
call ok graph~execute("UPDATE parent SET name='graph updated' WHERE id=3")
cr=graph~commit
call assert cr~status=.Error~COMMITTED, "explicit graph commit"
call rows sql,"SELECT id FROM audit WHERE id=9",1,"explicit staged insert"
q=sql~execute("SELECT name FROM parent WHERE id=3")
call assert q~rows[1]["name"]="graph updated", "explicit staged update"
call assert commitProbe~count=3, "explicit graph after commit"

call assert db~version~product="NoSQLServer", "version product"
call assert db~version~supports("STAGED_MUTATION_GRAPH"), "mutation graph survives newer release"
call assert db~version~supports("STAGED_MUTATION_GRAPH"), "graph capability"
call assert db~version~supports("FOREIGN_KEY_CASCADE"), "cascade capability"
call assert db~version~supports("FOREIGN_KEY_SET_NULL"), "set null capability"

ignore=.NoSQLServerTestSupport~removeDatabase(root)
say "NOSQLSERVER V0.45 STAGED MUTATION GRAPH SMOKE: OK"
exit 0

rows: procedure
  use arg sql,statement,wanted,message
  q=sql~execute(statement)
  call assert q~status=.Error~SUCCESS, message || " query"
  call assert q~rows~items=wanted, message
  return

ok: procedure
  use arg rs
  call assert rs~status=.Error~SUCCESS, "setup/stage"
  return

assert: procedure
  use arg condition,message
  if \condition then do
    say "ASSERT FAILED:" message
    exit 1
  end
  return

::class CascadeAudit
::attribute nextId
::method init
  self~nextId=1
::method onDatabaseEvent
  use arg event
  graph=event~mutationGraph
  if graph==.nil then return .true
  id=self~nextId
  self~nextId=id+1
  ignore=graph~execute("INSERT INTO audit VALUES (" || id || ",'parent delete staged')")
  return .true

::class GrandDeleteBlocker
::method onDatabaseEvent
  use arg event
  ignore=event~veto("grandchild policy veto")
  return .false

::class CommitProbe
::attribute count
::method init
  self~count=0
::method onDatabaseEvent
  use arg event
  self~count=self~count+1
  return .true

::requires "../src/NoSQLServer.cls"
::requires "TestSupport.cls"
