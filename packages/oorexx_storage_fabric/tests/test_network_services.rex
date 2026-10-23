/* Native ooRexx transport-neutral optional features regression. */
ordinary=.FakeOrdinary~new
routes=.StorageNamedServiceRoutes~new
registry=.ServiceRegistry~new('/tmp/storage-service-registry-candidate5.tsv')
manager=.FakeNamedManager~new
planner=.FakeStoragePlanner~new
port=.StorageServiceNetworkPort~new(ordinary,registry,manager,routes,planner)
call check port~mode('ed209c','READ')='ORDINARY_SOCKET','default ordinary transport'
a=port~sender('ed209c','READ')
call check a<>.nil & ordinary~senders=1,'TCP/UNIX fallback unchanged'
call check port~listener<>.nil & ordinary~listeners=1,'default listener unchanged'

/* The route table is a selector, NOT a service class authority. */
routes~bind('ed209c','READ','storage.acquire.C','ed209c')
call check port~mode('ed209c','READ')='NAMED_SERVICE_CONFIGURED','registered binding announced'
call check port~sender('ed209c','READ')==.nil,'unregistered named service cannot downgrade'
registry~register(.ServiceDescriptor~new('storage.acquire.C','normal.storage','ed209c'))
call check port~sender('ed209c','READ')<>.nil,'name selected before send'
call check manager~lastName='storage.acquire.C','FIRST uses registered name'
call check planner~lastClass='normal.storage','planner class sourced from registry'
registry~disable('storage.acquire.C')
call check port~sender('ed209c','READ')==.nil,'disabled service cannot downgrade'
registry~enable('storage.acquire.C')
registry~setPeer('storage.acquire.C','ed209B')
call check port~sender('ed209c','READ')==.nil,'cross-node route mismatch denied'
registry~setPeer('storage.acquire.C','ed209c')
planner~transmit='0'
call check port~sender('ed209c','READ')==.nil,'planner refusal denied'
planner~transmit='1'; planner~transform='1'
call check port~sender('ed209c','READ')==.nil,'untransformed SAMPLE/AGGREGATE denied'
planner~transform='0'; planner~parallel='2'
call check port~sender('ed209c','READ')==.nil,'capacity policy requires enforcement'
gov=.FakeGovernor~new
port=.StorageServiceNetworkPort~new(ordinary,registry,manager,routes,planner,'normal',gov)
s=port~sender('ed209c','READ')
call check s<>.nil & gov~acquired=1,'governed context admitted'
call check s~send('abc')=3 & gov~sends=1,'governor applies to every chunk'
s~close
call check gov~released=1,'governed context released on close'
gov~permit=.false
call check port~sender('ed209c','READ')==.nil,'governor rejects oversubscribed context'
gov~permit=.true
call check port~listener('ed209c')<>.nil & manager~lastListener='ed209c','named listener via registry manager'

peerService=.FakePeerService~new
guard=.StorageNamedInboundGuard~new(peerService)
guard~bind('READ','storage.acquire.C')
req=.directory~new; req['operation']='READ'
call check guard~handle('ed209a',req)['code']='NAMED_CONTEXT_REQUIRED','registered FIRST operation forbids raw fallback'
call check guard~handle('ed209a',req,.FakeAccepted~new('storage.search.C','ed209a'))['code']='SERVICE_OPERATION_MISMATCH','wrong FIRST service rejected'
call check guard~handle('',req,.FakeAccepted~new('storage.acquire.C','ed209a'))['code']='PEER_IDENTITY_MISMATCH','FIRST is not principal auth'
call check guard~handle('ed209b',req,.FakeAccepted~new('storage.acquire.C','ed209a'))['code']='PEER_IDENTITY_MISMATCH','caller identity must match session peer'
call check guard~handle('ed209a',req,.FakeAccepted~new('storage.acquire.C','ed209a',.false))['code']='SERVICE_NOT_ADMITTED','unadmitted context denied'
call check guard~handle('ed209a',req,.FakeNoPeer~new('storage.acquire.C'))['code']='PEER_CONTEXT_REQUIRED','unverified peer context denied'
resp=guard~handle('ed209a',req,.FakeAccepted~new('storage.acquire.C','ed209a'))
call check resp['status']='OK' & peerService~lastIdentity='ed209a','admitted named context retains authenticated identity'
other=.directory~new; other['operation']='LIST'
call check guard~handle('ed209a',other)['status']='OK','unbound operation preserves ordinary authenticated socket'
call check guard~handle('ed209a',other,.FakeAccepted~new('storage.acquire.C','ed209a'))['code']='SERVICE_OPERATION_MISMATCH','named context cannot call unrelated operation'

