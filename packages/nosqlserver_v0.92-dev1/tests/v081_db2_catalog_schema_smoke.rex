root=.NoSQLServerTestSupport~createBlankDatabase("v081_db2")
engine=.FileDatabaseEngine~new(root)
db2=.NoSQLServerDB2Personality~new(engine, "APPUSER", "APP")

call ok db2~execute("CREATE TABLE APP.department (id INTEGER PRIMARY KEY, code VARCHAR(20) UNIQUE NOT NULL)")
call ok db2~execute("CREATE TABLE APP.employee (id INTEGER PRIMARY KEY, department_id INTEGER REFERENCES APP.department(id), email VARCHAR(80) UNIQUE)")
call ok db2~execute("INSERT INTO APP.department VALUES (1,'ENG'),(2,'OPS')")
call ok db2~execute("INSERT INTO APP.employee VALUES (10,1,'a@example.test'),(11,2,'b@example.test')")

r=db2~execute("SELECT APP.employee.id,email FROM APP.employee ORDER BY APP.employee.id")
call assert r~status=.Error~SUCCESS, "schema-qualified SELECT status"
call assert r~rows~items=2, "schema-qualified SELECT count"
call assert r~rows[1]["employee.id"]=10, "schema-qualified projection"

r=db2~execute("SELECT CONSTNAME,TYPE FROM SYSCAT.TABCONST WHERE TABNAME='EMPLOYEE' ORDER BY CONSTNAME")
call assert r~status=.Error~SUCCESS, "SYSCAT.TABCONST status"
call assert r~rows~items=3, "employee has PK/UQ/FK constraints"

r=db2~execute("SELECT CONSTNAME,COLNAME,COLSEQ FROM SYSCAT.KEYCOLUSE WHERE TABNAME='EMPLOYEE' ORDER BY CONSTNAME")
call assert r~status=.Error~SUCCESS, "SYSCAT.KEYCOLUSE status"
call assert r~rows~items=3, "employee key column rows"

r=db2~execute("SELECT CONSTNAME,REFTABNAME,DELETERULE,UPDATERULE FROM SYSCAT.REFERENCES WHERE TABNAME='EMPLOYEE'")
call assert r~status=.Error~SUCCESS, "SYSCAT.REFERENCES status"
call assert r~rows~items=1, "one foreign key reference"
call assert r~rows[1]["REFTABNAME"]="DEPARTMENT", "foreign key target"

r=db2~execute("SELECT INDNAME,UNIQUERULE,COLCOUNT FROM SYSCAT.INDEXES WHERE TABNAME='EMPLOYEE' ORDER BY INDNAME")
call assert r~status=.Error~SUCCESS, "SYSCAT.INDEXES status"
call assert r~rows~items=2, "constraint-backed indexes"

r=db2~execute("SELECT INDNAME,COLNAME,COLSEQ,COLORDER FROM SYSCAT.INDEXCOLUSE WHERE INDNAME='PK_EMPLOYEE'")
call assert r~status=.Error~SUCCESS, "SYSCAT.INDEXCOLUSE status"
call assert r~rows~items=1, "PK index column"
call assert r~rows[1]["COLNAME"]="ID", "PK index column name"

info=db2~version
call assert info~personalityLevel="0.4", "personality level"
call assert info~supports("DB2_SCHEMA_QUALIFIED_NAMES"), "schema capability"
call assert info~supports("DB2_SYSCAT_REFERENCES"), "references capability"
call assert engine~version~release=.NoSQLServerBuild~RELEASE, "backend version bump"

ignore=.NoSQLServerTestSupport~removeDatabase(root)
say "NOSQLSERVER V0.81 DB2 CATALOG/SCHEMA SMOKE: OK"
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
