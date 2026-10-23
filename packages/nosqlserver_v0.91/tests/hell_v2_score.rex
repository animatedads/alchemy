corpus = arg(1)
if corpus = "" then corpus = "hell_corpus_v2.sql"
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
say "NOSQLSERVER HELL CORPUS V2 SCORE"
say "corpus:" corpus
say

do while lines(corpus) > 0
  line = linein(corpus)
  stripped = line~strip
  if stripped~startsWith("--") then do
    if stripped~pos("-- QUERIES") > 0 | stripped~pos("QUERIES") > 0 then phase = "QUERY"
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
      when queryNumber = 1 then if oracleQ1(rs) then return "PASS"
      when queryNumber = 2 then if oracleQ2(rs) then return "PASS"
      when queryNumber = 3 then if oracleQ3(rs) then return "PASS"
      when queryNumber = 4 then if oracleQ4(rs) then return "PASS"
      when queryNumber = 5 then if oracleQ5(rs) then return "PASS"
      when queryNumber = 6 then if oracleQ6(rs) then return "PASS"
      when queryNumber = 7 then if oracleQ7(rs) then return "PASS"
      when queryNumber = 8 then if oracleQ8(rs) then return "PASS"
      when queryNumber = 9 then if oracleQ9(rs) then return "PASS"
      when queryNumber = 13 then if oracleQ13(rs) then return "PASS"
      when queryNumber = 15 then if oracleQ15(rs) then return "PASS"
      when queryNumber = 16 then if oracleQ16(rs) then return "PASS"
      when queryNumber = 17 then if oracleQ17(rs) then return "PASS"
      when queryNumber = 18 then if oracleQ18(rs) then return "PASS"
      when queryNumber = 19 then if oracleQ19(rs) then return "PASS"
      when queryNumber = 20 then if oracleQ20(rs) then return "PASS"
      when queryNumber = 21 then if oracleQ21(rs) then return "PASS"
      when queryNumber = 22 then if oracleQ22(rs) then return "PASS"
      when queryNumber = 24 then if oracleQ24(rs) then return "PASS"
      when queryNumber = 25 then if oracleQ25(rs) then return "PASS"
      when queryNumber = 26 then if oracleQ26(rs) then return "PASS"
      when queryNumber = 27 then if oracleQ27(rs) then return "PASS"
      when queryNumber = 28 then if oracleQ28(rs) then return "PASS"
      when queryNumber = 29 then if oracleQ29(rs) then return "PASS"
      when queryNumber = 30 then if oracleQ30(rs) then return "PASS"
      otherwise nop
    end
    return "WRONG_RESULT"  -- success without an oracle is not yet trusted
  end
  if rs~error = .Error~SQLUNSUPPORTED then return "UNSUPPORTED"
  if rs~error = .Error~SQLPARSEERROR then return "PARSE_ERROR"
  return "EXECUTION_ERROR"


oracleQ1: procedure
  use arg rs
  names = "Ada Director|Grace Lead|Alan Engineer|Katherine Eng|Dennis Research|Barbara Scientist|Linus Sales|Empty Desk|Margaret Ops"~makeArray("|")
  depts = "10 10 10 10 20 20 30 30 40"~makeArray(" ")
  salaries = "120000 95000 72000 71000 88000 69000 80000 45000 78000"~makeArray(" ")
  ranks = "1 2 3 4 1 2 1 2 1"~makeArray(" ")
  if rs~rows~items \= 9 then return .false
  do i = 1 to 9
    row = rs~rows[i]
    if row["e.full_name"] \= names[i] then return .false
    if row["e.dept_id"] \= depts[i] then return .false
    if row["e.salary"] \= salaries[i] then return .false
    if row["rn"] \= ranks[i] then return .false
    if row["rk"] \= ranks[i] then return .false
    if row["dr"] \= ranks[i] then return .false
  end
  return .true

