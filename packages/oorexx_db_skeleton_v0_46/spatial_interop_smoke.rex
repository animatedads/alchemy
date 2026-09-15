/* Real GeoPackage POINT blob sampled from the supplied Inverness NGD data.
 * database_core does not parse GeoPackage; it preserves a backend-provided
 * geometry value and its relational metadata without losing type/SRID.
 */
hex = "47500001346C0000010100000000000000345610410000000080BE2941"
g = .DatabaseGeometryValue~new(hex, "POINT", 27700, .DatabaseSpatialEncoding~GPKGBLOBHEX)
call assert g~typeName = .DatabaseType~GEOMETRY, "generic geometry type"
call assert g~geometryType = "POINT", "GeoPackage subtype preserved"
call assert g~srid = 27700, "GeoPackage SRID preserved"
call assert g~encoding = .DatabaseSpatialEncoding~GPKGBLOBHEX, "GeoPackage encoding label"
call assert g~raw = hex, "GeoPackage blob preserved exactly"
call assert g~string~pos("POINT(SRID=27700,GPKGBLOBHEX=47500001346C000001010000") = 1, "safe bounded display"

row = .DatabaseRow~new
row~put("geometry", g)
call assert row~at("geometry")~isA(.DatabaseGeometryValue), "row preserves geometry object"
call assert row~at("geometry")~srid = 27700, "row geometry metadata survives"

say "DATABASE SPATIAL INTEROP SMOKE: OK"
exit 0

assert: procedure
  use arg condition, label
  if \condition then do
    say "ASSERTION FAILED:" label
    exit 9
  end
  return

::requires "database_core.cls"
