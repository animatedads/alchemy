/* test_python_gate.rex -- acceptance for oorexx_python_gate v0.1.
 * Architecture: Tom Dyer.  Coding: Claude (Opus 5.5), 2026-11-14.
 * Builds each fixture package in a fresh temporary directory and runs the gate.
 */
base = value("TMPDIR",, "ENVIRONMENT")
if base == "" then base = "/tmp"
base = base"/python_gate_test_"date("S")time("S")random(1, 99999)
call mkdirs base
passed = 0
failed = 0

/* 1. A clean ooRexx package passes. */
p = fixture("clean")
call put p"/main.rex", 'say "hello"'
call put p"/lib/Thing.cls", '::class Thing public'
r = gate(p)
call check r["status"] == "PASS", "clean ooRexx package passes"
call check r["python"]~items == 0, "clean package lists no Python"

/* 2. Tom's parody: Rexx shelling out to a Python script fails. */
p = fixture("parody")
call put p"/rexx.app.rex", '/* Complex rexx.app */', '"python3 codehehe.py"', 'Say "I told you it was rexx"'
call put p"/codehehe.py", 'print("hehe")'
r = gate(p)
call check r["status"] == "FAIL", "Rexx wrapper around a Python script fails"
call check r["calls"]~items == 1, "the python3 call is reported"
call check r["calls"][1]["line"] == 2, "call reported on line 2"
call check kinds(r) == "python-source python-call", "both the .py and its caller need justification"

/* 3. A .py with a proper justification passes, and the reason is reported. */
p = fixture("justified")
call put p"/tools/bridge.py", 'import thing'
call put p"/PYTHON_JUSTIFICATION", '# path | reason', -
  'tools/bridge.py | wraps the vendor SDK which ships only a Python client and no C API or wire specification'
r = gate(p)
call check r["status"] == "PASS", "justified .py passes"
call check r["python"][1]["justified"]~value == .true, "entry marked justified"
call check r["python"][1]["reason"]~pos("vendor SDK") > 0, "reason carried into report"

/* 4. A one-line excuse is not a justification. */
p = fixture("excuse")
call put p"/tools/read.py", 'open("x").read()'
call put p"/PYTHON_JUSTIFICATION", 'tools/read.py | reading a file is complex'
r = gate(p)
call check r["status"] == "FAIL", "short excuse fails"
call check r["findings"][1]~pos("minimum is 10") > 0, "finding names the word minimum"

/* 5. Renaming away the .py does not hide it: #! python is detected. */
p = fixture("shebang")
call put p"/bin/tool", '#!/usr/bin/env python3', 'print(1)'
r = gate(p)
call check r["status"] == "FAIL", "extensionless python script fails"
call check r["python"][1]["path"] == "bin/tool", "shebang file reported by path"

/* 6. Shell runners calling python -m are callers too. */
p = fixture("shell")
call put p"/run_tests.sh", '#!/bin/sh', 'python3 -m unittest -v tests.test_x'
r = gate(p)
call check r["status"] == "FAIL", "sh calling python3 -m fails"
call check kinds(r) == "python-call", "reported as python-call"

/* 7. Mentions are not calls. */
p = fixture("mentions")
call put p"/doc.rex", 'say "no python here"', '-- python3 tools/x.py was the old way', 'x = "pythonic"'
call put p"/run.sh", '# python3 -m was removed', 'echo python'
r = gate(p)
call check r["status"] == "PASS", "words, comments and echo are not calls"

/* 8. Third-party code under vendor/ or upstream/ is exempt but listed. */
p = fixture("vendor")
call put p"/vendor/lib/thing.py", 'x = 1'
call put p"/upstream/other/setup.py", 'x = 1'
r = gate(p)
call check r["status"] == "PASS", "vendor/upstream python does not fail"
call check r["exempt"]~items == 2, "both exempt files listed"

/* 9. A stale justification entry warns but does not fail. */
p = fixture("stale")
call put p"/main.rex", 'say 1'
call put p"/PYTHON_JUSTIFICATION", 'gone.py | this file was removed in the port to ooRexx so the entry is now stale'
r = gate(p)
call check r["status"] == "PASS", "stale entry alone does not fail"
call check r["warnings"]~items == 1, "stale entry reported as warning"

/* 10. A path that is not a directory fails closed. */
r = gate(base"/does-not-exist")
call check r["status"] == "FAIL", "missing package root fails closed"

/* 11. Interpreter versions in the command name are still python. */
p = fixture("versioned")
call put p"/x.rex", "address system '/usr/bin/python3.12 -c ""print(1)""'"
r = gate(p)
call check r["status"] == "FAIL", "/usr/bin/python3.12 -c is a call"

/* 12. .git is never scanned. */
p = fixture("gitdir")
call put p"/.git/hooks/pre-commit.py", 'x = 1'
call put p"/main.rex", 'say 1'
r = gate(p)
call check r["status"] == "PASS", ".git contents ignored"

say "python_gate tests:" passed "passed," failed "failed"
call removeTree base
if failed > 0 then exit 1
say "PASS test_python_gate"
exit 0

fixture: procedure expose base
  use strict arg name
  path = base"/"name
  call mkdirs path
  return path

gate: procedure
  use strict arg root
  g = .PythonGate~new(root)
  return g~run

kinds: procedure
  use strict arg r
  out = ""
  do item over r["python"]
    out = out item["kind"]
  end
  return out~strip

put: procedure
  use strict arg path, ...
  call mkdirs filespec("location", path)
  s = .stream~new(path)
  s~open("write replace")
  do i = 2 to arg()
    s~lineout(arg(i))
  end
  s~close
  return

mkdirs: procedure
  use strict arg path
  path = strip(path, "T", "/")
  if path == "" | sysIsFileDirectory(path) then return
  call mkdirs filespec("location", path)
  call sysMkDir path
  return

removeTree: procedure
  use strict arg path
  call sysFileTree path"/*", "f.", "FSO"
  do i = 1 to f.0
    call sysFileDelete f.i
  end
  call sysFileTree path"/*", "d.", "DSO"
  do i = d.0 to 1 by -1          -- deepest last in the list, so remove in reverse
    call sysRmDir d.i
  end
  call sysRmDir path
  return

check: procedure expose passed failed
  use strict arg ok, label
  if ok then do
    passed += 1
    say "ok   " label
  end
  else do
    failed += 1
    say "FAIL " label
  end
  return

::requires "../src/PythonGate.cls"
