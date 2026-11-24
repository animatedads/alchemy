/* test_dev9.rex - read, line edit / amend, lint and check (source editor v0.1-dev9)
   Architecture: Tom Dyer. Code: Claude (Opus 5.5).
   Run from the package root with AtomicFile on REXX_PATH (tests/run_tests.sh does it). */
call rxfuncadd 'SysLoadFuncs', 'rexxutil', 'SysLoadFuncs'
call SysLoadFuncs
base = directory()
tmp = base'/tests/.tmp-dev9'
call SysFileTree tmp'/*', 'old.', 'FO'
do i = 1 to old.0; call SysFileDelete old.i; end
call SysMkDir tmp
signal on syntax name failed
nl = '0a'x
cli = 'rexx' base'/bin/code-editor.rex'

/* --- lint ------------------------------------------------------------- */
bad = tmp'/pitfalls.rex'
call put bad, 'x = 1'||nl||'call obj~go'||nl||'result = 4'||nl||'say "result = 1" -- result = 3'||nl||'a = "a"(b)'||nl||'if rc == 0 then nop'
d = .SourceDocument~new(bad)
call assertEq 'oorexx', d~language, 'language oorexx'
f = d~lint
call assertEq 3, f~items, 'lint finds three pitfalls'
call assertEq 'P7 2', f[1]~rule f[1]~line, 'P7 call x~y on line 2'
call assertEq 'P9 3', f[2]~rule f[2]~line, 'P9 result= on line 3 (not the string, not the comment, not rc ==)'
call assertEq 'P1 5', f[3]~rule f[3]~line, 'P1 "a"(b) on line 5'

/* --- check ------------------------------------------------------------ */
good = tmp'/good.rex'
call put good, '::requires "Missing.cls"'||nl||'say 1'||nl||'::class Thing subclass NotHere'||nl||'::method go'||nl||'  return 1'
r = .SourceDocument~new(good)~check
call assertTrue r~ok, 'check: compiles with a missing ::requires and an unknown superclass'
call assertEq 2, r~dependencies~items, 'check: both reported as dependencies, not syntax'
call assertTrue .SourceDocument~new(good)~validate, 'validate uses check for ooRexx'
broken = tmp'/broken.rex'
call put broken, 'say 1'||nl||'do i = 1 to 3'||nl||'  say i'
r = .SourceDocument~new(broken)~check
call assertEq '0 14.5 3', (r~ok + 0) r~code r~line, 'check: missing END reported as 14.5 at line 3'
call assertTrue \.SourceDocument~new(broken)~validate, 'validate is false for a file that does not compile'
r = .SourceDocument~new(base'/src/SourceEditor.cls')~check
call assertTrue r~ok, 'check: the editor itself compiles'
call assertEq 0, .SourceDocument~new(base'/src/SourceEditor.cls')~lint~items, 'lint: the editor itself is clean (P9 result renamed)'

/* --- amend ------------------------------------------------------------ */
am = tmp'/amend.rex'
call put am, 'a = 1'||nl||'b = 2'||nl||'c = 3'||nl||'say a b c'
d = .SourceDocument~new(am)
old = d~amend(2, 3, 'b = 20'||nl||'c = 30'||nl||'e = 5')
call assertEq 'b = 2|c = 3', old~makeString('L', '|'), 'amend returns the replaced lines'
call assertEq 5, d~lineCount, 'amend 2 lines with 3'
old = d~amend(1, 0, '/* top */')
call assertEq 0, old~items, 'amend FIRST FIRST-1 inserts'
call assertEq '/* top */', d~line(1), 'amend insert at the top'
old = d~amend(d~lineCount + 1, d~lineCount, 'exit 0')
call assertEq 'exit 0', d~line(d~lineCount), 'amend insert after the last line'
d~saveChecked
call assertTrue .SourceEditorUtil~readAll(am)~pos('c = 30') > 0, 'saveChecked publishes a compiling edit'

/* --- saveChecked refuses an edit that breaks a compiling file --------- */
d = .SourceDocument~new(am)
d~replaceLine(2, 'do forever')
refused = 0
signal on syntax name refusedEdit
d~saveChecked
signal on syntax name failed
call assertTrue .false, 'saveChecked refused a breaking edit'
refusedEdit:
signal on syntax name failed
call assertTrue condition('O')~message~pos('edit refused') > 0 | condition('D')~pos('edit refused') > 0, 'saveChecked refused a breaking edit'
call assertTrue .SourceEditorUtil~readAll(am)~pos('do forever') = 0, 'the broken text was not written'
/* a file that was already broken may still be edited (that is how it gets fixed) */
d = .SourceDocument~new(broken)
d~insertAfter(3, 'end')
d~saveChecked
call assertTrue .SourceDocument~new(broken)~check~ok, 'saveChecked lets a broken file be fixed'

