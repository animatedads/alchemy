root=.NoSQLServerTestSupport~createBlankDatabase("v038")
sql=.NoSQLServerSQL~new(.FileDatabaseEngine~new(root))

call ok sql~execute("CREATE TABLE w (id INTEGER PRIMARY KEY, grp INTEGER, seq INTEGER, val INTEGER, parent INTEGER)")
call ok sql~execute("INSERT INTO w(id,grp,seq,val,parent) VALUES (1,1,1,10,NULL),(2,1,2,20,1),(3,1,3,30,1),(4,2,1,40,NULL),(5,2,2,50,4)")

q="SELECT grp,seq,val,SUM(val) OVER z AS run,AVG(val) OVER z AS av FROM w WINDOW z AS (PARTITION BY grp ORDER BY seq ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) ORDER BY grp,seq"
r=sql~execute(q)
call assert r~status=.Error~SUCCESS, "named window query"
call assert r~rows~items=5, "named window rows"
call assert r~rows[3]["run"]=60, "running sum"
call assert r~rows[3]["av"]=20, "running avg"
call assert r~rows[5]["run"]=90, "second partition sum"
call assert r~rows[5]["av"]=45, "second partition avg"

n="SELECT id,parent,val FROM w ORDER BY parent NULLS LAST, val DESC"
nr=sql~execute(n)
call assert nr~status=.Error~SUCCESS, "NULLS LAST query"
call assert nr~rows[1]["parent"]=1, "nonnull first"
call assert nr~rows[3]["parent"]=4, "second nonnull group"
call assert nr~rows[4]["parent"]==.nil, "nulls last first null"
call assert nr~rows[4]["val"]=40, "DESC within null peers"
call assert nr~rows[5]["val"]=10, "DESC null peer second"

db=.FileDatabaseEngine~new(root)
call assert db~version~product="NoSQLServer", "version product"
call assert db~version~supports("NAMED_WINDOWS"), "named windows survive newer release"
call assert db~version~supports("NAMED_WINDOWS"), "named window capability"
call assert db~version~supports("ORDER_BY_NULLS"), "NULL ordering capability"

ignore=.NoSQLServerTestSupport~removeDatabase(root)
say "NOSQLSERVER V0.38 NAMED WINDOW / NULL ORDER SMOKE: OK"
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
