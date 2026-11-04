parse arg ignored
root = .NoSQLServerTestSupport~createBlankDatabase("v019_select_expr")
db = .FileDatabaseEngine~new(root)
sql = .NoSQLServerSQL~new(db)
call assertSuccess sql~execute("CREATE TABLE account (id INTEGER PRIMARY KEY, name VARCHAR, score INTEGER)"), "create"
call assertSuccess sql~execute("INSERT INTO account (id,name,score) VALUES (1,'Ada',12),(2,'Bob',8),(3,'cara',NULL)"), "insert"
rs = sql~execute("SELECT id, UPPER(name) AS upper_name, LOWER(name) AS lower_name, SUBSTR(name,1,2) AS prefix, CASE WHEN score > 10 THEN 'high' ELSE 'low' END AS band FROM account ORDER BY id")
call assertSuccess rs, "select expressions"
call assert rs~rows~items = 3, "three rows"
call assert rs~rows[1]["upper_name"] = "ADA", "upper"
call assert rs~rows[2]["lower_name"] = "bob", "lower"
call assert rs~rows[3]["prefix"] = "ca", "substr"
call assert rs~rows[1]["band"] = "high", "searched case true"
call assert rs~rows[2]["band"] = "low", "searched case false"
rs2 = sql~execute("SELECT UPPER(name) FROM account WHERE id = 1")
call assertSuccess rs2, "unaliased function"
call assert rs2~rows[1]["UPPER(name)"] = "ADA", "expression label"
call assert db~version~release \= "", "release is present"
call assert db~version~supports("SELECT_SCALAR_FUNCTIONS"), "function capability"
call assert db~version~supports("SELECT_CASE_EXPRESSIONS"), "case capability"
cleanup = .NoSQLServerTestSupport~removeDatabase(root)
say "NOSQLSERVER V0.19 SELECT EXPRESSION SMOKE: OK"
exit 0
assertSuccess: procedure
  use arg rs, label
  if rs~status \= .Error~SUCCESS then do
    say "ASSERT FAILED:" label rs~status rs~error rs~message
    exit 1
  end
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
