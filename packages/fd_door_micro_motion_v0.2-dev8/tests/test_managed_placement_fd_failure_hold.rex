call fd_test_install_native_crypto
parse arg root .
if root='' then root='.'
q=root||'/qualification/managed-placement-hold'
address system 'rm -rf -- '||quote(q)
address system 'mkdir -p -- '||quote(q||'/state')' '||quote(q||'/evidence')
now=time('T')*1000; job='FD-HOLD-TEST'; node='NODE-H'; evidence='sha256:hold-source'
specPath=q||'/launch.tsv'; probePath=q||'/probe.tsv'; journal=q||'/job-node.journal'; auditPath=q||'/placement.audit'
s=.FDCheckpointState~new; s~put('job_id',job); s~put('partition_id','hold'); s~put('start_id','FDNEW-HOLD-1'); s~put('source_node_id',node); s~put('owner_node_id',node); s~put('migratable_state_root',q||'/state/migratable'); s~put('source_path',root||'/tests/synthetic_night_tiny.mp4'); s~put('profile','FD_NIGHT_F11'); s~put('output_prefix',q||'/evidence/analysis'); s~put('state_dir',q||'/state'); s~put('source_evidence_ref',evidence); s~put('wall_clock_origin','2023-10-10T00:00:00'); s~put('analysis_wall_start','2023-10-10T00:00:00'); s~put('analysis_wall_end','2023-10-10T00:00:05'); s~put('exclusion_count','0'); .FDControlFile~write(specPath,s)
p=.FDCheckpointState~new; p~put('schema',.FDDoorMicroMotionManagedPlacementBuild~PROBE_SCHEMA); p~put('job_id',job); p~put('source_node_id',node); p~put('owner_node_id',node); p~put('source_evidence_ref',evidence); p~put('architecture','X86_64'); p~put('memory_mib','8192'); p~put('disk_mib','65536'); p~put('cpu_units','4'); p~put('free_memory_mib','4096'); p~put('free_disk_mib','32768'); p~put('available_cpu_units','3'); p~put('observed_epoch_ms',now); p~put('lease_duration_ms','3600000'); p~put('expires_epoch_ms',now+3600000); p~put('capability_generation','1'); p~put('observation_generation','1'); p~put('runtime_generation','5.3-r13196'); p~put('proof_ref','probe:hold'); .FDControlFile~write(probePath,p)
app=.FDDoorMicroMotionStarterApplication~new(specPath,root||'/tests/fake_fd_fail_worker.rex',q||'/state/migratable','rexx',2000,50)
env=.FDDoorMicroMotionManagedEnvironment~new(probePath,journal,now); ignore=env~validateApplication(app)
req=.MigratableJobStartRequest~new('FDNEW-HOLD-1','NEW',job,app~definitionRef,'hold','',now)
audit=.MigratableJobPlacementAuditStore~new(auditPath)
store=.MigratableJobStartReceiptStore~new(app~layout~startReceipts); starter=.MigratableJobStarter~new(app,store); executor=.FDDoorMicroMotionPlacedStartExecutor~new(node,starter,app)
tool=.MigratableJobManagedPlacementTool~new(app,env~allocator,env~registry,env~eligibility,.nil,executor,audit)
r=tool~allocateStart(req,now,3600000,'HOLD-OP')
if r~ok then call fail 'failed worker reported success'
if r~code<>'START_FAILED_PLACEMENT_HELD' | \r~placementHeld | r~lease==.nil then call fail 'placement not held after failed start'
if \env~ownership~isCurrent(r~lease,now+1) then call fail 'ownership not current after failed start'
rel=tool~release(req,r~lease,now+2,'HOLD-RELEASE','confirmed failed worker exited')
if \rel~ok then call fail 'explicit release failed'
if env~ownership~current(job,now+3)<>.nil then call fail 'ownership survived explicit release'
if \audit~verify then call fail 'audit verify'
say 'PASS FD failed/ambiguous managed start retains placement until explicit RELEASE'
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
