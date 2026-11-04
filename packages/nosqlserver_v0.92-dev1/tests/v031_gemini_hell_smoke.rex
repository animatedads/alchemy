root = .NoSQLServerTestSupport~createBlankDatabase("v031gemini")
engine = .FileDatabaseEngine~new(root)
sql = .NoSQLServerSQL~new(engine)
call loadHellSeed sql, "hell_corpus_v1.sql"

call assertTrue engine~version~supports("NESTED_CORRELATED_CASE"), "v0.31+ nested correlated CASE capability"
call assertTrue engine~version~supports("NOT_IN_SUBQUERY"), "NOT IN capability"
call assertTrue engine~version~supports("NULLIF"), "NULLIF capability"
call assertTrue engine~version~supports("AGGREGATE_ARITHMETIC"), "aggregate arithmetic capability"
call assertTrue engine~version~supports("CORRELATED_DELETE_AGGREGATE"), "correlated delete capability"

q26 = "SELECT e.emp_id, e.full_name FROM emp e WHERE e.dept_id NOT IN (SELECT dept_id FROM dept WHERE location = 'London' OR location = 'Nonexistent') ORDER BY e.emp_id"
rs = sql~execute(q26)
call assertSuccess rs, "Gemini Q26"
expected = "1 2 3 4 5 6 8 9"~makeArray(" ")
call assertTrue rs~rows~items = expected~items, "Q26 row count"
do i = 1 to expected~items; call assertTrue rs~rows[i]["e.emp_id"] = expected[i], "Q26 id" i; end

-- Gemini's Q26 comment says NULL trap, but its dept subquery cannot yield NULL.
-- This is the actual three-valued-logic trap: manager_id subquery contains NULL.
rs = sql~execute("SELECT e.emp_id FROM emp e WHERE e.manager_id NOT IN (SELECT manager_id FROM emp) ORDER BY e.emp_id")
call assertSuccess rs, "real NOT IN NULL trap"
call assertTrue rs~rows~items = 0, "NOT IN with NULL subquery returns empty WHERE result"

q27 = "SELECT d.dept_name, SUM(e.salary) AS total_payroll, COUNT(e.emp_id) AS active_members, SUM(e.salary) / NULLIF(COUNT(e.emp_id), 0) AS safe_average FROM dept d LEFT JOIN emp e ON e.dept_id = d.dept_id AND e.active = TRUE GROUP BY d.dept_name ORDER BY safe_average DESC, d.dept_name"
rs = sql~execute(q27)
call assertSuccess rs, "Gemini Q27"
call assertTrue rs~rows~items = 4, "Q27 groups"
call assertGroup rs, "Engineering", 358000, 4, 89500
call assertGroup rs, "Research", 157000, 2, 78500
call assertGroup rs, "Operations", 78000, 1, 78000
call assertGroup rs, "Sales", 125000, 2, 62500
-- Force the zero-member bucket Gemini describes but its seed lacks.
ignore = sql~execute("INSERT INTO dept (dept_id, dept_name, location) VALUES (50, 'Legal', 'Rome')")
rs = sql~execute(q27)
call assertSuccess rs, "Q27 sparse bucket"
found = .false
do row over rs~rows
  if row["d.dept_name"] = "Legal" then do
    found = .true
    call assertTrue row["active_members"] = 0, "NULLIF zero count"
    call assertTrue row["total_payroll"] == .nil, "SUM empty outer bucket NULL"
    call assertTrue row["safe_average"] == .nil, "safe division returns NULL"
  end
end
call assertTrue found, "Legal sparse bucket present"

