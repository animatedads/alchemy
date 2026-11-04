/* NoSQLServer v0.76 real POINT/POLYGON spatial predicate smoke. */

fixture = "fixtures/v067_inverness_sample.gpkg"
gpkg = .GeoPackageDatabaseEngine~new(fixture)
sql = .NoSQLServerSQL~new(gpkg)

r = sql~execute("SELECT uprn,ST_GEOMETRYTYPE(geometry) AS gtype,ST_SRID(geometry) AS srid,ST_X(geometry) AS x,ST_Y(geometry) AS y FROM sample_address ORDER BY uprn")
call assert r~status = .Error~SUCCESS, "GeoPackage spatial accessors execute"
call assert r~rows~items = 4, "all sample points returned"
call assert r~rows[1]["gtype"] = "POINT", "ST_GEOMETRYTYPE reads WKB"
call assert r~rows[1]["srid"] = 27700, "ST_SRID preserves GeoPackage SRID"
call assert datatype(r~rows[1]["x"]~string, "N"), "ST_X numeric"
call assert datatype(r~rows[1]["y"]~string, "N"), "ST_Y numeric"

-- The bundled Inverness sample's polygon is intentionally not claimed to
-- contain any of its four address points. This proves the real fixture can be
-- searched spatially without inventing a positive relationship.
r = sql~execute("SELECT a.uprn FROM sample_address a JOIN sample_minor p ON ST_WITHIN(a.geometry,p.geometry)=TRUE")
call assert r~status = .Error~SUCCESS, "ST_WITHIN can drive general JOIN ON"
call assert r~rows~items = 0, "real fixture has no fabricated containment"

-- Synthetic typed GeoPackage geometries give positive, boundary and negative
-- cases while still exercising the exact GPKG binary/WKB parser.
inside = .GeoFixture~new("inside", .GeoPackageGeometry~new("47500001346C0000010100000000000000000014400000000000001440", "POINT", 27700))
boundary = .GeoFixture~new("boundary", .GeoPackageGeometry~new("47500001346C0000010100000000000000000000000000000000001440", "POINT", 27700))
outside = .GeoFixture~new("outside", .GeoPackageGeometry~new("47500001346C000001010000000000000000002E400000000000001440", "POINT", 27700))
polygon = .GeoFixture~new("square", .GeoPackageGeometry~new("47500001346C0000010300000001000000050000000000000000000000000000000000000000000000000024400000000000000000000000000000244000000000000024400000000000000000000000000000244000000000000000000000000000000000", "POLYGON", 27700))

points = .array~of(inside, boundary, outside)
polygons = .array~of(polygon)
map = .ObjectTableMapping~new
map~column("id", "VARCHAR", "id")
map~column("geometry", "GEOMETRY", "geometry")
obj = .ObjectDatabaseEngine~new
call assert obj~registerSnapshot("points", points, map), "point snapshot registered"
map2 = .ObjectTableMapping~new
map2~column("id", "VARCHAR", "id")
map2~column("geometry", "GEOMETRY", "geometry")
call assert obj~registerSnapshot("polygons", polygons, map2), "polygon snapshot registered"
sql = .NoSQLServerSQL~new(obj)

r = sql~execute("SELECT pt.id FROM points pt JOIN polygons p ON ST_WITHIN(pt.geometry,p.geometry)=TRUE ORDER BY pt.id")
call assert r~status = .Error~SUCCESS, "positive ST_WITHIN join"
call assert r~rows~items = 1, "strict within excludes boundary/outside"
call assert r~rows[1]["pt.id"] = "inside", "inside point selected"
call assert r~accessPath = "INNER_PREDICATE_CHAIN", "spatial predicate uses generic join predicate path"

r = sql~execute("SELECT pt.id FROM points pt JOIN polygons p ON ST_INTERSECTS(pt.geometry,p.geometry)=TRUE ORDER BY pt.id")
call assert r~status = .Error~SUCCESS, "ST_INTERSECTS join"
call assert r~rows~items = 2, "intersects includes boundary"
call assert r~rows[1]["pt.id"] = "boundary", "boundary intersects polygon"
call assert r~rows[2]["pt.id"] = "inside", "inside intersects polygon"

r = sql~execute("SELECT id,ST_X(geometry) AS x,ST_Y(geometry) AS y FROM points WHERE ST_INTERSECTS(geometry,geometry)=TRUE ORDER BY id")
call assert r~status = .Error~SUCCESS, "POINT/POINT intersects"
call assert r~rows~items = 3, "each point intersects itself"

-- Mismatched SRIDs fail explicitly instead of comparing unlike coordinate systems.
wrongSrid = .GeoFixture~new("wrong", .GeoPackageGeometry~new("47500001E6100000010100000000000000000014400000000000001440", "POINT", 4326))
wrong = .array~of(wrongSrid)
obj2 = .ObjectDatabaseEngine~new
call assert obj2~registerSnapshot("wrong_points", wrong, map), "mismatch snapshot registered"
fed = .FederatedDatabaseEngine~new(.NoSQLServerTestSupport~createBlankDatabase("v076_spatial"))
ignore = fed~addEngine(obj)
ignore = fed~addEngine(obj2)
sql = .NoSQLServerSQL~new(fed)
r = sql~execute("SELECT pt.id FROM wrong_points pt JOIN polygons p ON ST_WITHIN(pt.geometry,p.geometry)=TRUE")
call assert r~status = .Error~NOTEXECUTED, "SRID mismatch does not silently compare"
call assert r~error = .Error~SQLERROR | r~error = .Error~SQLPARSEERROR, "SRID mismatch is explicit SQL failure"
ignore = .NoSQLServerTestSupport~removeDatabase(fed~fileEngine~root)

v = .NoSQLServerVersionInfo~new
call assert v~release \= "", "release metadata present on successor"
call assert v~supports("SPATIAL_POINT_POLYGON_FUNCTIONS"), "spatial capability advertised narrowly"

say "NOSQLSERVER V0.76 SPATIAL PREDICATES: OK"
exit 0

assert: procedure
  use arg condition, message
  if \condition then do
    say "ASSERT FAILED:" message
    exit 1
  end
  return

::class GeoFixture public
::attribute id
::attribute geometry
::method init
  use arg id, geometry
  self~id = id
  self~geometry = geometry

::requires "../src/NoSQLServer.cls"
::requires "TestSupport.cls"
