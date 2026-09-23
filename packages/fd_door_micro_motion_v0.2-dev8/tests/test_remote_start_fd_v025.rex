numeric digits 30
call fd_test_install_native_crypto
parse arg root .
if root='' then root='.'
q=root||'/qualification/remote-start-v025'
address system 'rm -rf -- '||quote(q)
address system 'mkdir -p -- '||quote(q||'/state')' '||quote(q||'/evidence')
if rc<>0 then call fail 'mkdir'

now=time('T')*1000
job='FD-REMOTE-025'; node='NODE-B'; evidence='sha256:remote-v025-source'
specPath=q||'/launch.tsv'; probePath=q||'/probe.tsv'; journal=q||'/job-node.journal'; auditPath=q||'/placement.audit'; countPath=q||'/count.txt'; rpcLedger=q||'/remote-start.rpc'; receiptPath=q||'/start.receipts'

s=.FDCheckpointState~new
s~put('job_id',job); s~put('partition_id','remote'); s~put('start_id','FDNEW-REMOTE-025-1'); s~put('source_node_id',node); s~put('owner_node_id',node); s~put('allowed_destination_nodes','NODE-B'); s~put('migratable_state_root',q||'/state/migratable')
s~put('source_path',root||'/tests/synthetic_night_tiny.mp4'); s~put('profile','FD_NIGHT_F11'); s~put('output_prefix',q||'/evidence/analysis'); s~put('state_dir',q||'/state'); s~put('source_evidence_ref',evidence); s~put('resume_checkpoint_path',''); s~put('test_counter_path',countPath)
s~put('wall_clock_origin','2023-10-10T00:00:00'); s~put('analysis_wall_start','2023-10-10T00:00:00'); s~put('analysis_wall_end','2023-10-10T00:00:05'); s~put('exclusion_count','0')
.FDControlFile~write(specPath,s)

p=.FDCheckpointState~new
p~put('schema',.FDDoorMicroMotionManagedPlacementBuild~PROBE_SCHEMA); p~put('job_id',job); p~put('source_node_id',node); p~put('owner_node_id',node); p~put('source_evidence_ref',evidence); p~put('architecture','X86_64'); p~put('memory_mib','8192'); p~put('disk_mib','65536'); p~put('cpu_units','4'); p~put('free_memory_mib','4096'); p~put('free_disk_mib','32768'); p~put('available_cpu_units','3'); p~put('observed_epoch_ms',now); p~put('lease_duration_ms','3600000'); p~put('expires_epoch_ms',now+3600000); p~put('capability_generation','1'); p~put('observation_generation','1'); p~put('runtime_generation','5.3-r13196'); p~put('proof_ref','probe:remote-v025')
.FDControlFile~write(probePath,p)

sourceApp=.FDDoorMicroMotionStarterApplication~new(specPath,root||'/tests/fake_fd_started_worker.rex',q||'/state/migratable','rexx',10000,50)
destApp=.FDDoorMicroMotionStarterApplication~new(specPath,root||'/tests/fake_fd_started_worker.rex',q||'/state/migratable','rexx',10000,50)
env=.FDDoorMicroMotionManagedEnvironment~new(probePath,journal,now); ignore=env~validateApplication(sourceApp); ignore=env~validateApplication(destApp)

/* Queue Fabric is qualification scaffolding only. Production routes are owned
   by QueueRexx; this proves the FD workload binds correctly to upstream 0.2.5. */
