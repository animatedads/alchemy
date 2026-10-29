corpus = arg(1)
if corpus = "" then corpus = "hell_corpus_v1.sql"
if stream(corpus, "c", "query exists") = "" then do
  say "corpus not found:" corpus
  exit 2
end
root = .NoSQLServerTestSupport~createBlankDatabase("hell")
engine = .FileDatabaseEngine~new(root)
sql = .NoSQLServerSQL~new(engine)
phase = "LOAD"
statement = ""
currentTitle = ""
queryTotal = 0
pass = 0
unsupported = 0
parseErrors = 0
wrong = 0
execErrors = 0
loadFailures = 0
say "NOSQLSERVER HELL CORPUS BASELINE"
say "corpus:" corpus
say

do while lines(corpus) > 0
  line = linein(corpus)
  stripped = line~strip
  if stripped~startsWith("--") then do
    if stripped~pos("UNHELPFUL QUERIES") > 0 then phase = "QUERY"
    if phase = "QUERY" & stripped~startsWith("-- [") then currentTitle = stripped~substr(4)~strip
    iterate
  end
  if stripped = "" then iterate
  if statement = "" then statement = stripped
  else statement ||= " " || stripped
  if stripped~right(1) \= ";" then iterate
  rs = sql~execute(statement)
  if phase = "LOAD" then do
    if rs~status \= .Error~SUCCESS then do
      loadFailures += 1
      say "LOAD FAILURE:" rs~error "|" rs~message
      say "  SQL:" statement
    end
  end
  else do
    queryTotal += 1
    classification = classify(rs, queryTotal, sql)
    select
      when classification = "PASS" then pass += 1
      when classification = "UNSUPPORTED" then unsupported += 1
      when classification = "PARSE_ERROR" then parseErrors += 1
      when classification = "WRONG_RESULT" then wrong += 1
      otherwise execErrors += 1
    end
    n = queryTotal~format(2,0)~changestr(" ", "0")
    say "QUERY" n || ":" classification "|" currentTitle
    if rs~status \= .Error~SUCCESS then say "       " rs~error "|" rs~message
    else say "       rows=" rs~rowCount "affected=" rs~affectedRows "path=" rs~accessPath
  end
  statement = ""
end
call lineout corpus
say
say "load failures :" loadFailures
say "queries       :" queryTotal
say "  PASS           :" pass
say "  UNSUPPORTED    :" unsupported
say "  PARSE_ERROR    :" parseErrors
say "  WRONG_RESULT   :" wrong
say "  EXECUTION_ERROR:" execErrors
cleanup = .NoSQLServerTestSupport~removeDatabase(root)
if loadFailures > 0 then exit 1
exit 0

classify: procedure
  use arg rs, queryNumber, sql
  if rs~status = .Error~SUCCESS then do
    select
      when queryNumber = 1 then if \oracleQ1(rs) then return "WRONG_RESULT"
      when queryNumber = 2 then if \oracleQ2(rs) then return "WRONG_RESULT"
      when queryNumber = 3 then if \oracleQ3(rs) then return "WRONG_RESULT"
      when queryNumber = 4 then if \oracleQ4(rs) then return "WRONG_RESULT"
      when queryNumber = 5 then if \oracleQ5(rs) then return "WRONG_RESULT"
      when queryNumber = 6 then if \oracleQ6(rs) then return "WRONG_RESULT"
      when queryNumber = 7 then if \oracleQ7(rs) then return "WRONG_RESULT"
      when queryNumber = 8 then if \oracleQ8(rs) then return "WRONG_RESULT"
      when queryNumber = 9 then if \oracleQ9(rs) then return "WRONG_RESULT"
      when queryNumber = 10 then if \oracleQ10(rs) then return "WRONG_RESULT"
      when queryNumber = 11 then if \oracleQ11(rs) then return "WRONG_RESULT"
      when queryNumber = 12 then if \oracleQ12(rs) then return "WRONG_RESULT"
      when queryNumber = 13 then if \oracleQ13(rs) then return "WRONG_RESULT"
      when queryNumber = 14 then if \oracleQ14(rs) then return "WRONG_RESULT"
      when queryNumber = 15 then if \oracleQ15(rs) then return "WRONG_RESULT"
      when queryNumber = 16 then if \oracleQ16(rs) then return "WRONG_RESULT"
      when queryNumber = 17 then if \oracleQ17(rs) then return "WRONG_RESULT"
      when queryNumber = 18 then if \oracleQ18(rs) then return "WRONG_RESULT"
      when queryNumber = 19 then if \oracleQ19(rs) then return "WRONG_RESULT"
      when queryNumber = 20 then if \oracleQ20(rs) then return "WRONG_RESULT"
      when queryNumber = 21 then if \oracleQ21(rs, sql) then return "WRONG_RESULT"
      when queryNumber = 22 then if \oracleQ22(rs, sql) then return "WRONG_RESULT"
      when queryNumber = 24 then if \oracleQ24(rs) then return "WRONG_RESULT"
      when queryNumber = 25 then if \oracleQ25(rs) then return "WRONG_RESULT"
      otherwise return "WRONG_RESULT"  -- success without an oracle is not yet trusted
    end
    return "PASS"
  end
  if rs~error = .Error~SQLUNSUPPORTED then return "UNSUPPORTED"
  if rs~error = .Error~SQLPARSEERROR then return "PARSE_ERROR"
  return "EXECUTION_ERROR"

