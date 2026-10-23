/*--------------------------------------------------------------------
  NoSQLServer progressive SQL feature torture
  Starts easy, climbs through supported surfaces, then deliberately
  probes the current breaking points (unsupported / parse surfaces).

  Run from the tests/ directory:

      rexx sql_feature_torture.rex
--------------------------------------------------------------------*/

root = .NoSQLServerTestSupport~createBlankDatabase("feature_torture")
engine = .FileDatabaseEngine~new(root)
sql = .NoSQLServerSQL~new(engine)

total = 0
passed = 0
failed = 0
unsupported = 0
parseErrors = 0
executionErrors = 0
lastRs = .nil

say "╔══════════════════════════════════════════════════════════════╗"
say "║  NoSQLServer SQL Feature Torture – progressive climb         ║"
say "╚══════════════════════════════════════════════════════════════╝"
say

/*====================================================================
  LEVEL 0 – Foundation (DDL + DML + basic predicates)
====================================================================*/
call section "LEVEL 0 – Foundation (DDL / DML / predicates)"

call run sql, ,
  "CREATE TABLE account (" || ,
  "  account_id INTEGER PRIMARY KEY," || ,
  "  email      VARCHAR(120) NOT NULL UNIQUE," || ,
  "  score      DECIMAL," || ,
  "  active     BOOLEAN," || ,
  "  nickname   VARCHAR" || ,
  ") WITH (SEPARATOR='HEX:FE', NULLTOKEN='(NULL)')", ,
  "CREATE TABLE with typed columns, PK, UNIQUE, storage options"

call run sql, ,
  "INSERT INTO account (account_id,email,score,active,nickname)" || ,
  " VALUES (1,'ada@example.com',10.5,TRUE,NULL)", ,
  "single-row typed INSERT (NULL nickname)"

call run sql, ,
  "INSERT INTO account (account_id,email,score,active,nickname) VALUES" || ,
  " (2,'grace@example.com',4.25,FALSE,'Bee')," || ,
  " (3,'linus@example.com',25,TRUE,'See')", ,
  "multi-row INSERT"

call expectConstraint sql, ,
  "INSERT INTO account (account_id,email) VALUES (1,'dup-pk@example.com')", ,
  "duplicate PRIMARY KEY rejected"

call expectConstraint sql, ,
  "INSERT INTO account (account_id,email) VALUES (4,'ada@example.com')", ,
  "duplicate UNIQUE rejected"

call expectConstraint sql, ,
  "INSERT INTO account (account_id,email) VALUES (5,NULL)", ,
  "NOT NULL rejected"

call expectAnyFailure sql, ,
  "INSERT INTO account (account_id,email) VALUES ('bad','x@example.com')", ,
  "INTEGER type coercion rejection"

rs = sql~execute("SELECT * FROM account WHERE score >= 10 AND active = TRUE")
call expectRowCount rs, 2, "WHERE with comparison + boolean AND"

rs = sql~execute("SELECT * FROM account WHERE nickname IS NULL")
call expectRowCount rs, 1, "IS NULL predicate"
call expectValue rs, 1, "account_id", 1, "NULL survived storage round-trip"

rs = sql~execute("SELECT * FROM account WHERE nickname IS NOT NULL")
call expectRowCount rs, 2, "IS NOT NULL predicate"

call run sql, ,
  "UPDATE account SET score = 11.75, active = TRUE WHERE account_id = 2", ,
  "typed UPDATE"
call expectAffected 1

rs = sql~execute("SELECT * FROM account WHERE score > 11 AND active = TRUE")
call expectRowCount rs, 2, "updated values visible to subsequent predicates"

call run sql, "DELETE FROM account WHERE account_id = 3", "DELETE"
call expectAffected 1
rs = sql~execute("SELECT * FROM account")
call expectRowCount rs, 2, "row removed after DELETE"

call run sql, ,
  "CREATE TABLE membership (tenant INTEGER, user_id INTEGER, code VARCHAR," || ,
  " PRIMARY KEY (tenant, user_id), UNIQUE (code))", ,
  "composite PRIMARY KEY + table-level UNIQUE"

