root = .NoSQLServerTestSupport~createBlankDatabase("v026")
engine = .FileDatabaseEngine~new(root)
sql = .NoSQLServerSQL~new(engine)

call assertSuccess sql~execute("CREATE TABLE left_t (id INTEGER PRIMARY KEY, k INTEGER, name VARCHAR);"), "create left"
call assertSuccess sql~execute("CREATE TABLE right_t (id INTEGER PRIMARY KEY, k INTEGER, name VARCHAR);"), "create right"
call assertSuccess sql~execute("INSERT INTO left_t (id,k,name) VALUES (1,10,'L10'),(2,20,'L20'),(3,30,'L30');"), "insert left"
call assertSuccess sql~execute("INSERT INTO right_t (id,k,name) VALUES (11,10,'R10'),(22,20,'R20'),(44,40,'R40');"), "insert right"

rs = sql~execute("SELECT l.name, r.name FROM left_t l RIGHT JOIN right_t r ON r.k = l.k ORDER BY r.id;")
call assertSuccess rs, "right join"
call assertEq rs~accessPath, "RIGHT_HASH_CHAIN", "right path"
call assertEq rs~rows~items, 3, "right count"
call assertEq rs~rows[1]["l.name"], "L10", "right matched 10"
call assertEq rs~rows[2]["l.name"], "L20", "right matched 20"
call assertTrue rs~rows[3]["l.name"] == .nil, "right unmatched left null"
call assertEq rs~rows[3]["r.name"], "R40", "right preserves unmatched right"

rs2 = sql~execute("SELECT l.name, r.name FROM left_t l FULL OUTER JOIN right_t r ON r.k = l.k ORDER BY l.name, r.name;")
call assertSuccess rs2, "full outer join"
call assertEq rs2~accessPath, "FULL_OUTER_NESTED_LOOP", "full path"
call assertEq rs2~rows~items, 4, "full count"
seen = .table~new
do row over rs2~rows
  lv = row["l.name"]
  rv = row["r.name"]
  if lv == .nil then lk = "NULL"
  else lk = lv
  if rv == .nil then rk = "NULL"
  else rk = rv
  seen[lk || ":" || rk] = .true
end
call assertTrue seen["L10:R10"] \== .nil, "full matched 10"
call assertTrue seen["L20:R20"] \== .nil, "full matched 20"
call assertTrue seen["L30:NULL"] \== .nil, "full preserves unmatched left"
call assertTrue seen["NULL:R40"] \== .nil, "full preserves unmatched right"
call assertTrue engine~version~supports("RIGHT_JOIN"), "right capability"
call assertTrue engine~version~supports("FULL_OUTER_JOIN"), "full capability"

cleanupResult = .NoSQLServerTestSupport~removeDatabase(root)
say "NOSQLSERVER V0.26 RIGHT/FULL OUTER JOIN SMOKE: OK"
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
