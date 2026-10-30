sourceRoot = arg(1)
if sourceRoot = "" then do
  say "usage: v04_index_planner_smoke.rex DATABASE_ROOT"
  exit 2
end

root = .NoSQLServerTestSupport~createBlankDatabase("v04")

engine = .FileDatabaseEngine~new(root)
sql = .NoSQLServerSQL~new(engine)

call assertSuccess sql~execute("CREATE TABLE person (person_id INTEGER PRIMARY KEY, email VARCHAR UNIQUE, region VARCHAR)"), "create person"
call assertSuccess sql~execute("INSERT INTO person (person_id,email,region) VALUES (1,'a@example.com','N')"), "person 1"
call assertSuccess sql~execute("INSERT INTO person (person_id,email,region) VALUES (2,'b@example.com','S')"), "person 2"
call assertSuccess sql~execute("INSERT INTO person (person_id,email,region) VALUES (3,'c@example.com','N')"), "person 3"

-- Build an equality index at generation 3.
msg = engine~startIndexBuild("person", "region")
msg~wait
call assert (msg~errorCondition == .nil), "initial index build"
snap = msg~result
call assert (snap~indexedThrough = 3), "initial index watermark"
call assert (snap~lookupRows("N")~items = 2), "index carries row snapshots"

-- CURRENT path consumes the index directly, rather than scanning the authoritative table.
rs = sql~execute("SELECT * FROM person WHERE region = 'N'")
call assert (rs~status = .Error~SUCCESS), "current-index select succeeds"
call assert (rs~accessPath = "INDEX_CURRENT"), "planner chooses CURRENT index"
call assert (rs~rows~items = 2), "current index returns two rows"
call assert (rs~rowsScanned = 2), "current index examines candidates only"
call assert (rs~indexedThrough = 3), "result exposes index watermark"

-- Let the table get ahead: add a match, move a match out, move a non-match in, delete a match.
call assertSuccess sql~execute("INSERT INTO person (person_id,email,region) VALUES (4,'d@example.com','N')"), "insert stale delta"
call assertSuccess sql~execute("UPDATE person SET region='W' WHERE person_id = 1"), "update matching row out"
call assertSuccess sql~execute("UPDATE person SET region='N' WHERE person_id = 2"), "update row into match"
call assertSuccess sql~execute("DELETE FROM person WHERE person_id = 3"), "delete matching row"
call assert (engine~table("person")~generation = 7), "table reaches generation seven"
call assert (engine~indexSnapshot("person", "region")~indexedThrough = 3), "index remains behind at generation three"

-- BEHIND index + complete journal gap must still return the exact authoritative answer.
rs = sql~execute("SELECT * FROM person WHERE region = 'N'")
call assert (rs~status = .Error~SUCCESS), "delta-index select succeeds"
call assert (rs~accessPath = "INDEX_DELTA"), "planner chooses index plus journal delta"
call assert (rs~rows~items = 2), "delta reconciliation returns two current matches"
call assert hasId(rs~rows, "2"), "row moved into predicate is present"
call assert hasId(rs~rows, "4"), "inserted predicate row is present"
call assert (\hasId(rs~rows, "1")), "row moved out of predicate is absent"
call assert (\hasId(rs~rows, "3")), "deleted predicate row is absent"

-- Destroy one required journal generation. Correctness must beat acceleration: fall back to table scan.
call SysFileDelete root || "/tables/person/journal/7.yaml"
call assertSuccess sql~execute("INSERT INTO person (person_id,email,region) VALUES (5,'e@example.com','N')"), "advance after journal hole"
rs = sql~execute("SELECT * FROM person WHERE region = 'N'")
call assert (rs~status = .Error~SUCCESS), "journal-hole query still succeeds"
call assert (rs~accessPath = "TABLE_SCAN"), "missing journal forces authoritative scan"
call assert (rs~rows~items = 3), "fallback scan remains correct"
call assert hasId(rs~rows, "5"), "fallback sees newest row"

cleanupResult = .NoSQLServerTestSupport~removeDatabase(root)
say "NOSQLSERVER V0.4 INDEX PLANNER SMOKE: OK"
exit 0

hasId: procedure
  use arg rows, wanted
  do row over rows
    if row["person_id"] = wanted then return .true
  end
  return .false

assertSuccess: procedure
  use arg rs, message
  if rs~status \= .Error~SUCCESS then do
    say "ASSERT FAILED:" message rs~error rs~message
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
