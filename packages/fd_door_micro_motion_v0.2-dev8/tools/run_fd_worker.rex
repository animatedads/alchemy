/* Start or resume one FD analyser from a primitive control spec.
 * Initial jobs are configured from an absolute camera wall-clock window.
 * Resumed jobs reconstruct the exact config from the migration checkpoint so
 * destination launch cannot silently change the scientific window/exclusions.
 */
parse arg specPath
if specPath='' then do; say 'usage: run_fd_worker.rex SPEC.tsv'; exit 64; end
spec=.FDControlFile~read(specPath)
if spec==.nil then do; say 'FD_WORKER_SPEC_ERROR cannot read' specPath; exit 65; end
entryMode=spec~get('entry_mode','')~upper
starterApi=spec~get('starter_api','')
migrationApi=spec~get('migration_api','')
if entryMode<>'MIGRATABLE_NEW' & entryMode<>'MIGRATABLE_HANDOFF' & entryMode<>'COORDINATOR_RESUME' & entryMode<>'QUALIFICATION' then do
  say 'FD_WORKER_ENTRY_ERROR direct payload launch prohibited; use tools/start_fd_managed.rex for NEW jobs'
  exit 66
end
if (entryMode='MIGRATABLE_NEW' | entryMode='MIGRATABLE_HANDOFF') & starterApi<>'migratable.job.start/1' then do
  say 'FD_WORKER_ENTRY_ERROR missing standard starter binding'
  exit 66
end
if entryMode='COORDINATOR_RESUME' & migrationApi<>'migratable.job/0.2' then do
  say 'FD_WORKER_ENTRY_ERROR missing coordinator migration binding'
  exit 66
end
if entryMode='MIGRATABLE_NEW' then do
  if spec~get('source_node_id','')='' | spec~get('source_placement_id','')='' | spec~get('source_ownership_epoch','0')+0<1 then do
    say 'FD_WORKER_ENTRY_ERROR missing Job-to-Node initial placement/ownership binding'
    exit 66
  end
end
if entryMode='MIGRATABLE_HANDOFF' then do
  if spec~get('destination_node_id','')='' | spec~get('destination_placement_id','')='' | spec~get('destination_ownership_epoch','0')+0<1 then do
    say 'FD_WORKER_ENTRY_ERROR missing committed destination placement/ownership binding'
    exit 66
  end
end
source=spec~get('source_path',''); profile=spec~get('profile','FD_NIGHT_F11')~upper; prefix=spec~get('output_prefix',''); stateDir=spec~get('state_dir',''); evidence=spec~get('source_evidence_ref',''); resume=spec~get('resume_checkpoint_path','')
formatBridge=spec~get('format_bridge','camera_ffmpeg_avformat.bridge.json'); codecBridge=spec~get('codec_bridge','camera_ffmpeg_avcodec.bridge.json'); utilBridge=spec~get('util_bridge','camera_ffmpeg_avutil.bridge.json')

if resume<>'' then do
  checkpoint=.FDCheckpointState~read(resume)
  if checkpoint==.nil then do; say 'FD_WORKER_SPEC_ERROR cannot read resume checkpoint' resume; exit 65; end
  cfg=.FDDoorMicroMotionConfig~fromCompactText(checkpoint~require('config'))
end
else do
  if profile='FD_NIGHT_F11' then cfg=.FDDoorMicroMotionConfig~nightF11
  else if profile='TP00000_NIGHT' then cfg=.FDDoorMicroMotionConfig~tp00000Night
  else do; say 'FD_WORKER_SPEC_ERROR unsupported profile' profile; exit 65; end

  wallOrigin=spec~get('wall_clock_origin','')
  wallStart=spec~get('analysis_wall_start','')
  wallEnd=spec~get('analysis_wall_end','')
  if wallOrigin<>'' | wallStart<>'' | wallEnd<>'' then do
    if wallOrigin='' | wallStart='' | wallEnd='' then do; say 'FD_WORKER_SPEC_ERROR incomplete wall-clock window'; exit 65; end
    cfg~setWallWindow(wallOrigin,wallStart,wallEnd)
  end
  refMs=spec~get('reference_media_ms','')
  if refMs<>'' then cfg~referenceMediaMs=refMs+0

  exclusionCount=spec~get('exclusion_count','0')+0
  do i=1 to exclusionCount
    stem='exclusion_'||i||'_'
    xid=spec~get(stem||'id','FDX'||right(i,4,'0'))
    xs=spec~get(stem||'wall_start','')
    xe=spec~get(stem||'wall_end','')
    xr=spec~get(stem||'reason','USER_DECLARED_SCENE_OCCLUSION')
    if xs='' | xe='' then do; say 'FD_WORKER_SPEC_ERROR incomplete exclusion' i; exit 65; end
    cfg~addWallExclusion(xid,xs,xe,xr)
  end
end

posix=.PosixGapFactory~create
guard=.FDSourceStabilityGuard~new(posix,source,cfg~sourceStabilityQuietMs,cfg~sourceStabilityPollFrames)
w=.FDDoorMicroMotionWorker~new(source,cfg,prefix,stateDir,evidence,resume,formatBridge,codecBridge,utilBridge,guard)
status=w~run
exitState=.FDCheckpointState~new; exitState~put('status',status); exitState~put('spec_path',specPath); exitState~put('entry_mode',entryMode); exitState~put('starter_api',starterApi); exitState~put('migration_api',migrationApi); exitState~put('starter_start_id',spec~get('starter_start_id','')); exitState~put('job_id',spec~get('job_id','')); exitState~put('definition_ref',spec~get('definition_ref','')); exitState~put('partition_id',spec~get('partition_id','')); exitState~put('source_node_id',spec~get('source_node_id','')); exitState~put('source_placement_id',spec~get('source_placement_id','')); exitState~put('source_ownership_epoch',spec~get('source_ownership_epoch','0')); exitState~put('checkpoint_id',spec~get('checkpoint_id','')); exitState~put('destination_node_id',spec~get('destination_node_id','')); exitState~put('destination_placement_id',spec~get('destination_placement_id','')); exitState~put('destination_ownership_epoch',spec~get('destination_ownership_epoch','0'))
.FDControlFile~write(stateDir||'/worker.exit.tsv',exitState)
say 'FD_DOOR_MICRO' status 'source='source 'output='prefix 'resume='resume
if status='OK' | status='PAUSED' then exit 0
exit 1
::requires 'FDDoorMicroMotion.cls'
::requires 'PosixGap.cls'
