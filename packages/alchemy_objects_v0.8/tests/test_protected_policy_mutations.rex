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
policy~deny("METHOD","SETEXECUTIONEVIDENCEPOLICY","*")
policy~deny("METHOD","INSTRUMENTMETHOD","*")
policy~deny("METHOD","UNINSTRUMENTMETHOD","*")
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

r3=.Routine~newFile(agentPath)
r3~setSecurityManager(manager)
signal on syntax name executionDisableDenied
ignoreOutcome=r3~call(o,"EXECUTIONOFF")
signal off syntax
raise syntax 88.900 array("customer execution-evidence disable unexpectedly succeeded")
executionDisableDenied:
  signal off syntax

r4=.Routine~newFile(agentPath)
r4~setSecurityManager(manager)
signal on syntax name instrumentDenied
ignoreOutcome=r4~call(o,"INSTRUMENT")
signal off syntax
raise syntax 88.900 array("customer instrumentation install unexpectedly succeeded")
instrumentDenied:
  signal off syntax

installed=o~instrumentMethod("WORK")
if \installed~ok then raise syntax 88.900 array("host instrumentation setup failed")
callCountBefore=o~methodTelemetry~at("WORK")
if callCountBefore \== .nil then raise syntax 88.900 array("WORK telemetry unexpectedly exists before call")

r5=.Routine~newFile(agentPath)
r5~setSecurityManager(manager)
signal on syntax name uninstrumentDenied
ignoreOutcome=r5~call(o,"UNINSTRUMENT")
signal off syntax
raise syntax 88.900 array("customer instrumentation removal unexpectedly succeeded")
uninstrumentDenied:
  signal off syntax

ignoreWork=o~work("kept")
if o~methodTelemetry["WORK"]["calls"] \= 1 then raise syntax 88.900 array("denied instrumentation removal mutated telemetry wrapper")

pub=o~sealPublicIntrospection~payload
req=findRequirement(pub["environment_requirements"],"ENV:HOST-READY")
if req["status"] \= "UNCHECKED" then raise syntax 88.900 array("denied waiver mutated requirement state")

e=.directory~new; e["x"]="same"
a=o~alchemyInstrument("DEMO.REPEAT",e)
b=o~alchemyInstrument("DEMO.REPEAT",e)
if \a~hasIndex("sequence") then raise syntax 88.900 array("instrumentation point was disabled despite policy deny")
if b["reason"] \= "REPEAT_COLLAPSED" then raise syntax 88.900 array("instrumentation rule changed despite policy deny")
if pub["execution_provenance"]["retained_limit"] \= 128 then raise syntax 88.900 array("execution evidence policy changed despite policy deny")

if manager~auditEvents~items < 5 then raise syntax 88.900 array("expected protected mutation METHOD checkpoints")
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
  self~registerMethodContract("WORK","protected telemetry mutation target",.array~of("VALUE"),"STRING",.false)

::method work unguarded
  use strict arg value
  return "worked:" || value

::requires "AlchemyObjects.cls"
