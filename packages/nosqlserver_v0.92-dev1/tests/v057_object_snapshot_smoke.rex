people=.array~of(.Person~new(1,"Ada",36),.Person~new(2,"Grace",42))
m=.ObjectTableMapping~new("people")
ignore=m~column("id","INTEGER","id")
ignore=m~column("name","VARCHAR","name","name=")
ignore=m~column("age","INTEGER","age","age=")
ignore=m~identity("id")

engine=.ObjectDatabaseEngine~new
call assert engine~register("live_people",people,m),"live register"
call assert engine~registerSnapshot("people_snapshot",people,m),"snapshot register"
sql=.NoSQLServerSQL~new(engine)

q=sql~execute("SELECT id,name,age FROM people_snapshot ORDER BY id")
call assert q~status=.Error~SUCCESS,"snapshot query"
call assert q~rows~items=2,"snapshot rows"
call assert q~rows[1]["age"]=36,"snapshot initial value"

-- External object changes affect live table but not frozen snapshot.
people[1]~age=99
live=sql~execute("SELECT age FROM live_people WHERE id=1")
snap=sql~execute("SELECT age FROM people_snapshot WHERE id=1")
call assert live~rows[1]["age"]=99,"live object refreshed"
call assert snap~rows[1]["age"]=36,"snapshot remains frozen"

-- A snapshot created from an already registered live table freezes at that generation.
call assert engine~snapshotTable("live_people","later_snapshot"),"snapshot existing table"
people[2]~name="Changed Grace"
later=sql~execute("SELECT name FROM later_snapshot WHERE id=2")
call assert later~rows[1]["name"]="Grace","second snapshot frozen"
live=sql~execute("SELECT name FROM live_people WHERE id=2")
call assert live~rows[1]["name"]="Changed Grace","live still changes"

-- Snapshot rows participate in ordinary joins and aggregates.
dept=.array~of(.Dept~new(36,"Thirty Six"),.Dept~new(42,"Forty Two"))
dm=.ObjectTableMapping~new("dept")
ignore=dm~column("age","INTEGER","age")
ignore=dm~column("label","VARCHAR","label")
call assert engine~register("dept",dept,dm),"dept register"
r=sql~execute("SELECT people_snapshot.name,dept.label FROM people_snapshot JOIN dept ON people_snapshot.age=dept.age ORDER BY people_snapshot.name")
call assert r~status=.Error~SUCCESS,"snapshot join"
call assert r~rows~items=2,"snapshot join rows"
call assert r~rows[1]["people_snapshot.name"]="Ada","snapshot join first"

-- All mutation surfaces are explicitly read-only.
bad=sql~execute("UPDATE people_snapshot SET age=1 WHERE id=1")
call assert bad~error=.Error~SQLUNSUPPORTED,"snapshot update unsupported"
bad=sql~execute("DELETE FROM people_snapshot WHERE id=1")
call assert bad~error=.Error~SQLUNSUPPORTED,"snapshot delete unsupported"
bad=sql~execute("INSERT INTO people_snapshot VALUES (3,'Alan',29)")
call assert bad~error=.Error~SQLUNSUPPORTED,"snapshot insert unsupported"

call assert engine~version~product="NoSQLServer","version product"
call assert engine~version~supports("OBJECT_TABLE_SNAPSHOT"),"snapshot survives newer release"
call assert engine~version~supports("OBJECT_TABLE_SNAPSHOT"),"snapshot capability"

say "NOSQLSERVER V0.57 OBJECT SNAPSHOT SMOKE: OK"
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
  self~id=id; self~name=name; self~age=age

::class Dept
::attribute age
::attribute label
::method init
  use arg age,label
  self~age=age; self~label=label

::requires "../src/NoSQLServer.cls"
