root=.NoSQLServerTestSupport~createBlankDatabase("v080_db2")
engine=.FileDatabaseEngine~new(root)
db2=.NoSQLServerDB2Personality~new(engine, "APPUSER", "APP")

call ok db2~execute("CREATE TABLE customer (id INTEGER PRIMARY KEY, name VARCHAR(40) NOT NULL)")
call ok db2~execute("INSERT INTO customer VALUES (1,'one'),(2,'two'),(3,'three'),(4,'four')")

r=db2~execute("SELECT id,name FROM customer ORDER BY id FETCH FIRST 2 ROWS ONLY")
call assert r~status=.Error~SUCCESS, "DB2 FETCH FIRST status"
call assert r~rows~items=2, "DB2 FETCH FIRST count"
call assert r~rows[2]["id"]=2, "DB2 FETCH FIRST order"

r=db2~execute("SELECT id FROM customer ORDER BY id OFFSET 1 ROW FETCH NEXT 2 ROWS ONLY")
call assert r~status=.Error~SUCCESS, "DB2 OFFSET FETCH status"
call assert r~rows~items=2, "DB2 OFFSET FETCH count"
call assert r~rows[1]["id"]=2, "DB2 OFFSET FETCH first"
call assert r~rows[2]["id"]=3, "DB2 OFFSET FETCH second"

r=db2~execute("VALUES CURRENT SERVER")
call assert r~status=.Error~SUCCESS, "CURRENT SERVER"
call assert r~rows[1]["CURRENT SERVER"] \= "", "CURRENT SERVER value"

r=db2~execute("VALUES CURRENT SCHEMA")
call assert r~rows[1]["CURRENT SCHEMA"]="APP", "CURRENT SCHEMA initial"
call ok db2~execute("SET CURRENT SCHEMA = reporting")
r=db2~execute("VALUES CURRENT SCHEMA")
call assert r~rows[1]["CURRENT SCHEMA"]="REPORTING", "CURRENT SCHEMA set"

r=db2~execute("SELECT IBMREQD FROM SYSIBM.SYSDUMMY1")
call assert r~status=.Error~SUCCESS, "SYSDUMMY1 status"
call assert r~rows[1]["IBMREQD"]="Y", "SYSDUMMY1 value"

r=db2~execute("SELECT TABSCHEMA,TABNAME,TYPE,CARD FROM SYSCAT.TABLES WHERE TABNAME='CUSTOMER'")
call assert r~status=.Error~SUCCESS, "SYSCAT.TABLES status"
call assert r~rows~items=1, "SYSCAT.TABLES count"
call assert r~rows[1]["TABSCHEMA"]="REPORTING", "catalog reflects current schema"
call assert r~rows[1]["TABNAME"]="CUSTOMER", "catalog table name"
call assert r~rows[1]["CARD"]=4, "catalog cardinality"

r=db2~execute("SELECT COLNAME,TYPENAME,NULLS FROM SYSCAT.COLUMNS WHERE TABNAME='CUSTOMER' ORDER BY COLNO")
call assert r~status=.Error~SUCCESS, "SYSCAT.COLUMNS status"
call assert r~rows~items=2, "SYSCAT.COLUMNS count"
call assert r~rows[1]["COLNAME"]="ID", "catalog first column"
call assert r~rows[1]["TYPENAME"]="INTEGER", "catalog integer type"
call assert r~rows[2]["COLNAME"]="NAME", "catalog second column"
call assert r~rows[2]["NULLS"]="N", "catalog not null"

bad=db2~execute("SELECT id FROM customer WITH UR")
call assert bad~status \= .Error~SUCCESS, "WITH UR rejected honestly"
call assert bad~error=.Error~SQLUNSUPPORTED, "WITH UR unsupported code"

bad=db2~execute("CREATE TABLE identities (id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY)")
call assert bad~status \= .Error~SUCCESS, "identity rejected honestly"

info=db2~version
call assert info~personality="DB2", "personality identity"
call assert info~supports("DB2_SYSCAT_TABLES"), "personality capability"
call assert engine~version~release=.NoSQLServerBuild~RELEASE, "backend version bump"

ignore=.NoSQLServerTestSupport~removeDatabase(root)
say "NOSQLSERVER V0.80 DB2 PERSONALITY SMOKE: OK"
exit 0

ok: procedure
  use arg rs
  call assert rs~status=.Error~SUCCESS, "setup/statement: " || rs~message
  return

assert: procedure
  use arg condition,message
  if \condition then do
    say "ASSERT FAILED:" message
    exit 1
  end
  return

::requires "../src/NoSQLServerDB2Personality.cls"
::requires "TestSupport.cls"