/* --- code projection for ooRexx --------------------------------------- */
cp = tmp'/proj.rex'
call put cp, 'x = 1 -- needle in a comment'||nl||'y = "needle in a string"'||nl||'/* needle /* nested */ needle */ z = 2'||nl||'needle = 3'
m = .SourceDocument~new(cp)~find('needle', 'code')
/* code mode ignores comments only (README: strings stay visible) */
call assertEq 2, m~items, 'code mode: -- and nested /* */ comments ignored for ooRexx'
call assertEq '2 4', m[1]~lineNumber m[2]~lineNumber, 'code mode: the string and the code needle remain'

/* --- CLI -------------------------------------------------------------- */
cf = tmp'/cli.rex'
call put cf, 'a = 1'||nl||'say a'
call run cli 'insert-before' cf 1 q('/* head */')
call assertEq 0, rc, 'cli insert-before'
call run cli 'insert-after' cf 3 q('exit 0')
call assertEq 0, rc, 'cli insert-after'
call put tmp'/new.txt', 'a = 2'||nl||'b = 3'
call run cli 'amend' cf '2 2 --from' tmp'/new.txt'
call assertEq 0, rc, 'cli amend --from'
call assertTrue out~pos('- a = 1') > 0 & out~pos('AMENDED') > 0, 'cli amend shows the replaced line'
call assertEq '/* head */|a = 2|b = 3|say a|exit 0', .SourceDocument~new(cf)~lines~makeString('L', '|'), 'cli edits land in order'
call run cli 'check' cf
call assertEq 0, rc, 'cli check ok'
call run cli 'lint' cf
call assertEq 0, rc, 'cli lint clean'
call run cli 'lint' bad
call assertEq 1, rc, 'cli lint exit 1 on findings'
call assertTrue out~pos('FINDINGS 3') > 0, 'cli lint counts'
call run cli 'check' tmp'/syntax.rex'
call assertEq 2, rc, 'cli check of a missing file is an error (2)'
call put tmp'/syntax.rex', 'x = (1 +'
call run cli 'check' tmp'/syntax.rex'
call assertEq 1, rc, 'cli check exit 1 on a syntax error'
call assertTrue out~pos('SYNTAX 35') > 0, 'cli check names the error'
call run cli 'amend' cf 2 2 q('do forever')
call assertEq 2, rc, 'cli amend that breaks the file is refused'
call assertTrue .SourceEditorUtil~readAll(cf)~pos('do forever') = 0, 'cli refused edit not written'
call run cli 'grep' cf q('?ead')
call assertTrue out~pos('MATCHES 1') > 0, 'cli grep: ? is any one character in rxregexp'
call run cli 'grep' cf q('[[:digit:]]')
call assertTrue out~pos('MATCHES 3') > 0, 'cli grep: [[:digit:]] (lines 2, 3 and 5)'
say 'PASS ooRexx source editor dev9 (read, line edit / amend, lint, check)'
exit 0

failed:
  c = condition('O'); say 'FAIL syntax:' c~code c~message 'line' c~position condition('D')
  exit 1

/* a text argument for the CLI, quoted for the CLI ("...") and for the shell ('...') */
q: procedure
  use arg text
  return "'"'"'text'"'"'"

put: procedure
  use arg path, text
  s = .Stream~new(path); s~open('write replace'); s~charOut(text'0a'x); s~close
  return

run:
  parse arg command
  o = tmp'/cli.out'
  address system command '>' o '2>&1'
  out = .Stream~new(o)~charIn(1, .Stream~new(o)~chars)
  if out == '' then out = ''
  return

assertEq:
  use arg expected, actual, label
  if expected \= actual then do; say 'FAIL' label 'expected='expected 'actual='actual; exit 1; end
  say 'PASS' label
  return
assertTrue:
  use arg value, label
  if \value then do; say 'FAIL' label; exit 1; end
  say 'PASS' label
  return
::requires "SourceEditor.cls"
