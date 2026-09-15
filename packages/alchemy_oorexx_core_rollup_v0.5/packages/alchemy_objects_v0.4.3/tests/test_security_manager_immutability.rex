agentPath=arg(1)
policy=.AlchemySecurityPolicy~new("ALLOW")
policy~deny("METHOD", "SETSECURITYMANAGER", "*")
manager=.AlchemySecurityManager~new(policy,.nil,.AlchemySecurityRuntimeProfile~observedR13196)
r=.Routine~newFile(agentPath)
r~setSecurityManager(manager)
signal on syntax name blocked
ignore=r~call
signal off syntax
raise syntax 88.900 array("secure code replaced/removed its Security Manager")
blocked:
 signal off syntax
seen=.false
do ev over manager~auditEvents
 if ev["checkpoint"]="METHOD" then if ev["name"]="SETSECURITYMANAGER" then seen=.true
end
if \seen then raise syntax 88.900 array("SETSECURITYMANAGER denial was not observed")
say "PASS test_security_manager_immutability"
exit 0
::requires "AlchemyObjects.cls"
