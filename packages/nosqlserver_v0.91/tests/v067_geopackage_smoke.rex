file="fixtures/v067_inverness_sample.gpkg"

-- v0.74 reads the SQLite/GeoPackage binary directly in ooRexx.
-- No C bridge is built or executed.
gpkg=.GeoPackageDatabaseEngine~new(file)
call assert gpkg~table("sample_address") \== .nil,"address table discovered"
call assert gpkg~table("sample_minor") \== .nil,"minor table discovered"
call assert gpkg~table("sample_address")~geometryType="POINT","point metadata"
call assert gpkg~table("sample_minor")~geometryType="POLYGON","polygon metadata"
call assert gpkg~table("sample_address")~srid=27700,"address srid"
call assert gpkg~table("sample_minor")~srid=27700,"minor srid"

sql=.NoSQLServerSQL~new(gpkg)
r=sql~execute("SELECT uprn,fulladdress,postcode FROM sample_address WHERE townname='INVERNESS' ORDER BY postcode,fulladdress")
call assert r~status=.Error~SUCCESS,"gpkg select"
call assert r~rows~items>0,"gpkg rows"
call assert r~accessPath="GEOPACKAGE_NATIVE_SQLITE_SCAN","gpkg path"

-- Geometry is preserved as a typed value, not flattened to coordinate text.
all=gpkg~table("sample_address")~readRows
g=all[1]["geometry"]
call assert g~isA(.GeoPackageGeometry),"geometry object"
call assert g~geometryType="POINT","geometry object type"
call assert g~srid=27700,"geometry object srid"

root=.NoSQLServerTestSupport~createBlankDatabase("v067")
fed=.FederatedDatabaseEngine~new(root)
ignore=fed~addEngine(gpkg)
sql=.NoSQLServerSQL~new(fed)
q="SELECT r.crossreferenceid,a.fulladdress,a.postcode " ||,
  "FROM sample_minor_rltenty r JOIN sample_address a " ||,
  "ON r.crossreferenceid=a.uprn " ||,
  "WHERE r.crossreferencefeature='Built Address' ORDER BY a.postcode,a.fulladdress"
r=sql~execute(q)
call assert r~status=.Error~SUCCESS,"federated gpkg join"
call assert r~rows~items>0,"federated join rows"

ignore=.NoSQLServerTestSupport~removeDatabase(root)
say "NOSQLSERVER V0.67 GEOPACKAGE SMOKE: OK"
exit 0

assert: procedure
  use arg condition,message
  if \condition then do
    say "ASSERT FAILED:" message
    exit 1
  end
  return

::requires "../src/NoSQLServer.cls"
::requires "TestSupport.cls"
