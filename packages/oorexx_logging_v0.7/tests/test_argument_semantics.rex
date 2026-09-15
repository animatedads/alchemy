probe = .RuleProbe~new
nilCondition = .LogConditionArgNil~new(1)
omittedCondition = .LogConditionArgOmitted~new(1)
secondContains = .LogConditionArgPathContains~new(2, .array~of("VALUE"), "needle")

args = probe~capture
call assertFalse nilCondition~matches(probe, args), "omitted arg is not explicit NIL"
call assertTrue omittedCondition~matches(probe, args), "missing first arg is omitted"

args = probe~capture(.nil)
call assertTrue nilCondition~matches(probe, args), "explicit NIL matches NIL condition"
call assertFalse omittedCondition~matches(probe, args), "explicit NIL is not omitted"

/* Sparse ooRexx argument arrays must be addressed by HASINDEX, not ITEMS. */
args = probe~capture(, .ValueBox~new("contains-needle-here"))
call assertTrue omittedCondition~matches(probe, args), "sparse first position remains omitted"
call assertTrue secondContains~matches(probe, args), "second sparse argument remains addressable"

invocation = .LogInvocation~new(probe, "demo", args, .Log~INTERNAL)
call assertTrue invocation~argument(1, "missing") == "missing", "invocation reports omitted slot via default"
call assertTrue invocation~argument(2) == args[2], "invocation retrieves present sparse slot"

say "ARGUMENT_SEMANTICS nil_vs_omitted=PASS sparse_array=PASS"
say "PASS test_argument_semantics"
exit 0

assertTrue: procedure
  use strict arg actual, message
  if actual \= .true then raise syntax 88.900 array("assertTrue failed:" message)
  return
assertFalse: procedure
  use strict arg actual, message
  if actual \= .false then raise syntax 88.900 array("assertFalse failed:" message)
  return

::class RuleProbe
::method capture
  return arg(1, "A")

::class ValueBox
::attribute value get
::method init
  expose value
  use strict arg value
  value = value

::requires "../src/LoggingCore.cls"