call run sql, ,
  "INSERT INTO membership (tenant,user_id,code) VALUES (1,10,'A')", ,
  "composite-key insert"

call expectConstraint sql, ,
  "INSERT INTO membership (tenant,user_id,code) VALUES (1,10,'B')", ,
  "composite PK enforced"

call expectConstraint sql, ,
  "INSERT INTO membership (tenant,user_id,code) VALUES (1,11,'A')", ,
  "table-level UNIQUE enforced"

call run sql, "DROP TABLE membership", "DROP TABLE"
call expectNil engine~table("membership"), "dropped table no longer visible"

/*====================================================================
  LEVEL 1 – Projection, aliases, ORDER BY, DISTINCT
====================================================================*/
call section "LEVEL 1 – Projection / aliases / ORDER BY / DISTINCT"

call run sql, ,
  "CREATE TABLE customers (" || ,
  "  customer_id INTEGER PRIMARY KEY," || ,
  "  full_name   VARCHAR(100) NOT NULL," || ,
  "  city        VARCHAR(50)  NOT NULL," || ,
  "  loyalty_tier VARCHAR(20) NOT NULL)", ,
  "CREATE customers"

call run sql, ,
  "CREATE TABLE employees (" || ,
  "  employee_id INTEGER PRIMARY KEY," || ,
  "  full_name   VARCHAR(100) NOT NULL," || ,
  "  department  VARCHAR(50)," || ,
  "  manager_id  INTEGER)", ,
  "CREATE employees"

call run sql, ,
  "CREATE TABLE products (" || ,
  "  product_id   INTEGER PRIMARY KEY," || ,
  "  product_name VARCHAR(100) NOT NULL," || ,
  "  category     VARCHAR(50)  NOT NULL)", ,
  "CREATE products"

call run sql, ,
  "CREATE TABLE orders (" || ,
  "  order_id    INTEGER PRIMARY KEY," || ,
  "  customer_id INTEGER NOT NULL," || ,
  "  employee_id INTEGER," || ,
  "  order_date  VARCHAR(10)," || ,
  "  status      VARCHAR(20))", ,
  "CREATE orders"

call run sql, ,
  "CREATE TABLE order_items (" || ,
  "  order_item_id INTEGER PRIMARY KEY," || ,
  "  order_id      INTEGER NOT NULL," || ,
  "  product_id    INTEGER NOT NULL," || ,
  "  quantity      INTEGER," || ,
  "  unit_price    DECIMAL)", ,
  "CREATE order_items"

call run sql, ,
  "INSERT INTO customers (customer_id,full_name,city,loyalty_tier) VALUES" || ,
  " (1,'Ada Lovelace','London','PLATINUM')," || ,
  " (2,'Grace Hopper','New York','GOLD')," || ,
  " (3,'Linus Torvalds','Helsinki','BRONZE')," || ,
  " (4,'Margaret Hamilton','Cambridge','PLATINUM')", ,
  "seed customers"

call run sql, ,
  "INSERT INTO employees (employee_id,full_name,department,manager_id) VALUES" || ,
  " (10,'Alice Manager','Sales',NULL)," || ,
  " (11,'Bob Seller','Sales',10)," || ,
  " (12,'Carol Seller','Sales',10)," || ,
  " (13,'Dave Intern','Sales',11)", ,
  "seed employees (hierarchy)"

call run sql, ,
  "INSERT INTO products (product_id,product_name,category) VALUES" || ,
  " (100,'Alpha','Books'),(101,'Bravo','Books'),(102,'Charlie','Tools')," || ,
  " (103,'Delta','Tools'),(104,'Echo','Gadgets')", ,
  "seed products"

call run sql, ,
  "INSERT INTO orders (order_id,customer_id,employee_id,order_date,status) VALUES" || ,
  " (1000,1,11,'2025-01-10','SHIPPED')," || ,
  " (1001,1,12,'2025-02-14','PENDING')," || ,
  " (1002,2,11,'2025-03-01','SHIPPED')," || ,
  " (1003,4,13,'2025-03-15','PENDING')", ,
  "seed orders"

