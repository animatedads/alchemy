/* FDDoorMicroMotionMigratable.cls
 * Migratable Job v0.2.4 execution-runtime adapter for FD Door Micro Motion.
 *
 * The adapter never grants placement/ownership authority.  Migratable Job and
 * Job-to-Node own that.  It only asks the already-running FD worker to pause at
 * a safe committed frame boundary, returns the resulting digest-bound bundle,
 * and starts a destination worker from a verified transferred bundle.
 */

::class FDDoorMicroMotionMigratableExecutionAdapter subclass MigratableJobExecutionAdapter public
::attribute sourceControlDir get
::attribute destinationSourcePath get
::attribute destinationOutputPrefix get
::attribute destinationStateDir get
::attribute sourceEvidenceRef get
::attribute runnerScript get
::attribute profile get
::attribute destinationEntryMode get
::attribute destinationStartId get

::method init
  expose sourceControlDir destinationSourcePath destinationOutputPrefix destinationStateDir sourceEvidenceRef runnerScript profile destinationEntryMode destinationStartId rexxCommand pauseTimeoutMs resumeTimeoutMs pollMs formatBridge codecBridge utilBridge
  use strict arg sourceControlArg,destinationSourceArg,destinationPrefixArg,destinationStateArg,sourceEvidenceArg,runnerArg,profileArg='FD_NIGHT_F11',rexxArg='rexx',pauseTimeoutArg=120000,resumeTimeoutArg=120000,pollArg=250,formatArg='camera_ffmpeg_avformat.bridge.json',codecArg='camera_ffmpeg_avcodec.bridge.json',utilArg='camera_ffmpeg_avutil.bridge.json',entryModeArg='COORDINATOR_RESUME'
  sourceControlDir=sourceControlArg~string; destinationSourcePath=destinationSourceArg~string; destinationOutputPrefix=destinationPrefixArg~string; destinationStateDir=destinationStateArg~string; sourceEvidenceRef=sourceEvidenceArg~string; runnerScript=runnerArg~string; profile=profileArg~string~upper; destinationEntryMode=entryModeArg~string~upper; destinationStartId=''; rexxCommand=rexxArg~string
  pauseTimeoutMs=pauseTimeoutArg+0; resumeTimeoutMs=resumeTimeoutArg+0; pollMs=pollArg+0
  formatBridge=formatArg~string; codecBridge=codecArg~string; utilBridge=utilArg~string
  if sourceControlDir='' | destinationSourcePath='' | destinationOutputPrefix='' | destinationStateDir='' | runnerScript='' then raise syntax 88.900 array('incomplete FD migratable execution adapter')
  if pauseTimeoutMs<1 | resumeTimeoutMs<1 | pollMs<1 then raise syntax 88.900 array('invalid FD migration polling interval')
  if destinationEntryMode<>'COORDINATOR_RESUME' & destinationEntryMode<>'MIGRATABLE_HANDOFF' then raise syntax 88.900 array('invalid FD destination entry mode',destinationEntryMode)


::method bindDestinationStartId
  expose destinationStartId
  use strict arg startIdArg
  destinationStartId=startIdArg~string
  return self

::method shellQuote private
  use strict arg text
  return "'"||text~string~changestr("'","'\\''")||"'"

::method atomicControlWrite private
  use strict arg path,state
  tmp=path||'.tmp'
  .FDControlFile~write(tmp,state)
  address system 'mv -f -- '||self~shellQuote(tmp)||' '||self~shellQuote(path)
  return rc=0

