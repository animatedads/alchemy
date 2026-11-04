/* Real Memory Fabric dev10, real Operational Planner/Governor dev5 and
 * Service Descriptors dev1. A recording socket proves required rate call;
 * native XTP wire proof is a separate test. */
numeric digits 20
fabric=.MemoryFabricRegistry~new('FABRIC-1')
p5=.MemoryFabricProvider~new('P5','MU','MU5','','SITE-A','MACHINE5','',100000000,0,'ACTIVE','ACCEPTING',1,1,'boot5')
p7=.MemoryFabricProvider~new('P7','MU','MU7','','SITE-B','MACHINE7','',100000000,0,'ACTIVE','ACCEPTING',1,1,'boot7')
call must fabric~registerProvider(p5),'register P5'
call must fabric~registerProvider(p7),'register P7'
ref=.MemoryFabricBlockRef~new('BLOCK-A',8,'P5',0,67108864,'VOLATILE','',1)
call must fabric~publishBlock(ref),'publish authoritative block'
request=.MemoryXtpWindowRequest~new('FABRIC-1','BLOCK-A',8,0,67108864)
a=.MemoryXtpResidentOffer~new('FABRIC-1','BLOCK-A',8,'mu5-mem','P5',1,1,0,67108864,'owner-registry')
b=.MemoryXtpResidentOffer~new('FABRIC-1','BLOCK-A',8,'mu7-mem','P7',1,1,0,67108864,'replica-signed-evidence')
services=.ServiceRegistry~new(value('MF_TEST_REGISTRY',,'ENVIRONMENT'))
services~register(.ServiceDescriptor~new('memory.block.read.mu5','normal.memory','mu5-mem'))
services~register(.ServiceDescriptor~new('memory.block.read.mu7','normal.memory','mu7-mem'))
operational=.OperationalPlanner~new(value('MF_OPCTL',,'ENVIRONMENT'))
capacities=.OperationalCapacityRegistry~new(value('MF_OPCTL',,'ENVIRONMENT'))
capacities~set('mi2.ingress',1000000,1000000)
governor=.OperationalCapacityGovernor~new(capacities,operational)
policy=.MemoryXtpServicePolicy~new(services,operational)~forService('memory.block.read.mu5','normal')
plan=.MemoryXtpTransferPlanner~new~plan(request,.array~of(a,b),policy,fabric)
call must plan~slices~items=2,'two slices planned'
authority=.MemoryXtpAuthority~new(fabric)
call must authority~current(request,plan~slices[1]),'real current owner passes'
call must \authority~current(request,plan~slices[2]),'unverified replica rejected'
verifier=.TrustedReplica~new
authority=.MemoryXtpAuthority~new(fabric,verifier)
call must authority~current(request,plan~slices[2]),'independent signed-replica authority passes'
admission=.MemoryXtpCapacityAdmission~new(authority,governor)~admit(plan,'mi2.ingress')
call must governor~activeContexts('normal.memory','mi2.ingress')=2,'2 active contexts'
call must governor~activePercent('normal.memory','mi2.ingress')=60,'60 percent aggregate'
backend=.RecordingBackend~new
named=.XtpNamedServiceManager~new(services,backend)
call must admission~sendControl(1,named,'memory.block.read.mu5','request-1')=9,'first control send'
call must backend~lastRate=300000,'30 percent enforced by socket'
call must admission~sendControl(2,named,'memory.block.read.mu5','wrong')=-5,'wrong source peer rejected'
call must admission~sendControl(2,named,'memory.block.read.mu7','request-2')=9,'second control send'
call must backend~lastRate=300000,'second 30% socket rate'
capacities~set('mi2.ingress',1000000,500000)
call must admission~refreshDomain,'refresh capacity'
call must admission~sendControl(1,named,'memory.block.read.mu5','request-3')=9,'send after contraction'
call must backend~lastRate=150000,'rate contracts to 150kb/s'
ignored=admission~reconcile('emergency')
call must admission~sendControl(1,named,'memory.block.read.mu5','forbidden')=-6,'emergency suspended'
ignored=admission~reconcile('normal')
call must admission~sendControl(1,named,'memory.block.read.mu5','request-4')=9,'normal restored'
call must backend~lastRate=150000,'restored current cap'
verifier~allowed=.false
call must admission~sendControl(2,named,'memory.block.read.mu7','old')=-3,'replica proof revoked'
verifier~allowed=.true
p7new=fabric~reincarnateProvider('P7',1,'boot7-new')
call must p7new<>.nil,'provider reincarnated'
call must admission~sendControl(2,named,'memory.block.read.mu7','old')=-3,'provider epoch fences even trusted replica'
call must admission~release,'release tickets'
call must governor~activeContexts('normal.memory','mi2.ingress')=0,'zero active after release'
call must admission~sendControl(1,named,'memory.block.read.mu5','no')=-1,'released admission cannot send'
/* A plan with a too-small aggregate share must shrink or fail, not lie
 * about effective capacity while admitting two full 30% contexts. */
small=.directory~new
small['PER_CONTEXT_CAP_PERCENT']=30;small['MAX_PARALLEL_CONTEXTS']=2;small['AGGREGATE_CAP_PERCENT']=50
small['TRANSMIT']=1;small['TRANSFORM']=0
shrink=.MemoryXtpTransferPolicy~new('normal.memory','normal',small)
one=.MemoryXtpTransferPlanner~new~plan(request,.array~of(a,b),shrink,fabric)
call must one~slices~items=1,'aggregate allows one context only'
say 'PASS Memory XTP dev25 admission: block authority, replica verifier, rate, reconcile, fencing, rollback, aggregate'
exit 0
must:
  use arg result,label
  if \result then do; say 'FAIL:' label; exit 75; end
  return
::class TrustedReplica
::attribute allowed
::method init
  expose allowed
  allowed=.true
::method verifies
  expose allowed
  use strict arg offer,request,firstByte,endByte
  return allowed & offer~providerId='P7' & offer~evidenceId='replica-signed-evidence' & request~blockId=offer~blockId
::class RecordingBackend
::attribute lastRate
::method sender
  use strict arg address
  return .RecordingSocket~new(self)
::class RecordingSocket
::method init
  expose backend
  use strict arg b
  backend=b
::method service
  use strict arg name
  return self
::method capacityRate
  expose backend
  use strict arg rate
  backend~lastRate=rate
  return self
::method send
  use strict arg payload
  return length(payload)
::method close
  return 0
::requires 'MemoryXtpTransferPlanning.cls'
::requires 'MemoryXtpAdmission.cls'
::requires 'MemoryFabric.cls'
::requires 'OperationalPlanner.cls'
::requires 'ServiceDescriptors.cls'
::requires 'XtpNamedServices.cls'
