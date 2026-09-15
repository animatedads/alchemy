parse arg host port databaseName userName executable disabledCaps

if host = "" then do
  say "usage: rexx mysql_wire_identity_probe.rex host port database user [mysql-or-mariadb] [disabled-capabilities]"
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

id = db~endpointIdentity
say "MYSQL WIRE ENDPOINT IDENTITY"
say "protocol:" id~protocol
say "product:" id~product
say "version:" id~version
say "raw_version:" id~rawVersion
say "MYSQL WIRE IDENTITY PROBE: OK"
exit 0

::requires "database_core.cls"
