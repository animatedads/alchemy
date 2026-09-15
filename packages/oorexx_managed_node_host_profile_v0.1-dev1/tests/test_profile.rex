/* Managed Node Host Profile qualification against allocator v0.6. */
identity1=.ManagedNodeHostIdentity~new("OCI-MICRO-01","OCI","ocid-example-01","micro-a","NO_INCREMENTAL_COST","UK-LONDON-1","AD-1","FD-3",.true)
identity2=.ManagedNodeHostIdentity~new("OCI-MICRO-02","OCI","ocid-example-02","micro-b","NO_INCREMENTAL_COST","UK-LONDON-1","AD-1","FD-1",.true)
publisher=.ManagedNodeHostProfilePublisher~new
kinds=.array~of("COMMAND","TEST","COMPUTE")
runtimes=.array~of("OOREXX")

/* Bare/rebooting twin is reachable identity but not managed-execution ready. */
p1=.ManagedNodeCapabilityProfile~new(identity1~nodeId,.true,.true,"boot-a","X86_64",946,30720,1,runtimes,kinds,"cap-a")
p2=.ManagedNodeCapabilityProfile~new(identity2~nodeId,.true,.false,"boot-b","X86_64",946,30720,1,.array~new,kinds,"cap-b")
c1=publisher~capability(identity1,p1,1)
c2=publisher~capability(identity2,p2,1)
call assert c1~abilities~hasIndex("TEST_EXECUTION"),"queue-ready node advertises test execution"
call assert \c2~abilities~hasIndex("TEST_EXECUTION"),"non-ready node advertises no test execution"
call assert c1~runtimeGeneration="boot-a","boot generation propagated"
call assert c1~tags~hasIndex("FAULT_DOMAIN_FD-3"),"fault domain topology tag"

registry=.NodeCapabilityRegistry~new
call assert registry~advertiseCapability(c1),"advertise ready twin"
call assert registry~advertiseCapability(c2),"advertise not-ready twin"
s1=.ManagedNodeCapacitySample~new(identity1~nodeId,487,24576,1,1000000,0,0,"obs-a")
s2=.ManagedNodeCapacitySample~new(identity2~nodeId,700,25000,1,1000000,0,0,"obs-b")
call assert registry~observeCapacity(publisher~capacity(s1,1,1,100,1000)),"capacity ready twin"
call assert registry~observeCapacity(publisher~capacity(s2,1,1,100,1000)),"capacity not-ready twin"

req=.JobNodeRequirement~new(.nil,.nil,.nil,.nil,.array~of("TEST_EXECUTION"),.array~of("OOREXX"),.nil,"X86_64",0,0,0,1,1,1,0,.nil,"boot-a")
place=.JobPlacementRequest~new("PROFILE-JOB",req,"CONTROL",0,0)
policy=.JobNodeEligibilityPolicy~new
a1=policy~assess(place,c1,registry~capacity(identity1~nodeId),200)
a2=policy~assess(place,c2,registry~capacity(identity2~nodeId),200)
call assert a1~eligible,"queue-ready exact-generation twin eligible"
call assert \a2~eligible,"non-ready twin ineligible"

/* Same provider identity after reboot is a new runtime/capability generation. */
p1b=.ManagedNodeCapabilityProfile~new(identity1~nodeId,.true,.true,"boot-a2","X86_64",946,30720,1,runtimes,kinds,"cap-a2")
c1b=publisher~capability(identity1,p1b,2)
call assert registry~advertiseCapability(c1b),"new capability generation after reboot"
call assert c1b~runtimeGeneration="boot-a2","new boot generation visible"
call assert \registry~observeCapacity(publisher~capacity(s1,1,2,201,1001)),"old capability capacity rejected after reboot"
call assert registry~observeCapacity(publisher~capacity(s1,2,2,201,1001)),"fresh capability capacity accepted"

/* Once twin 2 is bootstrapped it independently becomes eligible; same shape does not collapse identity. */
p2b=.ManagedNodeCapabilityProfile~new(identity2~nodeId,.true,.true,"boot-b2","X86_64",946,30720,1,runtimes,kinds,"cap-b2")
c2b=publisher~capability(identity2,p2b,2)
call assert registry~advertiseCapability(c2b),"second twin ready capability"
call assert registry~observeCapacity(publisher~capacity(s2,2,2,201,1001)),"second twin fresh capacity"
req2=.JobNodeRequirement~new(.nil,.nil,.nil,.nil,.array~of("TEST_EXECUTION"),.array~of("OOREXX"),.nil,"X86_64",0,0,0,1,1,1,0,.nil,"")
place2=.JobPlacementRequest~new("PROFILE-JOB-2",req2,"CONTROL",0,0)
b1=policy~assess(place2,c1b,registry~capacity(identity1~nodeId),300)
b2=policy~assess(place2,c2b,registry~capacity(identity2~nodeId),300)
call assert b1~eligible,"rebooted first twin eligible with fresh capability"
call assert b2~eligible,"second independently ready twin eligible"

say "PASS Managed Node Host Profile identity/bootstrap/capacity/boot-generation/twin eligibility"
exit 0

assert: procedure
  use arg condition,label
  if \condition then do
    say "FAIL" label
    exit 1
  end
  return

::requires "../src/ManagedNodeHostProfile.cls"
