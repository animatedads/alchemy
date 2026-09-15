/* PostgreSQL integration probe.
 * Optional environment variables:
 *   DB_PG_HOST, DB_PG_PORT, DB_PG_DATABASE, DB_PG_USER, DB_PG_PSQL
 */
host = value("DB_PG_HOST", , "ENVIRONMENT")
if host = "" then host = "localhost"
port = value("DB_PG_PORT", , "ENVIRONMENT")
if port = "" then port = 5432
databaseName = value("DB_PG_DATABASE", , "ENVIRONMENT")
if databaseName = "" then databaseName = "postgres"
userName = value("DB_PG_USER", , "ENVIRONMENT")
psqlPath = value("DB_PG_PSQL", , "ENVIRONMENT")
if psqlPath = "" then psqlPath = "psql"

executor = .DatabaseProcessCommandExecutor~new
resolver = .DatabaseExecutableResolver~new
resolver~setOverride("postgresql", psqlPath)

conn = .DatabaseConnection~new(host, port, databaseName, userName, .nil, "postgresql")
db = .Database~new(conn, .nil, executor, resolver)

tx = db~transaction
tx~execute("DROP TABLE IF EXISTS oorexx_db_probe")
tx~execute("CREATE TABLE oorexx_db_probe (id INTEGER PRIMARY KEY, name VARCHAR(100))")

insertStatement = tx~prepareStatement("probe_insert", -
  "INSERT INTO oorexx_db_probe(id, name) VALUES (?, ?)")
tx~executePrepared(insertStatement, .array~of( -
  .DatabaseParameter~new(1, "integer"), "alpha"))
tx~executePrepared(insertStatement, .array~of( -
  .DatabaseParameter~new(2, "integer"), "O'Reilly"))

tx~execute("UPDATE oorexx_db_probe SET name = 'beta' WHERE id = 1")
tx~execute("DELETE FROM oorexx_db_probe WHERE id = 2")
rs = tx~commit

call reportResult rs

if rs~status = .Error~NOTEXECUTED then do
  say "POSTGRES LIVE PROBE: NOT EXECUTED"
  exit 20
end
if rs~status \= .Error~SUCCESS then do
  say "POSTGRES LIVE PROBE: FAILED"
  exit 21
end

verify = db~transaction
verify~execute("SELECT CASE WHEN COUNT(*) = 1 AND MIN(name) = 'beta' THEN 1 ELSE 0 END FROM oorexx_db_probe")
verifyResult = verify~commit
call reportResult verifyResult
if verifyResult~status \= .Error~SUCCESS then exit 22
if verifyResult~commandResult~stdout~pos("1") = 0 then do
  say "POSTGRES LIVE PROBE: VERIFICATION FAILED"
  exit 23
end

cleanup = db~transaction
cleanup~execute("DROP TABLE oorexx_db_probe")
cleanupResult = cleanup~commit
if cleanupResult~status \= .Error~SUCCESS then exit 24

say "POSTGRES LIVE PROBE: OK"
exit 0

reportResult: procedure
  use arg databaseResult
  say "status:" databaseResult~status
  say "error:" databaseResult~error
  if databaseResult~commandResult \== .nil then do
    say "rc:" databaseResult~commandResult~rc
    if databaseResult~commandResult~stdout <> "" then say "stdout:" databaseResult~commandResult~stdout
    if databaseResult~commandResult~stderr <> "" then say "stderr:" databaseResult~commandResult~stderr
  end
  return

::requires "database_core.cls"
