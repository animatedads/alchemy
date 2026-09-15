service = .LogService~new("test-selective")
service~enableMetrics
mem = .LogMemoryTarget~new("memory", .Log~INTERNAL)
service~addTarget(mem)

ui = .WebsiteUI~new
reg = service~registerMethod(ui, "generateCustomerPanel", .Log~INTERNAL)

/* No active rule: registration must leave the method physically unwrapped. */
call assertEq 0, service~metrics["instrumented_methods"], "inactive registration stays unwrapped"
service~resetMetrics

do i = 1 to 1000
  session = .Session~new(.Customer~new("ordinary-" || i))
  ignore = ui~generateCustomerPanel(session)
end
m = service~metrics
call assertEq 0, m["plan_evaluations"], "no rule means no predicate evaluation"
call assertEq 0, m["events_created"], "no rule means no events"
call assertEq 0, mem~count, "no rule leaves target untouched"

needle = "%';DROP"
condition = .LogConditionAny~new(.array~of( -
  .LogConditionArgNil~new(1), -
  .LogConditionArgPathContains~new(1, .array~of("CUSTOMER", "CUSTOMERNAME"), needle, .false)))
rule = .LogRule~new("website-panel-suspicious", "website", "WebsiteUI", "generateCustomerPanel", -
  .Log~INTERNAL, .Log~INTERNAL, .Log~DEBUG, condition, .array~of("memory"), -
  .array~of(.Log~ENTRY, .Log~EXIT, .Log~ERROR_POINT))
service~addRule(rule)
call assertEq 1, service~metrics["instrumented_methods"], "rule activation instruments only selected method"
service~resetMetrics

/* 1,000 benign calls: condition is evaluated, but logging never activates. */
do i = 1 to 1000
  session = .Session~new(.Customer~new("ordinary-" || i))
  ignore = ui~generateCustomerPanel(session)
end
m = service~metrics
call assertEq 1000, m["plan_evaluations"], "targeted method plan evaluated once per call"
call assertEq 0, m["rule_matches"], "benign calls do not activate logging"
call assertEq 0, m["invocations_created"], "benign calls allocate no LogInvocation"
call assertEq 0, m["active_loggers"], "benign calls create no active logger"
call assertEq 0, m["events_created"], "benign calls create no LogEvent"
call assertEq 0, mem~count, "benign calls deliver nothing"
say "SELECTIVE_BENIGN calls=1000 plan_evaluations="m["plan_evaluations"] "rule_matches="m["rule_matches"] "invocations="m["invocations_created"] "active_loggers="m["active_loggers"] "events="m["events_created"]

/* Matching by .nil activates logging for exactly this invocation. */
ignore = ui~generateCustomerPanel(.nil)
m = service~metrics
call assertEq 1001, m["plan_evaluations"], "nil call evaluated"
call assertEq 1, m["rule_matches"], "nil call activates rule"
call assertEq 1, m["invocations_created"], "nil call creates one invocation context"
call assertEq 1, m["active_loggers"], "nil call gets active logger"
call assertEq 2, m["events_created"], "entry and exit events created for nil call"
call assertEq 2, mem~count, "nil call delivered entry and exit"
say "SELECTIVE_NIL matches="m["rule_matches"] "invocations="m["invocations_created"] "events="m["events_created"]

/* Clear then matching through the object graph activates logging once. */
mem~clear
service~resetMetrics
attack = .Session~new(.Customer~new("Acme %';DROP TABLE customer;--"))
ignore = ui~generateCustomerPanel(attack)
m = service~metrics
call assertEq 1, m["plan_evaluations"], "attack call evaluated"
call assertEq 1, m["rule_matches"], "attack path activates rule"
call assertEq 1, m["invocations_created"], "attack creates one invocation context"
call assertEq 1, m["active_loggers"], "one active logger for attack"
call assertEq 2, m["events_created"], "attack gets entry and exit only"
call assertEq 2, mem~count, "attack delivered exactly two events"
first = mem~events[1]
call assertEq "GENERATECUSTOMERPANEL", first~methodName, "method identity retained"
call assertTrue first~payload~isA(.Array), "entry payload retains original argument array object"
call assertTrue first~payload[1] == attack, "entry payload retains session object identity"
say "SELECTIVE_ATTACK matches="m["rule_matches"] "invocations="m["invocations_created"] "events="m["events_created"]

/* Rule disable restores the original method and eliminates predicate work. */
service~disableRule("website-panel-suspicious")
call assertEq 0, service~metrics["instrumented_methods"], "disable physically removes wrapper"
mem~clear
service~resetMetrics
ignore = ui~generateCustomerPanel(attack)
m = service~metrics
call assertEq 0, m["plan_evaluations"], "disabled rule pays no predicate cost"
call assertEq 0, m["events_created"], "disabled rule creates no event"
call assertEq 0, mem~count, "disabled rule delivers nothing"
say "SELECTIVE_DISABLED plan_evaluations="m["plan_evaluations"] "events="m["events_created"] "instrumented_methods="service~metrics["instrumented_methods"]

say "PASS test_selective_method"
exit 0

assertTrue: procedure
  use strict arg actual, message
  if actual \= .true then raise syntax 88.900 array("assertTrue failed:" message)
  return
assertEq: procedure
  use strict arg expected, actual, message
  if expected \== actual then raise syntax 88.900 array("assertEq failed:" message "expected="expected "actual="actual)
  return

::class Customer
::attribute customerName get
::method init
  expose customerName
  use strict arg customerName
  customerName = customerName

::class Session
::attribute customer get
::method init
  expose customer
  use strict arg customer
  customer = customer

::class WebsiteUI inherit LogInstrumentationParticipant
::method generateCustomerPanel unguarded
  use arg session
  if session == .nil then return "anonymous"
  return "panel:" || session~customer~customerName

::requires "../src/LoggingCore.cls"
