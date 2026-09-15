service = .LogService~new("test-proxy")
service~enableMetrics
mem = .LogMemoryTarget~new("memory", .Log~INTERNAL)
service~addTarget(mem)

light = .TinyWorker~new
same = service~proxyIfRequired(light, .Log~INTERNAL)
call assertTrue same == light, "no rule returns original lightweight object"
call assertEq 0, service~metrics["proxies_created"], "no proxy allocated while inactive"

condition = .LogConditionArgPathContains~new(1, .array~of("CUSTOMER", "CUSTOMERNAME"), "%';DROP")
rule = .LogRule~new("tiny-suspicious", "tiny", "TinyWorker", "render", -
  .Log~INTERNAL, .Log~INTERNAL, .Log~DEBUG, condition, .array~of("memory"), -
  .array~of(.Log~ENTRY, .Log~EXIT))
service~addRule(rule)

wrapped = service~proxyIfRequired(light, .Log~INTERNAL)
call assertFalse wrapped == light, "active class rule allocates proxy"
call assertTrue wrapped~isA(.LogSelectiveProxy), "active wrapper is logging proxy"
call assertTrue wrapped~target == light, "proxy retains target"
call assertEq 1, service~metrics["proxies_created"], "exactly one proxy allocated"

service~resetMetrics
benign = .Session~new(.Customer~new("ordinary"))
call assertEq "tiny:ordinary", wrapped~render(benign), "proxy preserves result"
m = service~metrics
call assertEq 1, m["plan_evaluations"], "proxy evaluates targeted rule"
call assertEq 0, m["active_loggers"], "benign proxy call creates no logger"
call assertEq 0, mem~count, "benign proxy call emits nothing"

attack = .Session~new(.Customer~new("x %';DROP y"))
call assertEq "tiny:x %';DROP y", wrapped~render(attack), "matching proxy preserves result"
m = service~metrics
call assertEq 2, m["plan_evaluations"], "second proxy invocation evaluated"
call assertEq 1, m["active_loggers"], "matching invocation gets active logger"
call assertEq 2, mem~count, "matching invocation emits entry/exit"

/* A different message is forwarded without even evaluating the RENDER plan. */
before = service~metrics["plan_evaluations"]
call assertEq 42, wrapped~cheapValue, "unselected message forwarded"
call assertEq before, service~metrics["plan_evaluations"], "unselected message has no rule evaluation"

service~disableRule("tiny-suspicious")
again = service~proxyIfRequired(.TinyWorker~new, .Log~INTERNAL)
call assertFalse again~isA(.LogSelectiveProxy), "disabled rule stops future proxy allocation"

say "PASS test_selective_proxy"
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
::class TinyWorker
::method render
  use strict arg session
  return "tiny:" || session~customer~customerName
::method cheapValue
  return 42

::requires "../src/LoggingCore.cls"
