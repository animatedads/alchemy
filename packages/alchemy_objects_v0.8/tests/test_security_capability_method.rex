agentPath=arg(1)
ring=.CryptoMacKeyRing~new
ring~addKey("service-cap", "00112233445566778899aabbccddeeff")
authority=.AlchemyCapabilityAuthority~new(ring)
target=.SecureTarget~new
policy=.AlchemySecurityPolicy~new("DENY")
policy~requireCapability("SENSITIVE", "SECURETARGET", "SERVICE:WRITE", 0)
manager=.AlchemySecurityManager~new(policy, authority, .AlchemySecurityRuntimeProfile~observedR13196)

cap=authority~issue("tenant-A", target~alchemyObjectId, "SENSITIVE", "SERVICE:WRITE")
r=.Routine~newFile(agentPath); r~setSecurityManager(manager)
result=r~call(target,cap)
if result \== "changed:payload" then raise syntax 88.900 array("capability protected method did not run")

/* single use: replay must be denied at METHOD checkpoint */
r2=.Routine~newFile(agentPath); r2~setSecurityManager(manager)
signal on syntax name replayDenied
ignore=r2~call(target,cap)
signal off syntax
raise syntax 88.900 array("capability replay accepted")
replayDenied:
 signal off syntax

/* capability for another object must not authorize this target */
other=.SecureTarget~new
wrong=authority~issue("tenant-A", other~alchemyObjectId, "SENSITIVE", "SERVICE:WRITE")
r3=.Routine~newFile(agentPath); r3~setSecurityManager(manager)
signal on syntax name wrongDenied
ignore=r3~call(target,wrong)
signal off syntax
raise syntax 88.900 array("wrong-object capability accepted")
wrongDenied:
 signal off syntax

say "PASS test_security_capability_method"
exit 0

::class SecureTarget subclass AlchemyObject public
::method init
 expose changed
 changed=""
 self~initAlchemy
::method sensitive public protected
 expose changed
 use strict arg value, capability
 changed=value
 return "changed:"||value

::requires "AlchemyObjects.cls"
