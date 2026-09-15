parse arg agentPath securityPath
service=.AlchemySecurityPolicy~new("ALLOW")
service~deny("COMMAND", "*", "*")
tenant=.AlchemySecurityPolicy~new("ALLOW")
composite=.AlchemyCompositeSecurityPolicy~new(service,tenant)
manager=.AlchemySecurityManager~new(composite,.nil,.AlchemySecurityRuntimeProfile~observedR13196)
r=.Routine~newFile(agentPath); r~setSecurityManager(manager)
signal on syntax name serviceBlocked
ignore=r~call
signal off syntax
raise syntax 88.900 array("tenant policy weakened service COMMAND deny")
serviceBlocked:
 signal off syntax

/* Tenant can make the service policy stricter. */
service2=.AlchemySecurityPolicy~new("DENY")
service2~allow("METHOD","LOCKED","VICTIM")
tenant2=.AlchemySecurityPolicy~new("ALLOW")
tenant2~deny("METHOD","LOCKED","VICTIM")
composite2=.AlchemyCompositeSecurityPolicy~new(service2,tenant2)
manager2=.AlchemySecurityManager~new(composite2,.nil,.AlchemySecurityRuntimeProfile~observedR13196)
r2=.Routine~newFile(securityPath); r2~setSecurityManager(manager2)
signal on syntax name tenantBlocked
ignore=r2~call
signal off syntax
raise syntax 88.900 array("tenant stricter deny was ignored")
tenantBlocked:
 signal off syntax
say "PASS test_composite_policy"
exit 0
::requires "AlchemyObjects.cls"