oracleQ2: procedure
  use arg rs
  ids = "2 3 3 3 4 4 6 6 7 9"~makeArray(" ")
  dates = "2024-02-05 2024-02-05 2024-02-06 2025-01-20 2024-02-05 2025-01-21 2024-07-01 2024-07-02 2024-04-10 2024-02-06"~makeArray(" ")
  hours = "2 8 7.5 4 6 5 8 8 3 8"~makeArray(" ")
  prevs = "0 0 8 7.5 0 6 0 8 0 0"~makeArray(" ")
  nexts = "0 7.5 4 0 5 0 8 0 0 0"~makeArray(" ")
  if rs~rows~items \= 10 then return .false
  do i = 1 to 10
    row = rs~rows[i]
    if row["t.emp_id"] \= ids[i] then return .false
    if row["t.work_date"] \= dates[i] then return .false
    if abs(row["t.hours"] - hours[i]) >= 0.000001 then return .false
    if abs(row["prev_hours"] - prevs[i]) >= 0.000001 then return .false
    if abs(row["next_hours"] - nexts[i]) >= 0.000001 then return .false
  end
  return .true

oracleQ3: procedure
  use arg rs
  ids = "10 6 4 3 8 7 5 2 1"~makeArray(" ")
  salaries = "45000 69000 71000 72000 78000 80000 88000 95000 120000"~makeArray(" ")
  tiles = "1 1 1 2 2 3 3 4 4"~makeArray(" ")
  deptTotals = "125000 157000 358000 358000 78000 125000 157000 358000 358000"~makeArray(" ")
  if rs~rows~items \= 9 then return .false
  do i = 1 to 9
    row = rs~rows[i]
    if row["e.emp_id"] \= ids[i] then return .false
    if abs(row["e.salary"] - salaries[i]) >= 0.000001 then return .false
    if row["salary_quartile"] \= tiles[i] then return .false
    if abs(row["company_total"] - 718000) >= 0.000001 then return .false
    if abs(row["dept_total"] - deptTotals[i]) >= 0.000001 then return .false
  end
  return .true

oracleQ4: procedure
  use arg rs
  depts = "10 20 30 40"~makeArray(" ")
  allCounts = "5 2 2 1"~makeArray(" ")
  highCounts = "2 1 1 0"~makeArray(" ")
  payrolls = "358000 157000 125000 78000"~makeArray(" ")
  if rs~rows~items \= 4 then return .false
  do i = 1 to 4
    row = rs~rows[i]
    if row["e.dept_id"] \= depts[i] then return .false
    if row["all_emps"] \= allCounts[i] then return .false
    if row["high_earners"] \= highCounts[i] then return .false
    if abs(row["active_payroll"] - payrolls[i]) >= 0.000001 then return .false
  end
  return .true

oracleQ25: procedure
  use arg rs
  if rs~rows~items \= 1 then return .false
  row = rs~rows[1]
  if row["e.full_name"] \= "Alan Engineer" then return .false
  if row["e.dept_id"] \= 10 then return .false
  if abs(row["p.billable_hours"] - 15.5) > 0.000001 then return .false
  if abs(row["d.mean_hours"] - (23.5 / 3)) > 0.000001 then return .false
  if \rs~accessPath~startsWith("MULTI_CTE_") then return .false
  return .true

oracleQ26: procedure
  use arg rs
  depts = "10 20 30"~makeArray(" ")
  counts = "5 2 2"~makeArray(" ")
  highs = "2 1 1"~makeArray(" ")
  if rs~rows~items \= 3 then return .false
  do i = 1 to 3
    row = rs~rows[i]
    if row["e.dept_id"] \= depts[i] then return .false
    if row["n"] \= counts[i] then return .false
    if row["high_n"] \= highs[i] then return .false
  end
  return .true

