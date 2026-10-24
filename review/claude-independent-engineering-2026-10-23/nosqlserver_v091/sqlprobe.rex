/* Probe: NoSQLServer v0.91 SQLiteWritableDatabaseEngine - keyed lookup cost and byte fidelity. Claude (Opus 5.5). */
signal on syntax name onSyntax
path = directory() || "/probe.sqlite"
sql = .NoSQLServerSQL~new(.SQLiteWritableDatabaseEngine~create(path))
call x "CREATE TABLE t (k TEXT PRIMARY KEY, o TEXT, v TEXT)"
nl = "0a"x; cr = "0d"x
crlf = "::method x" || cr || nl || "  return 1" || cr || nl
call x "INSERT INTO t (k,o,v) VALUES ('crlf','c'," || q(crlf) || ")"
got = col(sql~execute("SELECT v FROM t WHERE k='crlf'")~rows[1], "v")
say "CRLF preserved:" (got == crlf) "len" got~length
call x "UPDATE t SET v='3*4' WHERE k='crlf'"
say "UPDATE literal '3*4' ->" col(sql~execute("SELECT v FROM t WHERE k='crlf'")~rows[1], "v")
rs = sql~execute("SELECT k FROM t WHERE k IN ('crlf','zz')"); say "IN list:" rs~status rs~message
do n over .array~of(250, 1000)
  call time "R"
  do i = 1 to n; call x "INSERT INTO t (k,o,v) VALUES ('k"i"_"n"','o"i"_"n"','" || copies("x", 200) || "')"; end
  say "inserted" n "rows in" format(time("E"),,1) "s ("format(time("E")/n*1000,,1) "ms/row)"
  call time "R"; do j = 1 to 20; rs = sql~execute("SELECT v FROM t WHERE k='k"j"_"n"'"); end
  say "  primary-key lookup" format(time("E")/20,,4) "s  rows="rs~rows~items "access="rs~accessPath
end
exit 0
col: procedure; use arg row, name; v = row[name]; if v == .nil then v = row[name~upper]; if v == .nil then return ""; return v
q: return "'" || arg(1)~changestr("'", "''") || "'"
x: parse arg s; r = sql~execute(s); if r~status \= "SUCCESS" then say "FAIL" s~left(60) r~status r~message; return
onSyntax: say "SYNTAX rc="rc "sigl="sigl condition("D"); co = condition("O"); if co~hasIndex("ADDITIONAL") then do e over co["ADDITIONAL"]; say " A=" || e; end; exit 1
::requires "NoSQLServerSQLiteWritable.cls"
