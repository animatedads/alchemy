/* One real owner block, one authorized named-service XTP/UDP context.
 * Exactly two bounded control payloads. No remote memory data is exposed. */
numeric digits 20
fabric=.MemoryFabricRegistry~new('FABRIC-WIRE')
p5=.MemoryFabricProvider~new('P5','MU','MU5','','SITE-A','MACHINE5','',100000000,0,'ACTIVE','ACCEPTING',1,1,'boot5')
call must fabric~registerProvider(p5),'provider registered'
call must fabric~publishBlock(.MemoryFabricBlockRef~new('BLOCK-1',8,'P5',0,2097152,'VOLATILE','',1)),'block published'
req=.MemoryXtpWindowRequest~new('FABRIC-WIRE','BLOCK-1',8,0,2097152)
offer=.MemoryXtpResidentOffer~new('FABRIC-WIRE','BLOCK-1',8,'mem-mu5','P5',1,1,0,2097152,'current-owner')
reg=.ServiceRegistry~new(value('MF_TEST_REGISTRY',,'ENVIRONMENT'))
reg~register(.ServiceDescriptor~new('memory.block.read.mu5','normal.memory','mem-mu5'))
backend=value('MF_OPCTL',,'ENVIRONMENT')
policyEngine=.OperationalPlanner~new(backend)
capRegistry=.OperationalCapacityRegistry~new(backend)
capRegistry~set('mi1.memory.ingress',1000000,1000000)
gov=.OperationalCapacityGovernor~new(capRegistry,policyEngine)
policy=.MemoryXtpServicePolicy~new(reg,policyEngine)~forService('memory.block.read.mu5','normal')
plan=.MemoryXtpTransferPlanner~new~plan(req,.array~of(offer),policy,fabric)
admission=.MemoryXtpCapacityAdmission~new(.MemoryXtpAuthority~new(fabric),gov)~admit(plan,'mi1.memory.ingress')
named=.XtpNamedServiceManager~new(reg)
payload='M'~copies(60000)
call time 'R'
n=admission~sendControl(1,named,'memory.block.read.mu5',payload)
first=time('E')
call must n=60000,'first native XTP send'
capRegistry~set('mi1.memory.ingress',1000000,500000)
call must admission~refreshDomain,'capacity domain refresh'
call time 'R'
n=admission~sendControl(1,named,'memory.block.read.mu5',payload)
second=time('E')
call must n=60000,'second native XTP send'
call must first>=0.17 & second>=0.36,'XTP live rate limits 300KB/s then 150KB/s'
call must admission~release,'ticket release'
say 'PASS Memory XTP live named service capacity first='first 'second='second
exit 0
must:
  use arg success,label
  if \success then do; say 'FAIL' label; exit 84; end
  return
::requires 'MemoryXtpTransferPlanning.cls'
::requires 'MemoryXtpAdmission.cls'
::requires 'MemoryFabric.cls'
::requires 'OperationalPlanner.cls'
::requires 'ServiceDescriptors.cls'
::requires 'XtpNamedServices.cls'
