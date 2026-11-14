/* test_log_stream_target.rex -- acceptance for oorexx_logging_stream_target v0.1.
 * Architecture: Tom Dyer.  Coding: Claude (Opus 5.5), 2026-11-14.
 */
passed = 0; failed = 0
sink = .Sink~new
w = .Worker~new
p = .ToolProgress~new("demo", w, "RUN", .Log~INFO, sink)
w~run(p~logger)
call check sink~lines~items == 2, "INFO and WARN delivered, DEBUG held back by the rule"
call check sink~lines[1]~pos("INFO  demo: step one") > 0, "line carries level, component and payload"
call check sink~lines[2]~pos("WARN  demo: careful") > 0, "WARN line"
call check p~target~written == 2, "target counts what it wrote"
p~quiet
w~run(p~logger)
call check sink~lines~items == 2, "quiet: nothing more written"
call check p~service~class == .LogService, "a real oorexx_logging LogService carries the events"
say "stream target tests:" passed "passed," failed "failed"
if failed > 0 then exit 1
say "PASS test_log_stream_target"
exit 0

check: procedure expose passed failed
  use strict arg ok, label
  if ok == .true then do; passed += 1; say "ok   " label; end
  else do; failed += 1; say "FAIL " label; end
  return

::class Worker
::method run
  use strict arg log
  log~log(.Log~INFO, "step one")
  log~log(.Log~DEBUG, "noise")
  log~log(.Log~WARN, "careful")

::class Sink
::attribute lines get
::method init
  expose lines
  lines = .array~new
::method lineout
  expose lines
  use strict arg line
  lines~append(line)
  return 0

::requires "../src/LogStreamTarget.cls"
