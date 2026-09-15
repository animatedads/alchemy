/* Two independent logging services share one physical ooRexx method wrapper.
 * Each can activate/deactivate without damaging the other service. */
obj = .CoordinatedWidget~new

s1 = .LogService~new("audit-A")
t1 = .LogMemoryTarget~new("memory-A", .Log~INTERNAL)
s1~addTarget(t1)
r1 = .LogRule~new("rule-A", "component-A", "CoordinatedWidget", "work", -
  .Log~INTERNAL, .Log~INTERNAL, .Log~DEBUG, .LogConditionAlways~new, .array~of("memory-A"), -
  .array~of(.Log~ENTRY, .Log~EXIT, .Log~ERROR_POINT))
s1~registerMethod(obj, "work", .Log~INTERNAL)
s1~addRule(r1)

s2 = .LogService~new("audit-B")
t2 = .LogMemoryTarget~new("memory-B", .Log~INTERNAL)
s2~addTarget(t2)
r2 = .LogRule~new("rule-B", "component-B", "CoordinatedWidget", "work", -
  .Log~INTERNAL, .Log~INTERNAL, .Log~DEBUG, .LogConditionAlways~new, .array~of("memory-B"), -
  .array~of(.Log~ENTRY, .Log~EXIT, .Log~ERROR_POINT))
s2~registerMethod(obj, "work", .Log~INTERNAL)
s2~addRule(r2)

status = obj~methodInterpositionStatus("work")
call assertEq 1, status["physical_wrappers"], "one physical wrapper for both services"
method = status["methods"][1]
call assertEq 2, method["provider_count"], "two providers share method slot"
call assertTrue method["wrapper_integrity"], "coordinator owns wrapper"

call assertEq "worked:x", obj~work("x"), "coordinated wrapper preserves result"
call assertEq 2, t1~count, "service A receives entry/exit"
call assertEq 2, t2~count, "service B receives entry/exit"

/* Removing A removes only its provider; the physical wrapper remains for B. */
s1~disableRule("rule-A")
status = obj~methodInterpositionStatus("work")
call assertEq 1, status["physical_wrappers"], "wrapper remains for second service"
method = status["methods"][1]
call assertEq 1, method["provider_count"], "only one provider remains"

t1before = t1~count
t2before = t2~count
call assertEq "worked:y", obj~work("y"), "remaining provider preserves result"
call assertEq t1before, t1~count, "disabled service A receives nothing"
call assertEq t2before + 2, t2~count, "service B continues logging"

/* Removing the final provider physically restores the original method. */
s2~disableRule("rule-B")
status = obj~methodInterpositionStatus("work")
call assertEq 0, status["physical_wrappers"], "last release removes physical wrapper"
s1~resetMetrics
s2~resetMetrics
call assertEq "worked:z", obj~work("z"), "original method restored"
call assertEq 0, s1~metrics["plan_evaluations"], "service A pays no post-disable cost"
call assertEq 0, s2~metrics["plan_evaluations"], "service B pays no post-disable cost"

say "COORDINATED_INTERPOSITION physical=1 providers=2 independent_release=PASS final_physical=0"
say "PASS test_coordinated_interposition"
exit 0

assertTrue: procedure
  use strict arg actual, message
  if actual \= .true then raise syntax 88.900 array("assertTrue failed:" message)
  return
assertEq: procedure
  use strict arg expected, actual, message
  if expected \== actual then raise syntax 88.900 array("assertEq failed:" message "expected="expected "actual="actual)
  return

::class CoordinatedWidget inherit LogInstrumentationParticipant
::method work unguarded
  use strict arg value
  return "worked:" || value

::requires "../src/LoggingCore.cls"
