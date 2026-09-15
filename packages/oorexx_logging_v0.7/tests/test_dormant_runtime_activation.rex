service = .LogService~new("runtime-activation")
service~enableMetrics
mem = .LogMemoryTarget~new("memory", .Log~INTERNAL)
service~addTarget(mem)

condition = .LogConditionArgNil~new(1)
rule = .LogRule~new("incident-rule", "web", "LightWidget", "render", -
  .Log~INTERNAL, .Log~INTERNAL, .Log~DEBUG, condition, .array~of("memory"), .array~of(.Log~ENTRY, .Log~EXIT))
service~addDormantRule(rule)

thing = .LightWidget~new
service~resetMetrics
ordinary = service~proxyIfRequired(thing, .Log~INTERNAL)
call assertTrue ordinary == thing, "dormant rule creates no proxy"
call assertEq 0, service~metrics["proxies_created"], "dormant rule allocates no proxy"
call assertEq 0, service~metrics["compiled_plans"], "dormant rule compiles no method plan"

control = .LogRuntimeControl~new(service)
call assertTrue control~enableRule("incident-rule", "customer incident"), "incident rule armed"
service~resetMetrics
wrapped = service~proxyIfRequired(thing, .Log~INTERNAL)
call assertTrue wrapped \== thing, "active class rule creates proxy only now"
call assertEq 1, service~metrics["proxies_created"], "one active proxy allocated"

/* A non-matching call crosses the active proxy but creates no invocation,
 * active logger or event. */
service~resetMetrics
call assertEq "OK", wrapped~render("normal"), "benign call forwarded"
call assertEq 1, service~metrics["plan_evaluations"], "one exact method plan evaluated"
call assertEq 1, service~metrics["rule_evaluations"], "one condition evaluated"
call assertEq 0, service~metrics["rule_matches"], "benign call does not match"
call assertEq 0, service~metrics["invocations_created"], "benign call allocates no invocation"
call assertEq 0, service~metrics["active_loggers"], "benign call allocates no active logger"
call assertEq 0, service~metrics["events_created"], "benign call creates no event"

service~resetMetrics
call assertEq "OK", wrapped~render(.nil), "matching call forwarded"
call assertEq 1, service~metrics["rule_matches"], "incident call matches"
call assertEq 1, service~metrics["invocations_created"], "incident invocation allocated"
call assertEq 1, service~metrics["active_loggers"], "incident active logger allocated"
call assertEq 2, service~metrics["events_created"], "entry/exit events created only for incident"
call assertEq 2, mem~count, "incident events delivered"

call assertTrue control~disableRule("incident-rule", "diagnosis complete"), "incident rule disarmed"
service~resetMetrics
ordinary2 = service~proxyIfRequired(thing, .Log~INTERNAL)
call assertTrue ordinary2 == thing, "new references no longer need proxy"
call assertEq 0, service~metrics["proxies_created"], "no proxy after disarm"
call assertEq 0, service~metrics["compiled_plans"], "plan removed after disarm"
/* A proxy already issued while active becomes a pure forwarding shell: it
 * cannot keep stale logging authority alive. */
call assertEq "OK", wrapped~render(.nil), "held proxy still forwards after disarm"
call assertEq 0, service~metrics["plan_evaluations"], "held proxy performs no plan work after disarm"
call assertEq 2, mem~count, "held proxy emits no stale events"

say "DORMANT_RUNTIME_ACTIVATION inactive_proxy=0 active_proxy=1 benign_allocations=0 stale_proxy_logging=0"
say "PASS test_dormant_runtime_activation"
exit 0

assertTrue: procedure
  use strict arg actual, message
  if actual \= .true then raise syntax 88.900 array("assertTrue failed:" message)
  return
assertEq: procedure
  use strict arg expected, actual, message
  if expected \== actual then raise syntax 88.900 array("assertEq failed:" message "expected="expected "actual="actual)
  return

::class LightWidget
::method render
  use strict arg session
  return "OK"

::requires "LoggingControl.cls"
