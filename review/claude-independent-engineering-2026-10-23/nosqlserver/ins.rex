root = directory() || "/ins"; call SysMkDir root
sql = .NoSQLServerSQL~new(.FederatedDatabaseEngine~new(root))
call x "CREATE TABLE t (k VARCHAR PRIMARY KEY, v VARCHAR)"
vals = .array~of("12-34", "a-b", "3*4", "6/2", "1+1", "abc_def", "x||y", "ssr_f96058f2", "ssrf96058f2", "NULL", "2026-10-23T17:00:00", "-5", "1e3", "0x10", "(1)")
i = 0
do v over vals
  i += 1
  rs = sql~execute("INSERT INTO t (k,v) VALUES ('k" || i || "','" || v || "')")
  got = sql~execute("SELECT v FROM t WHERE k='k" || i || "'")~rows
  g = "(none)"; if got~items > 0 then g = got[1]["v"]
  u = sql~execute("UPDATE t SET v='" || v || "' WHERE k='k" || i || "'")
  g2 = sql~execute("SELECT v FROM t WHERE k='k" || i || "'")~rows[1]["v"]
  say left(v,22) "INSERT:" left(rs~status,8) "->" left(g,22) "UPDATE:" left(u~status,11) "->" g2
end
exit
x: parse arg s; rs = sql~execute(s); if rs~status \= "SUCCESS" then say "FAIL" s rs~message; return
::requires "NoSQLServer.cls"
