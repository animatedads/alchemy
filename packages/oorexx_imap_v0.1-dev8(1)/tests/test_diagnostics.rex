/* Generic command diagnostics must never contain command arguments. */
chunks = .array~of("A000001 OK LOGIN completed" || "0d0a"x)
transport = .ImapScriptedTransport~new(chunks)
sink = .CaptureSink~new
session = .ImapSession~new(transport, .nil, sink)
r = session~execute('LOGIN "alice@example.invalid" "DO-NOT-LOG-THIS-PASSWORD"')
call assertTrue r~ok, "command succeeds"
call assertEq 2, sink~events~items, "begin and complete diagnostics"
begin = sink~events[1]
call assertEq "COMMAND_BEGIN", begin["point"], "begin point"
call assertEq "LOGIN", begin["payload"]["command"], "only safe verb is retained"
call assertFalse begin["payload"]~hasIndex("command_text"), "raw command absent"
call assertFalse begin["payload"]~hasIndex("user"), "username absent"
call assertFalse begin["payload"]~hasIndex("password"), "password absent"

/* Diagnostic target failure is fail-open for the protocol session. */
chunks2 = .array~of("A000001 OK NOOP completed" || "0d0a"x)
transport2 = .ImapScriptedTransport~new(chunks2)
session2 = .ImapSession~new(transport2, .nil, .ThrowingSink~new)
r2 = session2~noop
call assertTrue r2~ok, "logging failure must not desynchronise IMAP"
call assertTrue session2~lastEventError <> "", "logging failure is inspectable"

say "PASS test_diagnostics"
exit 0

assertTrue: procedure
  use strict arg actual, message
  if actual \= .true then do; say "FAIL:" message; exit 1; end
  return
assertFalse: procedure
  use strict arg actual, message
  if actual \= .false then do; say "FAIL:" message; exit 1; end
  return
assertEq: procedure
  use strict arg expected, actual, message
  if expected \== actual then do; say "FAIL:" message "expected="expected "actual="actual; exit 1; end
  return

::class CaptureSink
::attribute events get
::method init
  expose events
  events = .array~new
::method emit
  expose events
  use strict arg owner, point, level, payload = .nil
  row = .directory~new; row["point"] = point; row["level"] = level; row["payload"] = payload
  events~append(row)
  return .true

::class ThrowingSink
::method emit
  use strict arg owner, point, level, payload = .nil
  raise syntax 88.900 array("INTENTIONAL_DIAGNOSTIC_FAILURE")

::requires "ImapSession.cls"
::requires "TestSupport.cls"