oracleQ1: procedure
  use arg rs
  depts = "Engineering|Engineering|Engineering|Engineering|Engineering|Operations|Research|Research|Sales|Sales"~makeArray("|")
  names = "Ada Director|Alan Engineer|Grace Lead|Katherine Eng|Ken Contractor|Margaret Ops|Barbara Scientist|Dennis Research|Empty Desk|Linus Sales"~makeArray("|")
  if rs~rows~items \= 10 then return .false
  do i = 1 to 10
    if rs~rows[i]["d.dept_name"] \= depts[i] then return .false
    if rs~rows[i]["e.full_name"] \= names[i] then return .false
  end
  return .true

oracleQ2: procedure
  use arg rs
  names = "Ada Director|Ada Director|Alan Engineer|Alan Engineer|Barbara Scientist|Dennis Research|Empty Desk|Grace Lead|Grace Lead|Katherine Eng|Katherine Eng|Ken Contractor|Ken Contractor|Linus Sales|Margaret Ops"~makeArray("|")
  titles = "Hyperdrive|Skunkworks|Hyperdrive|Skunkworks|Quantum Lens|Quantum Lens|Sales Portal|Hyperdrive|Skunkworks|Hyperdrive|Skunkworks|Hyperdrive|Skunkworks|Sales Portal|Warehouse Bot"~makeArray("|")
  if rs~rows~items \= 15 then return .false
  do i = 1 to 15
    if rs~rows[i]["e.full_name"] \= names[i] then return .false
    if rs~rows[i]["p.title"] \= titles[i] then return .false
  end
  return .true

oracleQ3: procedure
  use arg rs
  if rs~rows~items \= 4 then return .false
  expected = "1 5 8 10"~makeArray(" ")
  do i = 1 to 4
    if rs~rows[i]["e.emp_id"] \= expected[i] then return .false
  end
  return .true

oracleQ4: procedure
  use arg rs
  if rs~rows~items \= 2 then return .false
  if rs~rows[1]["p.project_id"] \= 100 then return .false
  if rs~rows[2]["p.project_id"] \= 101 then return .false
  return .true

oracleQ5: procedure
  use arg rs
  if rs~rows~items \= 1 then return .false
  value = rs~rows[1]["mean_project_hours"]
  if value == .nil then return .false
  return abs(value - 14.875) < 0.000001


oracleQ6: procedure
  use arg rs
  if rs~rows~items \= 1 then return .false
  row = rs~rows[1]
  if row["e.dept_id"] \= 10 then return .false
  if row["headcount"] \= 4 then return .false
  if abs(row["avg_sal"] - 89500) >= 0.000001 then return .false
  return .true

oracleQ7: procedure
  use arg rs
  if rs~rows~items \= 9 then return .false
  names = "Alan Engineer|Barbara Scientist|Grace Lead|Katherine Eng|Ada Director|Dennis Research|Empty Desk|Linus Sales|Margaret Ops"~makeArray("|")
  counts = "1 1 1 1 0 0 0 0 0"~makeArray(" ")
  do i = 1 to 9
    if rs~rows[i]["e.full_name"] \= names[i] then return .false
    if rs~rows[i]["above_avg_assignments"] \= counts[i] then return .false
  end
  return .true

oracleQ8: procedure
  use arg rs
  if rs~rows~items \= 9 then return .false
  employees = "Margaret Ops|Linus Sales|Dennis Research|Grace Lead|Ken Contractor|Katherine Eng|Alan Engineer|Barbara Scientist|Empty Desk"
  managers = "Ada Director|Ada Director|Ada Director|Ada Director|Grace Lead|Grace Lead|Grace Lead|Dennis Research|Linus Sales"
  e = employees~makeArray("|")
  m = managers~makeArray("|")
  do i = 1 to 9
    if rs~rows[i]["employee"] \= e[i] then return .false
    if rs~rows[i]["manager"] \= m[i] then return .false
    if rs~rows[i]["emp_sal"] >= rs~rows[i]["mgr_sal"] then return .false
  end
  return .true


