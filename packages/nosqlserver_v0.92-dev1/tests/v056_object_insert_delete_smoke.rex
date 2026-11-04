people=.array~of(.Person~new(1,"Ada",36),.Person~new(2,"Grace",42))

mapping=.ObjectTableMapping~new("people")
ignore=mapping~column("id","INTEGER","id")
ignore=mapping~column("name","VARCHAR","name","name=")
ignore=mapping~column("age","INTEGER","age","age=")
ignore=mapping~identity("id")
factory=.PersonFactory~new
ignore=mapping~factory(factory,"newRow")
ignore=mapping~removal("ARRAY_DELETE")

engine=.ObjectDatabaseEngine~new
call assert engine~register("people",people,mapping),"register"
probe=.EventProbe~new
ignore=engine~events~on(.DatabaseEventType~BEFORE_INSERT,"people",probe)
ignore=engine~events~on(.DatabaseEventType~AFTER_INSERT,"people",probe)
ignore=engine~events~on(.DatabaseEventType~BEFORE_DELETE,"people",probe)
ignore=engine~events~on(.DatabaseEventType~AFTER_DELETE,"people",probe)
sql=.NoSQLServerSQL~new(engine)
t=engine~table("people")

r=sql~execute("INSERT INTO people VALUES (3,'Alan',29)")
call assert r~status=.Error~SUCCESS,"insert status"
call assert r~affectedRows=1,"insert count"
call assert people~items=3,"collection appended"
call assert people[3]~name="Alan","factory object appended"
call assert people[3]~age=29,"factory typed age"
call assert t~generation=1,"generation after insert"
call assert probe~beforeInsert=1,"before insert event"
call assert probe~afterInsert=1,"after insert event"
call assert probe~afterInsertName="Alan","insert event payload"

q=sql~execute("SELECT name,age FROM people ORDER BY id")
call assert q~rows~items=3,"insert visible to SELECT"
call assert q~rows[3]["name"]="Alan","SELECT sees inserted object"

bad=sql~execute("INSERT INTO people VALUES (3,'Duplicate',99)")
call assert bad~status=.Error~NOTEXECUTED,"identity collision rejected"
call assert people~items=3,"collision did not append"
call assert t~generation=1,"collision did not bump generation"

-- Multi-row INSERT stays unsupported because factory operations are not atomic.
bad=sql~execute("INSERT INTO people VALUES (4,'Four',4),(5,'Five',5)")
call assert bad~error=.Error~SQLUNSUPPORTED,"multi-row object insert unsupported"
call assert people~items=3,"multi-row refusal no mutation"

r=sql~execute("DELETE FROM people WHERE age < 30")
call assert r~status=.Error~SUCCESS,"delete status"
call assert r~affectedRows=1,"delete count"
call assert people~items=2,"collection delete"
call assert people[1]~id=1,"array order first"
call assert people[2]~id=2,"array order second"
call assert t~generation=2,"generation after delete"
call assert probe~beforeDelete=1,"before delete event"
call assert probe~afterDelete=1,"after delete event"
call assert probe~deletedName="Alan","delete event payload"

-- No removal policy means DELETE is cleanly rejected.
readonly=.ObjectTableMapping~new("readonly_people")
ignore=readonly~column("id","INTEGER","id")
ignore=readonly~column("name","VARCHAR","name")
ignore=readonly~identity("id")
call assert engine~register("readonly_people",people,readonly),"readonly register"
bad=sql~execute("DELETE FROM readonly_people WHERE id=1")
call assert bad~status=.Error~NOTEXECUTED,"missing removal policy rejected"
call assert people~items=2,"refused delete no mutation"

-- No factory means INSERT is cleanly rejected.
bad=sql~execute("INSERT INTO readonly_people VALUES (9,'Nine')")
call assert bad~status=.Error~NOTEXECUTED,"missing factory rejected"
call assert people~items=2,"refused insert no mutation"

call assert engine~version~product="NoSQLServer","version product"
call assert engine~version~supports("OBJECT_TABLE_INSERT"),"insert survives newer release"
call assert engine~version~supports("OBJECT_TABLE_INSERT"),"insert capability"
call assert engine~version~supports("OBJECT_TABLE_DELETE"),"delete capability"

say "NOSQLSERVER V0.56 OBJECT INSERT / DELETE SMOKE: OK"
exit 0

assert: procedure
  use arg condition,message
  if \condition then do
    say "ASSERT FAILED:" message
    exit 1
  end
  return

::class Person
::attribute id
::attribute name
::attribute age
::method init
  use arg id,name,age
  self~id=id
  self~name=name
  self~age=age

::class PersonFactory
::method newRow
  use arg row
  return .Person~new(row["id"],row["name"],row["age"])

::class EventProbe
::attribute beforeInsert
::attribute afterInsert
::attribute beforeDelete
::attribute afterDelete
::attribute afterInsertName
::attribute deletedName
::method init
  self~beforeInsert=0
  self~afterInsert=0
  self~beforeDelete=0
  self~afterDelete=0
::method onDatabaseEvent
  use arg event
  select
    when event~type=.DatabaseEventType~BEFORE_INSERT then self~beforeInsert=self~beforeInsert+1
    when event~type=.DatabaseEventType~AFTER_INSERT then do
      self~afterInsert=self~afterInsert+1
      self~afterInsertName=event~changes[1]["after"]["name"]
    end
    when event~type=.DatabaseEventType~BEFORE_DELETE then self~beforeDelete=self~beforeDelete+1
    when event~type=.DatabaseEventType~AFTER_DELETE then do
      self~afterDelete=self~afterDelete+1
      self~deletedName=event~changes[1]["before"]["name"]
    end
    otherwise nop
  end
  return .true

::requires "../src/NoSQLServer.cls"
