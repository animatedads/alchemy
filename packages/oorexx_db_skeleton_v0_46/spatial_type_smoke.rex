call assert .DatabaseType~fromPostgreSQL("geometry") = .DatabaseType~GEOMETRY, "postgres geometry mapping"
call assert .DatabaseType~fromPostgreSQL("geography") = .DatabaseType~GEOMETRY, "postgres geography mapping"
call assert .DatabaseType~fromMySQL("point") = .DatabaseType~GEOMETRY, "mysql point mapping"
call assert .DatabaseType~fromMySQL("multipolygon") = .DatabaseType~GEOMETRY, "mysql multipolygon mapping"

v = .DatabaseGeometryValue~new("01020304", "POINT", 27700, .DatabaseSpatialEncoding~WKBHEX)
call assert v~isA(.DatabaseValue), "geometry is database value"
call assert v~typeName = .DatabaseType~GEOMETRY, "geometry database type"
call assert v~geometryType = "POINT", "geometry subtype"
call assert v~srid = 27700, "geometry srid"
call assert v~encoding = .DatabaseSpatialEncoding~WKBHEX, "geometry encoding"
call assert v~raw = "01020304", "geometry raw preserved"
call assert v~string~pos("POINT(SRID=27700,WKBHEX=01020304") = 1, "geometry safe display"

parsed = .DatabaseValue~fromText("AABBCC", .DatabaseType~GEOMETRY)
call assert parsed~isA(.DatabaseGeometryValue), "typed result becomes geometry value"
call assert parsed~raw = "AABBCC", "typed geometry text preserved"

meta = .DatabaseColumnMetadata~new("geom", "geometry", .DatabaseType~GEOMETRY, .true, 2, "POINT", 27700)
call assert meta~geometryType = "POINT", "metadata geometry subtype"
call assert meta~srid = 27700, "metadata srid"

caps = .DatabaseCapabilities~new
call assert \caps~supports(.DatabaseCapability~SPATIALTYPES), "spatial not claimed by default"
caps~add(.DatabaseCapability~SPATIALTYPES)
call assert caps~supports(.DatabaseCapability~SPATIALTYPES), "spatial capability can be enabled"
call assert \caps~supports(.DatabaseCapability~SPATIALFUNCTIONS), "spatial functions remain separate"
pg = .PostgreSQLEngine~new
call assert pg~metadataQueryForTable("shape")~pos("udt_name") > 0, "postgres user-defined metadata preserved"

say "DATABASE SPATIAL TYPE SMOKE: OK"
exit 0

assert: procedure
  use arg condition, label
  if \condition then do
    say "ASSERTION FAILED:" label
    exit 9
  end
  return

::requires "database_core.cls"
