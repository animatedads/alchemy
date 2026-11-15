/* Run with a freshly-created temporary BASE directory as the first argument.
 * No default path: never operate on a real user's database by accident.
 */
parse arg base
if base = "" then do
  say "FAIL: pass an isolated temporary root directory"
  exit 2
end

lab = .OodDatabaseLab~new(base)
call check lab~databaseNames = "", "clean start"
call check lab~createDatabase("TestLab"), "create database"
call check lab~databaseNames = "TestLab", "database is listed"
call check lab~name = "TestLab", "current database"
call refuses lab, "CREATEDATABASE", .array~of("TestLab"), "duplicate database rejected"
call refuses lab, "CREATEDATABASE", .array~of("../outside"), "path traversal rejected"

cols = "id" || "09"x || "INTEGER" || "09"x || "0" || "09"x || "1" || "09"x || "0" || "0a"x || ,
       "name" || "09"x || "TEXT" || "09"x || "0" || "09"x || "0" || "09"x || "0"
call check lab~createTable("customers", cols) = "SUCCESS", "create table"
call check lab~tableNames = "customers", "table catalog"
call check lab~schema("customers")~makeArray("0a"x)~items = 2, "schema has two columns"
call check lab~schema("customers")~pos("name" || "09"x || "TEXT") > 0, "schema type"

view = .json~fromJSON(lab~executeJSON("INSERT INTO customers (id,name) VALUES (1,'Ada')"))
call check view["status"] = "SUCCESS", "insert succeeds"
view = .json~fromJSON(lab~executeJSON("SELECT * FROM customers"))
call check view["rowCount"] = 1, "select returns row"
call check view["rows"][1]["name"] = "Ada", "select has typed data"
call refuses lab, "REPLACEEMPTYTABLE", .array~of("customers", cols), "nonempty schema replacement rejected"
view = .json~fromJSON(lab~executeJSON("UPDATE customers SET name='Grace' WHERE id=1"))
call check view["affectedRows"] = 1, "update succeeds"
view = .json~fromJSON(lab~previewJSON("customers"))
call check view["rows"][1]["name"] = "Grace", "preview sees change"

view = .json~fromJSON(lab~executeJSON("DELETE FROM customers WHERE id=1"))
call check view["affectedRows"] = 1, "delete succeeds"
newCols = cols || "0a"x || "active" || "09"x || "BOOLEAN" || "09"x || "1" || "09"x || "0" || "09"x || "0"
call check lab~replaceEmptyTable("customers", newCols) = "SUCCESS", "replace schema of empty table"
call check lab~schema("customers")~makeArray("0a"x)~items = 3, "new column visible"
call refuses lab, "REPLACEEMPTYTABLE", .array~of("customers", "id" || "09"x || "QUANTUM" || "09"x || "1" || "09"x || "0" || "09"x || "0"), "invalid schema change refused before drop"
call check lab~schema("customers")~makeArray("0a"x)~items = 3, "failed edit preserves existing schema"
call refuses lab, "CREATETABLE", .array~of("bad_table", "no-name" || "09"x || "TEXT" || "09"x || "1" || "09"x || "0" || "09"x || "0"), "unsafe column name rejected"
call refuses lab, "CREATETABLE", .array~of("bad_table", "a" || "09"x || "QUANTUM" || "09"x || "1" || "09"x || "0" || "09"x || "0"), "unknown SQL type rejected"
call refuses lab, "PREVIEWJSON", .array~of("../outside"), "preview path traversal rejected"
view = .json~fromJSON(lab~executeJSON("ALTER TABLE customers ADD COLUMN x INTEGER"))
call check view["error"] = "SQLUNSUPPORTED", "unsupported ALTER is explicit"
rows = ""
do i = 1 to 205
  if rows \= "" then rows ||= ","
  rows ||= "(" || i || ",'Person" || i || "',TRUE)"
end
view = .json~fromJSON(lab~executeJSON("INSERT INTO customers (id,name,active) VALUES " || rows))
call check view["status"] = "SUCCESS", "bulk insert for bounded preview"
view = .json~fromJSON(lab~executeJSON("SELECT * FROM customers"))
call check view["rowCount"] = 205 & view["rows"]~items = 200 & view["truncated"] = 1, "JSON preview limits to first 200 rows"
call check lab~dropTable("customers") = "SUCCESS", "drop table"
call check lab~tableNames = "", "empty table catalog"

other = .OodDatabaseLab~new(base)
call check other~openDatabase("TestLab"), "reopen persistent backend"
call check other~tableNames = "", "reopen reads catalog"
call check lab~createDatabase("OtherLab"), "create second database"
call check lab~databaseNames~pos("TestLab") > 0 & lab~databaseNames~pos("OtherLab") > 0, "list multiple databases"
say "OODIALOG DATABASE LAB: 33 checks PASS"
exit 0

check: procedure
  use arg ok, message
  if ok then return
  say "FAIL:" message
  exit 1

refuses: procedure
  use arg receiver, name, args, message
  signal on syntax name expected
  receiver~sendWith(name, args)
  signal off syntax
  say "FAIL:" message
  exit 1
expected:
  signal off syntax
  return

::requires "OodDatabaseLab.cls"
