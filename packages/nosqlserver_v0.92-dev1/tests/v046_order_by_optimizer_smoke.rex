root=.NoSQLServerTestSupport~createBlankDatabase("v046")
sql=.NoSQLServerSQL~new(.FileDatabaseEngine~new(root))

call ok sql~execute("CREATE TABLE t (id INTEGER PRIMARY KEY, grp INTEGER, name VARCHAR, score INTEGER)")
call ok sql~execute("INSERT INTO t VALUES (1,1,'delta',40),(2,1,'alpha',10),(3,1,'charlie',30),(4,1,'bravo',20),(5,2,'echo',20),(6,2,'foxtrot',20),(7,2,'golf',NULL),(8,2,'hotel',50)")

-- Full merge sort, multi-key and NULL ordering.
r=sql~execute("SELECT id,name,score FROM t ORDER BY score DESC NULLS LAST, name ASC")
call assert r~status=.Error~SUCCESS, "full merge sort"
ids="8 1 3 4 5 6 2 7"~makeArray(" ")
call assert r~rows~items=8, "full row count"
do i=1 to 8
  call assert r~rows[i]["id"]=ids[i], "full order" i
end

-- Bounded top-N must match the prefix of the full stable ordering.
r=sql~execute("SELECT id,name,score FROM t ORDER BY score DESC NULLS LAST, name ASC LIMIT 4")
call assert r~status=.Error~SUCCESS, "top n"
call assert r~rows~items=4, "top n count"
do i=1 to 4
  call assert r~rows[i]["id"]=ids[i], "top n order" i
end

-- Offset + limit means the bounded sorter must keep offset+limit rows.
r=sql~execute("SELECT id FROM t ORDER BY score DESC NULLS LAST, name ASC LIMIT 2 OFFSET 3")
call assert r~status=.Error~SUCCESS, "offset top n"
call assert r~rows~items=2, "offset count"
call assert r~rows[1]["id"]=4, "offset first"
call assert r~rows[2]["id"]=5, "offset second"

-- Equal sort keys retain input order in the stable full sort and bounded path.
r=sql~execute("SELECT id FROM t WHERE score=20 ORDER BY score LIMIT 2")
call assert r~status=.Error~SUCCESS, "stable bounded peers"
call assert r~rows[1]["id"]=4, "stable peer first"
call assert r~rows[2]["id"]=5, "stable peer second"

db=.FileDatabaseEngine~new(root)
call assert db~version~product="NoSQLServer", "version product"
call assert db~version~supports("ORDER_BY_TOP_N"), "top-N survives newer release"
call assert db~version~supports("ORDER_BY_MERGESORT"), "merge sort capability"
call assert db~version~supports("ORDER_BY_TOP_N"), "top n capability"

ignore=.NoSQLServerTestSupport~removeDatabase(root)
say "NOSQLSERVER V0.46 ORDER BY OPTIMIZER SMOKE: OK"
exit 0

ok: procedure
  use arg rs
  call assert rs~status=.Error~SUCCESS, "setup"
  return
assert: procedure
  use arg condition,message,detail=""
  if \condition then do
    say "ASSERT FAILED:" message detail
    exit 1
  end
  return

::requires "../src/NoSQLServer.cls"
::requires "TestSupport.cls"
