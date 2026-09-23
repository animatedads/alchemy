call fd_test_install_native_crypto
/* End-to-end managed NEW start using the real tiny night-video worker. */
parse arg root .
if root='' then root='.'
q=root||'/qualification/starter-e2e-test'
address system 'rm -rf -- '||quote(q)
address system 'mkdir -p -- '||quote(q||'/state')' '||quote(q||'/evidence')
if rc<>0 then call fail 'mkdir'
now=time('T')*1000; job='FD-E2E-TEST'; node='NODE-AUTH-A'; evidenceRef='sha256:a3e17ac6da339bd86b04ee8833feb164cb4a142baef5f8e67a8112835aa697b9'
specPath=q||'/launch.tsv'; probePath=q||'/probe.tsv'; journal=q||'/job-node.journal'; auditPath=q||'/placement.audit'
s=.FDCheckpointState~new
s~put('job_id',job); s~put('partition_id','tiny'); s~put('start_id','FDNEW-FD-E2E-TEST-1'); s~put('source_node_id',node); s~put('owner_node_id',node); s~put('allowed_destination_nodes','NODE-AUTH-A,NODE-B'); s~put('migratable_state_root',q||'/state/migratable')
s~put('source_path',root||'/tests/synthetic_night_tiny.mp4'); s~put('profile','FD_NIGHT_F11'); s~put('output_prefix',q||'/evidence/analysis'); s~put('state_dir',q||'/state'); s~put('source_evidence_ref',evidenceRef); s~put('resume_checkpoint_path','')
s~put('wall_clock_origin','2023-10-10T00:00:00'); s~put('analysis_wall_start','2023-10-10T00:00:00'); s~put('analysis_wall_end','2023-10-10T00:00:05'); s~put('exclusion_count','0')
s~put('format_bridge',root||'/camera_ffmpeg_avformat.bridge.json'); s~put('codec_bridge',root||'/camera_ffmpeg_avcodec.bridge.json'); s~put('util_bridge',root||'/camera_ffmpeg_avutil.bridge.json')
.FDControlFile~write(specPath,s)
p=.FDCheckpointState~new; p~put('schema',.FDDoorMicroMotionManagedPlacementBuild~PROBE_SCHEMA); p~put('job_id',job); p~put('source_node_id',node); p~put('owner_node_id',node); p~put('source_evidence_ref',evidenceRef); p~put('architecture','X86_64'); p~put('memory_mib','8192'); p~put('disk_mib','65536'); p~put('cpu_units','4'); p~put('free_memory_mib','4096'); p~put('free_disk_mib','32768'); p~put('available_cpu_units','3'); p~put('observed_epoch_ms',now); p~put('lease_duration_ms','3600000'); p~put('expires_epoch_ms',now+3600000); p~put('capability_generation','1'); p~put('observation_generation','1'); p~put('runtime_generation','5.3-r13196'); p~put('proof_ref','probe:e2e'); .FDControlFile~write(probePath,p)

app=.FDDoorMicroMotionStarterApplication~new(specPath,root||'/tools/run_fd_worker.rex',q||'/state/migratable','rexx',30000,100)
env=.FDDoorMicroMotionManagedEnvironment~new(probePath,journal,now); ignore=env~validateApplication(app)
req=.MigratableJobStartRequest~new('FDNEW-FD-E2E-TEST-1','NEW',job,app~definitionRef,'tiny','',now)
audit=.MigratableJobPlacementAuditStore~new(auditPath)
allocTool=.MigratableJobManagedPlacementTool~new(app,env~allocator,env~registry,env~eligibility,.nil,.nil,audit)
a=allocTool~allocate(req,now,3600000,'E2E-ALLOC'); if \a~ok then call fail 'allocation'
if \allocTool~check(req,a~lease,now+1,'E2E-CHECK')~ok then call fail 'check'