oracleQ9: procedure
  use arg rs
  if rs~rows~items \= 6 then return .false
  labels = "HIGH HIGH HIGH HIGH LOW LOW"~makeArray(" ")
  scores = "120000 95000 88000 80000 45000 0"~makeArray(" ")
  do i = 1 to 6
    if rs~rows[i]["label"] \= labels[i] then return .false
    if rs~rows[i]["score"] \= scores[i] then return .false
  end
  return .true


oracleQ10: procedure
  use arg rs
  expected = "1 2 3 4"~makeArray(" ")
  if rs~rows~items \= 4 then return .false
  do i = 1 to 4
    if rs~rows[i]["emp_id"] \= expected[i] then return .false
  end
  return .true

oracleQ11: procedure
  use arg rs
  expected = "9 10"~makeArray(" ")
  if rs~rows~items \= 2 then return .false
  do i = 1 to expected~items
    if rs~rows[i]["emp_id"] \= expected[i] then return .false
  end
  return .true

oracleQ12: procedure
  use arg rs
  expected = "2 3 4 7 8"~makeArray(" ")
  if rs~rows~items \= expected~items then return .false
  do i = 1 to expected~items
    if rs~rows[i]["a.assignment_id"] \= expected[i] then return .false
  end
  return .true

oracleQ13: procedure
  use arg rs
  if rs~rows~items \= 2 then return .false
  if rs~rows[1]["e.emp_id"] \= 1 then return .false
  if rs~rows[1]["e.salary"] \= 120000 then return .false
  if rs~rows[2]["e.emp_id"] \= 2 then return .false
  if rs~rows[2]["e.salary"] \= 95000 then return .false
  return .true

oracleQ14: procedure
  use arg rs
  if rs~rows~items \= 2 then return .false
  if rs~rows[1]["e.emp_id"] \= 5 then return .false
  if rs~rows[1]["e.full_name"] \= "Dennis Research" then return .false
  if rs~rows[2]["e.emp_id"] \= 7 then return .false
  if rs~rows[2]["e.full_name"] \= "Linus Sales" then return .false
  return .true


oracleQ15: procedure
  use arg rs
  names = "Ada Director|Dennis Research|Grace Lead|Linus Sales|Alan Engineer|Barbara Scientist|Empty Desk|Katherine Eng|Ken Contractor|Margaret Ops"~makeArray("|")
  bands = "ABOVE ABOVE ABOVE ABOVE BELOW BELOW BELOW BELOW BELOW BELOW"~makeArray(" ")
  flags = "Y Y Y Y Y Y Y Y N Y"~makeArray(" ")
  if rs~rows~items \= 10 then return .false
  do i = 1 to 10
    if rs~rows[i]["e.full_name"] \= names[i] then return .false
    if rs~rows[i]["band"] \= bands[i] then return .false
    if rs~rows[i]["active_flag"] \= flags[i] then return .false
  end
  return .true

oracleQ16: procedure
  use arg rs
  if rs~rows~items \= 1 then return .false
  if rs~rows[1]["director"] \= "Ada Director" then return .false
  if rs~rows[1]["middle_managers"] \= 3 then return .false
  return .true

oracleQ17: procedure
  use arg rs
  years = "2015 2016 2017 2018 2019 2020 2023 2024"~makeArray(" ")
  hired = "1 2 1 2 1 1 1 1"~makeArray(" ")
  avgs = "120000 86500 88000 76000 71000 69000 45000 0"~makeArray(" ")
  if rs~rows~items \= 8 then return .false
  do i = 1 to 8
    if rs~rows[i]["hire_year"] \= years[i] then return .false
    if rs~rows[i]["hired"] \= hired[i] then return .false
    if abs(rs~rows[i]["avg_salary"] - avgs[i]) >= 0.000001 then return .false
  end
  return .true

oracleQ18: procedure
  use arg rs
  kinds = "NO_TS NO_TS NO_TS NO_TS WITH_TS WITH_TS WITH_TS WITH_TS WITH_TS WITH_TS"~makeArray(" ")
  ids = "1 5 8 10 2 3 4 6 7 9"~makeArray(" ")
  names = "Ada Director|Dennis Research|Margaret Ops|Empty Desk|Grace Lead|Alan Engineer|Katherine Eng|Barbara Scientist|Linus Sales|Ken Contractor"~makeArray("|")
  totals = "N N N N 2 19.5 11 16 3 8"~makeArray(" ")
  if rs~rows~items \= 10 then return .false
  do i = 1 to 10
    row = rs~rows[i]
    if row["kind"] \= kinds[i] then return .false
    if row["e.emp_id"] \= ids[i] then return .false
    if row["e.full_name"] \= names[i] then return .false
    if totals[i] = "N" then do
      if row["x.total_hours"] \== .nil then return .false
    end
    else if abs(row["x.total_hours"] - totals[i]) >= 0.000001 then return .false
  end
  return .true


