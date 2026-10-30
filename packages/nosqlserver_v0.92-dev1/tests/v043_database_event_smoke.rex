root=.NoSQLServerTestSupport~createBlankDatabase("v043")
db=.FileDatabaseEngine~new(root)
sql=.NoSQLServerSQL~new(db)

call ok sql~execute("CREATE TABLE customer (id INTEGER PRIMARY KEY, name VARCHAR)")
handler=.EventProbe~new

r1=db~events~on(.DatabaseEventType~BEFORE_INSERT,"customer",handler)
r2=db~events~on(.DatabaseEventType~AFTER_INSERT,"customer",handler)
r3=db~events~on(.DatabaseEventType~BEFORE_UPDATE,"customer",handler)
r4=db~events~on(.DatabaseEventType~AFTER_UPDATE,"customer",handler)
r5=db~events~on(.DatabaseEventType~BEFORE_DELETE,"customer",handler)
r6=db~events~on(.DatabaseEventType~AFTER_DELETE,"customer",handler)

r=sql~execute("INSERT INTO customer VALUES (1,'ok')")
call assert r~status=.Error~SUCCESS, "insert succeeds"
call assert handler~beforeInsert=1, "before insert observed"
call assert handler~afterInsert=1, "after insert observed"
call assert handler~lastInsertName="ok", "insert row data visible"

r=sql~execute("INSERT INTO customer VALUES (2,'BLOCK')")
call assert r~status=.Error~NOTEXECUTED, "vetoed insert rejected"
call assert r~error=.Error~CONSTRAINT, "veto maps to constraint"
call assert handler~beforeInsert=2, "veto before observed"
call assert handler~afterInsert=1, "veto has no after event"
q=sql~execute("SELECT * FROM customer ORDER BY id")
call assert q~rows~items=1, "vetoed row not published"

r=sql~execute("UPDATE customer SET name='updated' WHERE id=1")
call assert r~status=.Error~SUCCESS, "update succeeds"
call assert handler~beforeUpdate=1, "before update"
call assert handler~afterUpdate=1, "after update"
call assert handler~lastBeforeName="ok", "update before row"
call assert handler~lastAfterName="updated", "update after row"

handler~vetoDelete=.true
r=sql~execute("DELETE FROM customer WHERE id=1")
call assert r~status=.Error~NOTEXECUTED, "delete veto"
call assert r~error=.Error~CONSTRAINT, "delete veto constraint"
call assert handler~beforeDelete=1, "before delete observed"
call assert handler~afterDelete=0, "no after delete on veto"
q=sql~execute("SELECT * FROM customer")
call assert q~rows~items=1, "delete veto preserves row"

handler~vetoDelete=.false
r=sql~execute("DELETE FROM customer WHERE id=1")
call assert r~status=.Error~SUCCESS, "delete succeeds"
call assert handler~afterDelete=1, "after delete observed"

call assert db~events~off(r2), "unregister listener"
r=sql~execute("INSERT INTO customer VALUES (3,'after-off')")
call assert r~status=.Error~SUCCESS, "insert after unregister"
call assert handler~afterInsert=1, "disabled listener not invoked"

call assert db~version~product="NoSQLServer", "version product"
call assert db~version~supports("DATABASE_EVENTS"), "events survive newer release"
call assert db~version~supports("DATABASE_EVENTS"), "event capability"
call assert db~version~supports("MUTATION_EVENT_VETO"), "veto capability"

ignore=.NoSQLServerTestSupport~removeDatabase(root)
say "NOSQLSERVER V0.43 DATABASE EVENT SMOKE: OK"
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

::class EventProbe
::attribute beforeInsert
::attribute afterInsert
::attribute beforeUpdate
::attribute afterUpdate
::attribute beforeDelete
::attribute afterDelete
::attribute lastInsertName
::attribute lastBeforeName
::attribute lastAfterName
::attribute vetoDelete

::method init
  self~beforeInsert=0
  self~afterInsert=0
  self~beforeUpdate=0
  self~afterUpdate=0
  self~beforeDelete=0
  self~afterDelete=0
  self~vetoDelete=.false

::method onDatabaseEvent
  use arg event
  select
    when event~type=.DatabaseEventType~BEFORE_INSERT then do
      self~beforeInsert=self~beforeInsert+1
      self~lastInsertName=event~changes[1]["after"]["name"]
      if self~lastInsertName="BLOCK" then ignore=event~veto("blocked by object handler")
    end
    when event~type=.DatabaseEventType~AFTER_INSERT then self~afterInsert=self~afterInsert+1
    when event~type=.DatabaseEventType~BEFORE_UPDATE then do
      self~beforeUpdate=self~beforeUpdate+1
      self~lastBeforeName=event~changes[1]["before"]["name"]
      self~lastAfterName=event~changes[1]["after"]["name"]
    end
    when event~type=.DatabaseEventType~AFTER_UPDATE then self~afterUpdate=self~afterUpdate+1
    when event~type=.DatabaseEventType~BEFORE_DELETE then do
      self~beforeDelete=self~beforeDelete+1
      if self~vetoDelete then ignore=event~veto("delete blocked")
    end
    when event~type=.DatabaseEventType~AFTER_DELETE then self~afterDelete=self~afterDelete+1
    otherwise nop
  end
  return .true

::requires "../src/NoSQLServer.cls"
::requires "TestSupport.cls"
