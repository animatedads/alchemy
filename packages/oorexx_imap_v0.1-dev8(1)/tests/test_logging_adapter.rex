service = .LogService~new("imap-logging-test")
mem = .LogMemoryTarget~new("memory", .Log~INTERNAL)
service~addTarget(mem)
rule = .LogRule~new("imap-events", "imap", "ImapSession", "EVENT", -
  .Log~INTERNAL, .Log~INTERNAL, .Log~TRACE, .nil, .array~of("memory"))
service~addRule(rule)

chunks = .array~of("A000001 OK NOOP completed" || "0d0a"x)
transport = .ImapScriptedTransport~new(chunks)
adapter = .ImapLoggingAdapter~new(service, .Log~INTERNAL)
session = .ImapSession~new(transport, .nil, adapter)
r = session~noop
call assertTrue r~ok, "noop succeeds"
call assertEq 2, mem~count, "begin and complete become LogEvents"
first = mem~events[1]
call assertEq "COMMAND_BEGIN", first~point, "structured point"
call assertEq "NOOP", first~payload["command"], "structured safe command name"
call assertTrue first~payload~hasIndex("tag"), "tag retained"

say "PASS test_logging_adapter"
exit 0

assertTrue: procedure
  use strict arg actual, message
  if actual \= .true then do; say "FAIL:" message; exit 1; end
  return
assertEq: procedure
  use strict arg expected, actual, message
  if expected \== actual then do; say "FAIL:" message "expected="expected "actual="actual; exit 1; end
  return

::requires "ImapSession.cls"
::requires "ImapLoggingAdapter.cls"
::requires "TestSupport.cls"
