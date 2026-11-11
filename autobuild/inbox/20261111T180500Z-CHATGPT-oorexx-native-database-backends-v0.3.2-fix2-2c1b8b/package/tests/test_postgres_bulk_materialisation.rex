rowsWanted = 1400
lib = .FakeLibpq~new(rowsWanted)
handle = .FakePGresult~new
rs = .PostgreSQLNativeBulkResult~new(lib, handle)
call assert rs~ok, "bulk result ok"
call assert rs~rowCount = rowsWanted, "row count retained without tuple walk"
call assert rs~fieldCount = 12, "field metadata"

call time "R"
rows = rs~asArray
materialiseSeconds = time("E")
call assert rows~items = rowsWanted, "all rows materialised"
call assert handle~closeCount = 1, "native PGresult released after materialisation"
call assert rs~asArray~identityHash = rows~identityHash, "asArray cached zero-copy after first pass"
call assert rows[1]["id"] = "1", "integer lexical value"
call assert rows[1]["big_id"] = "9223372036854775807", "64-bit integer lexical value preserved"
call assert rows[1]["population"] = "1411778724", "10-digit integer preserved"
call assert rows[1]["code"]~isA(.JsonString), "numeric-looking varchar remains JSON string"
call assert rows[1]["code"] = "00123", "varchar bytes preserved"
call assert rows[1]["active"]~makeJSON = "true", "boolean typed for JSON"
call assert rows[2]["nullable"] == .nil, "NULL preserved"

call time "R"
jsonText = .json~toJSON(rows)
jsonSeconds = time("E")
call assert pos('"big_id":9223372036854775807', jsonText) > 0, "64-bit integer emits exact JSON number"
call assert pos('"population":1411778724', jsonText) > 0, "integer emits JSON number"
call assert pos('"code":"00123"', jsonText) > 0, "varchar emits JSON string"
call assert pos('"note":"text-value"', jsonText) > 0, "text emits JSON string"
call assert pos('"created":"2026-10-07"', jsonText) > 0, "date emits JSON string"
call assert pos('"changed":"2026-10-07 17:55:00"', jsonText) > 0, "timestamp emits JSON string"
call assert pos('"blob":"\\x001122"', jsonText) > 0, "bytea emits JSON string"
call assert pos('"payload":{"kind":"row","n":1}', jsonText) > 0, "jsonb remains structured JSON"
call assert pos('"active":true', jsonText) > 0, "boolean emits JSON boolean"
call assert pos('"nullable":null', jsonText) > 0, "NULL emits JSON null"

say "POSTGRESQL BULK MATERIALISATION: PASS"
say "BULK_ROWS=" rows~items
say "BULK_FIELDS=" rs~fieldCount
say "BULK_MATERIALISE_SECONDS=" materialiseSeconds
say "BULK_JSON_SECONDS=" jsonSeconds
say "BULK_JSON_BYTES=" length(jsonText)
exit 0

assert: procedure
  use arg condition, label
  if \condition then do
    say "FAIL" label
    exit 1
  end
  return

::class FakePGresult public
::attribute closeCount
::method init
  self~closeCount = 0
::method close
  self~closeCount += 1

::class FakeLibpq public
::method init
  expose rowCount names oids
  use strict arg rowCount
  names = .Array~of("id","big_id","population","amount","active","code","note","created","changed","blob","payload","nullable")
  oids = .Array~of(23,20,20,1700,16,1043,25,1082,1114,17,3802,1043)
::method field_count
  return 12
::method tuple_count
  expose rowCount
  return rowCount
::method field_name
  expose names
  use arg handle, c
  return names[c+1]
::method field_type
  expose oids
  use arg handle, c
  return oids[c+1]
::method field_is_null
  use arg handle, r, c
  if c=11 & r//2=1 then return 1
  return 0
::method field_value
  use arg handle, r, c
  n = r + 1
  select
    when c=0 then return n
    when c=1 then return "9223372036854775807"
    when c=2 then return "1411778724"
    when c=3 then return "12345.67"
    when c=4 then return "t"
    when c=5 then return "00123"
    when c=6 then return "text-value"
    when c=7 then return "2026-10-07"
    when c=8 then return "2026-10-07 17:55:00"
    when c=9 then return "\x001122"
    when c=10 then return '{"kind":"row","n":' || n || '}'
    when c=11 then return "present-" || n
    otherwise return ""
  end

::requires "PostgreSQLNativeBackend.cls"
