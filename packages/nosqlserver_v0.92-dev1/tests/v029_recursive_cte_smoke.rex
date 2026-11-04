root = .NoSQLServerTestSupport~createBlankDatabase("v029cte")
engine = .FileDatabaseEngine~new(root)
sql = .NoSQLServerSQL~new(engine)

call assertSuccess sql~execute("CREATE TABLE emp (emp_id INTEGER PRIMARY KEY, full_name VARCHAR NOT NULL, manager_id INTEGER);")
call assertSuccess sql~execute("INSERT INTO emp (emp_id,full_name,manager_id) VALUES (1,'Root',NULL),(2,'Child A',1),(3,'Child B',1),(4,'Grandchild',2);")
q = "WITH RECURSIVE chain AS ( SELECT emp_id, full_name, manager_id, 1 AS depth FROM emp WHERE manager_id IS NULL UNION ALL SELECT e.emp_id, e.full_name, e.manager_id, c.depth + 1 FROM emp e JOIN chain c ON e.manager_id = c.emp_id ) SELECT * FROM chain ORDER BY depth, emp_id;"
rs = sql~execute(q)
call assertSuccess rs
call assertEqual 4, rs~rows~items, "recursive row count"
call assertEqual "RECURSIVE_CTE_ITERATION", rs~accessPath, "recursive access path"
call assertEqual 1, rs~rows[1]["emp_id"], "root id"
call assertEqual 1, rs~rows[1]["depth"], "root depth"
call assertEqual 2, rs~rows[2]["depth"], "child depth"
call assertEqual 3, rs~rows[4]["depth"], "grandchild depth"
call assertTrue engine~version~supports("RECURSIVE_CTE"), "recursive CTE capability"

call assertSuccess sql~execute("CREATE TABLE cycle_node (node_id INTEGER PRIMARY KEY, parent_id INTEGER);")
call assertSuccess sql~execute("INSERT INTO cycle_node (node_id,parent_id) VALUES (1,2),(2,1);")
cycle = "WITH RECURSIVE chain AS ( SELECT node_id, parent_id, 1 AS depth FROM cycle_node WHERE node_id = 1 UNION ALL SELECT n.node_id, n.parent_id, c.depth + 1 FROM cycle_node n JOIN chain c ON n.parent_id = c.node_id ) SELECT * FROM chain ORDER BY depth, node_id;"
cr = sql~execute(cycle)
call assertTrue cr~status \= .Error~SUCCESS, "cycle must fail"
call assertTrue cr~message~pos("possible cycle") > 0, "cycle diagnostic"

cleanup = .NoSQLServerTestSupport~removeDatabase(root)
say "NOSQLSERVER V0.29 RECURSIVE CTE SMOKE: OK"
exit 0

assertSuccess: procedure
  use arg rs
  if rs~status \= .Error~SUCCESS then do
    say "ASSERT FAILED: expected success:" rs~error rs~message
    exit 1
  end
  return

assertEqual: procedure
  use arg expected, actual, label
  if expected \= actual then do
    say "ASSERT FAILED:" label "expected=" expected "actual=" actual
    exit 1
  end
  return

assertTrue: procedure
  use arg conditionValue, label
  if \conditionValue then do
    say "ASSERT FAILED:" label
    exit 1
  end
  return

::requires "../src/NoSQLServer.cls"
::requires "TestSupport.cls"
