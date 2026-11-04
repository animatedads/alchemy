root = .NoSQLServerTestSupport~createBlankDatabase("v09")
engine = .FileDatabaseEngine~new(root)
sql = .NoSQLServerSQL~new(engine)

call assertSuccess sql~execute("CREATE TABLE employees (employee_id INTEGER PRIMARY KEY, full_name VARCHAR(100) NOT NULL, hire_date DATE NOT NULL, manager_id INTEGER NULL, department VARCHAR(50) NOT NULL);"), "create employees"
call assertSuccess sql~execute("INSERT INTO employees (employee_id,full_name,hire_date,manager_id,department) VALUES (1,'Director','2020-01-01',NULL,'IT'), (2,'Manager','2021-01-01',1,'IT'), (3,'Worker','2022-01-01',2,'IT'), (4,'Solo','2023-01-01',NULL,'HR');"), "insert employees"

q = "SELECT e1.full_name AS employee, e2.full_name AS manager, e3.full_name AS director FROM employees e1 LEFT JOIN employees e2 ON e2.employee_id = e1.manager_id LEFT JOIN employees e3 ON e3.employee_id = e2.manager_id ORDER BY director, manager, employee;"
rs = sql~execute(q)
call assertSuccess rs, "self left join"
call assertEq rs~accessPath, "LEFT_HASH_CHAIN", "access path"
call assertEq rs~rows~items, 4, "row count preserves unmatched"

seen = .table~new
do row over rs~rows
  name = row["employee"]
  seen[name] = row
end
call assertTrue seen["Worker"] \== .nil, "worker row"
call assertEq seen["Worker"]["manager"], "Manager", "worker manager"
call assertEq seen["Worker"]["director"], "Director", "worker director"
call assertTrue seen["Manager"]["manager"] = "Director", "manager manager"
call assertTrue seen["Manager"]["director"] == .nil, "manager director null"
call assertTrue seen["Director"]["manager"] == .nil, "director manager null"
call assertTrue seen["Solo"]["manager"] == .nil, "solo manager null"

cleanupResult = .NoSQLServerTestSupport~removeDatabase(root)
say "NOSQLSERVER V0.9 LEFT JOIN SELF-JOIN SMOKE: OK"
exit 0

assertSuccess: procedure
  use arg rs, label
  if rs~status \= .Error~SUCCESS then do
    say "ASSERT FAILED:" label "status=" rs~status "error=" rs~error "message=" rs~message
    exit 1
  end
  return

assertEq: procedure
  use arg actual, expected, label
  if actual \= expected then do
    say "ASSERT FAILED:" label "expected=" expected "actual=" actual
    exit 1
  end
  return

assertTrue: procedure
  use arg condition, label
  if \condition then do
    say "ASSERT FAILED:" label
    exit 1
  end
  return

::requires "../src/NoSQLServer.cls"
::requires "TestSupport.cls"
