root=.NoSQLServerTestSupport~createBlankDatabase("v066")
db=.FileDatabaseEngine~new(root)
sql=.NoSQLServerSQL~new(db)

call ok sql~execute("CREATE TABLE fact (id INTEGER PRIMARY KEY, region VARCHAR, active BOOLEAN, amount DECIMAL)")
call ok sql~execute("INSERT INTO fact VALUES (1,'A',TRUE,10),(2,'A',TRUE,20),(3,'A',FALSE,5),(4,'B',TRUE,7)")

r=sql~execute("SELECT region,active,COUNT(*) AS n,SUM(amount) AS total FROM fact GROUP BY GROUPING SETS ((region,active),(region),()) ORDER BY region,active")
call assert r~status=.Error~SUCCESS,"grouping sets status"
call assert r~rows~items=6,"grouping sets count"
call assert r~rows[1]["region"]==.nil,"grand region null"
call assert r~rows[1]["active"]==.nil,"grand active null"
call assert r~rows[1]["n"]=4,"grand count"
call assert r~rows[1]["total"]=42,"grand total"
call assert r~rows[2]["region"]="A" & r~rows[2]["active"]==.nil & r~rows[2]["n"]=3,"A subtotal"
call assert r~rows[3]["region"]="A" & r~rows[3]["active"]="FALSE" & r~rows[3]["n"]=1,"A false"
call assert r~rows[4]["region"]="A" & r~rows[4]["active"]="TRUE" & r~rows[4]["n"]=2,"A true"
call assert r~rows[5]["region"]="B" & r~rows[5]["active"]==.nil & r~rows[5]["n"]=1,"B subtotal"
call assert r~rows[6]["region"]="B" & r~rows[6]["active"]="TRUE" & r~rows[6]["n"]=1,"B true"

r=sql~execute("SELECT region,active,COUNT(*) AS n FROM fact GROUP BY ROLLUP(region,active) ORDER BY region,active")
call assert r~status=.Error~SUCCESS,"rollup status"
call assert r~rows~items=6,"rollup count"
call assert r~rows[1]["region"]==.nil & r~rows[1]["n"]=4,"rollup grand"

r=sql~execute("SELECT region,active,COUNT(*) AS n FROM fact GROUP BY CUBE(region,active) ORDER BY region,active")
call assert r~status=.Error~SUCCESS,"cube status"
call assert r~rows~items=8,"cube count"
call assert r~rows[1]["region"]==.nil & r~rows[1]["active"]==.nil & r~rows[1]["n"]=4,"cube grand"
call assert r~rows[2]["region"]==.nil & r~rows[2]["active"]="FALSE" & r~rows[2]["n"]=1,"cube false subtotal"
call assert r~rows[3]["region"]==.nil & r~rows[3]["active"]="TRUE" & r~rows[3]["n"]=3,"cube true subtotal"

-- Duplicate grouping sets deliberately emit duplicate aggregate rows.
r=sql~execute("SELECT region,COUNT(*) AS n FROM fact GROUP BY GROUPING SETS ((region),(region)) ORDER BY region")
call assert r~status=.Error~SUCCESS,"duplicate grouping sets status"
call assert r~rows~items=4,"duplicate grouping sets preserved"

-- Empty input still emits the grand-total row for the empty grouping set.
r=sql~execute("SELECT COUNT(*) AS n,SUM(amount) AS total FROM fact WHERE id<0 GROUP BY GROUPING SETS (())")
call assert r~status=.Error~SUCCESS,"empty grouping set status"
call assert r~rows~items=1,"empty grouping set row"
call assert r~rows[1]["n"]=0,"empty count"
call assert r~rows[1]["total"]==.nil,"empty sum null"

call assert db~version~product="NoSQLServer","version product"
call assert db~version~supports("GROUPING_SETS"),"grouping sets capability"
call assert db~version~supports("ROLLUP"),"rollup capability"
call assert db~version~supports("CUBE"),"cube capability"

ignore=.NoSQLServerTestSupport~removeDatabase(root)
say "NOSQLSERVER V0.66 OLAP GROUPING SMOKE: OK"
exit 0

ok: procedure
  use arg rs
  call assert rs~status=.Error~SUCCESS,"setup"
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
