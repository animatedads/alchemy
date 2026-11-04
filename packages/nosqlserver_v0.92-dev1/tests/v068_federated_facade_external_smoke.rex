root=.NoSQLServerTestSupport~createBlankDatabase("v068_facade")
fed=.FederatedDatabaseEngine~new(root)

-- FILE source
call ok fed~execute("CREATE TABLE persisted (id INTEGER PRIMARY KEY, label VARCHAR)")
call ok fed~execute("INSERT INTO persisted VALUES (1,'disk')")

-- frozen OBJECT/SNAPSHOT source
people=.array~of(.Person~new(1,"Ada"),.Person~new(2,"Grace"))
m=.ObjectTableMapping~new("people_snapshot")
ignore=m~column("id","INTEGER","id")
ignore=m~column("name","VARCHAR","name")
call assert fed~registerSnapshot("people_snapshot",people,m),"snapshot registration"

-- external GeoPackage source
gpkg=.GeoPackageDatabaseEngine~new("fixtures/v067_inverness_sample.gpkg")
ignore=fed~addEngine(gpkg)

-- Facade execution must work over all three provider classes.
r=fed~execute("SELECT label FROM persisted WHERE id=1")
call ok r
call assert r~rows[1]["label"]="disk","file facade query"

r=fed~query("SELECT name FROM people_snapshot WHERE id=2")
call ok r
call assert r~rows[1]["name"]="Grace","snapshot facade query"

r=fed~execute("SELECT postcode,fulladdress FROM sample_address ORDER BY postcode,fulladdress LIMIT 1")
call ok r
call assert r~rows~items=1,"external facade query"
call assert r~accessPath="GEOPACKAGE_NATIVE_SQLITE_SCAN","external access path"

-- Generic metadata / Database Core paths must also be provider-agnostic.
meta=fed~tableMetadata("people_snapshot")
call assert meta \== .nil,"snapshot metadata"
call assert meta~columns~items=2,"snapshot metadata columns"

meta=fed~tableMetadata("sample_address")
call assert meta \== .nil,"GeoPackage metadata"
call assert meta~columns~items=8,"GeoPackage metadata columns"

core=fed~databaseCore
r=core~queryTable("sample_address")
call assert r~error=.Error~SUCCESS,"DatabaseCore GeoPackage query"
call assert r~rows~items=4,"DatabaseCore GeoPackage rows"
call assert r~metadata~columns~items=8,"DatabaseCore GeoPackage metadata"

-- Catalog is the architectural contract: all sources are ordinary table names.
catalog=fed~readCatalog
expected=.array~of("persisted","people_snapshot","sample_address","sample_minor","sample_minor_rltenty")
do wanted over expected
  found=.false
  do actual over catalog["tables"]
    if actual~caselessEquals(wanted) then found=.true
  end
  call assert found,"catalog contains" wanted
end
call assert catalog["tables"]~items=5,"merged catalog exact table count"

-- Read-only snapshot semantics survive facade parity.
bad=fed~execute("UPDATE people_snapshot SET name='Changed' WHERE id=1")
call assert bad~error=.Error~SQLUNSUPPORTED,"snapshot mutation rejected"

call assert fed~version~supports("FEDERATED_DATABASE_FACADE"),"facade capability"

ignore=.NoSQLServerTestSupport~removeDatabase(root)
say "NOSQLSERVER V0.68 FEDERATED FACADE EXTERNAL SMOKE: OK"
exit 0

ok: procedure
  use arg rs
  if rs~status \= .Error~SUCCESS then do
    say "FAILED:" rs~status rs~error rs~message
    exit 1
  end
  return .true

assert: procedure
  use arg condition,message,detail=""
  if \condition then do
    say "ASSERT FAILED:" message detail
    exit 1
  end
  return .true

::class Person
::attribute id
::attribute name
::method init
  use arg id,name
  self~id=id
  self~name=name

::requires "../src/NoSQLServer.cls"
::requires "TestSupport.cls"