transport=.QueueInProcessTransport~new
ma=.ObjectQueueManager~new('',.QueueGraphPayloadCodec~new,'admin')
mb=.ObjectQueueManager~new('',.QueueGraphPayloadCodec~new,'admin')
call must ma~createQueue('XMIT.B','TEMPORARY','MIGRATABLE_JOB',100,'admin'),'create source xmit'
call must ma~createQueue('REPLY','TEMPORARY','MIGRATABLE_JOB',100,'admin'),'create source reply'
call must ma~grant('REPLY','wire-a',.QueueAccess~PUT,'admin'),'grant reply wire'
call must ma~grant('REPLY','client-a',.QueueAccess~GET,'admin'),'grant reply client'
call must mb~createQueue('START.REQUEST','TEMPORARY','MIGRATABLE_JOB',100,'admin'),'create destination request'
call must mb~createQueue('XMIT.A','TEMPORARY','MIGRATABLE_JOB',100,'admin'),'create destination xmit'
call must mb~grant('START.REQUEST','wire-b',.QueueAccess~PUT,'admin'),'grant request wire'
call must mb~grant('START.REQUEST','mj-start-service',.QueueAccess~GET,'admin'),'grant request service'
fa=.QueueChannelFabric~new('QM.A',ma,transport,'admin')
fb=.QueueChannelFabric~new('QM.B',mb,transport,'admin')
ignore=transport~registerEndpoint('QM.A',fa); ignore=transport~registerEndpoint('QM.B',fb)
call must fa~defineSenderChannel('A.TO.B','XMIT.B','QM.B','A.TO.B','admin','wire-b',0,'TEMPORARY','admin'),'sender A-B'
call must fb~defineReceiverChannel('A.TO.B','QM.A','wire-b','TEMPORARY','admin'),'receiver A-B'
call must fb~defineSenderChannel('B.TO.A','XMIT.A','QM.A','B.TO.A','admin','wire-a',0,'TEMPORARY','admin'),'sender B-A'
call must fa~defineReceiverChannel('B.TO.A','QM.B','wire-a','TEMPORARY','admin'),'receiver B-A'
call must fa~startSenderChannel('A.TO.B','admin'),'start A-B'
call must fb~startReceiverChannel('A.TO.B','admin'),'recv A-B'
call must fb~startSenderChannel('B.TO.A','admin'),'start B-A'
call must fa~startReceiverChannel('B.TO.A','admin'),'recv B-A'
call must fa~defineRemoteQueue('B.MJ.START','START.REQUEST','QM.B','XMIT.B','A.TO.B','MIGRATABLE_JOB','TEMPORARY','admin','admin'),'remote start'
call must fa~grantRemotePut('B.MJ.START','client-a','admin'),'grant remote start'
call must fb~defineRemoteQueue('A.MJ.REPLY','REPLY','QM.A','XMIT.A','B.TO.A','MIGRATABLE_JOB','TEMPORARY','admin','admin'),'remote reply'
call must fb~grantRemotePut('A.MJ.REPLY','mj-start-service','admin'),'grant remote reply'

store=.MigratableJobStartReceiptStore~new(receiptPath)
starter=.MigratableJobStarter~new(destApp,store)
baseVerifier=.MigratableJobLocalPlacedStartLeaseVerifier~new(destApp,env~allocator)
fdVerifier=.FDDoorMicroMotionRemoteStartLeaseVerifier~new(destApp,baseVerifier)
access=.MigratableJobRemoteStartAccessPolicy~new; ignore=access~grant('client-a',node)
ledger=.MigratableJobRemoteStartRequestLedger~new(rpcLedger,.QueueGraphPayloadCodec~new)
service=.MigratableJobRemoteStartService~new(node,starter,fdVerifier,mb,'START.REQUEST',fb,'mj-start-service',access,ledger,.JobNodeDigestProvider~new,'FD-REMOTE-START-B')
ignore=service~bindClientReply('client-a','A.MJ.REPLY')
progress=.FDRemoteStartProgress~new(fa,fb,service)
executor=.MigratableJobQueuePlacedStartExecutor~new(fa,ma,'REPLY','client-a','client-a',.JobNodeDigestProvider~new,10,0,progress)
ignore=executor~bindNodeQueue(node,'B.MJ.START')
req=.MigratableJobStartRequest~new('FDNEW-REMOTE-025-1','NEW',job,sourceApp~definitionRef,'remote','',now)
audit=.MigratableJobPlacementAuditStore~new(auditPath)
tool=.MigratableJobManagedPlacementTool~new(sourceApp,env~allocator,env~registry,env~eligibility,.nil,executor,audit)

