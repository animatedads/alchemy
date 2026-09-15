/* Large rule sets are compiled at configuration time.  Runtime lookup must
 * touch only the exact class/method/scope plan, not scan unrelated rules. */
service = .LogService~new("index-test")
service~enableMetrics
mem = .LogMemoryTarget~new("memory", .Log~INTERNAL)
service~addTarget(mem)

noiseCondition = .CountingCondition~new(.false)
targetCondition = .CountingCondition~new(.false)
rules = .array~new

do i = 1 to 1000
  methodName = "NOISE" || right(i, 4, "0")
  rules~append(.LogRule~new("noise-" || i, "indexed", "IndexedWorker", methodName, -
    .Log~INTERNAL, .Log~INTERNAL, .Log~DEBUG, noiseCondition, .array~of("memory"), -
    .array~of(.Log~ENTRY, .Log~EXIT)))
end
rules~append(.LogRule~new("selected", "indexed", "IndexedWorker", "work", -
  .Log~INTERNAL, .Log~INTERNAL, .Log~DEBUG, targetCondition, .array~of("memory"), -
  .array~of(.Log~ENTRY, .Log~EXIT)))

call assertEq 1001, service~replaceRules(rules), "whole rule set replaced"
m = service~metrics
call assertEq 1001, m["compiled_plans"], "one compiled plan per exact method key"
call assertEq 1, m["active_class_scopes"], "class/scope proxy index is compact"

worker = .IndexedWorker~new
wrapped = service~proxyIfRequired(worker, .Log~INTERNAL)
call assertTrue wrapped~isA(.LogSelectiveProxy), "active class obtains proxy"

service~resetMetrics
call assertEq 7, wrapped~cheapValue, "unselected message forwarded"
m = service~metrics
call assertEq 0, m["plan_evaluations"], "unselected message does not enter a plan"
call assertEq 0, m["rule_evaluations"], "unselected message scans no rules"
call assertEq 0, noiseCondition~count, "noise predicates untouched"

call assertEq "work:ordinary", wrapped~work("ordinary"), "selected method result preserved"
m = service~metrics
call assertEq 1, m["plan_evaluations"], "selected invocation evaluates one exact plan"
call assertEq 1, m["rule_evaluations"], "selected invocation evaluates only its rule"
call assertEq 0, m["rule_matches"], "false selector does not activate logging"
call assertEq 0, m["invocations_created"], "condition miss allocates no invocation"
call assertEq 0, m["active_loggers"], "condition miss allocates no active logger"
call assertEq 0, m["events_created"], "condition miss creates no event"
call assertEq 0, noiseCondition~count, "1000 unrelated rule predicates remain untouched"
call assertEq 1, targetCondition~count, "only exact selected predicate evaluated"

/* Complete replacement invalidates already-issued active loggers as well as
 * future method plans. */
activeCondition = .CountingCondition~new(.true)
activeRule = .LogRule~new("selected-active", "indexed", "IndexedWorker", "work", -
  .Log~INTERNAL, .Log~INTERNAL, .Log~DEBUG, activeCondition, .array~of("memory"))
service~replaceRules(.array~of(activeRule))
oldLog = service~loggerFor(worker, "work", .array~of("x"), .Log~INTERNAL)
call assertTrue oldLog~active, "active logger issued before replacement"

/* A rejected replacement must leave the currently published configuration
 * intact; validation happens before publication. */
caught = .false
signal on syntax name duplicateRejected
service~replaceRules(.array~of(activeRule, activeRule))
signal off syntax
signal duplicateChecked
duplicateRejected:
  caught = .true
  signal off syntax
duplicateChecked:
call assertTrue caught, "duplicate replacement rejected before publication"
call assertTrue service~rule("selected-active") == activeRule, "rejected replacement leaves current rule set intact"
before = mem~count
call assertTrue oldLog~log(.Log~WARN, "still-current"), "old logger remains valid after rejected replacement"
call assertEq before + 1, mem~count, "rejected replacement does not disturb delivery"

before = mem~count
service~replaceRules(.array~new)
call assertFalse oldLog~log(.Log~WARN, "stale"), "old logger cannot emit after rule-set replacement"
call assertEq before, mem~count, "stale logger delivered nothing"

say "RULE_INDEXING rules=1001 unrelated_predicates=0 selected_predicates=1 allocations_on_miss=0"
say "RULE_REPLACEMENT rejected_update_atomic=PASS stale_logger_suppressed=PASS"
say "PASS test_rule_indexing"
exit 0

assertTrue: procedure
  use strict arg actual, message
  if actual \= .true then raise syntax 88.900 array("assertTrue failed:" message)
  return
assertFalse: procedure
  use strict arg actual, message
  if actual \= .false then raise syntax 88.900 array("assertFalse failed:" message)
  return
assertEq: procedure
  use strict arg expected, actual, message
  if expected \== actual then raise syntax 88.900 array("assertEq failed:" message "expected="expected "actual="actual)
  return

::class CountingCondition
::attribute count get
::method init
  expose result count
  use strict arg result
  count = 0
::method matches public unguarded
  expose result count
  use strict arg receiver, arguments
  count = count + 1
  return result

::class IndexedWorker
::method work unguarded
  use strict arg value
  return "work:" || value
::method cheapValue unguarded
  return 7

::requires "../src/LoggingCore.cls"