oracleQ5: procedure
  use arg rs
  ids = "2 3 3 3 4 4 6 6 7 9"~makeArray(" ")
  dates = "2024-02-05 2024-02-05 2024-02-06 2025-01-20 2024-02-05 2025-01-21 2024-07-01 2024-07-02 2024-04-10 2024-02-06"~makeArray(" ")
  hours = "2 8 7.5 4 6 5 8 8 3 8"~makeArray(" ")
  running = "2 8 15.5 19.5 6 11 8 16 3 8"~makeArray(" ")
  avgs = "2 8 7.75 6.5 6 5.5 8 8 3 8"~makeArray(" ")
  if rs~rows~items \= 10 then return .false
  do i = 1 to 10
    row = rs~rows[i]
    if row["t.emp_id"] \= ids[i] then return .false
    if row["t.work_date"] \= dates[i] then return .false
    if abs(row["t.hours"] - hours[i]) >= 0.000001 then return .false
    if abs(row["running"] - running[i]) >= 0.000001 then return .false
    if abs(row["running_avg"] - avgs[i]) >= 0.000001 then return .false
  end
  return .true

oracleQ13: procedure
  use arg rs
  ids = "1 2 5 7 8 3 4 6 9 10"~makeArray(" ")
  names = "Ada Director|Grace Lead|Dennis Research|Linus Sales|Margaret Ops|Alan Engineer|Katherine Eng|Barbara Scientist|Ken Contractor|Empty Desk"~makeArray("|")
  depths = "1 2 2 2 2 3 3 3 3 3"~makeArray(" ")
  paths = "1|1/2|1/5|1/7|1/8|1/2/3|1/2/4|1/5/6|1/2/9|1/7/10"~makeArray("|")
  if rs~rows~items \= 10 then return .false
  do i = 1 to 10
    row = rs~rows[i]
    if row["emp_id"] \= ids[i] then return .false
    if row["full_name"] \= names[i] then return .false
    if row["depth"] \= depths[i] then return .false
    if row["path"] \= paths[i] then return .false
  end
  return .true

oracleQ15: procedure
  use arg rs
  names = "Ada Director|Grace Lead|Dennis Research|Linus Sales|Margaret Ops|Alan Engineer|Katherine Eng|Ken Contractor|Barbara Scientist|Empty Desk"~makeArray("|")
  managers = "N 1 1 1 1 2 2 2 5 7"~makeArray(" ")
  salaries = "120000 95000 88000 80000 78000 72000 71000 0 69000 45000"~makeArray(" ")
  if rs~rows~items \= 10 then return .false
  do i = 1 to 10
    row = rs~rows[i]
    if row["e.full_name"] \= names[i] then return .false
    if managers[i] = "N" then do
      if row["e.manager_id"] \== .nil then return .false
    end
    else if row["e.manager_id"] \= managers[i] then return .false
    if abs(row["e.salary"] - salaries[i]) >= 0.000001 then return .false
  end
  return .true

oracleQ6: procedure
  use arg rs
  dept = .array~of(.nil,10,10,10,20,20,30,30,40,40)
  active = .array~of(.nil,.nil,"FALSE","TRUE",.nil,"TRUE",.nil,"TRUE",.nil,"TRUE")
  counts = "10 5 1 4 2 2 2 2 1 1"~makeArray(" ")
  payroll = "718000 358000 0 358000 157000 157000 125000 125000 78000 78000"~makeArray(" ")
  if rs~rows~items \= 10 then return .false
  if rs~accessPath \= "OLAP_GROUPING_TABLE_SCAN" then return .false
  do i = 1 to 10
    row = rs~rows[i]
    if row["e.dept_id"] \== dept[i] then return .false
    if row["e.active"] \== active[i] then return .false
    if row["n"] \= counts[i] then return .false
    if abs(row["payroll"] - payroll[i]) > 0.000001 then return .false
  end
  return .true

oracleQ7: procedure
  use arg rs
  locations = .array~of(.nil,"Edinburgh","Edinburgh","Glasgow","Glasgow","London","London","Manchester","Manchester")
  dept = .array~of(.nil,.nil,20,.nil,10,.nil,30,.nil,40)
  counts = "10 2 2 5 5 2 2 1 1"~makeArray(" ")
  if rs~rows~items \= 9 then return .false
  if rs~accessPath \= "OLAP_GROUPING_INNER_HASH_CHAIN" then return .false
  do i = 1 to 9
    row = rs~rows[i]
    if row["d.location"] \== locations[i] then return .false
    if row["e.dept_id"] \== dept[i] then return .false
    if row["n"] \= counts[i] then return .false
  end
  return .true

