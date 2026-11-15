/* check_checker.rex - RexxPitfallChecker as an editor asks it: each finding's
   rule, line and column; P1 and P2 fixed and then clean; P3 and P4 found
   with no fix; a ::RESOURCE's text left alone, with ::END or its own END.
   Architecture: Tom Dyer. Code: Claude (Opus 5.5).
   usage: rexx tests/check_checker.rex     (exit 0 when all pass) */
fails = 0
checks = 0
c = .RexxPitfallChecker~new
bad = .array~of("/* each line below is a trap */", -
  "phrase = '""'('the' x)'""'", -
  "call out '  UNREAD  'x", -
  "uNp = 1; unP = 2", -
  "f: procedure", -
  "  use arg en, ids", -
  "  do en over ids", -
  "  end", -
  "  return")
found = c~check(bad)
rules = ""
do p over found
  rules = rules p~rule"@"p~line":"p~column
end
call check "four findings, each where it is:" rules, rules~strip == "P1@2:13 P2@3:22 P3@4:10 P4@7:6"
call check "P1 and P2 have a fix, P3 and P4 none", found[1]~fixAt > 0 & found[2]~fixAt > 0 & found[3]~fixAt = 0 & found[4]~fixAt = 0
call check "P3 names both spellings", found[3]~names~makeString("L", " ") == "unP uNp"
fixed = c~fix(bad, found[1])
call check "P1 fixed:" fixed[2], fixed[2] == "phrase = '""' || ('the' x)'""'"
fixed = c~fix(fixed, c~check(fixed)[1])
call check "P2 fixed:" fixed[3], fixed[3] == "call out '  UNREAD  ' || x"
left = ""
do p over c~check(fixed)
  left = left p~rule
end
call check "after both fixes only P3 and P4 are left", left~strip == "P3 P4"
call check "a finding with no fix leaves the lines", c~fix(bad, found[3]) == bad
res = .array~of("say 'hi'", "::resource help", "Edit = edit it", "EDIT = EDIT", "::END", -
  "::resource more END ""---""", "uNp unP", "---", "x = 1")
call check "the text of a ::RESOURCE is not code", c~check(res)~items = 0
res~append("uNp = 1; unP = 2")
call check "  but code after it is", c~check(res)~items = 1
call check "report: the command's lines", c~report("bad.rex", bad)[1] == "bad.rex:2: P1 string followed by ""("" is a routine call: phrase = '""'('the' x)'""'"
call check "module_version", .RexxPitfallChecker~module_version == "0.23" & c~module_version == "0.23"
say "check_checker:" checks - fails "of" checks "checks passed"
exit fails > 0

check: procedure expose fails checks
  use arg ckLabel, ckOk
  checks = checks + 1
  if ckOk then say "  ok  " ckLabel
  else do
    say "  FAIL" ckLabel
    fails = fails + 1
  end
  return

::requires "PitfallChecker.cls"
