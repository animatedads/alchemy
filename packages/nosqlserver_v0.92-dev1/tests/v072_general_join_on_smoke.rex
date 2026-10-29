parse arg ignored
root = .NoSQLServerTestSupport~createBlankDatabase("v072_join_on")
db = .FileDatabaseEngine~new(root)
sql = .NoSQLServerSQL~new(db)

call assertSuccess sql~execute("CREATE TABLE left_order (order_id INTEGER PRIMARY KEY, product VARCHAR NOT NULL, qty INTEGER NOT NULL)"), "create left"
call assertSuccess sql~execute("CREATE TABLE right_order (row_id INTEGER PRIMARY KEY, order_id INTEGER NOT NULL, product VARCHAR NOT NULL, status VARCHAR NOT NULL, threshold INTEGER NOT NULL)"), "create right"
call assertSuccess sql~execute("INSERT INTO left_order (order_id,product,qty) VALUES (1,'A',5),(2,'B',7),(3,'C',9)"), "insert left"
call assertSuccess sql~execute("INSERT INTO right_order (row_id,order_id,product,status,threshold) VALUES (10,1,'A','ACTIVE',6),(11,2,'X','ACTIVE',8),(12,3,'C','INACTIVE',10),(13,99,'B','ACTIVE',4)"), "insert right"

-- This is the v0.71 failure shape from the cross-format experiment.
rs = sql~execute("SELECT l.order_id, l.product, r.product FROM left_order l JOIN right_order r ON l.order_id=r.order_id AND l.product=r.product ORDER BY l.order_id")
call assertSuccess rs, "compound equality ON"
call assertEqual 2, rs~rows~items, "compound equality row count"
call assertEqual "INNER_HASH_CHAIN", rs~accessPath, "compound equality uses connector optimisation"
call assertEqual 1, rs~rows[1]["l.order_id"], "first compound match"
call assertEqual 3, rs~rows[2]["l.order_id"], "second compound match"

-- Equality is an optimisation, not the semantics: residual boolean terms are
-- evaluated against the complete joined row.
rs = sql~execute("SELECT l.order_id, r.row_id FROM left_order l JOIN right_order r ON l.order_id=r.order_id AND (l.product=r.product OR r.status='ACTIVE') ORDER BY l.order_id")
call assertSuccess rs, "compound mixed boolean ON"
call assertEqual 3, rs~rows~items, "mixed boolean row count"
call assertEqual "INNER_HASH_CHAIN", rs~accessPath, "mixed boolean retains equality connector"

-- A top-level OR has no safe mandatory equality connector.  It must still be
-- semantically valid, using predicate evaluation over candidate row pairs.
rs = sql~execute("SELECT l.order_id, r.row_id FROM left_order l JOIN right_order r ON l.order_id=r.order_id OR l.product=r.product ORDER BY l.order_id, r.row_id")
call assertSuccess rs, "OR ON"
call assertEqual 4, rs~rows~items, "OR row count"
call assertEqual "INNER_PREDICATE_CHAIN", rs~accessPath, "OR uses predicate fallback"

-- A non-equality column predicate is a valid INNER JOIN condition even though
-- it cannot use the equality hash connector.
rs = sql~execute("SELECT l.order_id, r.row_id FROM left_order l JOIN right_order r ON l.qty < r.threshold")
call assertSuccess rs, "non-equality ON"
call assertEqual 6, rs~rows~items, "non-equality row count"
call assertEqual "INNER_PREDICATE_CHAIN", rs~accessPath, "non-equality uses predicate fallback"

-- Expression predicates use the same row-level evaluator rather than a JOIN-
-- specific column parser.
rs = sql~execute("SELECT l.order_id, r.row_id FROM left_order l JOIN right_order r ON UPPER(l.product)=UPPER(r.product) ORDER BY l.order_id")
call assertSuccess rs, "expression ON"
call assertEqual 3, rs~rows~items, "expression row count"
call assertEqual "INNER_PREDICATE_CHAIN", rs~accessPath, "expression uses predicate fallback"

call assertTrue db~version~supports("INNER_JOIN_GENERAL_ON_PREDICATE"), "feature advertised"
cleanup = .NoSQLServerTestSupport~removeDatabase(root)
say "NOSQLSERVER V0.72 GENERAL JOIN ON SMOKE: OK"
exit 0

assertSuccess: procedure
  use arg rs, label
  if rs~status \= .Error~SUCCESS then do
    say "ASSERT FAILED:" label rs~status rs~error rs~message
    exit 1
  end
  return

assertEqual: procedure
  use arg expected, actual, label
  if expected \== actual then do
    say "ASSERT FAILED:" label "expected=" expected "actual=" actual
    exit 1
  end
  return

assertTrue: procedure
  use arg value, label
  if \value then do
    say "ASSERT FAILED:" label
    exit 1
  end
  return

::requires "../src/NoSQLServer.cls"
::requires "TestSupport.cls"
