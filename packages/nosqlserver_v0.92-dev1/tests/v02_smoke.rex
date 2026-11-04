sourceRoot = arg(1)
if sourceRoot = "" then do
  say "usage: v02_smoke.rex DATABASE_ROOT"
  exit 2
end

root = .NoSQLServerTestSupport~createBlankDatabase("v02")

sql = .NoSQLServerSQL~new(.FileDatabaseEngine~new(root))

rs = sql~execute("CREATE TABLE account (account_id INTEGER PRIMARY KEY, email VARCHAR NOT NULL UNIQUE, score DECIMAL, active BOOLEAN, nickname VARCHAR) WITH (SEPARATOR='HEX:FE', NULLTOKEN='(NULL)')")
call assert (rs~status = .Error~SUCCESS), "CREATE TABLE account"

db = sql~engine
t = db~table("account")
call assert (t \== .nil), "created table reopens"
call assert (t~definition~delimiterDefinition~display = "HEX:FE"), "CREATE TABLE persisted FE separator"
call assert (t~definition~nullToken = "(NULL)"), "CREATE TABLE persisted null token"
call assert (t~definition~primaryKey~items = 1), "primary key loaded"
call assert (t~definition~primaryKey[1] = "account_id"), "primary key column"
catalog = db~readCatalog
call assert (catalog["tables"]~items = 1), "catalog contains created table"
call assert (catalog["tables"][1] = "account"), "catalog table name"

rs = sql~execute("INSERT INTO account (account_id,email,score,active,nickname) VALUES (1,'a@example.com',10.5,TRUE,NULL)")
call assert (rs~status = .Error~SUCCESS), "typed INSERT one"
rs = sql~execute("INSERT INTO account (account_id,email,score,active,nickname) VALUES (2,'b@example.com',4.25,FALSE,'Bee')")
call assert (rs~status = .Error~SUCCESS), "typed INSERT two"
rs = sql~execute("INSERT INTO account (account_id,email,score,active,nickname) VALUES (3,'c@example.com',25,TRUE,'See')")
call assert (rs~status = .Error~SUCCESS), "typed INSERT three"

rs = sql~execute("INSERT INTO account (account_id,email) VALUES (1,'duplicate-pk@example.com')")
call assert (rs~status = .Error~NOTEXECUTED), "duplicate primary key rejected"
call assert (rs~error = .Error~CONSTRAINT), "duplicate primary key is constraint failure"

rs = sql~execute("INSERT INTO account (account_id,email) VALUES (4,'a@example.com')")
call assert (rs~status = .Error~NOTEXECUTED), "duplicate unique rejected"

rs = sql~execute("INSERT INTO account (account_id,email) VALUES (5,NULL)")
call assert (rs~status = .Error~NOTEXECUTED), "NOT NULL rejected"

rs = sql~execute("INSERT INTO account (account_id,email) VALUES ('wrong','wrong@example.com')")
call assert (rs~status = .Error~NOTEXECUTED), "INTEGER type validation rejected"

rs = sql~execute("SELECT * FROM account WHERE score >= 10 AND active = TRUE")
call assert (rs~rows~items = 2), "AND + numeric comparison"

rs = sql~execute("SELECT * FROM account WHERE (score < 5 OR score >= 25) AND NOT active = FALSE")
call assert (rs~rows~items = 1), "parentheses OR NOT predicate"
call assert (rs~rows[1]["account_id"] = 3), "predicate returns expected row"

rs = sql~execute("SELECT * FROM account WHERE nickname IS NULL")
call assert (rs~rows~items = 1), "IS NULL predicate"
call assert (rs~rows[1]["account_id"] = 1), "NULL survives storage round trip"

rs = sql~execute("SELECT * FROM account WHERE nickname IS NOT NULL")
call assert (rs~rows~items = 2), "IS NOT NULL predicate"

rs = sql~execute("UPDATE account SET email='collision@example.com' WHERE account_id >= 1")
call assert (rs~status = .Error~NOTEXECUTED), "multi-row UPDATE unique collision rejected"

rs = sql~execute("SELECT * FROM account WHERE email = 'a@example.com'")
call assert (rs~rows~items = 1), "failed update leaves original table intact"

rs = sql~execute("UPDATE account SET score=11.75, active=TRUE WHERE account_id = 2")
call assert (rs~status = .Error~SUCCESS), "typed UPDATE succeeds"
call assert (rs~affectedRows = 1), "typed UPDATE affects one"
rs = sql~execute("SELECT * FROM account WHERE score > 11 AND active = TRUE")
call assert (rs~rows~items = 2), "updated typed values participate in predicate"

rs = sql~execute("CREATE TABLE membership (tenant INTEGER, user_id INTEGER, code VARCHAR, PRIMARY KEY (tenant,user_id), UNIQUE (code)) WITH (SEPARATOR='TAB')")
call assert (rs~status = .Error~SUCCESS), "table-level composite constraints"
rs = sql~execute("INSERT INTO membership (tenant,user_id,code) VALUES (1,10,'A')")
call assert (rs~status = .Error~SUCCESS), "composite-key first insert"
rs = sql~execute("INSERT INTO membership (tenant,user_id,code) VALUES (1,10,'B')")
call assert (rs~status = .Error~NOTEXECUTED), "composite primary key enforced"
rs = sql~execute("INSERT INTO membership (tenant,user_id,code) VALUES (1,11,'A')")
call assert (rs~status = .Error~NOTEXECUTED), "table-level UNIQUE enforced"
call assert (db~table("membership")~definition~delimiterDefinition~display = "TAB"), "TAB separator persisted"

rs = sql~execute("DROP TABLE membership")
call assert (rs~status = .Error~SUCCESS), "DROP TABLE succeeds"
call assert (db~table("membership") == .nil), "DROP TABLE removes table"
catalog = db~readCatalog
call assert (catalog["tables"]~items = 1), "catalog removes dropped table"
call assert (catalog["tables"][1] = "account"), "catalog preserves remaining table"

cleanupResult = .NoSQLServerTestSupport~removeDatabase(root)
say "NOSQLSERVER V0.2 RELATIONAL SMOKE: OK"
exit 0

assert: procedure
  use arg condition, message
  if \condition then do
    say "ASSERT FAILED:" message
    exit 1
  end
return

::requires "../src/NoSQLServer.cls"

::requires "TestSupport.cls"
