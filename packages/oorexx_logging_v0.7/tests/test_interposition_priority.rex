/* Generic method interposition priority is independent of logging. */
journal = .array~new
obj = .PrioritySubject~new(journal)
slow = .PriorityInterceptor~new("slow", journal)
fast = .PriorityInterceptor~new("fast", journal)

/* Register in the opposite order to execution priority. */
obj~__methodInterpositionAdd("work", "slow-provider", slow, 200)
obj~__methodInterpositionAdd("work", "fast-provider", fast, 10)
status = obj~methodInterpositionStatus("work")
call assertEq 1, status["physical_wrappers"], "priority providers share one wrapper"
details = status["methods"][1]["provider_details"]
call assertEq "fast-provider", details[1]["provider_id"], "lower numeric priority is first"
call assertEq 10, details[1]["priority"], "fast priority visible"
call assertEq "slow-provider", details[2]["provider_id"], "higher numeric priority is second"

call assertEq "result:x", obj~work("x"), "wrapped method result preserved"
call assertOrder journal, .array~of("before:fast", "before:slow", "body:x", "after:slow", "after:fast"), "priority order"

/* Replacing one provider can move it without creating another wrapper. */
journal~empty
obj~__methodInterpositionAdd("work", "slow-provider", slow, 1)
status = obj~methodInterpositionStatus("work")
call assertEq 1, status["physical_wrappers"], "priority replacement keeps one wrapper"
details = status["methods"][1]["provider_details"]
call assertEq "slow-provider", details[1]["provider_id"], "replacement reprioritises provider"
call assertEq 1, details[1]["priority"], "replacement priority visible"
call assertEq "result:y", obj~work("y"), "reprioritised method result preserved"
call assertOrder journal, .array~of("before:slow", "before:fast", "body:y", "after:fast", "after:slow"), "reprioritised order"

obj~__methodInterpositionRemove("work", "slow-provider")
obj~__methodInterpositionRemove("work", "fast-provider")
call assertEq 0, obj~methodInterpositionStatus("work")["physical_wrappers"], "final release restores original"

say "INTERPOSITION_PRIORITY one_wrapper=PASS ordered_before_after=PASS reprioritise=PASS"
say "PASS test_interposition_priority"
exit 0

assertEq: procedure
  use strict arg expected, actual, message
  if expected \== actual then raise syntax 88.900 array("assertEq failed:" message "expected="expected "actual="actual)
  return

assertOrder: procedure
  use strict arg actual, expected, message
  if actual~items \= expected~items then raise syntax 88.900 array("assertOrder count failed:" message)
  do i = 1 to expected~items
    if actual[i] \== expected[i] then raise syntax 88.900 array("assertOrder failed:" message "index="i "expected="expected[i] "actual="actual[i])
  end
  return

::class PrioritySubject inherit MethodInterpositionParticipant
::method init
  expose journal
  use strict arg journal
  journal = journal
::method work unguarded
  expose journal
  use strict arg value
  journal~append("body:" || value)
  return "result:" || value

::class PriorityInterceptor
::method init
  expose label journal
  use strict arg label, journal
  journal = journal
::method before public unguarded
  expose label journal
  use strict arg receiver, methodName, arguments
  journal~append("before:" || label)
  return label
::method after public unguarded
  expose label journal
  use strict arg receiver, methodName, token, result
  journal~append("after:" || label)
  return .true
::method failure public unguarded
  use strict arg receiver, methodName, token, conditionObject
  return .true

::requires "../src/MethodInterposition.cls"