call run sql, ,
  "INSERT INTO order_items (order_item_id,order_id,product_id,quantity,unit_price) VALUES" || ,
  " (1,1000,100,2,12.50),(2,1000,102,1,45.00)," || ,
  " (3,1001,101,3,9.99),(4,1002,102,2,45.00)," || ,
  " (5,1003,100,1,12.50),(6,1003,104,4,3.25)", ,
  "seed order_items"

rs = sql~execute("SELECT customer_id, full_name AS name, city FROM customers ORDER BY full_name")
call expectSuccessResult rs, "projection + alias + ORDER BY"
call expectRowCount rs, 4, "ORDER BY row count"
call expectValue rs, 1, "name", "Ada Lovelace", "ORDER BY ascending name"

rs = sql~execute("SELECT DISTINCT category FROM products ORDER BY category")
call expectSuccessResult rs, "DISTINCT + ORDER BY"
call expectRowCount rs, 3, "DISTINCT categories"

/*====================================================================
  LEVEL 2 – Multi-table comma / equijoin
====================================================================*/
call section "LEVEL 2 – Multi-table comma equijoin"

rs = sql~execute( ,
  "SELECT c.customer_id, c.full_name, c.city, p.category" ,
  " FROM customers c, orders o, order_items oi, products p" ,
  " WHERE o.customer_id = c.customer_id" ,
  "   AND oi.order_id = o.order_id" ,
  "   AND oi.product_id = p.product_id")
call expectSuccessResult rs, "4-table comma equijoin"
call expectRowCount rs, 6, "non-distinct multi-join rows"
if rs~status = .Error~SUCCESS & rs~accessPath \= "" then ,
  say "         accessPath =" rs~accessPath

rs = sql~execute( ,
  "SELECT DISTINCT c.customer_id, c.full_name, c.city, p.category" ,
  " FROM customers c, orders o, order_items oi, products p" ,
  " WHERE o.customer_id = c.customer_id" ,
  "   AND oi.order_id = o.order_id" ,
  "   AND oi.product_id = p.product_id")
call expectSuccessResult rs, "DISTINCT over multi-join"
call expectRowCount rs, 5, "distinct customer/category pairs"

rs = sql~execute("SELECT customer_id FROM customers c, orders o WHERE o.customer_id = c.customer_id")
call expectParseError rs, "ambiguous unqualified column rejected as parse error"

/*====================================================================
  LEVEL 3 – LEFT JOIN chains, self-joins, anti-join
====================================================================*/
call section "LEVEL 3 – LEFT JOIN / self-join / anti-join"

rs = sql~execute( ,
  "SELECT e1.full_name AS employee, e2.full_name AS manager," ,
  "       e3.full_name AS managers_manager" ,
  " FROM employees e1" ,
  " LEFT JOIN employees e2 ON e2.employee_id = e1.manager_id" ,
  " LEFT JOIN employees e3 ON e3.employee_id = e2.manager_id" ,
  " ORDER BY e1.employee_id")
call expectSuccessResult rs, "three-level self LEFT JOIN (org chart)"
call expectRowCount rs, 4, "org-chart row count"
call expectValue rs, 4, "employee", "Dave Intern", "deepest employee"
call expectValue rs, 4, "manager", "Bob Seller", "manager of intern"
call expectValue rs, 4, "managers_manager", "Alice Manager", "manager's manager"
call expectNull rs, 1, "manager", "top-level manager is NULL-extended"

rs = sql~execute( ,
  "SELECT c.customer_id, c.full_name" ,
  " FROM customers c" ,
  " LEFT JOIN orders o ON o.customer_id = c.customer_id" ,
  " WHERE o.order_id IS NULL")
call expectSuccessResult rs, "anti-join via LEFT JOIN + IS NULL"
call expectRowCount rs, 1, "customers with no orders"
call expectValue rs, 1, "c.full_name", "Linus Torvalds", "anti-join identity (qualified projection contract)"

