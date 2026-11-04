/* READ-side ingress gate against a real dev10 Memory Fabric Registry and
 * real v0.1 service descriptors. Authenticator and ACL are synthetic fakes;
 * no claim of production cryptographic authentication is made. */
numeric digits 20
registry=.MemoryFabricRegistry~new('MEM-REG')
p=.MemoryFabricProvider~new('P-MU','MU','MU5','','SITE-A','MACHINE-5','',50000000,0,'ACTIVE','ACCEPTING',1,1,'boot-1')
call must registry~registerProvider(p),'provider registration'
block=.MemoryFabricBlockRef~new('BLOCK-42',7,'P-MU',0,8388608,'VOLATILE','',1)
call must registry~publishBlock(block),'block published'
services=.ServiceRegistry~new(value('MF_TEST_REGISTRY',,'ENVIRONMENT'))
services~register(.ServiceDescriptor~new('memory.block.read.mu5','normal.memory','mu5-memory'))
services~register(.ServiceDescriptor~new('memory.block.read.bad','normal.memory','different-mu'))
services~register(.ServiceDescriptor~new('memory.block.read.control','memory.control','mu5-memory'))
auth=.TestIngressIdentity~new
acl=.TestIngressACL~new
gate=.MemoryXtpReadIngress~new(registry,services,auth,acl,'P-MU','mu5-memory')
intent=.MemoryXtpReadIntent~new('MEM-REG','BLOCK-42',7,0,4194304,2097152,'request_1234567890abcdef',106000)
call must gate~admit(intent,'memory.block.read.mu5','invalid',100000)==.nil,'unverified transport identity'
call must gate~admit(intent,'memory.block.read.bad','credentialA',100000)==.nil,'misrouted service'
call must gate~admit(intent,'memory.block.read.control','credentialA',100000)==.nil,'wrong service operational class'
acl~allowed=.false
call must gate~admit(intent,'memory.block.read.mu5','credentialA',100000)==.nil,'ACL denies'
acl~allowed=.true
/* Simulate authentication identity changing between the two independent
 * verifier lookups: the ACL-approved A cannot issue a permit for B. */
flip=.MemoryXtpReadIntent~new('MEM-REG','BLOCK-42',7,0,2097152,2097152,'request_1234567890abcdf5',106000)
auth~alternate=.true; auth~counter=0
call must gate~admit(flip,'memory.block.read.mu5','credentialA',100000)==.nil,'principal changed between admission checks'
auth~alternate=.false
permit=gate~admit(intent,'memory.block.read.mu5','credentialA',100000)
call must permit<>.nil,'authorized ingress receives a permit'
call must permit~identity='AUTHENTICATED-PEER-A','identity comes from verifier'
call must permit~validatePage(0,2097152,100001),'first page valid'
call must permit~validatePage(2097152,2097152,100001),'second page valid'
call must \permit~validatePage(4194304,2097152,100001),'outside window rejected'
call must \permit~validatePage(1,2097152,100001),'unaligned page rejected'
call must \permit~validatePage(0,1,100001),'partial page rejected'
call must gate~admit(intent,'memory.block.read.mu5','credentialA',100001)==.nil,'duplicate id rejected'
acl~allowed=.false
call must \permit~validatePage(0,2097152,100001),'ACL revocation fences page'
acl~allowed=.true
auth~allowed=.false
call must \permit~validatePage(0,2097152,100001),'identity revocation fences page'
auth~allowed=.true
call must \permit~validatePage(0,2097152,106001),'expiry fences page'
future=.MemoryXtpReadIntent~new('MEM-REG','BLOCK-42',7,0,2097152,2097152,'request_1234567890abcdf0',200000)
call must gate~admit(future,'memory.block.read.mu5','credentialA',100000)==.nil,'unbounded TTL rejected'
oversized=.MemoryXtpReadIntent~new('MEM-REG','BLOCK-42',7,0,8388608,2097152,'request_1234567890abcdf1',106000)
smallGate=.MemoryXtpReadIngress~new(registry,services,auth,acl,'P-MU','mu5-memory',2097152)
call must smallGate~admit(oversized,'memory.block.read.mu5','credentialA',100000)==.nil,'max inbound bytes'
wrongBlock=.MemoryXtpReadIntent~new('MEM-REG','BLOCK-42',6,0,2097152,2097152,'request_1234567890abcdf2',106000)
call must gate~admit(wrongBlock,'memory.block.read.mu5','credentialA',100000)==.nil,'stale block generation rejected'
other=.MemoryXtpReadIntent~new('MEM-REG','BLOCK-42',7,0,2097152,2097152,'request_1234567890abcdf3',106000)
otherPermit=gate~admit(other,'memory.block.read.mu5','credentialA',100000)
call must otherPermit<>.nil,'second independent read admitted'
newP=registry~reincarnateProvider('P-MU',1,'boot-2')
call must newP<>.nil,'provider incarnation changed'
call must \otherPermit~validatePage(0,2097152,100001),'old owner epoch is fenced'
call must gate~admit(.MemoryXtpReadIntent~new('MEM-REG','BLOCK-42',7,0,2097152,2097152,'request_1234567890abcdf4',106000),'memory.block.read.mu5','credentialA',100000)==.nil,'old authoritative block fenced'
say 'PASS Memory XTP ingress: verified identity, ACL, service, replay, TTL, page, epoch, generation'
exit 0
must:
  use arg condition,label
  if \condition then do
    say 'FAIL:' label
    exit 77
  end
  return
::class TestIngressIdentity
::attribute allowed
::attribute alternate
::attribute counter
::method init
  expose allowed alternate counter
  allowed=.true; alternate=.false; counter=0
::method identityFor
  expose allowed alternate counter
  use strict arg evidence
  if \allowed | evidence<>'credentialA' then return .nil
  if alternate then do
    counter+=1
    if counter//2=0 then return 'AUTHENTICATED-PEER-B'
  end
  return 'AUTHENTICATED-PEER-A'
::class TestIngressACL
::attribute allowed
::method init
  expose allowed
  allowed=.true
::method canRead
  expose allowed
  use strict arg identity,intent,block,provider
  return allowed & identity='AUTHENTICATED-PEER-A' & intent~blockId=block~blockId & provider~providerId='P-MU'
::requires 'MemoryFabric.cls'
::requires 'ServiceDescriptors.cls'
::requires 'MemoryXtpReadIngress.cls'
