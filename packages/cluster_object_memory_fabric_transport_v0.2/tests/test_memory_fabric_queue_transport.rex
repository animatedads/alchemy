/* Real Queue Fabric + Memory Fabric two-node semantic qualification.
 * Uses QueueInProcessTransport as carrier only; queue/channel semantics are
 * the same Object Queue Fabric APIs used by the XTP Grid carrier.
 */

numeric digits 20
say 'CLUSTER OBJECT / MEMORY FABRIC / QUEUE FABRIC TEST START'

fabric=.MemoryFabricRegistry~new('MF-AUDIO')
pA=.MemoryFabricProvider~new('P-A','MU','NODE-A','','SITE-1','MACHINE-A','',10485760,0,'ACTIVE','ACCEPTING',1,1,'boot-a')
pB=.MemoryFabricProvider~new('P-B','MU','NODE-B','','SITE-1','MACHINE-B','',10485760,0,'ACTIVE','ACCEPTING',1,1,'boot-b')
call must fabric~registerProvider(pA), 'register provider A'
call must fabric~registerProvider(pB), 'register provider B'
call must fabric~bindMU('NODE-A','P-A','memory://node-a',1)<>.nil, 'bind node A'
call must fabric~bindMU('NODE-B','P-B','memory://node-b',1)<>.nil, 'bind node B'

bA=.MemoryFabricBlockRef~new('audio-2200-2210',1,'P-A',0,4096,'RECONSTRUCTABLE','storage:audio:2200-2210',1)
bB=.MemoryFabricBlockRef~new('audio-2210-2220',1,'P-B',0,4096,'RECONSTRUCTABLE','storage:audio:2210-2220',1)
call must fabric~publishBlock(bA), 'publish block A'
call must fabric~publishBlock(bB), 'publish block B'

adapters=.ClusterObjectAdapterRegistry~new
adapters~register(.TestRunnerAdapter~new)
providersA=.array~of('P-A'); providersB=.array~of('P-B')
hostA=.ClusterObjectHost~new('NODE-A',adapters,fabric,providersA)
hostB=.ClusterObjectHost~new('NODE-B',adapters,fabric,providersB)
hostA~memoryResidents~publish(bA,.AudioWindow~new('2200-2210','AUDIO-A'))
hostB~memoryResidents~publish(bB,.AudioWindow~new('2210-2220','AUDIO-B'))
runner=.TestRunner~new('runner-1')
call must hostA~attach('runner-1',runner,'TEST_RUNNER',1), 'attach runner on A'

/* Queue Fabric topology. */
transport=.QueueInProcessTransport~new
codecA=.QueueGraphPayloadCodec~new; codecB=.QueueGraphPayloadCodec~new
mgrA=.ObjectQueueManager~new('',codecA,'admin')
mgrB=.ObjectQueueManager~new('',codecB,'admin')
qfA=.QueueChannelFabric~new('NODE-A',mgrA,transport,'admin')
qfB=.QueueChannelFabric~new('NODE-B',mgrB,transport,'admin')
transport~registerEndpoint('NODE-A',qfA); transport~registerEndpoint('NODE-B',qfB)

call qok mgrA~createQueue('XMIT.AB','TEMPORARY','OBJECT',64,'admin'), 'A xmit'
call qok mgrA~createQueue('OBJECT.REPLY.A','TEMPORARY','OBJECT',64,'admin'), 'A reply'
call qok mgrB~createQueue('OBJECT.REQUEST.B','TEMPORARY','OBJECT',64,'admin'), 'B request'
call qok mgrB~createQueue('XMIT.BA','TEMPORARY','OBJECT',64,'admin'), 'B xmit'

call qok mgrA~grant('XMIT.AB','object-client','PUT','admin'), 'A xmit put'
call qok mgrA~grant('XMIT.AB','object-client','GET','admin'), 'A xmit get'
call qok mgrA~grant('OBJECT.REPLY.A','object-client','PUT','admin'), 'A reply put'
call qok mgrA~grant('OBJECT.REPLY.A','object-client','GET','admin'), 'A reply get'
call qok mgrB~grant('OBJECT.REQUEST.B','object-service','PUT','admin'), 'B request put'
call qok mgrB~grant('OBJECT.REQUEST.B','object-service','GET','admin'), 'B request get'
call qok mgrB~grant('XMIT.BA','object-service','PUT','admin'), 'B xmit put'
call qok mgrB~grant('XMIT.BA','object-service','GET','admin'), 'B xmit get'

call qok qfA~defineSenderChannel('A.TO.B','XMIT.AB','NODE-B','B.FROM.A','object-client','object-service',1,'TEMPORARY','admin'), 'A sender'
call qok qfB~defineReceiverChannel('B.FROM.A','NODE-A','object-service','TEMPORARY','admin'), 'B receiver'
call qok qfA~startSenderChannel('A.TO.B','admin'), 'start A sender'
call qok qfB~startReceiverChannel('B.FROM.A','admin'), 'start B receiver'
call qok qfA~defineRemoteQueue('B.OBJECT','OBJECT.REQUEST.B','NODE-B','XMIT.AB','A.TO.B','OBJECT','TEMPORARY','admin','admin'), 'A remote request'
call qok qfA~grantRemotePut('B.OBJECT','object-client','admin'), 'grant A remote request'

