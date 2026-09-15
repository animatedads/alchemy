/* Large DML atomicity integration probe.
 *
 * Accepts a DML-only SQL corpus. Schema setup is intentionally outside the
 * measured transaction so PostgreSQL and MySQL/MariaDB are compared on DML
 * transaction semantics, not their different DDL commit behavior.
 */
parse arg engineName corpusPath

if engineName = "" then do
  say "usage: large_dml_atomicity_probe.rex postgres|mysql data_only.sql"
  exit 64
end
if corpusPath = "" then do
  say "usage: large_dml_atomicity_probe.rex postgres|mysql data_only.sql"
  exit 64
end

corpus = readAll(corpusPath)
if corpus == .nil then do
  say "ATOMICITY PROBE: corpus unreadable:" corpusPath
  exit 66
end

executor = .DatabaseProcessCommandExecutor~new
resolver = .DatabaseExecutableResolver~new

select
  when engineName~lower = "postgres" then do
    host = envDefault("DB_PG_HOST", "localhost")
    port = envDefault("DB_PG_PORT", 5432)
    databaseName = envDefault("DB_PG_DATABASE", "postgres")
    userName = envDefault("DB_PG_USER", "")
    clientPath = envDefault("DB_PG_PSQL", "psql")
    resolver~setOverride("postgresql", clientPath)
    conn = .DatabaseConnection~new(host, port, databaseName, userName, .nil, "postgresql")
  end
  when engineName~lower = "mysql" then do
    host = envDefault("DB_MY_HOST", "localhost")
    port = envDefault("DB_MY_PORT", 3306)
    databaseName = envDefault("DB_MY_DATABASE", "mysql")
    userName = envDefault("DB_MY_USER", "")
    clientPath = envDefault("DB_MY_CLIENT", "mysql")
    resolver~setOverride("mysql", clientPath)
    conn = .DatabaseConnection~new(host, port, databaseName, userName, .nil, "mysql")
  end
  otherwise do
    say "ATOMICITY PROBE: unsupported engine" engineName
    exit 64
  end
end

db = .Database~new(conn, .nil, executor, resolver)

preflight = db~transaction
preflight~execute("SELECT 1")
preflightResult = preflight~commit
if preflightResult~status \= .Error~SUCCESS then do
  say "ATOMICITY PROBE: PRECONDITION BLOCKED"
  say "status:" preflightResult~status
  say "error:" preflightResult~error
  exit 20
end

tx = db~transaction
tx~execute(corpus)
tx~execute("SELEC deliberately_invalid_atomicity_tail")
rs = tx~commit

say "ATOMICITY PROBE STATUS:" rs~status
say "ATOMICITY PROBE ERROR:" rs~error
if rs~error \= .Error~SYNTAXERROR then do
  say "ATOMICITY PROBE: unexpected failure classification"
  if rs~commandResult \== .nil then say rs~commandResult~stderr
  exit 30
end

say "ATOMICITY PROBE: FAILURE INJECTED; VERIFY BASELINE UNCHANGED"
exit 0

readAll: procedure
  use arg path
  stream = .stream~new(path)
  if stream~open("read") \= "READY:" then return .nil
  text = stream~charin(, stream~chars)
  stream~close
  return text

envDefault: procedure
  use arg name, defaultValue
  v = value(name, , "ENVIRONMENT")
  if v = "" then return defaultValue
  return v

::requires "database_core.cls"
