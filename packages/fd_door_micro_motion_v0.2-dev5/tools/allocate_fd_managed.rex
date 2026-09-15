/* Central authoritative initial placement: PLAN -> ALLOCATE -> CHECK.
 * This never starts the worker.  It persists Job-to-Node ownership in JOURNAL
 * and records standard migratable.job.placement.receipt/1 audit evidence.
 */
parse arg specPath probePath journalPath auditPath .
if specPath='' | probePath='' | journalPath='' | auditPath='' then do
  say 'usage: rexx allocate_fd_managed.rex SPEC.tsv PROBE.tsv JOB_NODE.journal PLACEMENT.audit'
  exit 64
end
signal on syntax name failed
parse source . . thisFile
here=filespec('LOCATION',thisFile)
app=.FDDoorMicroMotionStarterApplication~new(specPath,here||'run_fd_worker.rex','', 'rexx',120000,250)
now=time('T')*1000
env=.FDDoorMicroMotionManagedEnvironment~new(probePath,journalPath,now)
ignore=env~validateApplication(app)
spec=.FDControlFile~read(specPath)
req=.MigratableJobStartRequest~new(spec~require('start_id'),.MigratableJobStartMode~NEW,spec~require('job_id'),app~definitionRef,spec~get('partition_id',spec~require('job_id')),'',now)
audit=.MigratableJobPlacementAuditStore~new(auditPath)
tool=.MigratableJobManagedPlacementTool~new(app,env~allocator,env~registry,env~eligibility,.nil,.nil,audit)
plan=tool~plan(req,now,'FD-PLAN-'||req~startId)
if plan==.nil | \plan~ok then do
  code='PLAN_MISSING'; if plan<>.nil then code=plan~code
  say 'FD_MANAGED_ALLOCATE_ERROR' code
  exit 1
end
say 'FD_MANAGED_PLAN_OK recommended_node='plan~plan~recommendedNodeId 'request_digest='plan~plan~requestDigest
leaseMs=env~probe~leaseDurationMs
alloc=tool~allocate(req,now,leaseMs,'FD-ALLOCATE-'||req~startId)
if alloc==.nil | \alloc~ok | alloc~lease==.nil then do
  code='ALLOCATE_MISSING'; if alloc<>.nil then code=alloc~code
  say 'FD_MANAGED_ALLOCATE_ERROR' code
  exit 1
end
check=tool~check(req,alloc~lease,now,'FD-CHECK-'||req~startId)
if check==.nil | \check~ok then do
  code='CHECK_MISSING'; if check<>.nil then code=check~code
  say 'FD_MANAGED_ALLOCATE_ERROR' code
  exit 1
end
say 'FD_MANAGED_ALLOCATE_OK placement_api='||.MigratableJobPlacementContract~API 'code='||alloc~code
say 'job_id='||req~jobId
say 'node_id='||alloc~lease~nodeId
say 'placement_id='||alloc~lease~placementId
say 'ownership_epoch='||alloc~lease~ownershipEpoch
say 'issued_epoch_ms='||alloc~lease~issuedEpochMs
say 'expires_epoch_ms='||alloc~lease~expiresEpochMs
say 'requirement_digest='||alloc~lease~requirementDigest
say 'journal='||journalPath
say 'placement_audit='||auditPath
exit 0
failed:
  say 'FD_MANAGED_ALLOCATE_ERROR' condition('D')
  exit 1
::requires 'FDDoorMicroMotionStarter.cls'
::requires 'FDDoorMicroMotionManagedPlacement.cls'
