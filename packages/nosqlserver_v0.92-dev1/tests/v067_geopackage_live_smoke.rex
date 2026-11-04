addressFile="/mnt/data/add_gb_builtaddress.gpkg"
minorFile="/mnt/data/v067_work/functional/FunctionalAreas_Inverness_geopackage/asu_funcarea_retailareaminor/asu_funcarea_retailareaminor.gpkg"

if stream(addressFile,"c","query exists")="" | stream(minorFile,"c","query exists")="" then do
  say "NOSQLSERVER V0.67 GEOPACKAGE LIVE SMOKE: SKIP (source datasets absent)"
  exit 0
end

addrEngine=.GeoPackageDatabaseEngine~new(addressFile)
minorEngine=.GeoPackageDatabaseEngine~new(minorFile)

call assert addrEngine~table("add_gb_builtaddress") \== .nil,"built address discovered"
call assert addrEngine~table("add_gb_builtaddress")~rowCount=16508,"built address row count"
call assert addrEngine~table("add_gb_builtaddress")~geometryColumn="geometry","address geometry column"
call assert addrEngine~table("add_gb_builtaddress")~geometryType="POINT","address geometry type"
call assert addrEngine~table("add_gb_builtaddress")~srid=27700,"address srid"

call assert minorEngine~table("asu_funcarea_retailareaminor") \== .nil,"minor retail discovered"
call assert minorEngine~table("asu_funcarea_retailareaminor")~geometryType="POLYGON","minor geometry type"
call assert minorEngine~table("asu_funcarea_retailareaminor")~srid=27700,"minor srid"

sql=.NoSQLServerSQL~new(addrEngine)
r=sql~execute("SELECT uprn,fulladdress,postcode,townname FROM add_gb_builtaddress WHERE townname='INVERNESS' ORDER BY postcode LIMIT 3")
call assert r~status=.Error~SUCCESS,"direct address SQL"
call assert r~rows~items=3,"direct address row count"
call assert r~accessPath="GEOPACKAGE_NATIVE_SQLITE_SCAN","direct access path"
say "DIRECT ADDRESS SAMPLE:"
do row over r~rows
  say row["uprn"] "|" row["postcode"] "|" row["fulladdress"]
end

-- Federation: native empty file catalog + two independent GeoPackages.
fileRoot=.NoSQLServerTestSupport~createBlankDatabase("v067_fed")
fed=.FederatedDatabaseEngine~new(fileRoot)
ignore=fed~addEngine(addrEngine)
ignore=fed~addEngine(minorEngine)
sql=.NoSQLServerSQL~new(fed)

-- OS supplies a related-entity table linking Retail Area Minor features to
-- Built Address UPRNs. This proves cross-GeoPackage federation before spatial
-- predicates are added.
q="SELECT r.featuretypeid,r.crossreferenceid,a.fulladdress,a.postcode " ||,
  "FROM asu_funcarea_retailareaminor_rltenty r " ||,
  "JOIN add_gb_builtaddress a ON r.crossreferenceid=a.uprn " ||,
  "WHERE r.crossreferencefeature='Built Address' " ||,
  "ORDER BY a.postcode,a.fulladdress LIMIT 10"
r=sql~execute(q)
call assert r~status=.Error~SUCCESS,"cross gpkg federated join"
call assert r~rows~items=10,"cross gpkg join count"
say "MINOR RETAIL ADDRESS SAMPLE:"
do row over r~rows
  say row["a.postcode"] "|" row["a.fulladdress"] "| UPRN" row["r.crossreferenceid"]
end

ignore=.NoSQLServerTestSupport~removeDatabase(fileRoot)
say "NOSQLSERVER V0.67 GEOPACKAGE LIVE SMOKE: OK"
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
