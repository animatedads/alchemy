conn = .DatabaseConnection~new("db.example", 5432, "accounts", "appuser", .nil, "postgresql")
db = .Database~new(conn)
tx = db~transaction

ps = tx~prepareStatement("add_account", "INSERT INTO account(name, balance, note) VALUES (?, ?, ?)")
tx~executePrepared(ps, .array~of("Alice", .DatabaseParameter~new(100, "integer"), .DatabaseParameter~new(.nil, "varchar")))
tx~executePrepared(ps, .array~of("O'Reilly", .DatabaseParameter~new(250.50, "decimal"), "ok"))

cmd = db~engine~compile(tx~prepare)
sql = cmd~stdinText

call assert sql~pos("PREPARE add_account AS INSERT INTO account(name, balance, note) VALUES ($1, $2, $3);") > 0, "postgres prepare"
call assert sql~pos("EXECUTE add_account('Alice', 100, NULL);") > 0, "postgres execute 1"
call assert sql~pos("EXECUTE add_account('O''Reilly', 250.50, 'ok');") > 0, "postgres escaping"
call assert sql~pos("BEGIN;") > 0, "postgres begin"
call assert sql~pos("COMMIT;") > 0, "postgres commit"

conn2 = .DatabaseConnection~new("mysql.example", 3306, "accounts", "appuser", .nil, "mysql")
db2 = .Database~new(conn2)
tx2 = db2~transaction

ps2 = tx2~prepareStatement("add_account", "INSERT INTO account(name, balance, note) VALUES (?, ?, ?)")
tx2~executePrepared(ps2, .array~of("Alice", .DatabaseParameter~new(100, "integer"), .DatabaseParameter~new(.nil, "varchar")))
cmd2 = db2~engine~compile(tx2~prepare)
sql2 = cmd2~stdinText

call assert sql2~pos("PREPARE add_account FROM 'INSERT INTO account(name, balance, note) VALUES (?, ?, ?)';") > 0, "mysql prepare"
call assert sql2~pos("SET @dbp_add_account_1 = 'Alice';") > 0, "mysql set 1"
call assert sql2~pos("SET @dbp_add_account_2 = 100;") > 0, "mysql set 2"
call assert sql2~pos("SET @dbp_add_account_3 = NULL;") > 0, "mysql null"
call assert sql2~pos("EXECUTE add_account USING @dbp_add_account_1, @dbp_add_account_2, @dbp_add_account_3;") > 0, "mysql execute"

say "DATABASE PREPARED SMOKE: OK"
exit 0

assert: procedure
  use arg condition, label
  if \condition then do
    say "ASSERTION FAILED:" label
    exit 9
  end
  return

::requires "database_core.cls"
