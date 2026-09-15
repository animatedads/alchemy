parse arg ignored
root = .NoSQLServerTestSupport~createBlankDatabase("sql92_company")
engine = .FileDatabaseEngine~new(root)
sql = .NoSQLServerSQL~new(engine)

-- DDL
call ok sql~execute("CREATE TABLE departments (dept_id INTEGER PRIMARY KEY, dept_name VARCHAR UNIQUE, location VARCHAR)"), "departments DDL"
call ok sql~execute("CREATE TABLE employees (emp_id INTEGER PRIMARY KEY, dept_id INTEGER, first_name VARCHAR, last_name VARCHAR, salary DECIMAL, hire_date DATE, is_active BOOLEAN)"), "employees DDL"
call ok sql~execute("CREATE TABLE projects (project_id INTEGER PRIMARY KEY, emp_id INTEGER, project_name VARCHAR, budget DECIMAL)"), "projects DDL"

-- DML load
call ok sql~execute("INSERT INTO departments (dept_id, dept_name, location) VALUES (1,'Engineering','London'),(2,'Sales','New York'),(3,'Marketing','Paris')"), "departments load"
call ok sql~execute("INSERT INTO employees (emp_id, dept_id, first_name, last_name, salary, hire_date, is_active) VALUES (101,1,'Alice','Smith',75000.00,'2023-01-15',TRUE),(102,1,'Bob','Jones',68000.50,'2023-03-22',TRUE),(103,2,'Charlie','Brown',55000.00,'2022-11-01',FALSE),(104,NULL,'Diana','Prince',90000.00,'2024-01-10',TRUE)"), "employees load"
call ok sql~execute("INSERT INTO projects (project_id, emp_id, project_name, budget) VALUES (1001,101,'Alpha Rewrite',150000.00),(1002,102,'Beta Maintenance',50000.00),(1003,NULL,'Gamma Launch',200000.00)"), "projects load"

-- A: predicates LIKE BETWEEN
rs = sql~execute("SELECT first_name, last_name, salary FROM employees WHERE is_active = TRUE AND (salary BETWEEN 60000.00 AND 100000.00) AND last_name LIKE 'S%'")
call ok rs, "A"
call assert rs~rows~items = 1, "A one row"
call assert rs~rows[1]["first_name"] = "Alice", "A Alice"

-- B: explicit multi inner join chain
rs = sql~execute("SELECT d.dept_name, e.first_name, p.project_name, p.budget FROM employees e JOIN departments d ON e.dept_id = d.dept_id JOIN projects p ON e.emp_id = p.emp_id WHERE p.budget > 100000.00")
call ok rs, "B"
call assert rs~rows~items = 1, "B one row"
call assert rs~rows[1]["e.first_name"] = "Alice", "B Alice"
call assert rs~rows[1]["p.project_name"] = "Alpha Rewrite", "B project"

-- C: LEFT JOIN / IS NULL
rs = sql~execute("SELECT e.first_name, e.last_name, d.dept_name FROM employees e LEFT JOIN departments d ON e.dept_id = d.dept_id WHERE d.dept_id IS NULL")
call ok rs, "C"
call assert rs~rows~items = 1, "C one orphan"
call assert rs~rows[1]["e.first_name"] = "Diana", "C Diana"
call assert rs~rows[1]["d.dept_name"] == .nil, "C NULL extension"

-- D: aggregate join + GROUP BY
rs = sql~execute("SELECT d.dept_name, COUNT(*), SUM(e.salary), AVG(e.salary), MAX(e.salary) FROM employees e JOIN departments d ON e.dept_id = d.dept_id GROUP BY d.dept_name")
call ok rs, "D"
call assert rs~rows~items = 2, "D two populated departments"
foundEngineering = .false
foundSales = .false
do row over rs~rows
  if row["d.dept_name"] = "Engineering" then do
    foundEngineering = .true
    call assert row["COUNT(*)"] = 2, "D engineering count"
    call assert row["SUM(e.salary)"] = 143000.5, "D engineering sum"
  end
  if row["d.dept_name"] = "Sales" then do
    foundSales = .true
    call assert row["COUNT(*)"] = 1, "D sales count"
    call assert row["MAX(e.salary)"] = 55000, "D sales max"
  end
end
call assert foundEngineering & foundSales, "D expected groups"

-- E: IN subquery
rs = sql~execute("SELECT first_name, last_name FROM employees WHERE emp_id IN (SELECT emp_id FROM projects)")
call ok rs, "E"
call assert rs~rows~items = 2, "E two assigned employees"

-- F: CASE, concat, expression ORDER BY
rs = sql~execute("SELECT e.first_name || ' ' || e.last_name AS full_name, CASE e.is_active WHEN TRUE THEN 'Active Employee' ELSE 'Former Employee' END AS status_label FROM employees e ORDER BY CASE e.is_active WHEN TRUE THEN 1 ELSE 2 END, e.last_name DESC")
call ok rs, "F"
call assert rs~rows~items = 4, "F four employees"
call assert rs~rows[1]["status_label"] = "Active Employee", "F active first"
call assert rs~rows[4]["status_label"] = "Former Employee", "F former last"
call assert rs~rows[1]["full_name"] = "Alice Smith", "F concat/order"

-- G: UNION + global ORDER BY alias
rs = sql~execute("SELECT dept_name AS entity_name FROM departments UNION SELECT project_name AS entity_name FROM projects ORDER BY entity_name ASC")
call ok rs, "G"
call assert rs~rows~items = 6, "G six unique entities"
call assert rs~rows[1]["entity_name"] = "Alpha Rewrite", "G ordered first"

-- H: scalar functions in SELECT list
rs = sql~execute("SELECT UPPER(first_name), LOWER(last_name), SUBSTR(hire_date, 1, 4) AS hire_year FROM employees WHERE is_active = TRUE")
call ok rs, "H"
call assert rs~rows~items = 3, "H active employees"
call assert rs~rows[1]["UPPER(first_name)"] \= .nil, "H upper projected"
call assert rs~rows[1]["hire_year"]~length = 4, "H year"

-- UPDATE / DELETE
rs = sql~execute("UPDATE employees SET salary = 60000.00 WHERE is_active = FALSE AND salary < 60000.00")
call ok rs, "UPDATE"
call assert rs~affectedRows = 1, "one employee updated"
rs = sql~execute("SELECT salary FROM employees WHERE emp_id = 103")
call ok rs, "UPDATE verify"
call assert rs~rows[1]["salary"] = 60000, "updated salary"

rs = sql~execute("DELETE FROM projects WHERE budget < 60000.00")
call ok rs, "DELETE"
call assert rs~affectedRows = 1, "one project deleted"
rs = sql~execute("SELECT * FROM projects")
call ok rs, "DELETE verify"
call assert rs~rows~items = 2, "two projects remain"

v = engine~version
call assert v~product = "NoSQLServer", "version product"
cleanup = .NoSQLServerTestSupport~removeDatabase(root)
say "NOSQLSERVER SQL-92 COMPANY SMOKE: OK"
exit 0

ok: procedure
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
