root=.NoSQLServerTestSupport~createBlankDatabase("v040")
sql=.NoSQLServerSQL~new(.FileDatabaseEngine~new(root))

call ok sql~execute("CREATE TABLE customer (customer_id INTEGER PRIMARY KEY, name VARCHAR, email VARCHAR, grp INTEGER)")
call ok sql~execute("INSERT INTO customer VALUES (101,'less silly','me@here.com',1),(102,'two  spaces','two@example.test',1),(103,'three','three@example.test',2)")

lf=x2c("0A")
crlf=x2c("0D0A")
tab=x2c("09")

-- Exact external-client shape that previously failed.
q="SELECT *" || lf || "FROM customer" || lf || "WHERE customer_id = 101"
r=sql~execute(q)
call assert r~status=.Error~SUCCESS, "multiline SELECT/FROM/WHERE"
call assert r~rows~items=1, "one selected row"
call assert r~rows[1]["customer_id"]=101, "selected id"

-- GROUP BY / ORDER BY on separate lines.
q="SELECT grp, COUNT(*) AS n" || crlf || ,
  "FROM customer" || crlf || ,
  "GROUP" || tab || "BY grp" || crlf || ,
  "ORDER" || lf || "BY grp"
r=sql~execute(q)
call assert r~status=.Error~SUCCESS, "multiline GROUP BY / ORDER BY"
call assert r~rows~items=2, "group rows"
call assert r~rows[1]["grp"]=1, "first group"
call assert r~rows[1]["n"]=2, "first count"

-- UPDATE / SET / WHERE split across lines.
u="UPDATE customer" || lf || ,
  "SET name='updated  but  spaced'" || lf || ,
  "WHERE customer_id=101"
r=sql~execute(u)
call assert r~status=.Error~SUCCESS, "multiline UPDATE"
call assert r~affectedRows=1, "update affected"

-- DELETE / FROM / WHERE split across arbitrary SQL whitespace.
d="DELETE" || tab || "FROM customer" || crlf || ,
  "WHERE customer_id=103"
r=sql~execute(d)
call assert r~status=.Error~SUCCESS, "multiline DELETE"
call assert r~affectedRows=1, "delete affected"

-- INSERT retains the v0.39 cases through the central normalizer.
i="INSERT INTO customer" || lf || ,
  "(customer_id,name,email,grp)" || lf || ,
  "VALUES" || lf || ,
  "(104,'insert  spacing','four@example.test',2)"
r=sql~execute(i)
call assert r~status=.Error~SUCCESS, "multiline INSERT"

-- Quoted whitespace is never collapsed.
v=sql~execute("SELECT name FROM customer WHERE customer_id=102")
call assert v~rows[1]["name"]="two  spaces", "existing quoted whitespace preserved"
v=sql~execute("SELECT name FROM customer WHERE customer_id=101")
call assert v~rows[1]["name"]="updated  but  spaced", "UPDATE quoted whitespace preserved"
v=sql~execute("SELECT name FROM customer WHERE customer_id=104")
call assert v~rows[1]["name"]="insert  spacing", "INSERT quoted whitespace preserved"

db=.FileDatabaseEngine~new(root)
call assert db~version~product="NoSQLServer", "version product"
call assert db~version~supports("SQL_FLEXIBLE_WHITESPACE"), "SQL whitespace survives newer release"
call assert db~version~supports("SQL_FLEXIBLE_WHITESPACE"), "SQL whitespace capability"

ignore=.NoSQLServerTestSupport~removeDatabase(root)
say "NOSQLSERVER V0.40 SQL WHITESPACE SMOKE: OK"
exit 0

ok: procedure
  use arg rs
  call assert rs~status=.Error~SUCCESS, "setup"
  return
assert: procedure
  use arg condition,message
  if \condition then do
    say "ASSERT FAILED:" message
    exit 1
  end
  return

::requires "../src/NoSQLServer.cls"
::requires "TestSupport.cls"
