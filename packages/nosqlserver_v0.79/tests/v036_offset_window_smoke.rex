root = .NoSQLServerTestSupport~createBlankDatabase("v036")
sql = .NoSQLServerSQL~new(.FileDatabaseEngine~new(root))

call ok sql~execute("CREATE TABLE w (id INTEGER PRIMARY KEY, grp INTEGER, seq INTEGER, val INTEGER)")
call ok sql~execute("INSERT INTO w(id,grp,seq,val) VALUES (1,1,1,10),(2,1,2,20),(3,1,3,30),(4,2,1,40),(5,2,2,50)")

q = "SELECT grp,seq,val,LAG(val,1,-1) OVER (PARTITION BY grp ORDER BY seq) AS p,LEAD(val,1,-2) OVER (PARTITION BY grp ORDER BY seq) AS n FROM w ORDER BY grp,seq"
rs=sql~execute(q)
call assert rs~status=.Error~SUCCESS, "lag lead query"
call assert rs~rows~items=5, "lag lead rows"
call assert rs~rows[1]["p"]=-1, "lag default"
call assert rs~rows[1]["n"]=20, "lead first"
call assert rs~rows[3]["n"]=-2, "lead partition default"
call assert rs~rows[4]["p"]=-1, "lag second partition default"

q2 = "SELECT id,NTILE(4) OVER (ORDER BY seq) AS tile FROM w WHERE grp = 1 ORDER BY id"
nr=sql~execute(q2)
call assert nr~status=.Error~SUCCESS, "ntile query"
call assert nr~rows[1]["tile"]=1, "ntile bucket 1"
call assert nr~rows[2]["tile"]=2, "ntile bucket 2"
call assert nr~rows[3]["tile"]=3, "ntile buckets greater than rows have no gaps"

db=.FileDatabaseEngine~new(root)
call assert db~version~product="NoSQLServer", "version product"
call assert db~version~supports("WINDOW_LAG_LEAD"), "lag lead capability survives newer release"
call assert db~version~supports("WINDOW_LAG_LEAD"), "lag lead capability"
call assert db~version~supports("WINDOW_NTILE"), "ntile capability"

ignore=.NoSQLServerTestSupport~removeDatabase(root)
say "NOSQLSERVER V0.36 OFFSET WINDOW SMOKE: OK"
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
