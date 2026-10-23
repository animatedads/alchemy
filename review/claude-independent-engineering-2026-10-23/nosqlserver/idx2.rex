root = directory() || "/idx2"; call SysMkDir root
eng = .FileDatabaseEngine~new(root)
call x "CREATE TABLE t (k VARCHAR PRIMARY KEY, o VARCHAR, v VARCHAR)"
call time "R"
do i = 1 to 600; call x "INSERT INTO t (k,o,v) VALUES ('k"i"','o"i"','" || copies("x", 200) || "')"; end
say "FileDatabaseEngine inserted 600 in" format(time("E"),,1) "s"
call time "R"; do j = 1 to 30; rs = eng~execute("SELECT v FROM t WHERE k='k"j"'"); end
say "  pk lookup" format(time("E")/30,,4) "s  access=" rs~accessPath
call time "R"; do j = 1 to 30; rs = eng~execute("SELECT v FROM t WHERE o='o"j"'"); end
say "  col lookup" format(time("E")/30,,4) "s  access=" rs~accessPath
exit
x: parse arg s; r = eng~execute(s); if r~status \= "SUCCESS" then say "FAIL" s~left(60) r~message; return
::requires "NoSQLServer.cls"
