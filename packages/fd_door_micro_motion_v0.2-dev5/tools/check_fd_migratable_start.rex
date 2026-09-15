/* Strong worker-side checker for dev5 managed initial placement. */
parse arg specPath probePath journalPath .
if specPath='' | probePath='' | journalPath='' then do
  say 'usage: rexx check_fd_migratable_start.rex SPEC.tsv PROBE.tsv JOB_NODE.journal'
  exit 64
end
signal on syntax name failed
spec=.FDControlFile~read(specPath); if spec==.nil then do; say 'FD_MIGRATABLE_CHECK_ERROR spec unreadable'; exit 1; end
stateDir=spec~require('state_dir')
st=.FDControlFile~read(stateDir||'/migratable.start.status.tsv'); if st==.nil then do; say 'FD_MIGRATABLE_CHECK_ERROR status missing'; exit 1; end
if st~get('status','')<>'RUNNING' then do; say 'FD_MIGRATABLE_CHECK_ERROR status='||st~get('status',''); exit 1; end
if st~get('start_contract','')<>.MigratableJobStartContract~API then do; say 'FD_MIGRATABLE_CHECK_ERROR starter contract'; exit 1; end
if st~get('migration_api','')<>.MigratableJobBuild~API then do; say 'FD_MIGRATABLE_CHECK_ERROR migration api'; exit 1; end
if st~get('migratable_job_version','')<>.MigratableJobBuild~VERSION | .MigratableJobBuild~VERSION<>'0.2.4' then do; say 'FD_MIGRATABLE_CHECK_ERROR Migratable Job baseline='||st~get('migratable_job_version',''); exit 1; end
if st~get('placement_api','')<>.MigratableJobPlacementContract~API | st~get('placement_receipt_api','')<>.MigratableJobPlacementContract~RECEIPT_API then do; say 'FD_MIGRATABLE_CHECK_ERROR managed placement contract'; exit 1; end
parse source . . thisFile
here=filespec('LOCATION',thisFile)
app=.FDDoorMicroMotionStarterApplication~new(specPath,here||'run_fd_worker.rex',spec~get('migratable_state_root',stateDir||'/migratable'),'rexx',120000,250)
now=time('T')*1000
env=.FDDoorMicroMotionManagedEnvironment~new(probePath,journalPath,now); ignore=env~validateApplication(app)
lease=env~ownership~current(spec~require('job_id'),now)
if lease==.nil then do; say 'FD_MIGRATABLE_CHECK_ERROR no current Job-to-Node lease in journal'; exit 1; end
if \env~rawAllocator~verifyLease(lease,app~definition(.nil)~placementRequest,now) then do; say 'FD_MIGRATABLE_CHECK_ERROR Job-to-Node lease does not verify'; exit 1; end
if st~get('source_node_id','')<>lease~nodeId | st~get('source_placement_id','')<>lease~placementId | st~get('source_ownership_epoch','0')+0<>lease~ownershipEpoch then do; say 'FD_MIGRATABLE_CHECK_ERROR start status/lease mismatch'; exit 1; end
auth=.FDControlFile~read(stateDir||'/migratable.initial.authority.tsv'); if auth==.nil then do; say 'FD_MIGRATABLE_CHECK_ERROR initial authority evidence missing'; exit 1; end
if auth~get('placement_api','')<>.MigratableJobPlacementContract~API | auth~get('source_placement_id','')<>lease~placementId | auth~get('source_ownership_epoch','0')+0<>lease~ownershipEpoch then do; say 'FD_MIGRATABLE_CHECK_ERROR authority evidence mismatch'; exit 1; end
say 'status=RUNNING'
say 'start_contract='||st~get('start_contract','')
say 'migration_api='||st~get('migration_api','')
say 'migratable_job_version='||st~get('migratable_job_version','')
say 'placement_api='||st~get('placement_api','')
say 'placement_receipt_api='||st~get('placement_receipt_api','')
say 'source_node_id='||lease~nodeId
say 'source_placement_id='||lease~placementId
say 'source_ownership_epoch='||lease~ownershipEpoch
say 'source_lease_expires_epoch_ms='||lease~expiresEpochMs
say 'FD_MIGRATABLE_CHECK_OK'
exit 0
failed:
  say 'FD_MIGRATABLE_CHECK_ERROR' condition('D')
  exit 1
::requires 'FDDoorMicroMotionStarter.cls'
::requires 'FDDoorMicroMotionManagedPlacement.cls'