placedResult=tool~allocateStart(req,now,3600000,'REMOTE-ALLOCATE-START')
if placedResult==.nil | \placedResult~ok | placedResult~code<>'RUNNING' then call fail 'remote allocate-start' placedResult~code placedResult~detail
if placedResult~lease==.nil | placedResult~lease~nodeId<>node then call fail 'remote destination lease'
if placedResult~startResult==.nil | placedResult~startResult~executionRef='' then call fail 'remote execution ref'
if destApp~sourcePlacementId<>placedResult~lease~placementId | destApp~sourceOwnershipEpoch<>placedResult~lease~ownershipEpoch then call fail 'FD destination did not bind verified lease'
if sourceApp~sourcePlacementId<>'' | sourceApp~sourceOwnershipEpoch<>0 then call fail 'source application was mutated by remote start'
call SysSleep 0.1
count=linein(countPath)+0; call stream countPath,'C','CLOSE'; if count<>1 then call fail 'initial worker count='||count

/* Reconstruct only the RPC service/ledger and replay exact start id. */
ledger2=.MigratableJobRemoteStartRequestLedger~new(rpcLedger,.QueueGraphPayloadCodec~new)
service2=.MigratableJobRemoteStartService~new(node,starter,fdVerifier,mb,'START.REQUEST',fb,'mj-start-service',access,ledger2,.JobNodeDigestProvider~new,'FD-REMOTE-START-B-RESTART')
ignore=service2~bindClientReply('client-a','A.MJ.REPLY')
progress2=.FDRemoteStartProgress~new(fa,fb,service2)
executor2=.MigratableJobQueuePlacedStartExecutor~new(fa,ma,'REPLY','client-a','client-a',.JobNodeDigestProvider~new,10,0,progress2)
ignore=executor2~bindNodeQueue(node,'B.MJ.START')
tool2=.MigratableJobManagedPlacementTool~new(sourceApp,env~allocator,env~registry,env~eligibility,.nil,executor2,audit)
again=tool2~start(req,placedResult~lease,now+1,'REMOTE-REPLAY')
if again==.nil | \again~ok | again~code<>'RUNNING' then call fail 'remote replay'
if again~startResult==.nil | \again~startResult~replayed then call fail 'remote replay flag'
call SysSleep 0.1
count=linein(countPath)+0; call stream countPath,'C','CLOSE'; if count<>1 then call fail 'duplicate remote worker count='||count

/* Same start id with changed authority binding must fail before workload entry. */
l=placedResult~lease
badLease=.JobNodePlacementLease~new(l~placementId,l~jobId,l~nodeId,l~ownerNodeId,l~capabilityGeneration,l~capacityObservationGeneration,l~issuedEpochMs,l~expiresEpochMs,l~requirementDigest,l~capabilityDigest,l~capacityDigest,l~allocationPolicyGeneration,l~proofRef,l~reservationRef,l~signature,l~ownershipEpoch+1,l~renewalSequence,l~supersedesPlacementId)
bad=executor2~start(badLease,req,now+2)
if bad==.nil | bad~ok | bad~code<>'REQUEST_ID_CONFLICT' then call fail 'conflicting remote start accepted/code=' bad~code
call SysSleep 0.1
count=linein(countPath)+0; call stream countPath,'C','CLOSE'; if count<>1 then call fail 'conflict reached worker count='||count
if \audit~verify then call fail 'placement audit integrity'

say 'PASS FD Migratable Job v0.2.5 remote NEW start, verified-lease binding, durable replay, conflict rejection worker_count=1 placement='||placedResult~lease~placementId
exit 0

must: procedure
  use arg r,label
  if r==.nil then do; say 'FAIL nil' label; exit 11; end
  if \r~ok then do; say 'FAIL' label r~code r~detail; exit 12; end
  return
quote: procedure
  parse arg x
  return "'"||x~changestr("'","'\\''")||"'"
fail: procedure
  parse arg a,b,c
  say 'FAIL' a b c
  exit 1

::class FDRemoteStartProgress
::method init
  expose fa fb service
  use strict arg faArg,fbArg,serviceArg
  fa=faArg; fb=fbArg; service=serviceArg
::method progress
  expose fa fb service
  r=fa~pump('A.TO.B',1,'admin')
  if r<>.nil then if r~ok then do
    s=service~processOne
    if s<>.nil then if s~ok then ignore=fb~pump('B.TO.A',1,'admin')
  end
  return .true

::requires 'FDDoorMicroMotionRemoteStart.cls'
::requires 'FDDoorMicroMotionManagedPlacement.cls'
::requires 'FDTestCryptoBootstrap.cls'
