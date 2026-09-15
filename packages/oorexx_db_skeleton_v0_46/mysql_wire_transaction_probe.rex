parse arg host port databaseName userName executable tableName disabledCaps

if host = "" then do
  say "usage: rexx mysql_wire_transaction_probe.rex host port database user mysql-or-mariadb dedicated_table [disabled-capabilities]"
  say "This probe mutates ONLY the supplied dedicated table."
  exit 64
end

if port = "" then port = 3306
if executable = "" then executable = "mysql"
if tableName = "" then do
  say "MYSQL WIRE TRANSACTION PROBE: dedicated table name required"
  exit 64
end

/* Simple identifier guard: probe must not accept arbitrary SQL in tableName. */
first = tableName~substr(1,1)
if \first~datatype("A") then do
  if first <> "_" then do
    say "MYSQL WIRE TRANSACTION PROBE: invalid table name"
    exit 64
  end
end
do i = 2 to tableName~length
  ch = tableName~substr(i,1)
  if \ch~datatype("A") then do
    if \ch~datatype("N") then do
      if ch <> "_" then do
        say "MYSQL WIRE TRANSACTION PROBE: invalid table name"
        exit 64
      end
    end
  end
end

conn = .DatabaseConnection~new(host, port, databaseName, userName, .nil, "mysql")
engine = .MySQLEngine~new
endpoint = .DatabaseEndpointCapabilities~new(engine~capabilities)

if disabledCaps <> "" then do
  caps = disabledCaps~makeArray(",")
  do cap over caps
    cap = cap~strip~upper
    if cap <> "" then ignore = endpoint~disable(cap)
  end
end

resolver = .DatabaseExecutableResolver~new
ignore = resolver~setOverride("mysql", executable)
db = .Database~new(conn, engine, .DatabaseProcessCommandExecutor~new, resolver, endpoint)

say "MYSQL WIRE TRANSACTION PROBE"
say "table:" tableName

/* The supplied table must already exist with columns:
 * id INTEGER
 * value INTEGER
 *
 * Probe owns row id=900001 only.
 */
cleanup = db~execute("DELETE FROM " || tableName || " WHERE id = 900001")

tx1 = db~transaction
ignore = tx1~execute("INSERT INTO " || tableName || " (id, value) VALUES (900001, 1)")
rs1 = tx1~commit
if rs1~status \= .Error~SUCCESS then do
  say "commit insert failed:" rs1~status rs1~error
  exit 9
end

q1 = db~query("SELECT value FROM " || tableName || " WHERE id = 900001")
if \q1~isA(.DatabaseQueryResult) then exit 9
if q1~rowCount \= 1 then exit 9
if q1~rows[1]~rawAt("value") <> "1" then exit 9

tx2 = db~transaction
ignore = tx2~execute("UPDATE " || tableName || " SET value = 2 WHERE id = 900001")
rs2 = tx2~rollback
if rs2~status \= .Error~NOTEXECUTED then exit 9

q2 = db~query("SELECT value FROM " || tableName || " WHERE id = 900001")
if q2~rows[1]~rawAt("value") <> "1" then do
  say "rollback changed row unexpectedly"
  exit 9
end

tx3 = db~transaction
ignore = tx3~execute("UPDATE " || tableName || " SET value = 3 WHERE id = 900001")
rs3 = tx3~commit
if rs3~status \= .Error~SUCCESS then exit 9

q3 = db~query("SELECT value FROM " || tableName || " WHERE id = 900001")
if q3~rows[1]~rawAt("value") <> "3" then exit 9

cleanup = db~execute("DELETE FROM " || tableName || " WHERE id = 900001")
say "MYSQL WIRE TRANSACTION PROBE: OK"
exit 0

::requires "database_core.cls"
