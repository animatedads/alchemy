fixture = "fixtures/v074_sqlite_native_fixture.sqlite"
db = .SQLiteNativeDatabase~new(fixture)

call assert db~pageSize = 512, "512-byte page size decoded"
call assert db~pageCount > 2, "multi-page database decoded"
call assert db~textEncoding = 1, "UTF-8 database encoding"

typed = db~table("typed")
call assert typed \== .nil, "typed table discovered from sqlite_schema"
call assert typed~columns~items = 7, "typed schema column count"
call assert typed~columns[1]~rowidAlias, "INTEGER PRIMARY KEY rowid alias detected"

rows = db~rows("typed")
call assert rows~items = 2, "typed row count"
r = rows[1]
call assert r["id"] = 1, "rowid alias materialized"
call assert r["neg"] = -123, "signed integer decoded"
call assert r["big"] = 9223372036854775807, "signed 64-bit maximum decoded"
call assert (r["realv"] - 3.141592653589793)~abs < 0.000000000000001, "IEEE-754 REAL decoded"
call assert r["txt"] = "hello μSQLite", "UTF-8 text decoded"
call assert r["blobv"]~isA(.SQLiteNativeBlob), "BLOB preserved as binary object"
call assert r["blobv"]~hex = "0001FEFF", "BLOB bytes preserved"
call assert r["nullable"] == .nil, "NULL decoded"

r = rows[2]
call assert r["neg"] = -9223372036854775808, "signed 64-bit minimum decoded"
call assert r["big"] = -281474976710655, "negative 48-bit integer decoded"
call assert r["realv"] = -0.125, "negative REAL decoded"
call assert r["txt"]~length = 1800, "overflow TEXT reassembled"
call assert r["blobv"]~bytes~length = 2048, "overflow BLOB reassembled"
call assert r["nullable"] = "tail", "post-overflow record field aligned"

many = db~rows("many")
call assert many~items = 400, "interior table b-tree walked"
call assert many[1]["id"] = 1, "first interior-tree row"
call assert many[400]["id"] = 400, "last interior-tree row"

composite = db~table("composite")
call assert composite~columns[1]~primaryKey, "table-level primary key column one"
call assert composite~columns[2]~primaryKey, "table-level primary key column two"
call assert \composite~columns[1]~rowidAlias, "table-level TEXT PK is not rowid alias"

wr = db~table("wr")
call assert wr~withoutRowid, "WITHOUT ROWID storage detected"
signal on syntax name expectedWithoutRowid
ignore = db~rows("wr")
signal off syntax
call assert .false, "WITHOUT ROWID read must not be silently accepted"
expectedWithoutRowid:
signal off syntax

-- The same native storage reader is exposed as an ordinary read-only NoSQL engine.
sqlite = .SQLiteDatabaseEngine~new(fixture)
call assert sqlite~table("typed") \== .nil, "generic SQLite relation discovered"
sq = sqlite~execute("SELECT id,neg,realv FROM typed WHERE id=1")
call assert sq~status = .Error~SUCCESS, "NoSQL SQL over native SQLite"
call assert sq~rows~items = 1, "native SQLite NoSQL result count"
call assert sq~rows[1]["neg"] = -123, "native SQLite projected integer"
call assert sq~accessPath = "SQLITE_NATIVE_SCAN", "native SQLite access path"
call assert sqlite~version~storage = "SQLITE_NATIVE_READONLY", "generic native SQLite storage identity"
wrQuery = sqlite~execute("SELECT * FROM wr")
call assert wrQuery~error = .Error~STORAGEERROR, "WITHOUT ROWID rejected through NoSQL boundary"

-- GeoPackage consumer: pass a path that cannot possibly be an executable helper.
-- If v0.74 accidentally shells to the old bridge, this construction/read fails.
gpkg = .GeoPackageDatabaseEngine~new("fixtures/v067_inverness_sample.gpkg", "/definitely/not/a/sqlite/bridge")
call assert gpkg~table("sample_address") \== .nil, "GeoPackage schema discovered natively"
call assert gpkg~table("sample_address")~rowCount = 4, "GeoPackage row count"
call assert gpkg~table("sample_address")~geometryType = "POINT", "geometry metadata"
call assert gpkg~table("sample_address")~srid = 27700, "geometry SRID"

grows = gpkg~table("sample_address")~readRows
call assert grows~items = 4, "GeoPackage rows decoded"
g = grows[1]["geometry"]
call assert g~isA(.GeoPackageGeometry), "GeoPackage BLOB promoted to typed geometry"
call assert g~hex~startsWith("4750"), "GeoPackage GP binary magic preserved"

sql = .NoSQLServerSQL~new(gpkg)
q = sql~execute("SELECT uprn,postcode FROM sample_address WHERE townname='INVERNESS' ORDER BY postcode,uprn")
call assert q~status = .Error~SUCCESS, "NoSQL query over native GeoPackage"
call assert q~rows~items = 4, "NoSQL native GeoPackage result count"
call assert q~accessPath = "GEOPACKAGE_NATIVE_SQLITE_SCAN", "native GeoPackage access path"
call assert gpkg~version~storage = "SQLITE_GPKG_NATIVE_READONLY", "native storage identity"
call assert gpkg~version~features~hasItem("SQLITE_NATIVE_BINARY_READ") > 0, "native binary capability advertised"

say "NOSQLSERVER V0.74 NATIVE SQLITE/GEOPACKAGE SMOKE: OK"
exit 0

assert: procedure
  use arg condition, message
  if \condition then do
    say "ASSERT FAILED:" message
    exit 1
  end
  return

::requires "../src/NoSQLServer.cls"