q28 = "SELECT SUBSTR(d.location, 1, 3) || '-' || UPPER(d.dept_name) AS region_code, COUNT(e.emp_id) AS head_count, MAX(e.salary) - MIN(e.salary) AS salary_spread FROM dept d JOIN emp e ON e.dept_id = d.dept_id GROUP BY d.location, d.dept_name HAVING COUNT(e.emp_id) >= 2 AND AVG(e.salary) > 70000 ORDER BY salary_spread DESC"
rs = sql~execute(q28)
call assertSuccess rs, "Gemini Q28"
call assertTrue rs~rows~items = 2, "Q28 row count"
call assertTrue rs~rows[1]["region_code"] = "Gla-ENGINEERING", "Q28 engineering"
call assertTrue rs~rows[1]["head_count"] = 5, "Q28 engineering headcount"
call assertTrue rs~rows[1]["salary_spread"] = 120000, "Q28 engineering spread"
call assertTrue rs~rows[2]["region_code"] = "Edi-RESEARCH", "Q28 research"
call assertTrue rs~rows[2]["salary_spread"] = 19000, "Q28 research spread"

q30 = "SELECT e.full_name, CASE WHEN e.salary > (SELECT AVG(salary) FROM emp WHERE dept_id = e.dept_id) THEN 'DEPT_HIGH' WHEN e.salary = (SELECT MAX(salary) FROM emp) THEN 'TOP_EARNER' WHEN e.salary IS NULL OR e.salary = 0 THEN 'UNPAID_OR_NULL' ELSE 'STANDARD' END AS compensation_tier FROM emp e ORDER BY e.salary DESC, e.full_name"
rs = sql~execute(q30)
call assertSuccess rs, "Gemini Q30"
call assertTrue rs~rows~items = 10, "Q30 row count"
call assertTier rs, "Ada Director", "DEPT_HIGH"
call assertTier rs, "Grace Lead", "DEPT_HIGH"
call assertTier rs, "Ken Contractor", "UNPAID_OR_NULL"
call assertTier rs, "Empty Desk", "STANDARD"

q29 = "DELETE FROM assignment WHERE hours_week < (SELECT AVG(a2.hours_week) FROM assignment a2 WHERE a2.project_id = assignment.project_id)"
rs = sql~execute(q29)
call assertSuccess rs, "Gemini Q29"
call assertTrue rs~affectedRows = 4, "Q29 deleted count"
remaining = sql~execute("SELECT assignment_id FROM assignment ORDER BY assignment_id")
call assertSuccess remaining, "Q29 remaining rows"
expected = "2 3 5 7 8 9"~makeArray(" ")
call assertTrue remaining~rows~items = expected~items, "Q29 remaining count"
do i = 1 to expected~items; call assertTrue remaining~rows[i]["assignment_id"] = expected[i], "Q29 remaining id" i; end

cleanup = .NoSQLServerTestSupport~removeDatabase(root)
say "NOSQLSERVER V0.31 GEMINI HELL-V2 SMOKE: OK"
exit 0

loadHellSeed: procedure
  use arg sql, corpus
  statement = ""
  do while lines(corpus) > 0
    line = linein(corpus); stripped = line~strip
    if stripped~startsWith("-- [1]") then leave
    if stripped~startsWith("--") | stripped = "" then iterate
    if statement = "" then statement = stripped; else statement ||= " " || stripped
    if stripped~right(1) \= ";" then iterate
    rs = sql~execute(statement)
    call assertSuccess rs, "hell seed load"
    statement = ""
  end
  call lineout corpus
  return

assertGroup: procedure
  use arg rs, wanted, payroll, members, average
  do row over rs~rows
    if row["d.dept_name"] = wanted then do
      call assertTrue row["total_payroll"] = payroll, wanted "payroll"
      call assertTrue row["active_members"] = members, wanted "members"
      call assertTrue row["safe_average"] = average, wanted "average"
      return
    end
  end
  call fail "group missing:" wanted

assertTier: procedure
  use arg rs, wanted, tier
  do row over rs~rows
    if row["e.full_name"] = wanted then do
      call assertTrue row["compensation_tier"] = tier, wanted "tier"
      return
    end
  end
  call fail "tier row missing:" wanted

assertSuccess: procedure
  use arg rs, label
  if rs~status \= .Error~SUCCESS then call fail label || ": " || rs~error || " " || rs~message
  return

assertTrue: procedure
  use arg condition, label
  if \condition then call fail label
  return

fail: procedure
  use arg message
  say "ASSERT FAILED:" message
  exit 1

::requires "../src/NoSQLServer.cls"
::requires "TestSupport.cls"
