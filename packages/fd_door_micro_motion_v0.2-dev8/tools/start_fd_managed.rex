/* Worker-node authoritative START for an already allocated Job-to-Node lease.
 * JOURNAL must be the unmodified durable snapshot produced by
 * allocate_fd_managed.rex.  The standard managed tool re-verifies the exact
 * lease before the standard starter is entered.
 */
parse arg specPath probePath journalPath auditPath .
if specPath='' | probePath='' | journalPath='' | auditPath='' then do
  say 'usage: rexx start_fd_managed.rex SPEC.tsv PROBE.tsv JOB_NODE.journal PLACEMENT.audit'
  exit 64
end
signal on syntax name failed
spec=.FDControlFile~read(specPath)
if spec==.nil then do; say 'FD_MANAGED_START_ERROR cannot read launch spec'; exit 65; end
parse source . . thisFile
here=filespec('LOCATION',thisFile)
app=.FDDoorMicroMotionStarterApplication~new(specPath,here||'run_fd_worker.rex',spec~get('migratable_state_root',spec~require('state_dir')||'/migratable'),'rexx',120000,250)
now=time('T')*1000
env=.FDDoorMicroMotionManagedEnvironment~new(probePath,journalPath,now)
ignore=env~validateApplication(app)
lease=env~ownership~current(spec~require('job_id'),now)
if lease==.nil then do; say 'FD_MANAGED_START_ERROR no current Job-to-Node placement in supplied durable journal'; exit 1; end
store=.MigratableJobStartReceiptStore~new(app~layout~startReceipts)
starter=.MigratableJobStarter~new(app,store)
executor=.FDDoorMicroMotionPlacedStartExecutor~new(spec~require('source_node_id'),starter,app)
audit=.MigratableJobPlacementAuditStore~new(auditPath)
tool=.MigratableJobManagedPlacementTool~new(app,env~allocator,env~registry,env~eligibility,.nil,executor,audit)
req=.MigratableJobStartRequest~new(spec~require('start_id'),.MigratableJobStartMode~NEW,spec~require('job_id'),app~definitionRef,spec~get('partition_id',spec~require('job_id')),'',now)
check=tool~check(req,lease,now,'FD-WORKER-CHECK-'||req~startId)
if check==.nil | \check~ok then do
  code='CHECK_MISSING'; if check<>.nil then code=check~code
  say 'FD_MANAGED_START_ERROR' code
  exit 1
end
started=tool~start(req,lease,now,'FD-WORKER-START-'||req~startId)
if started==.nil | \started~ok then do
  code='START_MISSING'; detail=''; if started<>.nil then do; code=started~code; detail=started~detail; end
  say 'FD_MANAGED_START_ERROR' code detail
  if started<>.nil then if started~placementHeld then say 'PLACEMENT_HELD=YES'
  exit 1
end
say 'FD_MANAGED_START_OK'
say 'placement_api='||.MigratableJobPlacementContract~API
say 'placement_receipt_api='||.MigratableJobPlacementContract~RECEIPT_API
say 'start_contract='||.MigratableJobStartContract~API
say 'migratable_job_version='||.MigratableJobBuild~VERSION
say 'job_id='||req~jobId
say 'node_id='||lease~nodeId
say 'placement_id='||lease~placementId
say 'ownership_epoch='||lease~ownershipEpoch
say 'execution_ref='||started~startResult~executionRef
say 'replayed='||started~startResult~replayed
say 'PLACEMENT_HELD=YES'
exit 0
failed:
  say 'FD_MANAGED_START_ERROR' condition('D')
  exit 1
::requires 'FDDoorMicroMotionStarter.cls'
::requires 'FDDoorMicroMotionManagedPlacement.cls'
