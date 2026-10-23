root=.NoSQLServerTestSupport~createBlankDatabase("v082_db2")
engine=.FileDatabaseEngine~new(root)
db2=.NoSQLServerDB2Personality~new(engine, "APPUSER", "APP")

call ok db2~execute("CREATE TABLE APP.department (id INTEGER, code VARCHAR(20), CONSTRAINT DEPT_PK PRIMARY KEY(id), CONSTRAINT DEPT_CODE_UQ UNIQUE(code))")
call ok db2~execute("CREATE TABLE APP.employee (id INTEGER, department_id INTEGER CONSTRAINT EMP_DEPT_FK REFERENCES APP.department(id), region VARCHAR(10), CONSTRAINT EMP_PK PRIMARY KEY(id))")
call ok db2~execute("INSERT INTO APP.department VALUES (1,'ENG'),(2,'OPS')")
call ok db2~execute("INSERT INTO APP.employee VALUES (10,1,'N'),(11,2,'S')")

-- Re-open the personality to prove declared names are durable, not session-only.
db2=.NoSQLServerDB2Personality~new(engine, "APPUSER", "APP")

r=db2~execute("SELECT CONSTNAME,TYPE FROM SYSCAT.TABCONST WHERE TABNAME='DEPARTMENT' ORDER BY CONSTNAME")
call assert r~status=.Error~SUCCESS, "department constraints query"
call assert r~rows~items=2, "department constraint count"
call assert r~rows[1]["CONSTNAME"]="DEPT_CODE_UQ", "named unique preserved"
call assert r~rows[2]["CONSTNAME"]="DEPT_PK", "named primary key preserved"

r=db2~execute("SELECT CONSTNAME,TYPE FROM SYSCAT.TABCONST WHERE TABNAME='EMPLOYEE' ORDER BY CONSTNAME")
call assert r~status=.Error~SUCCESS, "employee constraints query"
call assert r~rows~items=2, "employee constraint count"
call assert r~rows[1]["CONSTNAME"]="EMP_DEPT_FK", "named foreign key preserved"
call assert r~rows[2]["CONSTNAME"]="EMP_PK", "employee named primary key preserved"

call ok db2~execute("CREATE INDEX EMP_REGION_IX ON APP.employee(region)")
db2=.NoSQLServerDB2Personality~new(engine, "APPUSER", "APP")
r=db2~execute("SELECT INDNAME,COLNAME FROM SYSCAT.INDEXCOLUSE WHERE INDNAME='EMP_REGION_IX'")
call assert r~status=.Error~SUCCESS, "named index catalog query"
call assert r~rows~items=1, "named index present"
call assert r~rows[1]["COLNAME"]="REGION", "named index column"

r=db2~execute("CREATE UNIQUE INDEX EMP_REGION_UX ON APP.employee(region)")
call assert r~error=.Error~SQLUNSUPPORTED, "unique index fails honestly"
r=db2~execute("CREATE INDEX EMP_MULTI_IX ON APP.employee(region,department_id)")
call assert r~error=.Error~SQLUNSUPPORTED, "multi-column index fails honestly"

call ok db2~execute("DROP INDEX APP.EMP_REGION_IX")
r=db2~execute("SELECT INDNAME FROM SYSCAT.INDEXES WHERE INDNAME='EMP_REGION_IX'")
call assert r~status=.Error~SUCCESS, "dropped index catalog query"
call assert r~rows~items=0, "dropped index absent"

info=db2~version
call assert info~personalityLevel="0.4", "personality level"
call assert info~supports("DB2_NAMED_CONSTRAINTS"), "named constraint capability"
call assert info~supports("DB2_CREATE_INDEX"), "create index capability"
call assert engine~version~release=.NoSQLServerBuild~RELEASE, "backend version bump"

ignore=.NoSQLServerTestSupport~removeDatabase(root)
say "NOSQLSERVER V0.82 DB2 NAMED CONSTRAINT/INDEX SMOKE: OK"
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
