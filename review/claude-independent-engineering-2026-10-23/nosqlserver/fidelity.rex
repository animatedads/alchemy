/* Probe: does NoSQLServer v0.79 store source text byte-exactly? Claude (Opus 5.5). */
signal on syntax name onSyntax
root = directory() || "/fid"
call SysMkDir root
sql = .NoSQLServerSQL~new(.FederatedDatabaseEngine~new(root))
call chk sql~execute("CREATE TABLE t (k VARCHAR PRIMARY KEY, v VARCHAR, n INTEGER)"), "create"
nl = "0a"x; cr = "0d"x; tab = "09"x
cases = .array~new
cases~append("simple")
cases~append("line1" || nl || "line2" || nl)
cases~append("::method x" || cr || nl || "  return 1" || cr || nl)
cases~append("a|b|c" || tab || "d")
cases~append("it's ""quoted"" \n \\ backslash")
cases~append("café ünï 日本")
cases~append("  leading and trailing spaces   ")
cases~append("")
cases~append("0"x || "nul inside")
cases~append(copies("::method m" || nl || "  x = 'v|' || ""q""" || tab || nl, 400))   -- ~12 KB
ok = 0
do i = 1 to cases~items
  v = cases[i]
  call chk sql~execute("INSERT INTO t (k,v,n) VALUES ('k" || i || "'," || q(v) || "," || i || ")"), "insert" i
  rs = sql~execute("SELECT v FROM t WHERE k='k" || i || "'")
  call chk rs, "select" i
  got = rs~rows[1]["V"]
  if got == .nil then got = rs~rows[1]["v"]
  if got == v then do; ok += 1; say "OK    case" i "len="v~length; end
  else say "DIFF  case" i "len="v~length "got_len="length(got) "want="c2x(left(v,24)) "got="c2x(left(got,24))
end
say "fidelity:" ok "of" cases~items
exit 0
q: return "'" || arg(1)~changestr("'", "''") || "'"
chk: procedure
  use arg rs, what
  if rs~status \= "SUCCESS" then do; say "SQL FAIL" what rs~status rs~message; exit 2; end
  return
onSyntax:
  say "SYNTAX rc="rc "sigl="sigl "C="condition("C") "D="condition("D"); exit 1
::requires "NoSQLServer.cls"
