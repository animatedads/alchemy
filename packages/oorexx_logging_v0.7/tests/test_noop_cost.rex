iterations = 300000
log = .LogNullLogger~instance
bench = .NoopBench~new(log)

/* Warm both paths before timing. */
do i = 1 to 20000
  ignore = bench~plain
  ignore = bench~withLog
end

call time "R"
do i = 1 to iterations
  ignore = bench~plain
end
plainSeconds = time("E")

call time "R"
do i = 1 to iterations
  ignore = bench~withLog
end
loggedSeconds = time("E")

extraSeconds = loggedSeconds - plainSeconds
extraMicros = (extraSeconds * 1000000) / iterations
ratio = 0
if plainSeconds > 0 then ratio = loggedSeconds / plainSeconds

say "NOOP_BENCH iterations="iterations "plain_s="plainSeconds "noop_log_s="loggedSeconds "extra_us_per_call="format(extraMicros,,3) "ratio="format(ratio,,3)

/* Structural acceptance is stronger than timing: the null logger owns no
 * target/rule/service state and the call cannot construct LogEvent objects. */
call assertFalse log~active, "null logger inactive"
call assertFalse log~enabledFor(.Log~FATAL), "null logger rejects every level"
call assertFalse log~log(.Log~WARN, "not fired"), "null log call returns false"

/* Generous machine-independent ceiling: one no-op ooRexx message send should
 * remain in the low-microsecond range, with no rule/target work behind it. */
call assertTrue extraMicros < 10, "disabled logging overhead should remain below 10us/call"

say "PASS test_noop_cost"
exit 0

assertTrue: procedure
  use strict arg actual, message
  if actual \= .true then raise syntax 88.900 array("assertTrue failed:" message)
  return
assertFalse: procedure
  use strict arg actual, message
  if actual \= .false then raise syntax 88.900 array("assertFalse failed:" message)
  return

::class NoopBench
::method init
  expose log
  use strict arg log
  log = log
::method plain unguarded
  return 7
::method withLog unguarded
  expose log
  log~log(.Log~WARN, "not fired")
  return 7

::requires "../src/LoggingCore.cls"
