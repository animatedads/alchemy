/* Real ooRexx contract qualification against Memory Fabric dev10 registry. */
call must .MemoryXtpTransferBuild~API='memory.fabric.xtp-transfer/0.1','API'
fabric=.MemoryFabricRegistry~new('FABRIC-1')
p1=.MemoryFabricProvider~new('P5','MU','MU5','','SITE-A','MACHINE5','',100000000,0,'ACTIVE','ACCEPTING',1,1,'boot5')
p2=.MemoryFabricProvider~new('P7','MU','MU7','','SITE-B','MACHINE7','',100000000,0,'ACTIVE','ACCEPTING',1,1,'boot7')
call must fabric~registerProvider(p1),'provider 5'
call must fabric~registerProvider(p2),'provider 7'
services=.ServiceRegistry~new(value('MF_TEST_REGISTRY',,'ENVIRONMENT'))
services~register(.ServiceDescriptor~new('memory.block.read','normal.memory','mu5-mem','memory.block.read'))
planner=.TestOperationalPlanner~new
policy=.MemoryXtpServicePolicy~new(services,planner)~forService('memory.block.read','NORMAL')
call must policy~className='normal.memory','class from service registry'
call must policy~maximumInboundPercent=60,'class inbound 60%'
request=.MemoryXtpWindowRequest~new('FABRIC-1','BLOCK-A',8,0,67108864)
a=.MemoryXtpResidentOffer~new('FABRIC-1','BLOCK-A',8,'mu5-mem','P5',1,1,0,67108864,'proof-5')
b=.MemoryXtpResidentOffer~new('FABRIC-1','BLOCK-A',8,'mu7-mem','P7',1,1,0,67108864,'proof-7')
offers=.array~of(a,b)
plan=.MemoryXtpTransferPlanner~new~plan(request,offers,policy,fabric)
call must plan~slices~items=2,'two contexts'
call must plan~totalBytes=67108864,'exact requested length'
call must plan~slices[1]~length=33554432,'16 pages from first replica'
call must plan~slices[2]~firstByte=33554432,'aligned split'
call must plan~slices[1]~perContextCapPercent=30,'30% per context'
call must plan~effectiveInboundPercent=60,'60% aggregate'
call must plan~slices[1]~offer~peerId='mu5-mem','logical peer first'
call must .MemoryXtpTransferPlanner~new~revalidate(plan~slices[2],fabric),'valid before change'
p2new=fabric~reincarnateProvider('P7',1,'boot7-new')
call must p2new<>.nil,'reincarnated P7'
call must \.MemoryXtpTransferPlanner~new~revalidate(plan~slices[2],fabric),'old epoch fenced'
call must .MemoryXtpTransferPlanner~new~revalidate(plan~slices[1],fabric),'unaffected peer still current'

/* Emergency class fails closed, no best-effort fallback. */
blocked=.MemoryXtpServicePolicy~new(services,planner)~forService('memory.block.read','EMERGENCY')
call must \blocked~transmit,'suspended memory.bulk'
call must blocked~maximumInboundPercent=60,'policy limit remains descriptive, transmit denied'

/* XTP service manager composes the actual Service Descriptor Registry.  The
 * recording backend observes the exact XTP named service and logical peer. */
backend=.RecordingXtpBackend~new
xtpNamed=.XtpNamedServiceManager~new(services,backend,planner,'NORMAL')
control=.MemoryXtpNamedControl~new(xtpNamed)
call must control~send('memory.block.read','small-control')=13,'named XTP sender accepted bounded control'
call must backend~lastPeer='mu5-mem','route remains a logical peer'
call must backend~lastService='memory.block.read','FIRST uses canonical named service'
call must backend~lastPayload='small-control','control payload preserved'


say 'PASS Memory XTP planning: 2x30/60, aligned slices, fencing and REAL named-service registry/manager'
exit 0
must:
  use arg ok,label
  if \ok then do; say 'FAIL' label; exit 60; end
  return
::class TestOperationalPlanner
::method decide
  use strict arg className, state
  d=.directory~new
  d['PER_CONTEXT_CAP_PERCENT']=30
  d['MAX_PARALLEL_CONTEXTS']=2
  d['AGGREGATE_CAP_PERCENT']=60
  d['FALLBACK']='forbid'
  d['PROTECTED_ONLY']=1
  d['TRANSFORM']=0
  d['TRANSMIT']=(state<>'EMERGENCY')
  return d
::class RecordingXtpBackend
::attribute lastPeer
::attribute lastService
::attribute lastPayload
::method sender
  use strict arg address
  self~lastPeer=address~xtpAddress
  return .RecordingXtpSocket~new(self)
::class RecordingXtpSocket
::method init
  expose backend
  use strict arg backend
::method service
  expose backend
  use strict arg name
  backend~lastService=name
  return self
::method send
  expose backend
  use strict arg bytes
  backend~lastPayload=bytes
  return length(bytes)
::method close
  return 0
::requires 'ServiceDescriptors.cls'
::requires 'XtpNamedServices.cls'
::requires 'MemoryFabric.cls'
::requires 'MemoryXtpTransferPlanning.cls'
