agentPath=arg(1)
if agentPath="" then agentPath="policy_mutation_agent.rex"
ring=.CryptoMacKeyRing~new
ring~addKey("mut", "00112233445566778899aabbccddeeff")
sealer=.AlchemyMacSealer~new(ring)
authority=.AlchemyCapabilityAuthority~new(ring)
o=.MutationSubject~new(sealer,authority)

policy=.AlchemySecurityPolicy~new("ALLOW")
policy~deny("METHOD","RECORDREQUIREMENTRESULT","*")
policy~deny("METHOD","SETINSTRUMENTATIONRULE","*")
manager=.AlchemySecurityManager~new(policy,.nil,.AlchemySecurityRuntimeProfile~observedR13196)
r=.Routine~newFile(agentPath)
r~setSecurityManager(manager)

signal on syntax name waiveDenied
ignoreOutcome=r~call(o,"WAIVE")
signal off syntax
raise syntax 88.900 array("customer self-waiver unexpectedly succeeded")
waiveDenied:
  signal off syntax

r2=.Routine~newFile(agentPath)
r2~setSecurityManager(manager)
signal on syntax name disableDenied
ignoreOutcome=r2~call(o,"DISABLE")
signal off syntax
raise syntax 88.900 array("customer instrumentation disable unexpectedly succeeded")
disableDenied:
  signal off syntax

pub=o~sealPublicIntrospection~payload
req=findRequirement(pub["environment_requirements"],"ENV:HOST-READY")
if req["status"] \= "UNCHECKED" then raise syntax 88.900 array("denied waiver mutated requirement state")

e=.directory~new; e["x"]="same"
a=o~alchemyInstrument("DEMO.REPEAT",e)
b=o~alchemyInstrument("DEMO.REPEAT",e)
if \a~hasIndex("sequence") then raise syntax 88.900 array("instrumentation point was disabled despite policy deny")
if b["reason"] \= "REPEAT_COLLAPSED" then raise syntax 88.900 array("instrumentation rule changed despite policy deny")

if manager~auditEvents~items < 2 then raise syntax 88.900 array("expected protected mutation METHOD checkpoints")
say "PASS test_protected_policy_mutations"
exit 0

findRequirement: procedure
  use strict arg records,id
  do rec over records
    if rec["requirement_id"] = id then return rec
  end
  return .nil

::class MutationSubject subclass AlchemyObject
::method init
  use strict arg sealer,authority
  forward class (super) array (.nil,sealer,authority) continue
  self~registerEnvironmentRequirement("HOST-READY","must be operator checked",.true,"","PUBLIC")
  self~registerInstrumentationPoint("DEMO.REPEAT","protected policy mutation test",.true,"COLLAPSE","INTERNAL")

::requires "AlchemyObjects.cls"