/* restore the durable placement as the worker-side authority snapshot */
app2=.FDDoorMicroMotionStarterApplication~new(specPath,root||'/tools/run_fd_worker.rex',q||'/state/migratable','rexx',30000,100)
env2=.FDDoorMicroMotionManagedEnvironment~new(probePath,journal,now+2); ignore=env2~validateApplication(app2)
lease=env2~ownership~current(job,now+2); if lease==.nil then call fail 'lease restore'
store=.MigratableJobStartReceiptStore~new(app2~layout~startReceipts); starter=.MigratableJobStarter~new(app2,store); executor=.FDDoorMicroMotionPlacedStartExecutor~new(node,starter,app2)
tool=.MigratableJobManagedPlacementTool~new(app2,env2~allocator,env2~registry,env2~eligibility,.nil,executor,audit)
r=tool~start(req,lease,now+3,'E2E-START'); if r==.nil | \r~ok | r~code<>'RUNNING' then call fail 'managed starter did not reach RUNNING'
startStatus=.FDControlFile~read(q||'/state/migratable.start.status.tsv'); if startStatus==.nil then call fail 'start status missing'
if startStatus~get('start_contract','')<>'migratable.job.start/1' then call fail 'start contract'
if startStatus~get('placement_api','')<>'migratable.job.placement/1' then call fail 'placement api'
if startStatus~get('migration_api','')<>'migratable.job/0.2' then call fail 'migration api'
if startStatus~get('migratable_job_version','')<>'0.2.5' then call fail 'Migratable Job version'
if startStatus~get('source_placement_id','')<>lease~placementId | startStatus~get('source_ownership_epoch','0')+0<>lease~ownershipEpoch then call fail 'initial authority binding'
exitState=.nil
do i=1 to 1800
  exitState=.FDControlFile~read(q||'/state/worker.exit.tsv')
  if exitState<>.nil then leave
  call SysSleep 0.05
end
if exitState==.nil then call fail 'worker exit timeout'
if exitState~get('status','')<>'OK' then call fail 'worker status='||exitState~get('status','')
if exitState~get('entry_mode','')<>'MIGRATABLE_NEW' then call fail 'entry mode'
if exitState~get('starter_api','')<>'migratable.job.start/1' then call fail 'worker starter api'
if exitState~get('source_placement_id','')<>lease~placementId | exitState~get('source_ownership_epoch','0')+0<>lease~ownershipEpoch then call fail 'worker authority binding'
run=readOne(q||'/evidence/analysis.run.tsv'); if run==.nil then call fail 'run evidence missing'
if run['status']<>'OK' | run['version']<>'0.2-dev8' then call fail 'run status/version'
if run['migration_api']<>'migratable.job/0.2' then call fail 'run migration api'
if run['decoded_frames']+0<>75 | run['analysed_frames']+0<>75 | run['samples_emitted']+0<>61 then call fail 'unexpected tiny-video evidence counts'
if run['audio_used']<>'NO' then call fail 'audio boundary'
if \audit~verify then call fail 'placement audit integrity'
say 'PASS FD real tiny-video managed NEW start v0.2.5 frames=75 samples=61 placement='||lease~placementId||' epoch='||lease~ownershipEpoch
exit 0

readOne: procedure
  use arg path
  inp=.CSVStream~new(path,.false); inp~delimiter='09'x; inp~open('read')
  if inp~state<>'READY' then return .nil
  header=inp~csvLineIn; row=inp~csvLineIn; inp~close
  if header==.nil | row==.nil then return .nil
  d=.directory~new
  do i=1 to header~items
    v=''; if row~items>=i then v=row[i]
    d[header[i]]=v
  end
  return d
quote: procedure
 parse arg x
 return "'"||x~changestr("'","'\\''")||"'"
fail: procedure
 parse arg m
 say 'FAIL' m
 exit 1
::requires 'csvStream.cls'
::requires 'FDDoorMicroMotionStarter.cls'
::requires 'FDDoorMicroMotionManagedPlacement.cls'

::requires 'FDTestCryptoBootstrap.cls'