call qok qfB~defineSenderChannel('B.TO.A','XMIT.BA','NODE-A','A.FROM.B','object-service','object-client',1,'TEMPORARY','admin'), 'B sender'
call qok qfA~defineReceiverChannel('A.FROM.B','NODE-B','object-client','TEMPORARY','admin'), 'A receiver'
call qok qfB~startSenderChannel('B.TO.A','admin'), 'start B sender'
call qok qfA~startReceiverChannel('A.FROM.B','admin'), 'start A receiver'
call qok qfB~defineRemoteQueue('A.REPLY','OBJECT.REPLY.A','NODE-A','XMIT.BA','B.TO.A','OBJECT','TEMPORARY','admin','admin'), 'B remote reply'
call qok qfB~grantRemotePut('A.REPLY','object-service','admin'), 'grant B remote reply'

serviceB=.ClusterObjectPeerService~new('NODE-B',hostB)
serverB=.ClusterObjectQueueFabricServer~new(qfB,'NODE-A',serviceB,'OBJECT.REQUEST.B','A.REPLY','B.TO.A','object-service')
clientTransport=.ClusterObjectQueueFabricClientTransport~new(qfA,'B.OBJECT','A.TO.B','OBJECT.REPLY.A','object-client',2000)
client=.ClusterObjectPeerClient~new('NODE-A',clientTransport)
coord=.ClusterObjectMoveCoordinator~new(hostA,client)

/* Server runs concurrently while the client waits for the response. */
/* The transport graph names resident memory but must not contain its payload. */
probeEnv=hostA~snapshot('runner-1',2)
probeReq=.ClusterObjectCodec~newRequest('move-wire-probe','NODE-A','NODE-B','MOVE')
.ClusterMoveRequestMutator~new(probeEnv,.ClusterObjectCodec~memoryRef(fabric~fabricId,bB))~apply(probeReq)
encodedMove=codecA~encode(probeReq)
call must pos(c2x('audio-2210-2220'),encodedMove)>0, 'MOVE graph carries Memory Fabric block identity'
call must pos(c2x('AUDIO-B'),encodedMove)=0, 'MOVE graph does not carry resident audio bytes'

serverMessage=.message~new(serverB,'PROCESSONE'); serverMessage~start
move=coord~moveToBlock('runner-1','NODE-B',bB,fabric~fabricId)
debugServer=serverMessage~result
call must move~ok, 'move runner to resident memory B'
serverResult=serverMessage~result
call must serverResult~ok, 'server accepted move'
call must hostA~resident('runner-1')==.nil, 'runner released from A after ACK'
call must hostB~resident('runner-1')<>.nil, 'runner resident on B'

/* Queue graph codec must round-trip the actual call request graph. */
args=.array~of(.ClusterObjectCodec~memoryBlockArg(fabric~fabricId,bB))
callReq=.ClusterObjectCodec~newRequest('codec-probe','NODE-A','NODE-B','CALL')
callReq['object_id']='runner-1'; callReq['method']='processWindow'; callReq['args']=args
encoded=codecA~encode(callReq); decoded=codecB~decode(encoded)
call must decoded['args'][1]['memory_ref']['block_id']='audio-2210-2220', 'QueueGraph payload preserves Memory Fabric reference'

/* Direct service CALL here isolates argument resolution from the already-proved
 * Queue Fabric request/reply movement above. */
callResp=serviceB~handleFrom('NODE-A',decoded)
call must callResp['status']='OK', 'destination call succeeded'
call must callResp['payload']['value']='runner-1:2210-2220:AUDIO-B:1', 'runner executed beside B memory'

/* Prove the same block generation cannot be used after provider reincarnation. */
newPB=fabric~reincarnateProvider('P-B',1,'boot-b2','memory://node-b2')
call must newPB<>.nil, 'provider B reincarnated'
staleReq=.ClusterObjectCodec~newRequest('stale-probe','NODE-A','NODE-B','CALL')
staleReq['object_id']='runner-1'; staleReq['method']='processWindow'; staleReq['args']=args
staleResp=serviceB~handleFrom('NODE-A',staleReq)
call must staleResp['status']='ERROR', 'stale memory generation rejected after provider epoch change'
call must staleResp['code']='ARGUMENT_RESOLUTION_FAILED', 'stale ref fails closed'

say 'PASS cluster.object.peer/0.2 Queue Fabric carries execution; Memory Fabric keeps bytes resident'
exit 0

must:
  use arg conditionValue,label
  if \conditionValue then do
    say 'FAIL:' label
    exit 90
  end
  return
qok:
  use arg outcome,label
  if outcome==.nil | \outcome~ok then do
    if outcome==.nil then say 'FAIL:' label 'nil outcome'
    else say 'FAIL:' label outcome~code outcome~detail
    exit 91
  end
  return

::class AudioWindow public
::method init
  expose label bytes
  use strict arg labelArg,bytesArg
  label=labelArg~string; bytes=bytesArg~string
::attribute label get
::attribute bytes get

::class TestRunner public
::method init
  expose id visits
  use strict arg idArg
  id=idArg~string; visits=0
::attribute id get
::attribute visits get
::method processWindow
  expose id visits
  use strict arg window
  visits+=1
  return id||':'||window~label||':'||window~bytes||':'||visits

::class TestRunnerAdapter public
::method adapterId
  return 'TEST_RUNNER'
::method capture
  use strict arg runner
  d=.directory~new; d['id']=runner~id; d['visits']=runner~visits
  return d
::method restore
  use strict arg state
  r=.TestRunner~new(state['id'])
  do i=1 to state['visits']; ignore=r~processWindow(.AudioWindow~new('restore','noop')); end
  return r

::requires 'ClusterObjectMemoryFabricTransport.cls'
::requires 'ObjectQueueChannels.cls'
