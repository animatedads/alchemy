root = .NoSQLServerTestSupport~createBlankDatabase("v039")
sql = .NoSQLServerSQL~new(.FileDatabaseEngine~new(root))

call ok sql~execute("CREATE TABLE customer (customer_id INTEGER PRIMARY KEY, name VARCHAR, email VARCHAR)")

-- Exact shape exposed by the MariaDB client: newline between the column list
-- and VALUES, and another newline before the tuple.
statement = "INSERT INTO customer" || x2c("0A") || ,
            "    (customer_id, name, email)" || x2c("0A") || ,
            "VALUES" || x2c("0A") || ,
            "    (101, 'silly idea', 'me@here.com')"
r = sql~execute(statement)
call assert r~status = .Error~SUCCESS, "multiline explicit-column INSERT"
call assert r~affectedRows = 1, "multiline affected row"

-- Standard positional form: values map to TableDefinition declared order.
r = sql~execute("INSERT INTO customer VALUES (102,'positional','p@example.test')")
call assert r~status = .Error~SUCCESS, "positional INSERT"
call assert r~affectedRows = 1, "positional affected row"

-- Tabs/CRLF are grammar whitespace too, but whitespace inside values is data.
statement = "INSERT INTO" || x2c("09") || "customer" || x2c("0D0A") || ,
            "(customer_id,name,email)" || x2c("09") || "VALUES" || x2c("0D0A") || ,
            "(103,'two  spaces','tab@example.test')"
r = sql~execute(statement)
call assert r~status = .Error~SUCCESS, "tab/CRLF INSERT"

-- Multi-row positional form.
r = sql~execute("INSERT INTO customer VALUES (104,'four','4@example.test')," || x2c("0A") || ,
                "(105,'five','5@example.test')")
call assert r~status = .Error~SUCCESS, "multi-row positional INSERT"
call assert r~affectedRows = 2, "multi-row positional affected rows"

q = sql~execute("SELECT customer_id,name,email FROM customer ORDER BY customer_id")
call assert q~status = .Error~SUCCESS, "verification SELECT"
call assert q~rows~items = 5, "five persisted rows"
call assert q~rows[1]["customer_id"] = 101, "first id"
call assert q~rows[1]["name"] = "silly idea", "first name"
call assert q~rows[1]["email"] = "me@here.com", "first email"
call assert q~rows[2]["customer_id"] = 102, "positional id"
call assert q~rows[3]["name"] = "two  spaces", "quoted whitespace preserved"
call assert q~rows[5]["customer_id"] = 105, "multi-row final id"

-- Parentheses remain mandatory around each VALUES tuple.
bad = sql~execute("INSERT INTO customer VALUES 106,'bad','bad@example.test'")
call assert bad~status \= .Error~SUCCESS, "unparenthesized VALUES rejected"

db = .FileDatabaseEngine~new(root)
call assert db~version~product = "NoSQLServer", "version product"
call assert db~version~supports("INSERT_POSITIONAL_VALUES"), "positional INSERT survives newer release"
call assert db~version~supports("INSERT_POSITIONAL_VALUES"), "positional capability"
call assert db~version~supports("INSERT_FLEXIBLE_WHITESPACE"), "whitespace capability"

ignore = .NoSQLServerTestSupport~removeDatabase(root)
say "NOSQLSERVER V0.39 INSERT GRAMMAR SMOKE: OK"
exit 0

ok: procedure
  use arg rs
  call assert rs~status = .Error~SUCCESS, "setup"
  return

assert: procedure
  use arg condition, message
  if \condition then do
    say "ASSERT FAILED:" message
    exit 1
  end
  return

::requires "../src/NoSQLServer.cls"
::requires "TestSupport.cls"