rs = sql~execute( ,
  "SELECT c.customer_id, c.full_name, o.order_id, o.status" ,
  " FROM customers c" ,
  " LEFT JOIN orders o ON o.customer_id = c.customer_id AND o.status = 'PENDING'" ,
  " ORDER BY c.customer_id")
call expectSuccessResult rs, "LEFT JOIN ON equality + extra predicate"

/*====================================================================
  LEVEL 4 – UNION + recursive IN subqueries
====================================================================*/
call section "LEVEL 4 – UNION + recursive IN subqueries"

rs = sql~execute( ,
  "SELECT * FROM orders WHERE status = 'PENDING'" ,
  " UNION" ,
  " SELECT * FROM orders WHERE status = 'SHIPPED'" ,
  " UNION" ,
  " SELECT * FROM orders" ,
  " WHERE customer_id IN (SELECT customer_id FROM customers WHERE loyalty_tier = 'GOLD')" ,
  " ORDER BY order_id")
call expectSuccessResult rs, "multi-branch UNION + final ORDER BY + simple IN"
call expectRowCount rs, 4, "UNION result (all orders in this corpus)"

rs = sql~execute( ,
  "SELECT * FROM products" ,
  " WHERE product_id IN (" ,
  "   SELECT product_id FROM order_items WHERE order_id IN (" ,
  "     SELECT order_id FROM orders WHERE customer_id IN (" ,
  "       SELECT customer_id FROM customers WHERE city IN (" ,
  "         SELECT city FROM customers WHERE loyalty_tier = 'PLATINUM'" ,
  "       )" ,
  "     )" ,
  "   )" ,
  " )")
call expectSuccessResult rs, "four-deep nested IN subqueries"
call expectRowCount rs, 4, "products reachable via PLATINUM cities"

rs = sql~execute( ,
  "SELECT customer_id FROM customers WHERE city IN (" ,
  "  SELECT city FROM customers WHERE customer_id IN (" ,
  "    SELECT customer_id FROM customers WHERE city IN (" ,
  "      SELECT city FROM customers WHERE customer_id IN (" ,
  "        SELECT customer_id FROM customers WHERE loyalty_tier = 'PLATINUM'" ,
  "      )" ,
  "    )" ,
  "  )" ,
  ")")
call expectSuccessResult rs, "deeper-than-four recursive IN executes"
call expectTrue rs~rows~items >= 1, "deeper recursive IN returned rows"

/*====================================================================
  LEVEL 5 – Breaking-point probes (expected unsupported / parse)
====================================================================*/
call section "LEVEL 5 – Breaking-point probes (unsupported / parse surfaces)"

call probe sql, ,
  "SELECT category, COUNT(*) FROM products GROUP BY category", ,
  "GROUP BY + aggregate"

call probe sql, ,
  "SELECT c.customer_id," || ,
  " (SELECT COUNT(*) FROM orders o WHERE o.customer_id = c.customer_id) AS cnt" || ,
  " FROM customers c", ,
  "correlated SELECT-list subquery"

call probe sql, ,
  "SELECT o.order_id," || ,
  " (SELECT SUM(oi.quantity * oi.unit_price) FROM order_items oi" || ,
  "  WHERE oi.order_id = o.order_id)" || ,
  " FROM orders o", ,
  "aggregate correlated subquery"

call probe sql, ,
  "SELECT * FROM customers c RIGHT JOIN orders o ON o.customer_id = c.customer_id", ,
  "RIGHT JOIN"

call probe sql, ,
  "SELECT * FROM customers c FULL JOIN orders o ON o.customer_id = c.customer_id", ,
  "FULL JOIN"

call probe sql, ,
  "SELECT CASE WHEN score > 10 THEN 'high' ELSE 'low' END FROM account", ,
  "CASE expression"

call probe sql, ,
  "SELECT UPPER(full_name) FROM customers", ,
  "scalar function UPPER"

