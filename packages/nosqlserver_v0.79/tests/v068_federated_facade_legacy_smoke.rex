root=.NoSQLServerTestSupport~createBlankDatabase('v066_federated_facade')
engine=.FederatedDatabaseEngine~new(root)
people=.array~of(.Person~new(1,'Ada',36),.Person~new(2,'Grace',42))
m=.ObjectTableMapping~new('people_snapshot')
ignore=m~column('id','INTEGER','id')
ignore=m~column('name','VARCHAR','name')
ignore=m~column('age','INTEGER','age')
call assert engine~registerSnapshot('people_snapshot',people,m),'snapshot register'

r=engine~execute("SELECT name,age FROM people_snapshot WHERE id=1")
call ok r
call assert r~rows~items=1,'execute row'
call assert r~rows[1]['name']='Ada','execute value'

r=engine~query("SELECT name FROM people_snapshot WHERE id=2")
call ok r
call assert r~rows[1]['name']='Grace','query value'

meta=engine~tableMetadata('people_snapshot')
call assert meta \== .nil,'native metadata'
call assert meta~columns~items=3,'native metadata columns'

core=engine~databaseCore
coreMeta=core~tableMetadata('people_snapshot')
call assert coreMeta~columns~items=3,'database core metadata columns'

coreResult=core~queryTable('people_snapshot')
call assert coreResult~error=.Error~SUCCESS,'database core query table'
call assert coreResult~rows~items=2,'database core rows'

catalog=engine~readCatalog
call assert catalog['tables']~items=1,'federated catalog table count'
call assert catalog['tables'][1]~caselessEquals('people_snapshot'),'federated catalog contains snapshot'

bad=engine~execute("UPDATE people_snapshot SET age=1 WHERE id=1")
call assert bad~error=.Error~SQLUNSUPPORTED,'snapshot remains read only'

ignore=.NoSQLServerTestSupport~removeDatabase(root)
say 'NOSQLSERVER V0.66 FEDERATED FACADE SMOKE: OK'
exit 0

ok: procedure
  use arg rs
  if rs~status \= .Error~SUCCESS then do
    say 'FAILED:' rs~status rs~error rs~message
    exit 1
  end
  return .true

assert: procedure
  use arg condition,message
  if \condition then do
    say 'ASSERT FAILED:' message
    exit 1
  end
  return .true

::class Person
::attribute id
::attribute name
::attribute age
::method init
  use arg id,name,age
  self~id=id; self~name=name; self~age=age

::requires '../src/NoSQLServer.cls'
::requires 'TestSupport.cls'