::method pauseAndCheckpoint
  expose sourceControlDir sourceEvidenceRef pauseTimeoutMs pollMs
  use strict arg definition,sourceLease,migrationId,nowEpochMs
  if definition==.nil | sourceLease==.nil then return .MigratableJobCheckpointResult~failure('FD_SOURCE_BINDING_MISSING')
  requestId='FDPAUSE-'||migrationId||'-'||sourceLease~ownershipEpoch
  checkpointId='FDCK-'||migrationId||'-'||sourceLease~ownershipEpoch
  ctl=.FDCheckpointState~new
  ctl~put('command','PAUSE'); ctl~put('request_id',requestId); ctl~put('migration_id',migrationId); ctl~put('job_id',definition~jobId); ctl~put('checkpoint_id',checkpointId); ctl~put('source_node_id',sourceLease~nodeId); ctl~put('source_placement_id',sourceLease~placementId); ctl~put('source_ownership_epoch',sourceLease~ownershipEpoch); ctl~put('now_epoch_ms',nowEpochMs)
  call SysMkDir sourceControlDir
  address system 'rm -f -- '||self~shellQuote(sourceControlDir||'/paused.tsv')
  if \self~atomicControlWrite(sourceControlDir||'/pause.request.tsv',ctl) then return .MigratableJobCheckpointResult~failure('FD_PAUSE_REQUEST_WRITE_FAILED')

  waited=0; paused=.nil
  do while waited<=pauseTimeoutMs
    p=.FDControlFile~read(sourceControlDir||'/paused.tsv')
    if p<>.nil then do
      if p~get('status','')='PAUSED' & p~get('request_id','')=requestId then do; paused=p; leave; end
    end
    call SysSleep pollMs/1000
    waited+=pollMs
  end
  if paused==.nil then return .MigratableJobCheckpointResult~failure('FD_PAUSE_TIMEOUT','worker did not publish a matching safe-point checkpoint')
  if paused~get('job_id','')<>definition~jobId | paused~get('migration_id','')<>migrationId | paused~get('checkpoint_id','')<>checkpointId then return .MigratableJobCheckpointResult~failure('FD_CHECKPOINT_BINDING_MISMATCH')
  if paused~get('source_node_id','')<>sourceLease~nodeId | paused~get('source_placement_id','')<>sourceLease~placementId | (paused~get('source_ownership_epoch','-1')+0)<>sourceLease~ownershipEpoch then return .MigratableJobCheckpointResult~failure('FD_SOURCE_LEASE_BINDING_MISMATCH')
  transferRef=paused~get('checkpoint_transfer_ref',''); stateRef=paused~get('checkpoint_state_ref',transferRef); digest=paused~get('checkpoint_state_digest','')
  if transferRef='' | stateRef='' | digest='' then return .MigratableJobCheckpointResult~failure('FD_CHECKPOINT_TRANSFER_EVIDENCE_MISSING')
  if stream(transferRef,'C','QUERY EXISTS')=='' then return .MigratableJobCheckpointResult~failure('FD_CHECKPOINT_TRANSFER_OBJECT_MISSING',transferRef)
  if \digest~lower~startsWith('sha256:') then return .MigratableJobCheckpointResult~failure('FD_CHECKPOINT_DIGEST_UNSUPPORTED',digest)
  inputEvidence=paused~get('input_evidence_ref',sourceEvidenceRef); outputEvidence=paused~get('output_evidence_ref','')
  if sourceEvidenceRef<>'' & inputEvidence<>'' & sourceEvidenceRef<>inputEvidence then return .MigratableJobCheckpointResult~failure('FD_INPUT_EVIDENCE_MISMATCH')
  manifest=.MigratableJobCheckpointManifest~new(checkpointId,definition~jobId,migrationId,definition~partitionId,sourceLease~nodeId,sourceLease~placementId,sourceLease~ownershipEpoch,definition~runtimeId,definition~runtimeGeneration,definition~executableRevision,stateRef,digest,inputEvidence,outputEvidence,nowEpochMs,0,nowEpochMs,paused~get('checkpoint_generation','0')+0)
  return .MigratableJobCheckpointResult~success(manifest,transferRef)

