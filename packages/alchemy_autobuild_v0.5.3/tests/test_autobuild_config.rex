/* test_autobuild_config.rex -- tools/autobuild_config.rex keeps JSON types and refuses bad input.
 * Architecture: Tom Dyer.  Coding: Claude (Opus 5.5), 2026-11-14. */
here = filespec("location", .context~package~name)
tool = here"../tools/autobuild_config.rex"
dir = value("TMPDIR",, "ENVIRONMENT")
if dir == "" then dir = "/tmp"
cfg = dir"/autobuild_config_test_"date("S")time("S")random(1, 99999)".json"
.stream~new(cfg)~~open("write replace")~~lineout('{"root": "/x", "git_intake": true, "poll_seconds": 2}')~~close
passed = 0; failed = 0
call check run("set git_intake false" cfg) == 0, "set boolean"
call check run("set python_gate advisory" cfg) == 0, "set gate mode"
call check run("set poll_seconds 5" cfg) == 0, "set number"
call check run("set python_gate off" cfg) == 2, "bad gate mode refused"
call check run("set gitintake false" cfg) == 2, "unknown key refused"
c = .json~fromJsonFile(cfg)
call check c["git_intake"]~isA(.JsonBoolean) & \c["git_intake"]~value, "git_intake is the JSON boolean false"
call check c["python_gate"] == "advisory", "python_gate stored"
call check c["poll_seconds"] == 5 & \c["poll_seconds"]~isA(.JsonString), "poll_seconds stays a number"
call check c["root"] == "/x", "other keys kept"
call check \c~hasIndex("gitintake"), "refused key not added"
call sysFileDelete cfg
say "autobuild_config tests:" passed "passed," failed "failed"
if failed > 0 then exit 1
say "PASS test_autobuild_config"
exit 0

run: procedure expose tool
  use strict arg args
  address system "rexx" tool args ">/dev/null 2>&1"
  return rc

check: procedure expose passed failed
  use strict arg ok, label
  if ok == .true then do; passed += 1; say "ok   " label; end
  else do; failed += 1; say "FAIL " label; end
  return

::requires "json.cls"
