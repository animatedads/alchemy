rowsWanted = 1400
lib = .FakeMariaLibrary~new(rowsWanted)
handle = .FakeMariaResult~new
rs = .MySQLNativeBulkResult~new(lib, handle)
call assert rs~ok, "bulk result ok"
call assert rs~rowCount = rowsWanted, "row count retained without fetch loop"
call assert rs~fieldCount = 12, "field metadata"

call time "R"
rows = rs~asArray
materialiseSeconds = time("E")
call assert rows~items = rowsWanted, "all rows materialised"
call assert handle~closeCount = 1, "native MYSQL_RES released after materialisation"
call assert rs~asArray~identityHash = rows~identityHash, "asArray cached zero-copy after first pass"
call assert lib~rewindCount = 1, "single producer traversal"
call assert lib~nextCount = rowsWanted, "one mysql_fetch_row-equivalent per row"
call assert rows[1]["id"] = "1", "integer lexical value"
call assert rows[1]["big_id"] = "9223372036854775807", "signed 64-bit integer preserved"
call assert rows[1]["unsigned_id"] = "18446744073709551615", "unsigned 64-bit integer lexical value preserved"
call assert rows[1]["population"] = "1411778724", "10-digit integer preserved"
call assert rows[1]["code"]~isA(.JsonString), "numeric-looking varchar remains JSON string"
call assert rows[1]["code"] = "00123", "varchar bytes preserved"
call assert rows[1]["active"]~makeJSON = "true", "boolean typed for JSON"
call assert rows[2]["nullable"] == .nil, "NULL preserved"

call time "R"
jsonText = .json~toJSON(rows)
jsonSeconds = time("E")
call assert pos('"big_id":9223372036854775807', jsonText) > 0, "signed 64-bit integer emits exact JSON number"
call assert pos('"unsigned_id":18446744073709551615', jsonText) > 0, "unsigned 64-bit integer emits exact JSON number"
call assert pos('"population":1411778724', jsonText) > 0, "integer emits JSON number"
call assert pos('"amount":12345.67', jsonText) > 0, "decimal emits JSON number"
call assert pos('"code":"00123"', jsonText) > 0, "varchar emits JSON string"
call assert pos('"changed":"2026-10-07 17:55:00"', jsonText) > 0, "datetime emits JSON string"
call assert pos('"blob":"\\x001122"', jsonText) > 0, "blob uses exact hexadecimal string representation"
call assert pos('"payload":{"kind":"row","n":1}', jsonText) > 0, "json remains structured JSON"
call assert pos('"active":true', jsonText) > 0, "boolean emits JSON boolean"
call assert pos('"nullable":null', jsonText) > 0, "NULL emits JSON null"

say "MYSQL/MARIADB BULK MATERIALISATION: PASS"
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

::class FakeMariaResult public
::attribute closeCount
::method init
  self~closeCount = 0
::method close
  self~closeCount += 1

::class FakeMariaLibrary public
::method init
  expose rowCount names types current rewindCount nextCount
  use strict arg rowCount
  names = .Array~of("id","big_id","unsigned_id","population","amount","active","code","changed","blob","payload","note","nullable")
  types = .Array~of("INTEGER","INTEGER","INTEGER","INTEGER","DECIMAL","BOOLEAN","VARCHAR","DATETIME","BLOB","JSON","VARCHAR","VARCHAR")
  current = 0; rewindCount=0; nextCount=0
::attribute rewindCount get
::attribute nextCount get
::method result_field_count
  return 12
::method result_row_count
  expose rowCount
  return rowCount
::method result_field_name
  expose names
  use arg handle, c
  return names[c+1]
::method result_field_native_type
  use arg handle, c
  return c + 1
::method result_field_flags
  return 0
::method result_field_common_type
  expose types
  use arg handle, c
  return types[c+1]
::method result_rewind
  expose current rewindCount
  current=0; rewindCount += 1
  return 1
::method result_next
  expose current rowCount nextCount
  if current >= rowCount then return 0
  current += 1; nextCount += 1
  return 1
::method result_current_is_null
  expose current
  use arg handle, c
  if c=11 & current//2=0 then return 1
  return 0
::method result_current_value
  expose current
  use arg handle, c
  n=current
  select
    when c=0 then return n
    when c=1 then return "9223372036854775807"
    when c=2 then return "18446744073709551615"
    when c=3 then return "1411778724"
    when c=4 then return "12345.67"
    when c=5 then return "1"
    when c=6 then return "00123"
    when c=7 then return "2026-10-07 17:55:00"
    when c=8 then return "\x001122"
    when c=9 then return '{"kind":"row","n":' || n || '}'
    when c=10 then return "text-value"
    when c=11 then return "present-" || n
    otherwise return ""
  end

::requires "MySQLNativeBackend.cls"
