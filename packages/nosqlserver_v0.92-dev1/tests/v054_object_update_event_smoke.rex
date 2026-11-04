people=.array~of(.Person~new(1,"Ada",36),.Person~new(2,"Grace",42))
m=.ObjectTableMapping~new("people")
ignore=m~column("id","INTEGER","id")
ignore=m~column("name","VARCHAR","name","name=")
ignore=m~column("age","INTEGER","age","age=")
ignore=m~identity("id")
engine=.ObjectDatabaseEngine~new
call assert engine~register("people",people,m),"register"
probe=.EventProbe~new
ignore=engine~events~on(.DatabaseEventType~BEFORE_UPDATE,"people",probe)
ignore=engine~events~on(.DatabaseEventType~AFTER_UPDATE,"people",probe)
sql=.NoSQLServerSQL~new(engine)
t=engine~table("people")
call assert t~generation=0,"initial generation"

r=sql~execute("UPDATE people SET age=50 WHERE id=1")
call assert r~status=.Error~SUCCESS,"update status"
call assert r~affectedRows=1,"update count"
call assert people[1]~age=50,"setter side effect"
call assert t~generation=1,"generation bumped"
call assert probe~beforeCount=1,"before event"
call assert probe~afterCount=1,"after event"
call assert probe~afterAge=50,"after event new value"

q=sql~execute("SELECT name,age FROM people WHERE id=1")
call assert q~rows[1]["age"]=50,"subsequent SELECT sees setter"

-- Read-only mapped column rejects UPDATE without changing the object.
ro=.ObjectTableMapping~new("readonly_people")
ignore=ro~column("id","INTEGER","id")
ignore=ro~column("name","VARCHAR","name")
ignore=ro~identity("id")
call assert engine~register("readonly_people",people,ro),"readonly register"
bad=sql~execute("UPDATE readonly_people SET name='Nope' WHERE id=1")
call assert bad~status=.Error~NOTEXECUTED,"readonly rejected"
call assert people[1]~name="Ada","readonly object unchanged"

call assert engine~version~supports("OBJECT_TABLE_UPDATE"),"update capability"
call assert engine~version~supports("OBJECT_TABLE_EVENTS"),"event capability"
say "NOSQLSERVER V0.54 OBJECT UPDATE / EVENT SMOKE: OK"
exit 0

assert: procedure
 use arg condition,message
 if \condition then do; say "ASSERT FAILED:" message; exit 1; end
 return

::class EventProbe
::attribute beforeCount
::attribute afterCount
::attribute afterAge
::method init
 self~beforeCount=0; self~afterCount=0
::method onDatabaseEvent
 use arg event
 if event~type=.DatabaseEventType~BEFORE_UPDATE then self~beforeCount=self~beforeCount+1
 if event~type=.DatabaseEventType~AFTER_UPDATE then do
   self~afterCount=self~afterCount+1
   self~afterAge=event~changes[1]["after"]["age"]
 end
 return .true

::class Person
::attribute id
::attribute name
::attribute age
::method init
 use arg id,name,age
 self~id=id; self~name=name; self~age=age

::requires "../src/NoSQLServer.cls"
