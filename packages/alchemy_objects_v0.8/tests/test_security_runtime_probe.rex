agentPath = arg(1)
if agentPath = "" then agentPath = "security_agent.rex"

profile = .AlchemySecurityRuntimeProfile~current
evidence = profile~evidence
call assertTrue profile~observed, "live runtime semantics probe is executable"
call assertEq .false, profile~continueProcessingReturn, "live runtime .false continues normal processing"
call assertEq .true, profile~handledReturn, "live runtime .true is handled/substitution path"
call assertTrue evidence["matches_reference"], "live METHOD checkpoint matches ooRexx reference convention"
call assertTrue evidence["version_text"]~length > 0, "runtime version text captured"

/* current() is process-cached: subsequent users consume the observed profile,
 * they do not repeatedly probe interpreter semantics during introspection. */
profileAgain = .AlchemySecurityRuntimeProfile~current
call assertTrue profile == profileAgain, "runtime profile cached for process lifetime"

/* Most important integration case: no explicit profile is supplied.  The
 * manager must use the live observed profile and still permit the protected
 * body under an ALLOW policy. */
policy = .AlchemySecurityPolicy~new("DENY")
policy~allow("METHOD", "LOCKED", "VICTIM")
manager = .AlchemySecurityManager~new(policy)
r = .Routine~newFile(agentPath)
r~setSecurityManager(manager)
actual = r~call
call assertEq "body:abc", actual, "default manager uses live runtime probe"
call assertTrue manager~runtimeProfile~observed, "manager retained executable observed profile"
call assertEq profile~continueProcessingReturn, manager~runtimeProfile~continueProcessingReturn, "manager continuation semantics match probe"

say "PASS test_security_runtime_probe"
exit 0

assertTrue: procedure
  use arg value, msg
  if value \== .true then raise syntax 88.900 array("assertTrue failed: " || msg)
  return

assertEq: procedure
  use arg expected, actual, msg
  if expected \== actual then raise syntax 88.900 array("assertEq failed: " || msg || " expected=" || expected || " actual=" || actual)
  return

::requires "AlchemyObjects.cls"
