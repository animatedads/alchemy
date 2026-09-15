/* Requires reachable MySQL/MariaDB server and suitable authentication. */
host = value("DB_MY_HOST", , "ENVIRONMENT")
if host = "" then host = "localhost"
port = value("DB_MY_PORT", , "ENVIRONMENT")
if port = "" then port = 3306
databaseName = value("DB_MY_DATABASE", , "ENVIRONMENT")
if databaseName = "" then databaseName = "mysql"
userName = value("DB_MY_USER", , "ENVIRONMENT")
clientPath = value("DB_MY_CLIENT", , "ENVIRONMENT")
if clientPath = "" then clientPath = "mysql"

executor = .DatabaseProcessCommandExecutor~new
resolver = .DatabaseExecutableResolver~new
resolver~setOverride("mysql", clientPath)
conn = .DatabaseConnection~new(host, port, databaseName, userName, .nil, "mysql")
db = .Database~new(conn, .nil, executor, resolver)

preflight = db~transaction
preflight~execute("SELECT 1")
preflightResult = preflight~commit
if preflightResult~status \= .Error~SUCCESS then do
  say "MYSQL ERROR PROBE: PRECONDITION BLOCKED"
  say "status:" preflightResult~status
  say "error:" preflightResult~error
  if preflightResult~commandResult \== .nil then do
    if preflightResult~commandResult~stderr <> "" then say "stderr:" preflightResult~commandResult~stderr
  end
  exit 20
end

call runCase db, "SELEC 1", .Error~SYNTAXERROR, "syntax"

setup = db~transaction
setup~execute("DROP TABLE IF EXISTS oorexx_error_probe")
setup~execute("CREATE TABLE oorexx_error_probe (id INTEGER PRIMARY KEY)")
setupResult = setup~commit
if setupResult~status \= .Error~SUCCESS then do
  say "MYSQL ERROR PROBE: SETUP FAILED" setupResult~error
  exit 21
end

call runCase db, "INSERT INTO oorexx_error_probe(id) VALUES (1); INSERT INTO oorexx_error_probe(id) VALUES (1)", .Error~DUPLICATEKEY, "duplicate"

cleanup = db~transaction
cleanup~execute("DROP TABLE IF EXISTS oorexx_error_probe")
cleanupResult = cleanup~commit
if cleanupResult~status \= .Error~SUCCESS then exit 22

say "MYSQL ERROR PROBE: OK"
exit 0

runCase: procedure
  use arg db, sql, expectedError, label
  tx = db~transaction
  tx~execute(sql)
  rs = tx~commit
  say label":" rs~status rs~error
  if rs~error \= expectedError then do
    say "EXPECTED:" expectedError
    if rs~commandResult \== .nil then say "STDERR:" rs~commandResult~stderr
    exit 30
  end
  return

::requires "database_core.cls"
