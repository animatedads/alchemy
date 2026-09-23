call fd_test_install_native_crypto
parse arg root .
if root='' then root='.'
q=root||'/qualification/starter-handoff'
address system 'rm -rf -- '||quote(q)
address system 'mkdir -p -- '||quote(q||'/state')' '||quote(q||'/evidence')' '||quote(q||'/handoff')
if rc<>0 then call fail 'mkdir'

specPath=q||'/destination.tsv'; evidenceRef='sha256:handoff-source'
s=.FDCheckpointState~new
s~put('job_id','FD-HANDOFF-TEST'); s~put('partition_id','tp-test'); s~put('start_id','FDNEW-FD-HANDOFF-TEST-1')
/* These describe the stable/original job context used to reconstruct the same
   definition. HANDOFF authority itself comes from the committed instruction. */
s~put('source_node_id','NODE-A'); s~put('owner_node_id','NODE-A')
s~put('migratable_state_root',q||'/state/migratable'); s~put('source_path',root||'/tests/synthetic_night_tiny.mp4'); s~put('profile','FD_NIGHT_F11'); s~put('output_prefix',q||'/evidence/analysis'); s~put('state_dir',q||'/state'); s~put('source_evidence_ref',evidenceRef); s~put('resume_checkpoint_path','')
s~put('wall_clock_origin','2023-10-10T00:00:00'); s~put('analysis_wall_start','2023-10-10T00:00:00'); s~put('analysis_wall_end','2023-10-10T00:00:05'); s~put('exclusion_count','0')
.FDControlFile~write(specPath,s)
app=.FDDoorMicroMotionStarterApplication~new(specPath,root||'/tests/fake_fd_started_worker.rex',q||'/state/migratable','rexx',10000,100)
fake=.FakeResumeAdapter~new
fdExec=.FDDoorMicroMotionHandoffExecutor~new(app,fake)
localRunner=.MigratableJobDestinationRunner~new(fdExec)
store=.MigratableJobStartReceiptStore~new(app~layout~startReceipts)
starter=.MigratableJobStarter~new(app,store,.nil,localRunner)
bridge=.MigratableJobStarterDestinationRunner~new(starter)
transport=.MigratableJobFileHandoffTransport~new(q||'/handoff')
manual=.MigratableJobFileManualStarter~new(transport,bridge)
checkpoint=q||'/checkpoint.bundle'; call lineout checkpoint,'fixture'; call stream checkpoint,'C','CLOSE'
i=.MigratableJobHandoffInstruction~new('FDH-1','FILE','MIG-FD-1','FD-HANDOFF-TEST',app~definitionRef,'tp-test','FDCK-1','NODE-A','PLACE-A',4,'NODE-B','PLACE-B',5,checkpoint,'sha256:state-digest','provider:verified','commit:fd-test','OOREXX','5.3-r13196','0.2-dev8',1000,'')
handoff=q||'/handoff/FDH-1.mjob'; if \transport~write(handoff,i) then call fail 'handoff write'
ackPath=q||'/handoff/FDH-1.ack'
a1=manual~start(handoff,1100,'',ackPath)
if a1==.nil | \a1~ok then call fail 'handoff first start'
if a1~executionRef<>'fd-test-execution:FDH-1' then call fail 'execution ref'
a2=manual~start(handoff,1200,'',ackPath)
if a2==.nil | \a2~ok | a2~executionRef<>a1~executionRef then call fail 'handoff replay'
if fake~starts<>1 then call fail 'handoff duplicate reached execution adapter'
if fake~nodeId<>'NODE-B' | fake~placementId<>'PLACE-B' | fake~ownershipEpoch<>5 then call fail 'destination lease binding'
if fake~checkpointId<>'FDCK-1' | fake~migrationId<>'MIG-FD-1' then call fail 'checkpoint/migration binding'
if fake~inputEvidence<>'sha256:handoff-source' then call fail 'input evidence binding'
if stream(ackPath,'C','QUERY EXISTS')='' then call fail 'ack missing'
say 'PASS FD file HANDOFF enters standard starter, preserves committed destination authority, and suppresses duplicate destination start'
exit 0
quote: procedure
  parse arg x
  return "'"||x~changestr("'","'\\''")||"'"
fail: procedure
  parse arg m
  say 'FAIL' m
  exit 1

::class FakeResumeAdapter public
::attribute starts get
::attribute nodeId get
::attribute placementId get
::attribute ownershipEpoch get
::attribute checkpointId get
::attribute migrationId get
::attribute inputEvidence get
::method init
  expose starts nodeId placementId ownershipEpoch checkpointId migrationId inputEvidence
  starts=0; nodeId=''; placementId=''; ownershipEpoch=0; checkpointId=''; migrationId=''; inputEvidence=''
::method resumeFromCheckpoint
  expose starts nodeId placementId ownershipEpoch checkpointId migrationId inputEvidence
  use strict arg definition,lease,manifest,checkpointRef,now
  starts+=1; nodeId=lease~nodeId; placementId=lease~placementId; ownershipEpoch=lease~ownershipEpoch; checkpointId=manifest~checkpointId; migrationId=manifest~migrationId; inputEvidence=manifest~inputEvidenceRef
  if checkpointRef='' then return .MigratableJobResumeResult~failure('CHECKPOINT_MISSING')
  return .MigratableJobResumeResult~success('fd-test-execution:FDH-1')

::requires 'FDDoorMicroMotionHandoff.cls'

::requires 'FDTestCryptoBootstrap.cls'
