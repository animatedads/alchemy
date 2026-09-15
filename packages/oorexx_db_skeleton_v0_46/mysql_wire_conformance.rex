parse arg host port databaseName userName executable tableName disabledCaps

if host = "" then do
  say "usage: rexx mysql_wire_conformance.rex host port database user mysql-or-mariadb dedicated_table [disabled-capabilities]"
  say "This runner mutates ONLY the supplied dedicated table."
  exit 64
end

if port = "" then port = 3306
if executable = "" then executable = "mysql"
if tableName = "" then do
  say "MYSQL WIRE CONFORMANCE: dedicated table name required"
  exit 64
end

first = tableName~substr(1,1)
if \first~datatype("A") then do
  if first <> "_" then do
    say "MYSQL WIRE CONFORMANCE: invalid table name"
    exit 64
  end
end
do i = 2 to tableName~length
  ch = tableName~substr(i,1)
  if \ch~datatype("A") then do
    if \ch~datatype("N") then do
      if ch <> "_" then do
        say "MYSQL WIRE CONFORMANCE: invalid table name"
        exit 64
      end
    end
  end
end

conn = .DatabaseConnection~new(host, port, databaseName, userName, .nil, "mysql")
engine = .MySQLEngine~new
endpoint = .DatabaseEndpointCapabilities~new(engine~capabilities)

if disabledCaps <> "" then do
  caps = disabledCaps~makeArray(",")
  do cap over caps
    cap = cap~strip~upper
    if cap <> "" then ignore = endpoint~disable(cap)
  end
end

resolver = .DatabaseExecutableResolver~new
ignore = resolver~setOverride("mysql", executable)
db = .Database~new(conn, engine, .DatabaseProcessCommandExecutor~new, resolver, endpoint)

say "MYSQL WIRE CONFORMANCE"
id = db~endpointIdentity
say "identity:" id~product id~rawVersion

passed = 0
failed = 0
skipped = 0

cleanup = db~execute("DELETE FROM " || tableName || " WHERE id = 900001")

qr = db~query("SELECT 1 AS probe_value")
if qr~isA(.DatabaseQueryResult) then do
  if qr~rowCount = 1 then do
    if qr~rows[1]~rawAt("probe_value") = "1" then do
      say "PASS basic_query"
      passed += 1
    end
    else do
      say "FAIL basic_query wrong value"
      failed += 1
    end
  end
  else do
    say "FAIL basic_query wrong row count"
    failed += 1
  end
end
else do
  say "FAIL basic_query" qr~status qr~error
  failed += 1
end

if db~supports(.DatabaseCapability~TRANSACTIONS) then do
  tx = db~transaction
  ignore = tx~execute("INSERT INTO " || tableName || " (id, value) VALUES (900001, 11)")
  rs = tx~commit
  if rs~status = .Error~SUCCESS then do
    check = db~query("SELECT value FROM " || tableName || " WHERE id = 900001")
    if check~rowCount = 1 then do
      if check~rows[1]~rawAt("value") = "11" then do
        say "PASS transaction_commit"
        passed += 1
      end
      else do
        say "FAIL transaction_commit wrong state"
        failed += 1
      end
    end
    else do
      say "FAIL transaction_commit missing row"
      failed += 1
    end
  end
  else do
    say "FAIL transaction_commit" rs~status rs~error
    failed += 1
  end

  tx2 = db~transaction
  ignore = tx2~execute("UPDATE " || tableName || " SET value = 12 WHERE id = 900001")
  rr = tx2~rollback
  if rr~status = .Error~NOTEXECUTED then do
    check2 = db~query("SELECT value FROM " || tableName || " WHERE id = 900001")
    if check2~rows[1]~rawAt("value") = "11" then do
      say "PASS rollback_before_commit"
      passed += 1
    end
    else do
      say "FAIL rollback_before_commit changed state"
      failed += 1
    end
  end
  else do
    say "FAIL rollback_before_commit" rr~status rr~error
    failed += 1
  end
end
else do
  say "SKIP transaction_commit capability"
  say "SKIP rollback_before_commit capability"
  skipped += 2
end

if db~supports(.DatabaseCapability~PREPAREDSTATEMENTS) then do
  tx3 = db~transaction
  ps = tx3~prepareStatement("wire_u", "UPDATE " || tableName || " SET value = ? WHERE id = ?")
  params = .DatabaseParameterSet~new
  ignore = params~add(.DatabaseParameter~new("13", "integer"))
  ignore = params~add(.DatabaseParameter~new("900001", "integer"))
  ignore = tx3~executePrepared(ps, params)
  prs = tx3~commit
  if prs~status = .Error~SUCCESS then do
    check3 = db~query("SELECT value FROM " || tableName || " WHERE id = 900001")
    if check3~rows[1]~rawAt("value") = "13" then do
      say "PASS prepared_statement"
      passed += 1
    end
    else do
      say "FAIL prepared_statement wrong state"
      failed += 1
    end
  end
  else do
    say "FAIL prepared_statement" prs~status prs~error
    failed += 1
  end
end
else do
  say "SKIP prepared_statement capability"
  skipped += 1
end

if db~supports(.DatabaseCapability~MUTATIONRESULTS) then do
  tx4 = db~transaction
  ignore = tx4~execute("UPDATE " || tableName || " SET value = 14 WHERE id = 900001")
  mrs = tx4~commit
  if mrs~status = .Error~SUCCESS then do
    if mrs~mutationResults~items > 0 then do
      if mrs~mutationResults[1]~affectedRows = 1 then do
        say "PASS mutation_results"
        passed += 1
      end
      else do
        say "FAIL mutation_results affectedRows"
        failed += 1
      end
    end
    else do
      say "FAIL mutation_results missing"
      failed += 1
    end
  end
  else do
    say "FAIL mutation_results" mrs~status mrs~error
    failed += 1
  end
end
else do
  say "SKIP mutation_results capability"
  skipped += 1
end

if db~supports(.DatabaseCapability~GENERATEDKEYS) then do
  say "SKIP generated_keys live table contract not configured"
  skipped += 1
end
else do
  say "SKIP generated_keys capability"
  skipped += 1
end

cleanup = db~execute("DELETE FROM " || tableName || " WHERE id = 900001")

say "SUMMARY PASS=" || passed "FAIL=" || failed "SKIP=" || skipped
if failed > 0 then do
  say "MYSQL WIRE CONFORMANCE: FAILED"
  exit 9
end

say "MYSQL WIRE CONFORMANCE: OK"
exit 0

::requires "database_core.cls"
