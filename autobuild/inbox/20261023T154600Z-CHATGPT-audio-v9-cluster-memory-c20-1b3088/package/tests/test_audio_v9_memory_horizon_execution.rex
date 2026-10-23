/* Candidate20 semantic qualification.
 * One ordinary Audio runner starts beside block 1.  Reading near the adaptive
 * Memory Fabric horizon raises demand for block 2.  The coordinator verifies
 * placement and moves the runner through Queue Fabric to block 2.  No PCM/data
 * payload is placed in the MOVE graph.
 */
numeric digits 30
say 'AUDIO V9 CANDIDATE20 MEMORY HORIZON TEST START'

fabric=.MemoryFabricRegistry~new('AUDIO-HOT')
pA=.MemoryFabricProvider~new('P-A','MU','NODE-A','','SITE-1','MACHINE-A','',10485760,0,'ACTIVE','ACCEPTING',1,1,'boot-a')
pB=.MemoryFabricProvider~new('P-B','MU','NODE-B','','SITE-1','MACHINE-B','',10485760,0,'ACTIVE','ACCEPTING',1,1,'boot-b')
call must fabric~registerProvider(pA), 'register provider A'
call must fabric~registerProvider(pB), 'register provider B'

bA=.MemoryFabricBlockRef~new('audio-samples-1-10',1,'P-A',0,4096,'RECONSTRUCTABLE','storage:audio:1-10',1)
bB=.MemoryFabricBlockRef~new('audio-samples-11-20',1,'P-B',0,4096,'RECONSTRUCTABLE','storage:audio:11-20',1)
call must fabric~publishBlock(bA), 'publish block A'
call must fabric~publishBlock(bB), 'publish block B'

/* Audio logical stream + adaptive event horizon. */
stream=.MemoryFabricSparseArray~new('audio-stream',1)
stream~putValue('8','s8'); stream~putValue('9','s9'); stream~putValue('10','s10')
cursor=stream~openCursor('audio-cursor','audio-task','audio-reader','1','1','10',2,'FORWARD')
call must cursor<>.nil, 'open audio cursor'
stream~armHorizonProjection
/* 10 items/s * 100ms * safety 2 = 2 items. */
distance=stream~adaptCursorHorizon('audio-cursor',10,100,2,1,10)
call must distance=2, 'adaptive horizon distance'

/* Candidate19 execution plan for the next resident block. */
subject=.directory~new; subject['event']='candidate20-horizon'
intent=.AudioV9ExecutionIntegration~scientificIntent('continue measured-delay reconstruction',subject)
requirements=.AudioV9ExecutionIntegration~computeRequirements(1,'CPU',4096,'PREFER_SOURCE_RESIDENT','CHECKPOINTED')
continuation=.AudioV9TrajectoryContinuation~new('traj-20','FD',.directory~new)
ref=.AudioV9FencedMemoryBlockRef~new('AUDIO-HOT','audio-samples-11-20',1,'P-B',1)
plan=.AudioV9ExecutionIntegration~planMemoryExecution('RECONSTRUCT_NEXT_BLOCK',ref,continuation,intent,requirements)

routes=.AudioV9ResidentWindowDirectory~new(fabric,'AUDIO-HOT')
nextRange=.MemoryFabricLogicalRange~new('11','20')
call must routes~publishPlan(nextRange,plan)<>.nil, 'publish next resident route'

adapters=.ClusterObjectAdapterRegistry~new
adapters~register(.TestAudioRunnerAdapter~new)
hostA=.ClusterObjectHost~new('NODE-A',adapters,fabric,.array~of('P-A'))
hostB=.ClusterObjectHost~new('NODE-B',adapters,fabric,.array~of('P-B'))
hostA~memoryResidents~publish(bA,.TestAudioBlock~new('1-10','PCM-A'))
hostB~memoryResidents~publish(bB,.TestAudioBlock~new('11-20','PCM-B'))
runner=.TestAudioRunner~new('audio-runner',continuation)
call must hostA~attach('audio-runner',runner,'AUDIO_RUNNER',1), 'attach runner A'

/* Real Object Queue Fabric semantics; in-process carrier only. */
transport=.QueueInProcessTransport~new
codecA=.QueueGraphPayloadCodec~new; codecB=.QueueGraphPayloadCodec~new
mgrA=.ObjectQueueManager~new('',codecA,'admin'); mgrB=.ObjectQueueManager~new('',codecB,'admin')
qfA=.QueueChannelFabric~new('NODE-A',mgrA,transport,'admin'); qfB=.QueueChannelFabric~new('NODE-B',mgrB,transport,'admin')
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
moveCoordinator=.ClusterObjectMoveCoordinator~new(hostA,client)
placement=.TestPlacementGuard~new('NODE-B')
horizon=.AudioV9MemoryHorizonCoordinator~new(stream,routes,moveCoordinator,placement,'audio-runner')

/* Ordinary read crosses the adaptive event horizon. */
call must stream~at('7')==.nil, 'ordinary absent read before horizon'
call must stream~activeHorizonDemands~items=0, 'no early demand'
call must stream~at('8')='s8', 'horizon access returns normal value'
call must stream~activeHorizonDemands~items=1, 'one next-window demand'
demand=stream~activeHorizonDemands[1]
call must demand~requestedRange~first~value='11', 'demand starts at next block'
call must demand~requestedRange~last~value='20', 'demand covers next block'

