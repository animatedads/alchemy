people=.array~new
people~append(.Person~new(1,"Ada",36,"London"))
people~append(.Person~new(2,"Grace",42,"New York"))
people~append(.Person~new(3,"Alan",29,"Manchester"))
people~append(.Person~new(4,"Katherine",42,"London"))

mapping=.ObjectTableMapping~new("people")
ignore=mapping~column("id","INTEGER","id")
ignore=mapping~column("name","VARCHAR","name")
ignore=mapping~column("age","INTEGER","age")
ignore=mapping~column("city","VARCHAR","city")
ignore=mapping~identity("id")

engine=.ObjectDatabaseEngine~new
call assert engine~register("people",people,mapping), "register"
sql=.NoSQLServerSQL~new(engine)

r=sql~execute("SELECT name,age FROM people WHERE age >= 40 ORDER BY name")
call assert r~status=.Error~SUCCESS, "select status"
call assert r~rows~items=2, "select count"
call assert r~rows[1]["name"]="Grace", "ordered first"
call assert r~rows[1]["age"]=42, "typed age"
call assert r~rows[2]["name"]="Katherine", "ordered second"
call assert r~accessPath="OBJECT_TABLE_SCAN", "object scan path"

-- Live means getters are re-read, not snapshotted at registration.
people[1]~age=50
r=sql~execute("SELECT name,age FROM people WHERE age >= 40 ORDER BY name")
call assert r~rows~items=3, "live getter refresh"
call assert r~rows[1]["name"]="Ada", "live Ada now visible"

-- Raw objects remain ordinary ooRexx objects; no file materialisation occurred.
call assert people[1]~age=50, "original object retained"
call assert engine~version~engine="OBJECT", "object engine version"
call assert engine~version~supports("OBJECT_TABLE_SELECT"), "object select capability"

-- Mutation semantics are exercised by the v0.54 smoke in newer releases.

say "NOSQLSERVER V0.52 OBJECT TABLE SELECT SMOKE: OK"
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
::attribute city
::method init
  use arg id,name,age,city
  self~id=id
  self~name=name
  self~age=age
  self~city=city

::requires "../src/NoSQLServer.cls"
