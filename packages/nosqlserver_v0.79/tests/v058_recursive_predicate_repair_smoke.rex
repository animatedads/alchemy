root=.NoSQLServerTestSupport~createBlankDatabase("v058")
sql=.NoSQLServerSQL~new(.FileDatabaseEngine~new(root))

call ok sql~execute("CREATE TABLE emp (emp_id INTEGER PRIMARY KEY, full_name VARCHAR, manager_id INTEGER)")
call ok sql~execute("INSERT INTO emp VALUES (1,'Root',NULL),(2,'Child',1),(3,'Grandchild',2)")

q="WITH RECURSIVE chain AS (" ||,
  "SELECT emp_id, full_name, manager_id, 1 AS depth, CAST(emp_id AS VARCHAR) AS path " ||,
  "FROM emp WHERE manager_id IS NULL " ||,
  "UNION ALL " ||,
  "SELECT e.emp_id, e.full_name, e.manager_id, c.depth + 1, " ||,
  "c.path || '/' || CAST(e.emp_id AS VARCHAR) " ||,
  "FROM emp e JOIN chain c ON e.manager_id = c.emp_id " ||,
  "WHERE c.path NOT LIKE '%' || CAST(e.emp_id AS VARCHAR) || '%' " ||,
  ") SELECT emp_id,full_name,depth,path FROM chain ORDER BY depth,emp_id"

r=sql~execute(q)
call assert r~status=.Error~SUCCESS,"recursive guarded query"
call assert r~rows~items=3,"recursive row count"
call assert r~rows[1]["emp_id"]=1,"root id"
call assert r~rows[1]["path"]="1","root path"
call assert r~rows[2]["emp_id"]=2,"child id"
call assert r~rows[2]["path"]="1/2","child path"
call assert r~rows[3]["emp_id"]=3,"grandchild id"
call assert r~rows[3]["path"]="1/2/3","grandchild path"

-- Shared predicate parser: concat + NOT LIKE outside recursive CTE too.
r=sql~execute("SELECT emp_id FROM emp WHERE full_name NOT LIKE '%' || 'zzz' || '%' ORDER BY emp_id")
call assert r~status=.Error~SUCCESS,"shared NOT LIKE concat"
call assert r~rows~items=3,"shared predicate rows"

db=.FileDatabaseEngine~new(root)
call assert db~version~product="NoSQLServer","version product"
call assert db~version~supports("PREDICATE_CONCAT_EXPRESSION"),"v0.58 predicate repair survives"
call assert db~version~supports("PREDICATE_CONCAT_EXPRESSION"),"predicate concat capability"

ignore=.NoSQLServerTestSupport~removeDatabase(root)
say "NOSQLSERVER V0.58 RECURSIVE PREDICATE REPAIR SMOKE: OK"
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