/* MOVE wire mentions identity, never resident PCM. */
probeEnv=hostA~snapshot('audio-runner',2)
probeReq=.ClusterObjectCodec~newRequest('candidate20-wire','NODE-A','NODE-B','MOVE')
.ClusterMoveRequestMutator~new(probeEnv,.ClusterObjectCodec~memoryRef(fabric~fabricId,bB))~apply(probeReq)
encodedMove=codecA~encode(probeReq)
call must pos(c2x('audio-samples-11-20'),encodedMove)>0, 'wire has block identity'
call must pos(c2x('PCM-B'),encodedMove)=0, 'wire has no resident PCM payload'

serverMessage=.message~new(serverB,'PROCESSONE'); serverMessage~start
moved=horizon~serviceDemand(demand)
serverAnswer=serverMessage~result
call must serverAnswer~ok, 'destination accepted move'
call must moved~ok, 'horizon moved runner'
call must moved~destinationNode='NODE-B', 'runner moved to block owner'
call must demand~state='SATISFIED', 'demand satisfied only after move ACK'
call must stream~cursor('audio-cursor')~residentRange~first~value='11', 'cursor first advanced'
call must stream~cursor('audio-cursor')~residentRange~last~value='20', 'cursor last advanced'
call must hostA~resident('audio-runner')==.nil, 'source runner released'
call must hostB~resident('audio-runner')<>.nil, 'destination runner resident'

/* Destination resolves and processes B-local block. */
args=.array~of(.ClusterObjectCodec~memoryBlockArg(fabric~fabricId,bB))
callReq=.ClusterObjectCodec~newRequest('candidate20-call','NODE-A','NODE-B','CALL')
callReq['object_id']='audio-runner'; callReq['method']='processResidentBlock'; callReq['args']=args
encodedCall=codecA~encode(callReq); decodedCall=codecB~decode(encodedCall)
callResp=serviceB~handleFrom('NODE-A',decodedCall)
call must callResp['status']='OK', 'audio runner executes on B'
call must callResp['payload']['value']='audio-runner:11-20:PCM-B:1', 'runner sees B-local PCM'

/* Stale provider epoch must prevent route resolution and therefore movement. */
newPB=fabric~reincarnateProvider('P-B',1,'boot-b2','memory://node-b2')
call must newPB<>.nil, 'provider B reincarnated'
call must routes~resolve(nextRange)==.nil, 'stale route fenced after reincarnation'

say 'PASS Audio V9 candidate20: adaptive horizon moves runner to resident Memory Fabric block'
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
  if outcome==.nil then do; say 'FAIL:' label 'nil outcome'; exit 91; end
  if \outcome~ok then do; say 'FAIL:' label outcome~code outcome~detail; exit 91; end
  return

::class TestAudioBlock public
::method init
  expose label marker
  use strict arg labelArg,markerArg
  label=labelArg~string; marker=markerArg~string
::attribute label get
::attribute marker get

::class TestAudioRunner public
::method init
  expose id continuation visits
  use strict arg idArg,continuationArg
  id=idArg~string; continuation=continuationArg; visits=0
::attribute id get
::attribute continuation get
::attribute visits get
::method restoreVisits
  expose visits
  use strict arg n
  visits=n+0
  return visits
::method processResidentBlock
  expose id visits
  use strict arg block
  visits+=1
  return id||':'||block~label||':'||block~marker||':'||visits

::class TestAudioRunnerAdapter public
::method adapterId
  return 'AUDIO_RUNNER'
::method capture
  use strict arg runner
  continuation=runner~continuation
  c=.directory~new
  c['trajectory_id']=continuation~trajectoryId
  c['feed']=continuation~feed
  c['source_cursor']=continuation~sourceCursor
  c['path_state']=continuation~pathState
  c['doppler_state']=continuation~dopplerState
  c['spectral_state']=continuation~spectralState
  c['reconstruction_state']=continuation~reconstructionState
  c['physics_state']=continuation~physicsState
  c['vehicle_state']=continuation~vehiclePassState
  c['evidence_refs']=continuation~evidenceRefs
  d=.directory~new; d['id']=runner~id; d['continuation']=c; d['visits']=runner~visits
  return d
::method restore
  use strict arg state
  c=state['continuation']
  continuation=.AudioV9TrajectoryContinuation~new(c['trajectory_id'],c['feed'],c['source_cursor'],c['path_state'],c['doppler_state'],c['spectral_state'],c['reconstruction_state'],c['physics_state'],c['vehicle_state'],c['evidence_refs'])
  runner=.TestAudioRunner~new(state['id'],continuation)
  ignore=runner~restoreVisits(state['visits'])
  return runner

::class TestPlacementGuard public
::method init
  expose allowedNode
  use strict arg nodeArg
  allowedNode=nodeArg~string
::method verify
  expose allowedNode
  use strict arg plan,destinationNode,block,demand
  if destinationNode<>allowedNode then return .false
  if plan~placementAuthority<>.false then return .false
  if block~blockId<>plan~memoryRef~blockId then return .false
  return .true

::requires 'AudioV9MemoryHorizonExecution.cls'
::requires 'ObjectQueueChannels.cls'
