agentPath=arg(1)
policy=.AlchemySecurityPolicy~new("ALLOW")
policy~deny("REQUIRES", "*", "*")
manager=.AlchemySecurityManager~new(policy,.nil,.AlchemySecurityRuntimeProfile~observedR13196)
r=.Routine~newFile(agentPath)
r~setSecurityManager(manager)
result=r~call
if result \== "loaded" then raise syntax 88.900 array("required child did not load")
seen=.false
do ev over manager~auditEvents
 if ev["checkpoint"]="REQUIRES" then seen=.true
end
if seen then raise syntax 88.900 array("static ::REQUIRES unexpectedly reached Security Manager on supplied r13196")
say "PASS test_security_requires_gap"
exit 0
::requires "AlchemyObjects.cls"
