service = .LogService~new("bounded-control", .nil, 3)
mem = .LogMemoryTarget~new("memory", .Log~INTERNAL)
service~addTarget(mem)
rule = .LogRule~new("bounded-rule", "demo", "BoundedSubject", "work", -
  .Log~INTERNAL, .Log~INTERNAL, .Log~WARN, .nil, .array~of("memory"), .array~new)
service~addRule(rule)
control = .LogRuntimeControl~new(service)

call assertTrue control~disableRule("bounded-rule", "1"), "disable 1"
call assertTrue control~enableRule("bounded-rule", "2"), "enable 2"
call assertTrue control~disableRule("bounded-rule", "3"), "disable 3"
call assertTrue control~enableRule("bounded-rule", "4"), "enable 4"
call assertTrue control~disableRule("bounded-rule", "5"), "disable 5"

call assertEq 3, service~controlEvents~items, "journal retains configured window"
call assertEq 2, service~controlEventsDropped, "journal reports trimmed history"
call assertEq "3", service~controlEvents[1]~reason, "oldest retained event is third change"
call assertEq "5", service~controlEvents[3]~reason, "newest retained event is fifth change"

adapter = .LogRuntimeNoSQLAdapter~new(service, "ctl_")
rs = adapter~query("SELECT control_journal_limit,control_events,control_events_dropped FROM ctl_runtime")
call assertEq .Error~SUCCESS, rs~status, "runtime journal status query succeeds"
call assertEq 3, rs~rows[1]["control_journal_limit"], "journal limit queryable"
call assertEq 3, rs~rows[1]["control_events"], "retained count queryable"
call assertEq 2, rs~rows[1]["control_events_dropped"], "dropped count queryable"

say "CONTROL_JOURNAL_BOUND retained=3 dropped=2 structured=PASS"
say "PASS test_control_journal_bound"
exit 0

assertTrue: procedure
  use strict arg actual, message
  if actual \= .true then raise syntax 88.900 array("assertTrue failed:" message)
  return
assertEq: procedure
  use strict arg expected, actual, message
  if expected \== actual then raise syntax 88.900 array("assertEq failed:" message "expected="expected "actual="actual)
  return

::class BoundedSubject
::method work
  return .true

::requires "LoggingControl.cls"
