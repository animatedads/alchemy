/* Fixture tests of dev34 accepted-socket metadata against real MemoryFabric
 * dev10 registry and real Service Descriptors. NOT real AEAD packet testing. */
numeric digits 20
registry=.MemoryFabricRegistry~new('MEM-REG')
p=.MemoryFabricProvider~new('P-MU','MU','MU5','','SITE-A','MACHINE-5','',50000000,0,'ACTIVE','ACCEPTING',1,1,'boot-1')
call must registry~registerProvider(p),'provider registered'
block=.MemoryFabricBlockRef~new('BLOCK-42',7,'P-MU',0,8388608,'VOLATILE','',1)
call must registry~publishBlock(block),'block published'
services=.ServiceRegistry~new(value('MF_TEST_REGISTRY',,'ENVIRONMENT'))
services~register(.ServiceDescriptor~new('memory.block.read.mu5','normal.memory','mu5-memory'))
keys=.FixtureKeys~new
clock=.FixtureClock~new
auth=.MemoryXtp34KeyAuthenticator~new(keys,clock,'memory.block.read.mu5')
acl=.FixtureAcl~new

gate=.MemoryXtpReadIngress~new(registry,services,auth,acl,'P-MU','mu5-memory')
bridge=.MemoryXtp34ReadBridge~new(gate,'memory.block.read.mu5')
intent=.MemoryXtpReadIntent~new('MEM-REG','BLOCK-42',7,0,4194304,2097152,'request_1234567890abcdef',106000)
frame=.MemoryXtp34ReadWire~encode(intent)
call must .MemoryXtp34ReadWire~decode(frame)<>.nil,'wire roundtrip'
call must .MemoryXtp34ReadWire~decode(frame||'09'x||'EXTRA')==.nil,'extra field rejected'
call must .MemoryXtp34ReadWire~decode('MFXR1' || '09'x || 'ZZ' || '09'x || 'FF')==.nil,'invalid hex rejected'
call must .MemoryXtp34ReadWire~decode(frame||'0a'x)==.nil,'newline rejected'
call must .MemoryXtp34ReadWire~decode(frame~substr(1,frame~lastPos('09'x)))==.nil,'missing expiry field rejected'
call must .MemoryXtp34ReadWire~decode(frame||copies('a',2048))==.nil,'oversized frame rejected'
call must bridge~admitReceived(.XtpNamedAcceptedSocket~new('memory.block.read.mu5','none','0000000000000001','MU5',frame),100000)==.nil,'clear denied'
call must bridge~admitReceived(.XtpNamedAcceptedSocket~new('memory.block.read.mu5','authenticate','0000000000000001','MU5',frame),100000)==.nil,'auth-only denied'
call must bridge~admitReceived(.XtpNamedAcceptedSocket~new('memory.block.read.other','encrypt','0000000000000001','MU5',frame),100000)==.nil,'wrong service denied'
call must bridge~admitReceived(.XtpNamedAcceptedSocket~new('memory.block.read.mu5','encrypt','NOTHEX','MU5',frame),100000)==.nil,'invalid key ID denied'
call must bridge~admitReceived(.XtpNamedAcceptedSocket~new('memory.block.read.mu5','encrypt','0000000000000001','-',frame),100000)==.nil,'missing key principal denied'
call must bridge~admitReceived(.XtpNamedAcceptedSocket~new('memory.block.read.mu5','encrypt','0000000000000001','OTHER',frame),100000)==.nil,'wrong principal denied'
call must bridge~admitReceived('pretend socket',100000)==.nil,'arbitrary object denied'
call must bridge~admitReceived(.XtpNamedAcceptedSocket~new('memory.block.read.mu5','encrypt','0000000000000001','MU5',frame||'a'),100000)==.nil,'overflow/trailing data denied'
acl~allowed=.false
call must bridge~admitReceived(.XtpNamedAcceptedSocket~new('memory.block.read.mu5','encrypt','0000000000000001','MU5',frame),100000)==.nil,'ACL denies valid transport'
acl~allowed=.true
clock~now=2000
call must bridge~admitReceived(.XtpNamedAcceptedSocket~new('memory.block.read.mu5','encrypt','0000000000000001','MU5',frame),100000)==.nil,'expired live key denied'
clock~now=1000
testSocket=.XtpNamedAcceptedSocket~new('memory.block.read.mu5','encrypt','0000000000000001','MU5',frame)
permit=bridge~admitReceived(testSocket,100000)
call must permit<>.nil,'registered encrypted service accepted'
call must permit~identity='MU5','key principal is bound to ACL'
call must permit~validatePage(0,2097152,100001),'page before revocation'
keys~revoked=.true
call must \permit~validatePage(0,2097152,100001),'live key revocation fences page'
keys~revoked=.false
call must bridge~admitReceived(.XtpNamedAcceptedSocket~new('memory.block.read.mu5','encrypt','0000000000000001','MU5',frame),100001)==.nil,'replay denied'
keys~revoked=.true
say 'PASS protected read adapter: dev34 metadata, active LDAP key, ACL, framing, page revocation, replay'
exit 0
must:
 use arg ok,label
 if \ok then do
  say 'FAIL:' label
  exit 77
 end
 return
::class FixtureKeys
::attribute revoked
::attribute source
::method init
 expose revoked source
 revoked=.false; source='ldap'
::method list
 expose revoked source
 a=.array~new
 if revoked then return a
 k=.directory~new
 k['SERVICE']='memory.block.read.mu5'; k['KEYID']='0000000000000001'; k['PRINCIPAL']='MU5'
 k['PROTECTION']='encrypt';k['SOURCE']=source;k['STATE']='ACTIVE';k['NOTBEFORE']='900';k['NOTAFTER']='1500'
 a~append(k)
 return a
::class FixtureClock
::attribute now
::method init
 expose now
 now=1000
::method epochSeconds
 expose now
 return now
::class FixtureAcl
::attribute allowed
::method init
 expose allowed
 allowed=.true
::method canRead
 expose allowed
 use strict arg principal,intent,block,provider
 return allowed & principal='MU5' & block~blockId=intent~blockId & provider~providerId='P-MU'
::requires 'MemoryFabric.cls'
::requires 'ServiceDescriptors.cls'
::requires 'MemoryXtp34ProtectedRead.cls'
