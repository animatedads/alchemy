call fd_test_install_native_crypto
parse arg root .
if root='' then root='.'
q=root||'/qualification/managed-placement-new'
address system 'rm -rf -- '||quote(q)
address system 'mkdir -p -- '||quote(q||'/state')' '||quote(q||'/evidence')
if rc<>0 then call fail 'mkdir'
now=time('T')*1000
job='FD-MANAGED-TEST'; node='NODE-A'; evidence='sha256:managed-test-source'; specPath=q||'/launch.tsv'; probePath=q||'/probe.tsv'; journal=q||'/job-node.journal'; auditPath=q||'/placement.audit'; countPath=q||'/count.txt'

s=.FDCheckpointState~new
s~put('job_id',job); s~put('partition_id','tp-test'); s~put('start_id','FDNEW-FD-MANAGED-TEST-1'); s~put('source_node_id',node); s~put('owner_node_id',node); s~put('migratable_state_root',q||'/state/migratable')
s~put('source_path',root||'/tests/synthetic_night_tiny.mp4'); s~put('profile','FD_NIGHT_F11'); s~put('output_prefix',q||'/evidence/analysis'); s~put('state_dir',q||'/state'); s~put('source_evidence_ref',evidence); s~put('resume_checkpoint_path','')
s~put('wall_clock_origin','2023-10-10T00:00:00'); s~put('analysis_wall_start','2023-10-10T00:00:00'); s~put('analysis_wall_end','2023-10-10T00:00:05'); s~put('exclusion_count','0'); s~put('test_counter_path',countPath)
.FDControlFile~write(specPath,s)

p=.FDCheckpointState~new
p~put('schema',.FDDoorMicroMotionManagedPlacementBuild~PROBE_SCHEMA); p~put('job_id',job); p~put('source_node_id',node); p~put('owner_node_id',node); p~put('source_evidence_ref',evidence); p~put('architecture','X86_64'); p~put('memory_mib','8192'); p~put('disk_mib','65536'); p~put('cpu_units','4'); p~put('free_memory_mib','4096'); p~put('free_disk_mib','32768'); p~put('available_cpu_units','3'); p~put('observed_epoch_ms',now); p~put('lease_duration_ms','3600000'); p~put('expires_epoch_ms',now+3600000); p~put('capability_generation','1'); p~put('observation_generation','1'); p~put('runtime_generation','5.3-r13196'); p~put('proof_ref','probe:managed-test')
.FDControlFile~write(probePath,p)

runner=root||'/tests/fake_fd_started_worker.rex'
app=.FDDoorMicroMotionStarterApplication~new(specPath,runner,q||'/state/migratable','rexx',10000,100)
env=.FDDoorMicroMotionManagedEnvironment~new(probePath,journal,now); ignore=env~validateApplication(app)
req=.MigratableJobStartRequest~new('FDNEW-FD-MANAGED-TEST-1','NEW',job,app~definitionRef,'tp-test','',now)
audit=.MigratableJobPlacementAuditStore~new(auditPath)
tool=.MigratableJobManagedPlacementTool~new(app,env~allocator,env~registry,env~eligibility,.nil,.nil,audit)
plan=tool~plan(req,now,'PLAN-1'); if \plan~ok | plan~plan~recommendedNodeId<>node then call fail 'plan'
a=tool~allocate(req,now,3600000,'ALLOC-1'); if \a~ok | a~lease==.nil then call fail 'allocate'
if a~lease~nodeId<>node | a~lease~ownershipEpoch<>1 then call fail 'lease identity'
a2=tool~allocate(req,now+1,3600000,'ALLOC-REPLAY'); if \a2~ok | a2~code<>'PLACED_REPLAY' | a2~lease~placementId<>a~lease~placementId then call fail 'allocation replay'
c=tool~check(req,a~lease,now+2,'CHECK-1'); if \c~ok then call fail 'check'
if \audit~verify then call fail 'audit after allocation'

/* Simulate transfer of the same durable journal to the execution node by
 * restoring a second environment from the journal. */
app2=.FDDoorMicroMotionStarterApplication~new(specPath,runner,q||'/state/migratable','rexx',10000,100)
env2=.FDDoorMicroMotionManagedEnvironment~new(probePath,journal,now+3); ignore=env2~validateApplication(app2)
lease2=env2~ownership~current(job,now+3); if lease2==.nil then call fail 'restored lease missing'
store=.MigratableJobStartReceiptStore~new(app2~layout~startReceipts)
starter=.MigratableJobStarter~new(app2,store)
executor=.FDDoorMicroMotionPlacedStartExecutor~new(node,starter,app2)
tool2=.MigratableJobManagedPlacementTool~new(app2,env2~allocator,env2~registry,env2~eligibility,.nil,executor,audit)
cs=tool2~check(req,lease2,now+3,'WORKER-CHECK'); if \cs~ok then call fail 'worker check'
r1=tool2~start(req,lease2,now+4,'START-1'); if \r1~ok | r1~code<>'RUNNING' then call fail 'managed start'
r2=tool2~start(req,lease2,now+5,'START-REPLAY'); if \r2~ok | \r2~startResult~replayed then call fail 'start replay'
call SysSleep 0.2
count=linein(countPath)+0; call stream countPath,'C','CLOSE'; if count<>1 then call fail 'duplicate worker count='||count
st=.FDControlFile~read(q||'/state/migratable.start.status.tsv'); if st==.nil then call fail 'start status missing'
if st~get('placement_api','')<>'migratable.job.placement/1' | st~get('migratable_job_version','')<>'0.2.5' then call fail 'managed API/version status'
if st~get('source_placement_id','')<>lease2~placementId | st~get('source_ownership_epoch','0')+0<>lease2~ownershipEpoch then call fail 'status placement binding'
if \audit~verify then call fail 'audit after start'

call SysSleep 2.2
rel=tool~release(req,a~lease,now+10,'RELEASE-1','test runtime ended'); if \rel~ok | rel~placementHeld then call fail 'release'
if env~ownership~current(job,now+11)<>.nil then call fail 'ownership survived release'
if \audit~verify then call fail 'audit after release'
say 'PASS FD managed placement PLAN/ALLOCATE/CHECK/START/replay/RELEASE via v0.2.5 placement API'
exit 0

quote: procedure
  parse arg x
  return "'"||x~changestr("'","'\\''")||"'"
fail: procedure
  parse arg m
  say 'FAIL' m
  exit 1
::requires 'FDDoorMicroMotionStarter.cls'
::requires 'FDDoorMicroMotionManagedPlacement.cls'

::requires 'FDTestCryptoBootstrap.cls'