m=.StorageMulticastDiscovery~new
h=('ab'~copies(32))
call check \m~available,'optional multicast absent'
call check \m~probe(h,'challenge123'),'absent multicast does not send'
raw=.FakeMcast~new
m=.StorageMulticastDiscovery~new(raw)
call check m~available & m~probe(h,'challenge123'),'digest SEARCH multicast sent'
call check pos('SEARCH',raw~lastFrame)>0,'multicast search message'
call check m~advertise(h,'challenge123'),'digest OFFER multicast sent'
received=m~parseHint(raw~lastFrame)
call check received['status']='UNTRUSTED_HINT' & received['kind']='OFFER','multicast never counts as HAVE'
call check \m~probe('not-a-sha256','challenge123'),'invalid hash not broadcast'
call check m~parseHint('bogus')['status']='INVALID','malformed hint refused'
selector=.FakeMcastSelector~new(raw)
selected=.StorageMulticastSelection~new~sender(selector,'storage.discovery.group')
call check selected==raw,'multicast socket selected by capability'
selector~enabled=.false
call check .StorageMulticastSelection~new~sender(selector,'storage.discovery.group')==.nil,'unsupported multicast not assumed'
call check guard~handle('ed209a',.nil)['code']='REQUEST_INVALID','malformed inbound refused' 
r=.StorageSourceRangeOffer~new('ed209c',h,1048576,262144)
call check r~offset=1048576 & r~byteCount=262144,'explicit immutable range offered'

call SysFileDelete registry~path
say 'PASS Storage optional networking: ordinary sockets, FIRST registration, class policy, capacity, multicast hints, pinned range'
exit 0
check: procedure
  parse arg truth,label
  if truth then return
  say 'FAIL' label
  exit 1

::class FakeOrdinary public
::attribute senders get
::attribute listeners get
::method init
  expose senders listeners
  senders=0; listeners=0
::method sender
  expose senders
  use strict arg nodeId
  senders+=1
  return .FakeSocket~new
::method listener
  expose listeners
  listeners+=1
  return .FakeSocket~new
::class FakeSocket public
::method send
  use strict arg bytes
  return length(bytes)
::method close
  return 0
::class FakeNamedManager public
::attribute lastName get
::attribute lastListener get
::method sender
  expose lastName
  use strict arg service
  lastName=service
  return .FakeSocket~new
::method listener
  expose lastListener
  use strict arg logicalPeer
  lastListener=logicalPeer
  return .FakeSocket~new
::class FakeStoragePlanner public
::attribute lastClass get
::attribute transmit
::attribute transform
::attribute parallel
::method init
  expose transmit transform parallel
  transmit='1'; transform='0'; parallel='0'
::method decide
  expose lastClass transmit transform parallel
  use strict arg registeredClass,state
  lastClass=registeredClass
  d=.directory~new
  d['TRANSMIT']=transmit; d['TRANSFORM']=transform
  d['PER_CONTEXT_CAP_PERCENT']='0'; d['MAX_PARALLEL_CONTEXTS']=parallel; d['AGGREGATE_CAP_PERCENT']='0'
  return d
::class FakeGovernor public
::attribute permit
::attribute acquired get
::attribute released get
::attribute sends get
::method init
  expose permit acquired released sends
  permit=.true; acquired=0; released=0; sends=0
::method acquire
  expose permit acquired
  use strict arg registeredClass,decision,peerNodeId
  if \permit then return .nil
  acquired+=1
  return 'ticket'
::method send
  expose sends
  use strict arg ticket,socket,bytes
  sends+=1
  return socket~send(bytes)
::method release
  expose released
  use strict arg ticket
  released+=1
::class FakePeerService public
::attribute lastIdentity get
::method handleFrom
  expose lastIdentity
  use strict arg identity,request
  lastIdentity=identity
  d=.directory~new; d['status']='OK'
  return d
::class FakeAccepted public
::attribute serviceName get
::attribute authenticatedPeerId get
::attribute serviceAdmitted get
::method init
  expose serviceName authenticatedPeerId serviceAdmitted
  use strict arg s,peer,admitted=.true
  serviceName=s; authenticatedPeerId=peer; serviceAdmitted=admitted
::class FakeNoPeer public
::attribute serviceName get
::method init
  expose serviceName
  use strict arg s
  serviceName=s
::class FakeMcast public
::attribute lastFrame get
::method send
  expose lastFrame
  use strict arg data
  lastFrame=data
  return length(data)

::class FakeMcastSelector public
::attribute enabled
::method init
  expose enabled mcast
  use strict arg socket
  enabled=.true; mcast=socket
::method capabilities
  expose enabled
  use strict arg logicalName,role
  return .FakeCaps~new(enabled)
::method sender
  expose mcast
  use strict arg group
  return mcast
::class FakeCaps public
::attribute multicast get
::method init
  expose multicast
  use strict arg value
  multicast=value

::requires "StorageNetworkServices.cls"
::requires "ServiceDescriptors.cls"
