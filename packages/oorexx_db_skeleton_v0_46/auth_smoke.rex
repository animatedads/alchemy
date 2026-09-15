cred = .DatabaseCredential~new("password", "secret-value")
conn = .DatabaseConnection~new("db.example", 5432, "accounts", "appuser", cred, "postgresql")
resolver = .DatabaseExecutableResolver~new
resolver~setOverride("postgresql", "/opt/db/bin/psql")
db = .Database~new(conn, .nil, .nil, resolver)
tx = db~transaction
tx~execute("SELECT 1")
cmd = db~engine~compile(tx~prepare)
call assert cmd~status = .Error~SUCCESS, "command status"
call assert cmd~executable = "/opt/db/bin/psql", "resolver override"
call assert cmd~environment~has("PGPASSWORD"), "postgres password env"
call assert cmd~environment~at("PGPASSWORD") = "secret-value", "postgres env value"
do i = 1 to cmd~arguments~items
  call assert cmd~arguments[i] <> "secret-value", "password absent from argv"
end
call assert cred~masked = "***", "masked credential"

cred2 = .DatabaseCredential~new("password", "mysql-secret")
conn2 = .DatabaseConnection~new("db.example", 3306, "accounts", "appuser", cred2, "mysql")
db2 = .Database~new(conn2)
tx2 = db2~transaction
tx2~execute("SELECT 1")
cmd2 = db2~engine~compile(tx2~prepare)
call assert cmd2~environment~has("MYSQL_PWD"), "mysql password env"
call assert cmd2~environment~at("MYSQL_PWD") = "mysql-secret", "mysql env value"

say "DATABASE AUTH SMOKE: OK"
exit 0

assert: procedure
  use arg condition, label
  if \condition then do
    say "ASSERTION FAILED:" label
    exit 9
  end
  return

::requires "database_core.cls"
