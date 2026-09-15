agentPath = arg(1)
if agentPath = "" then agentPath = "security_agent.rex"

allowPolicy = .AlchemySecurityPolicy~new("DENY")
allowPolicy~allow("METHOD", "LOCKED", "VICTIM")
manager = .AlchemySecurityManager~new(allowPolicy, .nil, .AlchemySecurityRuntimeProfile~observedR13196)
r = .Routine~newFile(agentPath)
r~setSecurityManager(manager)
result = r~call
call assertEq "body:abc", result, "observed r13196 .false return permits original protected method"
call assertEq 1, manager~auditEvents~items, "one METHOD checkpoint"
call assertEq "METHOD", manager~auditEvents~at(1)["checkpoint"], "checkpoint kind"

denyPolicy = .AlchemySecurityPolicy~new("DENY")
denyPolicy~deny("METHOD", "LOCKED", "VICTIM")
denyManager = .AlchemySecurityManager~new(denyPolicy, .nil, .AlchemySecurityRuntimeProfile~observedR13196)
r2 = .Routine~newFile(agentPath)
r2~setSecurityManager(denyManager)
signal on syntax name denied
ignore = r2~call
signal off syntax
raise syntax 88.900 array("denied protected method unexpectedly ran")
denied:
  c = condition("C")
  signal off syntax
  call assertEq "SYNTAX", c, "denial raises syntax authorization condition"

/* The published reference and the observed r13196 behavior agree:
 * .false means authorized/continue normal processing; .true means the
 * Security Manager handled the action itself. */
referenceProfile = .AlchemySecurityRuntimeProfile~documented
call assertEq .false, referenceProfile~continueProcessingReturn, "reference .false continues normal processing"
call assertEq .true, referenceProfile~handledReturn, "reference .true means handled"
call assertEq .false, referenceProfile~observed, "reference profile is descriptive, not executable"
call assertEq .false, referenceProfile~allowReturn, "legacy allowReturn accessor aliases continuation value"
referenceEvidence = referenceProfile~evidence
call assertEq .false, referenceEvidence["continue_processing_return"], "structured reference evidence continuation value"
call assertEq .true, referenceEvidence["handled_return"], "structured reference evidence handled value"
call assertEq .true, referenceEvidence["matches_reference"], "reference evidence self-consistent"
observedEvidence = .AlchemySecurityRuntimeProfile~observedR13196~evidence
call assertEq .true, observedEvidence["observed"], "observed profile marked executable"
call assertEq .true, observedEvidence["matches_reference"], "observed r13196 semantics match reference"

/* Fail closed: descriptive/reference semantics are never accepted as an
 * executable runtime profile until independently observed on that runtime. */
signal on syntax name unobservedBlocked
ignoreManager = .AlchemySecurityManager~new(allowPolicy, .nil, referenceProfile)
signal off syntax
raise syntax 88.900 array("unobserved reference profile unexpectedly accepted for execution")
unobservedBlocked:
  signal off syntax

/* A raw .true checkpoint return is the handled/substitution path, not the
 * authorization/continue path.  With no replacement result, normal protected
 * method execution must not occur. */
docManager = .RawTrueSecurityManager~new
r3 = .Routine~newFile(agentPath)
r3~setSecurityManager(docManager)
signal on syntax name handledWithoutResult
ignore = r3~call
signal off syntax
raise syntax 88.900 array("raw .true Security Manager return unexpectedly executed protected method body")
handledWithoutResult:
  signal off syntax

say "PASS test_security_manager_contract"
exit 0

assertEq: procedure
  use arg expected, actual, msg
  if expected \== actual then raise syntax 88.900 array("assertEq failed: " || msg || " expected=" || expected || " actual=" || actual)
  return

::class RawTrueSecurityManager public
::method unknown
  use arg name, args
  return .true

::requires "AlchemyObjects.cls"