call probe sql, ,
  "SELECT * FROM customers WHERE full_name LIKE 'A%'", ,
  "LIKE predicate"

call probe sql, ,
  "SELECT * FROM customers WHERE customer_id BETWEEN 1 AND 2", ,
  "BETWEEN predicate"

call probe sql, ,
  "SELECT * FROM customers c" || ,
  " INNER JOIN orders o ON o.customer_id = c.customer_id" || ,
  " INNER JOIN order_items oi ON oi.order_id = o.order_id", ,
  "explicit multi INNER JOIN chain"

rs = sql~execute("SELECT * FROM nonexistent_table")
call expectAnyFailureResult rs, "reference to missing table"

rs = sql~execute("SELEC * FROM customers")
call expectParseError rs, "obvious parse error (typo keyword)"

rs = sql~execute("SELECT * FROM customers WHERE")
call expectParseError rs, "incomplete WHERE clause"

/*====================================================================
  Summary
====================================================================*/
say
say "╔══════════════════════════════════════════════════════════════╗"
say "║  SUMMARY                                                     ║"
say "╠══════════════════════════════════════════════════════════════╣"
say "║  Total checks     :" total~right(4)
say "║  Passed           :" passed~right(4)
say "║  Failed           :" failed~right(4)
say "║  Unsupported (ok) :" unsupported~right(4) "  (clean SQLUNSUPPORTED)"
say "║  Parse errors (ok):" parseErrors~right(4) "  (clean SQLPARSEERROR)"
say "║  Execution errors :" executionErrors~right(4)
say "╚══════════════════════════════════════════════════════════════╝"
say

cleanup = .NoSQLServerTestSupport~removeDatabase(root)

if failed > 0 | executionErrors > 0 then do
  say "RESULT: FAILURES DETECTED"
  exit 1
end
say "RESULT: ALL EXPECTED BEHAVIOURS OBSERVED"
exit 0

/*--------------------------------------------------------------------
  Helpers
--------------------------------------------------------------------*/
section: procedure
  use arg title
  say
  say "──" title
  say
  return

/* run sql, statement, label  – expects SUCCESS */
run: procedure expose total passed failed unsupported parseErrors executionErrors lastRs
  use arg sql, stmt, label
  total += 1
  lastRs = sql~execute(stmt)
  if lastRs~status = .Error~SUCCESS then do
    passed += 1
    say "  ✓" label
  end
  else do
    failed += 1
    say "  ✗" label
    say "      " lastRs~error "|" lastRs~message
  end
  return lastRs

expectSuccessResult: procedure expose total passed failed unsupported parseErrors executionErrors
  use arg rs, label
  total += 1
  if rs~status = .Error~SUCCESS then do
    passed += 1
    say "  ✓" label
  end
  else do
    failed += 1
    say "  ✗" label
    say "      " rs~error "|" rs~message
  end
  return

expectConstraint: procedure expose total passed failed unsupported parseErrors executionErrors
  use arg sql, stmt, label
  total += 1
  rs = sql~execute(stmt)
  if rs~status = .Error~NOTEXECUTED & rs~error = .Error~CONSTRAINT then do
    passed += 1
    say "  ✓" label
  end
  else do
    failed += 1
    say "  ✗" label "(expected CONSTRAINT)"
    say "      " rs~status rs~error "|" rs~message
  end
  return

expectAnyFailure: procedure expose total passed failed unsupported parseErrors executionErrors
  use arg sql, stmt, label
  total += 1
  rs = sql~execute(stmt)
  if rs~status \= .Error~SUCCESS then do
    passed += 1
    say "  ✓" label
  end
  else do
    failed += 1
    say "  ✗" label "(expected failure)"
  end
  return

expectAnyFailureResult: procedure expose total passed failed unsupported parseErrors executionErrors
  use arg rs, label
  total += 1
  if rs~status \= .Error~SUCCESS then do
    passed += 1
    say "  ✓" label
  end
  else do
    failed += 1
    say "  ✗" label "(expected failure)"
  end
  return