oracleQ8: procedure
  use arg rs
  dept = .array~of(.nil,.nil,.nil,10,10,10,20,20,30,30,40,40)
  active = .array~of(.nil,"FALSE","TRUE",.nil,"FALSE","TRUE",.nil,"TRUE",.nil,"TRUE",.nil,"TRUE")
  counts = "10 1 9 5 1 4 2 2 2 2 1 1"~makeArray(" ")
  if rs~rows~items \= 12 then return .false
  if rs~accessPath \= "OLAP_GROUPING_TABLE_SCAN" then return .false
  do i = 1 to 12
    row = rs~rows[i]
    if row["e.dept_id"] \== dept[i] then return .false
    if row["e.active"] \== active[i] then return .false
    if row["n"] \= counts[i] then return .false
  end
  return .true

oracleQ9: procedure
  use arg rs
  ids = "3 6 4 9 7 2"~makeArray(" ")
  totals = "19.5 16 11 8 3 2"~makeArray(" ")
  ranks = "1 2 3 4 5 6"~makeArray(" ")
  if rs~rows~items \= 6 then return .false
  do i = 1 to 6
    row = rs~rows[i]
    if row["x.emp_id"] \= ids[i] then return .false
    if abs(row["x.total_hours"] - totals[i]) >= 0.000001 then return .false
    if row["hours_rank"] \= ranks[i] then return .false
  end
  return .true

oracleQ16: procedure
  use arg rs
  names = "Ada Director|Grace Lead|Dennis Research"~makeArray("|")
  salaries = "120000 95000 88000"~makeArray(" ")
  if rs~rows~items \= 3 then return .false
  do i = 1 to 3
    row = rs~rows[i]
    if row["e.full_name"] \= names[i] then return .false
    if abs(row["e.salary"] - salaries[i]) >= 0.000001 then return .false
  end
  return .true

oracleQ17: procedure
  use arg rs
  ids = "3 4 99"~makeArray(" ")
  notes = "review promote missing"~makeArray(" ")
  names = "Alan Engineer|Katherine Eng|<NULL>"~makeArray("|")
  if rs~rows~items \= 3 then return .false
  do i = 1 to 3
    row = rs~rows[i]
    if row["v.emp_id"] \= ids[i] then return .false
    if row["v.note"] \= notes[i] then return .false
    if names[i] = "<NULL>" then do
      if row["e.full_name"] \== .nil then return .false
    end
    else if row["e.full_name"] \= names[i] then return .false
  end
  return .true

oracleQ18: procedure
  use arg rs
  assignmentIds = "1 2 3 10 4 5 6 7 8 9"~makeArray(" ")
  empIds = "1 2 3 3 4 4 5 6 7 8"~makeArray(" ")
  names = "Ada Director|Grace Lead|Alan Engineer|Alan Engineer|Katherine Eng|Katherine Eng|Dennis Research|Barbara Scientist|Linus Sales|Margaret Ops"~makeArray("|")
  if rs~rows~items \= 10 then return .false
  if rs~accessPath \= "NATURAL_HASH_JOIN" then return .false
  do i = 1 to 10
    row = rs~rows[i]
    if row["assignment_id"] \= assignmentIds[i] then return .false
    if row["emp_id"] \= empIds[i] then return .false
    if row["full_name"] \= names[i] then return .false
    -- emp_id is the one common column and must appear only once in SELECT *.
    if row~values~allIndexes~items \= 12 then return .false
  end
  return .true

oracleQ19: procedure
  use arg rs
  ids = "1 2 3 4 9"~makeArray(" ")
  names = "Ada Director|Grace Lead|Alan Engineer|Katherine Eng|Ken Contractor"~makeArray("|")
  if rs~rows~items \= 5 then return .false
  do i = 1 to 5
    row = rs~rows[i]
    if row["emp_id"] \= ids[i] then return .false
    if row["full_name"] \= names[i] then return .false
  end
  if rs~accessPath \= "UNION_CORRESPONDING" then return .false
  return .true

