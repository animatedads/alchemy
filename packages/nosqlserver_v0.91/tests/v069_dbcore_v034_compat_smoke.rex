fixture = "fixtures/v067_inverness_sample.gpkg"
root = .NoSQLServerTestSupport~createBlankDatabase("v069_db34")
fed = .FederatedDatabaseEngine~new(root)

created = fed~execute("CREATE TABLE persisted (id INTEGER PRIMARY KEY, note VARCHAR)")
call assert created~status = .Error~SUCCESS, "persisted table create"
inserted = fed~execute("INSERT INTO persisted (id,note) VALUES (1,'db34')")
call assert inserted~status = .Error~SUCCESS, "persisted row insert"

gpkg = .GeoPackageDatabaseEngine~new(fixture)
ignore = fed~addEngine(gpkg)

/* DB Core v0.34 relational-source facade shape, kept namespaced because
 * database_core.cls and NoSQLServer.cls intentionally publish overlapping
 * historical class names and are not loaded into one ooRexx package.
 */
core = fed~databaseCore
source = core~relationalSource
call assert source~isA(.NoSQLDatabaseRelationalSource), "relational source class"
call assert source~identity~sourceKind = .NoSQLDatabaseCoreSourceKind~DATABASE, "database source kind"
call assert source~identity~engineName = "federated", "federated source engine"
call assert source~identity~name = "v069_db34", "source database name"
call assert source~identity~product = "NoSQLServer", "source endpoint product"
call assert source~supports(.NoSQLDatabaseCoreCapability~TABLEDISCOVERY), "table discovery capability"
call assert source~supports(.NoSQLDatabaseCoreCapability~TYPEDRESULTS), "typed result capability"
call assert source~supports(.NoSQLDatabaseCoreCapability~SPATIALTYPES), "spatial type transport capability"
call assert \source~supports(.NoSQLDatabaseCoreCapability~SPATIALFUNCTIONS), "spatial functions not falsely claimed"

descriptors = source~tables
call assert descriptorExists(descriptors, "persisted"), "file relation descriptor"
call assert descriptorExists(descriptors, "sample_address"), "GeoPackage relation descriptor"
call assert descriptorExists(descriptors, "sample_minor"), "second GeoPackage relation descriptor"

tableSource = source~table("persisted")
call assert tableSource~isA(.NoSQLDatabaseTableSource), "table source class"
call assert tableSource~identity~sourceKind = .NoSQLDatabaseCoreSourceKind~TABLE, "table source kind"
call assert tableSource~identity~name = "persisted", "table identity"
call assert tableSource~metadata~columns~items = 2, "table metadata"
rows = tableSource~rows
call assert rows~status = .Error~SUCCESS, "table source rows status"
call assert rows~rows~items = 1, "table source row count"
call assert rows~rows[1]~isA(.NoSQLDatabaseCoreRow), "table source row adapter"
call assert rows~rows[1]~valueAt("note") = "db34", "table source row value"
description = tableSource~describe
call assert description["name"] = "persisted", "table describe name"
call assert description["engine"] = "federated", "table describe engine"
call assert description["capabilities"]~items > 0, "table describe capabilities"

/* DB Core v0.34 geometry metadata/value interoperability. */
gpCore = gpkg~databaseCore
gpMeta = gpCore~tableMetadata("sample_address")
geomMeta = metadataColumn(gpMeta, "geometry")
call assert geomMeta \== .nil, "geometry metadata exists"
call assert geomMeta~databaseType = .DatabaseType~GEOMETRY, "generic GEOMETRY type"
call assert geomMeta~geometryType = "POINT", "geometry subtype preserved"
call assert geomMeta~srid = 27700, "geometry metadata SRID preserved"

pointRows = gpCore~queryTable("sample_address")
call assert pointRows~status = .Error~SUCCESS, "GeoPackage core queryTable"
call assert pointRows~rows~items > 0, "GeoPackage core rows"
geometry = pointRows~rows[1]~at("geometry")
call assert geometry~isA(.NoSQLDatabaseCoreGeometryValue), "typed core geometry value"
call assert geometry~typeName = .DatabaseType~GEOMETRY, "geometry value common type"
call assert geometry~geometryType = "POINT", "geometry value subtype"
call assert geometry~srid = 27700, "geometry value SRID"
call assert geometry~encoding = .NoSQLDatabaseCoreSpatialEncoding~GPKGBLOBHEX, "geometry encoding"
call assert geometry~raw~length > 24, "geometry raw payload preserved"
call assert geometry~string~pos("POINT(SRID=27700,GPKGBLOBHEX=") = 1, "bounded geometry display"

/* Federation must delegate metadata to the provider rather than flatten it. */
fedMeta = core~tableMetadata("sample_address")
fedGeomMeta = metadataColumn(fedMeta, "geometry")
call assert fedGeomMeta~databaseType = .DatabaseType~GEOMETRY, "federated geometry type"
call assert fedGeomMeta~geometryType = "POINT", "federated geometry subtype"
call assert fedGeomMeta~srid = 27700, "federated geometry SRID"
fedRows = core~queryTable("sample_address")
fedGeometry = fedRows~rows[1]~at("geometry")
call assert fedGeometry~isA(.NoSQLDatabaseCoreGeometryValue), "federated typed geometry"
call assert fedGeometry~srid = 27700, "federated geometry SRID"

ignore = .NoSQLServerTestSupport~removeDatabase(root)
say "NOSQLSERVER V0.69 DB CORE V0.34 COMPAT SMOKE: OK"
exit 0

descriptorExists: procedure
  use arg descriptors, wanted
  do descriptor over descriptors
    if descriptor~name~caselessEquals(wanted) then return .true
  end
  return .false

metadataColumn: procedure
  use arg metadata, wanted
  do column over metadata~columns
    if column~name~caselessEquals(wanted) then return column
  end
  return .nil

assert: procedure
  use arg condition, message
  if \condition then do
    say "ASSERT FAILED:" message
    exit 1
  end
  return

::requires "../src/NoSQLServer.cls"
::requires "TestSupport.cls"
