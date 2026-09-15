parse arg host port databaseName userName executable disabledCaps

if host = "" then do
  say "usage: rexx mysql_wire_live_probe.rex host port database user [mysql-or-mariadb] [disabled-capabilities]"
  say "example:"
  say "  rexx mysql_wire_live_probe.rex 127.0.0.1 3333 nosqlserver '' /usr/bin/mariadb GENERATEDKEYS,TRANSACTIONTIMEOUT"
  exit 64
end

if port = "" then port = 3306
if executable = "" then executable = "mysql"

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

say "MYSQL WIRE LIVE PROBE"
say "host:" host
say "port:" port
say "database:" databaseName
say "executable:" executable

qr = db~query("SELECT 1 AS probe_value")
if \qr~isA(.DatabaseQueryResult) then do
  say "status:" qr~status
  say "error:" qr~error
  say "MYSQL WIRE LIVE PROBE: FAILED"
  exit 9
end

if qr~rowCount < 1 then do
  say "MYSQL WIRE LIVE PROBE: FAILED - no rows"
  exit 9
end

if qr~rows[1]~rawAt("probe_value") <> "1" then do
  say "MYSQL WIRE LIVE PROBE: FAILED - wrong value:" qr~rows[1]~rawAt("probe_value")
  exit 9
end

say "probe_value:" qr~rows[1]~rawAt("probe_value")
say "transactions:" db~supports(.DatabaseCapability~TRANSACTIONS)
say "generated_keys:" db~supports(.DatabaseCapability~GENERATEDKEYS)
say "transaction_timeout:" db~supports(.DatabaseCapability~TRANSACTIONTIMEOUT)
say "MYSQL WIRE LIVE PROBE: OK"
exit 0

::requires "database_core.cls"