::method resumeFromCheckpoint
  expose destinationSourcePath destinationOutputPrefix destinationStateDir sourceEvidenceRef runnerScript profile destinationEntryMode destinationStartId rexxCommand resumeTimeoutMs pollMs formatBridge codecBridge utilBridge
  use strict arg definition,destinationLease,manifest,destinationCheckpointRef,nowEpochMs
  if definition==.nil | destinationLease==.nil | manifest==.nil then return .MigratableJobResumeResult~failure('FD_DESTINATION_BINDING_MISSING')
  if destinationCheckpointRef='' then return .MigratableJobResumeResult~failure('FD_DESTINATION_CHECKPOINT_MISSING')
  if sourceEvidenceRef<>'' & manifest~inputEvidenceRef<>'' & sourceEvidenceRef<>manifest~inputEvidenceRef then return .MigratableJobResumeResult~failure('FD_DESTINATION_INPUT_EVIDENCE_MISMATCH')
  call SysMkDir destinationStateDir
  material=.nil
  signal on syntax name materialFailure
  material=.FDMigrationBundle~materialize(destinationCheckpointRef,destinationOutputPrefix,destinationStateDir,manifest~stateDigest,manifest~checkpointId)
  signal off syntax
  if material==.nil then return .MigratableJobResumeResult~failure('FD_BUNDLE_MATERIALIZATION_FAILED')

  address system 'rm -f -- '||self~shellQuote(destinationStateDir||'/running.tsv')||' '||self~shellQuote(destinationStateDir||'/worker.exit.tsv')||' '||self~shellQuote(destinationStateDir||'/resume.pid')
  spec=.FDCheckpointState~new
  startBinding=destinationStartId; if startBinding='' then startBinding=manifest~checkpointId
  spec~put('entry_mode',destinationEntryMode); spec~put('starter_start_id',startBinding); spec~put('migration_api','migratable.job/0.2'); if destinationEntryMode='MIGRATABLE_HANDOFF' then spec~put('starter_api','migratable.job.start/1'); spec~put('source_path',destinationSourcePath); spec~put('profile',profile); spec~put('output_prefix',destinationOutputPrefix); spec~put('state_dir',destinationStateDir); spec~put('source_evidence_ref',sourceEvidenceRef); spec~put('resume_checkpoint_path',material~checkpointPath); spec~put('format_bridge',formatBridge); spec~put('codec_bridge',codecBridge); spec~put('util_bridge',utilBridge); spec~put('job_id',definition~jobId); spec~put('definition_ref',definition~definitionRef); spec~put('partition_id',definition~partitionId); spec~put('checkpoint_id',manifest~checkpointId); spec~put('destination_node_id',destinationLease~nodeId); spec~put('destination_placement_id',destinationLease~placementId); spec~put('destination_ownership_epoch',destinationLease~ownershipEpoch); spec~put('started_epoch_ms',nowEpochMs)
  specPath=destinationStateDir||'/resume.'||manifest~checkpointId||'.launch.tsv'
  if \self~atomicControlWrite(specPath,spec) then return .MigratableJobResumeResult~failure('FD_RESUME_SPEC_WRITE_FAILED')
  logPath=destinationStateDir||'/resume.'||manifest~checkpointId||'.log'
  cmd='nohup '||self~shellQuote(rexxCommand)||' '||self~shellQuote(runnerScript)||' '||self~shellQuote(specPath)||' > '||self~shellQuote(logPath)||' 2>&1 & echo $! > '||self~shellQuote(destinationStateDir||'/resume.pid')
  address system cmd
  if rc<>0 then return .MigratableJobResumeResult~failure('FD_DESTINATION_LAUNCH_FAILED',logPath)

  waited=0
  do while waited<=resumeTimeoutMs
    running=.FDControlFile~read(destinationStateDir||'/running.tsv')
    if running<>.nil then do
      status=running~get('status','')
      if status='RUNNING' | status='OK' then do
        pid=''; if stream(destinationStateDir||'/resume.pid','C','QUERY EXISTS')<>'' then do; pid=linein(destinationStateDir||'/resume.pid')~strip; call stream destinationStateDir||'/resume.pid','C','CLOSE'; end
        return .MigratableJobResumeResult~success('fd:'||destinationLease~nodeId||':'||manifest~checkpointId||':pid='||pid)
      end
    end
    exited=.FDControlFile~read(destinationStateDir||'/worker.exit.tsv')
    if exited<>.nil then do
      status=exited~get('status','')
      if status<>'OK' & status<>'' then return .MigratableJobResumeResult~failure('FD_DESTINATION_WORKER_FAILED',status)
    end
    call SysSleep pollMs/1000
    waited+=pollMs
  end
  return .MigratableJobResumeResult~failure('FD_DESTINATION_START_TIMEOUT',logPath)

materialFailure:
  signal off syntax
  return .MigratableJobResumeResult~failure('FD_BUNDLE_MATERIALIZATION_FAILED',condition('D'))

::method retireSource
  expose sourceControlDir
  use strict arg definition,sourceLease,migrationId,nowEpochMs
  paused=.FDControlFile~read(sourceControlDir||'/paused.tsv')
  if paused==.nil then return .false
  if paused~get('status','')<>'PAUSED' | paused~get('migration_id','')<>migrationId | paused~get('job_id','')<>definition~jobId then return .false
  retired=.FDCheckpointState~new; retired~put('status','RETIRED'); retired~put('job_id',definition~jobId); retired~put('migration_id',migrationId); retired~put('source_node_id',sourceLease~nodeId); retired~put('source_placement_id',sourceLease~placementId); retired~put('source_ownership_epoch',sourceLease~ownershipEpoch); retired~put('retired_epoch_ms',nowEpochMs)
  if \self~atomicControlWrite(sourceControlDir||'/retired.tsv',retired) then return .false
  address system 'rm -f -- '||self~shellQuote(sourceControlDir||'/pause.request.tsv')
  return .true

::requires 'FDDoorMicroMotion.cls'
::requires 'MigratableJob.cls'