oracleQ19: procedure
  use arg rs
  emps = "2 3 3 3 4 4 6 6 7 9"~makeArray(" ")
  dates = "2024-02-05|2024-02-05|2024-02-06|2025-01-20|2024-02-05|2025-01-21|2024-07-01|2024-07-02|2024-04-10|2024-02-06"~makeArray("|")
  hours = "2 8 7.5 4 6 5 8 8 3 8"~makeArray(" ")
  runs = "2 8 15.5 19.5 6 11 8 16 3 8"~makeArray(" ")
  if rs~rows~items \= 10 then return .false
  do i = 1 to 10
    row = rs~rows[i]
    if row["t.emp_id"] \= emps[i] then return .false
    if row["t.work_date"] \= dates[i] then return .false
    if row["t.hours"] \= hours[i] then return .false
    if abs(row["running_hours"] - runs[i]) >= 0.000001 then return .false
  end
  return .true

oracleQ20: procedure
  use arg rs
  ids = "1 2 5 7 8 3 4 6 9 10"~makeArray(" ")
  managers = .array~new
  managers~append(.nil); managers~append(1); managers~append(1); managers~append(1); managers~append(1)
  managers~append(2); managers~append(2); managers~append(5); managers~append(2); managers~append(7)
  depths = "1 2 2 2 2 3 3 3 3 3"~makeArray(" ")
  if rs~rows~items \= 10 then return .false
  do i = 1 to 10
    row = rs~rows[i]
    if row["emp_id"] \= ids[i] then return .false
    if managers[i] == .nil then do
      if row["manager_id"] \== .nil then return .false
    end
    else if row["manager_id"] \= managers[i] then return .false
    if row["depth"] \= depths[i] then return .false
  end
  return .true

oracleQ21: procedure
  use arg rs, sql
  if rs~affectedRows \= 1 then return .false
  check = sql~execute("SELECT emp_id, salary FROM emp WHERE manager_id = 2 ORDER BY emp_id;")
  if check~status \= .Error~SUCCESS then return .false
  if check~rows~items \= 3 then return .false
  if check~rows[1]["emp_id"] \= 3 | check~rows[1]["salary"] \= 72000 then return .false
  if check~rows[2]["emp_id"] \= 4 | check~rows[2]["salary"] \= 74550 then return .false
  if check~rows[3]["emp_id"] \= 9 | check~rows[3]["salary"] \= 0 then return .false
  return .true

oracleQ22: procedure
  use arg rs, sql
  if rs~affectedRows \= 1 then return .false
  gone = sql~execute("SELECT entry_id FROM timesheet WHERE entry_id = 10;")
  if gone~status \= .Error~SUCCESS | gone~rows~items \= 0 then return .false
  kept = sql~execute("SELECT entry_id FROM timesheet WHERE billable = FALSE ORDER BY entry_id;")
  if kept~status \= .Error~SUCCESS | kept~rows~items \= 2 then return .false
  if kept~rows[1]["entry_id"] \= 3 | kept~rows[2]["entry_id"] \= 5 then return .false
  return .true

oracleQ24: procedure
  use arg rs
  if rs~rows~items \= 8 then return .false
  depts = "Engineering|Operations|Research|Sales|Engineering|Operations|Research|Sales"~makeArray("|")
  titles = "Hyperdrive|Hyperdrive|Hyperdrive|Hyperdrive|Quantum Lens|Quantum Lens|Quantum Lens|Quantum Lens"~makeArray("|")
  budgets = "500000|500000|500000|500000|320000|320000|320000|320000"~makeArray("|")
  do i = 1 to 8
    if rs~rows[i]["d.dept_name"] \= depts[i] then return .false
    if rs~rows[i]["p.title"] \= titles[i] then return .false
    if rs~rows[i]["p.budget"] \= budgets[i] then return .false
  end
  return .true

oracleQ25: procedure
  use arg rs
  names = "Ada Director|Grace Lead|Margaret Ops|Dennis Research|Alan Engineer|Linus Sales|Katherine Eng"~makeArray("|")
  dates = "2015-01-15|2016-06-01|2016-12-01|2017-02-20|2018-03-12|2018-07-07|2019-09-01"~makeArray("|")
  if rs~rows~items \= 7 then return .false
  do i = 1 to 7
    if rs~rows[i]["e.full_name"] \= names[i] then return .false
    if rs~rows[i]["e.hire_date"] \= dates[i] then return .false
  end
  return .true

::requires "../src/NoSQLServer.cls"
::requires "TestSupport.cls"
