/* NoSQLServer v0.86 bulk result materialisation forcing regression. */

rs = .DatabaseResult~new(.DatabaseOperationType~QUERY)

do i = 1 to 1400
  vals = .table~new
  raw = .table~new
  types = .table~new

  call putTyped vals, raw, types, "id", i, .DatabaseType~INTEGER
  call putTyped vals, raw, types, "population", "1411778724", .DatabaseType~INTEGER
  call putTyped vals, raw, types, "ratio", "12345.6789", .DatabaseType~DECIMAL
  call putTyped vals, raw, types, "numeric_text", "1411778724", .DatabaseType~VARCHAR
  call putTyped vals, raw, types, "name", "row-" || i, .DatabaseType~VARCHAR
  call putTyped vals, raw, types, "active", "TRUE", .DatabaseType~BOOLEAN
  call putTyped vals, raw, types, "created_date", "2026-10-07", .DatabaseType~DATE
  call putTyped vals, raw, types, "created_at", "2026-10-07T17:55:00", .DatabaseType~DATETIME
  call putTyped vals, raw, types, "payload", "00FF7E", .DatabaseType~BLOB
  call putTyped vals, raw, types, "shape", "POINT (1 2)", .DatabaseType~GEOMETRY
  vals["nothing"] = .nil
  raw["nothing"] = .nil
  types["nothing"] = .DatabaseType~NULL

  rs~rows~append(.DatabaseRow~new(vals, raw, types))
end

call assert rs~rowCount = 1400, "source row count"
call assert rs~asArray == rs~rows, "asArray is zero-copy"

call time "R"
dirs = rs~asDirectories
dirSeconds = time("E")
call assert dirs~items = 1400, "directory row count"
call assert dirs[1]["population"] == "1411778724", "integer exact in object graph"
call assert dirs[1]["numeric_text"] == "1411778724", "varchar exact in object graph"

call time "R"
jsonText = rs~asJson
jsonSeconds = time("E")
call assert jsonText~startsWith("["), "JSON array start"
call assert jsonText~endsWith("]"), "JSON array end"
call assert jsonText~pos('"population":1411778724') > 0, "INTEGER encoded as JSON number"
call assert jsonText~pos('"ratio":12345.6789') > 0, "DECIMAL encoded as JSON number"
call assert jsonText~pos('"numeric_text":"1411778724"') > 0, "numeric-looking VARCHAR remains JSON string"
call assert jsonText~pos('"active":true') > 0, "BOOLEAN encoded as JSON boolean"
call assert jsonText~pos('"nothing":null') > 0, "NULL encoded as JSON null"
call assert jsonText~pos('"created_date":"2026-10-07"') > 0, "DATE encoded as JSON string"
call assert jsonText~pos('"created_at":"2026-10-07T17:55:00"') > 0, "DATETIME encoded as JSON string"
call assert jsonText~pos('"payload":"00FF7E"') > 0, "BLOB textual representation encoded as JSON string"
call assert jsonText~pos('"shape":"POINT (1 2)"') > 0, "GEOMETRY fallback encoded as JSON string"

say "BULK_ROWS=" || rs~rowCount
say "BULK_DIRECTORIES_SECONDS=" || dirSeconds
say "BULK_JSON_SECONDS=" || jsonSeconds
say "BULK_JSON_BYTES=" || jsonText~length
say "NOSQLSERVER V0.86 BULK RESULT MATERIALISATION: PASS"
exit 0

putTyped: procedure
  use arg vals, raw, types, name, value, typeName
  vals[name] = value
  raw[name] = value
  types[name] = typeName
  return

assert: procedure
  use arg condition, label
  if \condition then do
    say "FAIL" label
    exit 1
  end
  return

::requires "NoSQLServer.cls"
