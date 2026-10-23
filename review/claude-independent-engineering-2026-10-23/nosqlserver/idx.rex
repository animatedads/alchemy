/* Probe: keyed lookup cost vs table size on NoSQLServer v0.79, with and without CREATE INDEX. */
root = directory() || "/idx"; call SysMkDir root
sql = .NoSQLServerSQL~new(.FederatedDatabaseEngine~new(root))
call x "CREATE TABLE t (k VARCHAR PRIMARY KEY, o VARCHAR, v VARCHAR)"
call x "CREATE TABLE u (k VARCHAR PRIMARY KEY, o VARCHAR, v VARCHAR)"
rs = sql~execute("CREATE INDEX u_o ON u (o)"); say "CREATE INDEX:" rs~status rs~message
do n over .array~of(250, 1000)
  call time "R"
  do i = 1 to n
    call x "INSERT INTO t (k,o,v) VALUES ('k"i"_"n"','o"i"_"n"','" || copies("x", 200) || "')"
    call x "INSERT INTO u (k,o,v) VALUES ('k"i"_"n"','o"i"_"n"','" || copies("x", 200) || "')"
  end
  say "inserted" n "rows/table in" format(time("E"),,1) "s"
  call time "R"; do j = 1 to 50; rs = sql~execute("SELECT v FROM t WHERE k='k"j"_"n"'"); end; pk = time("E") / 50
  call time "R"; do j = 1 to 50; rs = sql~execute("SELECT v FROM t WHERE o='o"j"_"n"'"); end; nonidx = time("E") / 50
  call time "R"; do j = 1 to 50; rs = sql~execute("SELECT v FROM u WHERE o='o"j"_"n"'"); end; idx = time("E") / 50
  say "  per lookup: primary-key" format(pk,,4) "s | unindexed column" format(nonidx,,4) "s | indexed column" format(idx,,4) "s  (" rs~accessPath ")"
end
exit
x: parse arg s; r = sql~execute(s); if r~status \= "SUCCESS" then say "FAIL" s~left(60) r~message; return
::requires "NoSQLServer.cls"