expectParseError: procedure expose total passed failed unsupported parseErrors executionErrors
  use arg rs, label
  total += 1
  if rs~status = .Error~NOTEXECUTED & rs~error = .Error~SQLPARSEERROR then do
    passed += 1
    parseErrors += 1
    say "  ✓" label
  end
  else do
    failed += 1
    say "  ✗" label "(expected SQLPARSEERROR)"
    say "      " rs~status rs~error "|" rs~message
  end
  return

probe: procedure expose total passed failed unsupported parseErrors executionErrors
  use arg sql, stmt, label
  total += 1
  rs = sql~execute(stmt)
  if rs~status = .Error~NOTEXECUTED & rs~error = .Error~SQLUNSUPPORTED then do
    passed += 1
    unsupported += 1
    say "  ✓ clean SQLUNSUPPORTED –" label
  end
  else if rs~status = .Error~NOTEXECUTED & rs~error = .Error~SQLPARSEERROR then do
    passed += 1
    parseErrors += 1
    say "  ✓ clean SQLPARSEERROR  –" label
  end
  else if rs~status = .Error~SUCCESS then do
    passed += 1
    say "  ★ now supported       –" label
  end
  else do
    executionErrors += 1
    failed += 1
    say "  ✗ unexpected failure  –" label
    say "      " rs~status rs~error "|" rs~message
  end
  return

expectRowCount: procedure expose total passed failed unsupported parseErrors executionErrors
  use arg rs, expected, label
  total += 1
  if rs~status \= .Error~SUCCESS then do
    failed += 1
    say "  ✗" label "(query failed)"
    return
  end
  actual = rs~rows~items
  if actual = expected then do
    passed += 1
    say "  ✓" label "(" || actual || " rows)"
  end
  else do
    failed += 1
    say "  ✗" label "expected" expected "got" actual
  end
  return

expectValue: procedure expose total passed failed unsupported parseErrors executionErrors
  use arg rs, rowIdx, col, expected, label
  total += 1
  if rs~status \= .Error~SUCCESS | rs~rows~items < rowIdx then do
    failed += 1
    say "  ✗" label "(missing row)"
    return
  end
  actual = rs~rows[rowIdx][col]
  if actual = expected then do
    passed += 1
    say "  ✓" label
  end
  else do
    failed += 1
    say "  ✗" label "expected '" || expected || "' got '" || actual || "'"
  end
  return

expectNull: procedure expose total passed failed unsupported parseErrors executionErrors
  use arg rs, rowIdx, col, label
  total += 1
  if rs~status \= .Error~SUCCESS | rs~rows~items < rowIdx then do
    failed += 1
    say "  ✗" label "(missing row)"
    return
  end
  actual = rs~rows[rowIdx][col]
  if actual == .nil then do
    passed += 1
    say "  ✓" label
  end
  else do
    failed += 1
    say "  ✗" label "expected NULL got '" || actual || "'"
  end
  return

expectAffected: procedure expose total passed failed unsupported parseErrors executionErrors lastRs
  use arg expected
  total += 1
  if lastRs == .nil then do
    failed += 1
    say "  ✗ affectedRows check (no prior result)"
    return
  end
  if lastRs~affectedRows = expected then do
    passed += 1
    say "  ✓ affectedRows =" expected
  end
  else do
    failed += 1
    say "  ✗ affectedRows expected" expected "got" lastRs~affectedRows
  end
  return

expectNil: procedure expose total passed failed unsupported parseErrors executionErrors
  use arg value, label
  total += 1
  if value == .nil then do
    passed += 1
    say "  ✓" label
  end
  else do
    failed += 1
    say "  ✗" label
  end
  return

expectTrue: procedure expose total passed failed unsupported parseErrors executionErrors
  use arg cond, label
  total += 1
  if cond then do
    passed += 1
    say "  ✓" label
  end
  else do
    failed += 1
    say "  ✗" label
  end
  return

::requires "../src/NoSQLServer.cls"
::requires "TestSupport.cls"
