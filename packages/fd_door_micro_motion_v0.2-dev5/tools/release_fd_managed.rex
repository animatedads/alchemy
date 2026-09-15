/* Explicit central release.  Never use until runtime absence/completion has
 * been established independently. */
parse arg specPath probePath journalPath auditPath .
if specPath='' | probePath='' | journalPath='' | auditPath='' then do
  say 'usage: rexx release_fd_managed.rex SPEC.tsv PROBE.tsv JOB_NODE.journal PLACEMENT.audit'
  exit 64
end
if value('FD_RELEASE_CONFIRMED_NO_RUNTIME',,'ENVIRONMENT')<>'YES' then do
  say 'FD_MANAGED_RELEASE_ERROR set FD_RELEASE_CONFIRMED_NO_RUNTIME=YES only after proving no execution is running'
  exit 65
end
signal on syntax name failed
spec=.FDControlFile~read(specPath); if spec==.nil then do; say 'FD_MANAGED_RELEASE_ERROR cannot read spec'; exit 65; end
parse source . . thisFile
here=filespec('LOCATION',thisFile)
app=.FDDoorMicroMotionStarterApplication~new(specPath,here||'run_fd_worker.rex','', 'rexx',120000,250)
now=time('T')*1000
env=.FDDoorMicroMotionManagedEnvironment~new(probePath,journalPath,now)
ignore=env~validateApplication(app)
lease=env~ownership~current(spec~require('job_id'),now)
if lease==.nil then do; say 'FD_MANAGED_RELEASE_ERROR no current placement'; exit 1; end
req=.MigratableJobStartRequest~new(spec~require('start_id'),.MigratableJobStartMode~NEW,spec~require('job_id'),app~definitionRef,spec~get('partition_id',spec~require('job_id')),'',now)
audit=.MigratableJobPlacementAuditStore~new(auditPath)
tool=.MigratableJobManagedPlacementTool~new(app,env~allocator,env~registry,env~eligibility,.nil,.nil,audit)
r=tool~release(req,lease,now,'FD-RELEASE-'||req~startId,'operator confirmed runtime absent')
if r==.nil | \r~ok then do; code='RELEASE_MISSING'; if r<>.nil then code=r~code; say 'FD_MANAGED_RELEASE_ERROR' code; exit 1; end
say 'FD_MANAGED_RELEASE_OK placement='||lease~placementId 'epoch='||lease~ownershipEpoch
exit 0
failed:
  say 'FD_MANAGED_RELEASE_ERROR' condition('D')
  exit 1
::requires 'FDDoorMicroMotionStarter.cls'
::requires 'FDDoorMicroMotionManagedPlacement.cls'