oracleQ20: procedure
  use arg rs
  names = "Ada Director|Alan Engineer|Grace Lead|Katherine Eng"~makeArray("|")
  roles = "Sponsor|Engineer|Lead|Engineer"~makeArray("|")
  if rs~rows~items \= 4 then return .false
  do i = 1 to 4
    row = rs~rows[i]
    if row["e.full_name"] \= names[i] then return .false
    if row["p.title"] \= "Hyperdrive" then return .false
    if row["a.role"] \= roles[i] then return .false
  end
  return .true

oracleQ21: procedure
  use arg rs
  if rs~affectedRows \= 4 then return .false
  if rs~rows~items \= 0 then return .false
  if rs~accessPath \= "UPDATE_FROM_NESTED_LOOP" then return .false
  return .true

oracleQ22: procedure
  use arg rs
  if rs~affectedRows \= 1 then return .false
  if rs~rows~items \= 0 then return .false
  if rs~accessPath \= "DELETE_USING_NESTED_LOOP" then return .false
  return .true

oracleQ24: procedure
  use arg rs
  if rs~rows~items \= 1 then return .false
  row = rs~rows[1]
  if row["dept_id"] \= 40 then return .false
  if abs(row["median_salary"] - 78000) >= 0.000001 then return .false
  return .true

oracleQ27: procedure
  use arg rs
  names = "Ada Director|Dennis Research|Linus Sales|Margaret Ops"~makeArray("|")
  salaries = "132000 88000 80000 78000"~makeArray(" ")
  if rs~rows~items \= 4 then return .false
  do i = 1 to 4
    row = rs~rows[i]
    if row["full_name"] \= names[i] then return .false
    if abs(row["salary"] - salaries[i]) >= 0.000001 then return .false
    if row["dept_rank"] \= 1 then return .false
  end
  return .true

oracleQ28: procedure
  use arg rs
  ids = "3 4 9"~makeArray(" ")
  if rs~rows~items \= 3 then return .false
  do i = 1 to 3
    row = rs~rows[i]
    if row["id"] \= ids[i] then return .false
    -- CORRESPONDING BY(id) exposes only the selected corresponding column.
    if row~values~allIndexes~items \= 1 then return .false
  end
  if rs~accessPath \= "SET_EXCEPT_CORRESPONDING" then return .false
  return .true

oracleQ29: procedure
  use arg rs
  names = "Alan Engineer|Barbara Scientist|Katherine Eng|Linus Sales|Grace Lead|Ada Director|Dennis Research|Empty Desk|Margaret Ops"~makeArray("|")
  assignments = "2 1 2 1 1 1 1 0 1"~makeArray(" ")
  avgs = "22.5 40 17.5 20 30 4 25 N 10"~makeArray(" ")
  logged = "19.5 16 11 3 2 0 0 0 0"~makeArray(" ")
  if rs~rows~items \= 9 then return .false
  do i = 1 to 9
    row = rs~rows[i]
    if row["e.full_name"] \= names[i] then return .false
    if row["assignments"] \= assignments[i] then return .false
    if avgs[i] = "N" then do
      if row["avg_awarded"] \== .nil then return .false
    end
    else if abs(row["avg_awarded"] - avgs[i]) >= 0.000001 then return .false
    if abs(row["logged"] - logged[i]) >= 0.000001 then return .false
  end
  return .true

oracleQ30: procedure
  use arg rs
  ids = "2 3 4 6 7 9"~makeArray(" ")
  salary = "8000 12000 11800 5750 6666.67 0"~makeArray(" ")
  bonus = "1000 500 0 0 0 0"~makeArray(" ")
  contract = "0 0 0 0 0 2000"~makeArray(" ")
  if rs~rows~items \= 6 then return .false
  do i = 1 to 6
    row = rs~rows[i]
    if row["emp_id"] \= ids[i] then return .false
    if abs(row["salary_paid"] - salary[i]) >= 0.000001 then return .false
    if abs(row["bonus_paid"] - bonus[i]) >= 0.000001 then return .false
    if abs(row["contract_paid"] - contract[i]) >= 0.000001 then return .false
  end
  return .true

::requires "../src/NoSQLServer.cls"
::requires "TestSupport.cls"
