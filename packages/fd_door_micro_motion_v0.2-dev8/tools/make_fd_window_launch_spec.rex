/* Create an FD night-analysis launch specification for managed NEW placement.
 * v0.2-dev8 deliberately contains no operator-supplied placement id, ownership
 * epoch or FD-specific authority receipt.  Those are obtained later through
 * Migratable Job v0.2.5 migratable.job.placement/1 and Job-to-Node v0.6.
 *
 * Required environment:
 *   FD_SOURCE_PATH FD_OUTPUT_PREFIX FD_STATE_DIR FD_SOURCE_EVIDENCE_REF
 *   FD_WALL_CLOCK_ORIGIN FD_ANALYSIS_WALL_START FD_ANALYSIS_WALL_END
 *   FD_JOB_ID FD_SOURCE_NODE_ID
 * Optional:
 *   FD_PARTITION_ID FD_START_ID FD_OWNER_NODE_ID
 *   FD_ALLOWED_DESTINATION_NODES FD_MIGRATABLE_STATE_ROOT
 *   FD_PROFILE FD_REFERENCE_MEDIA_MS
 *   FD_EXCLUSION_COUNT and FD_EXCLUSION_<N>_{ID,WALL_START,WALL_END,REASON}
 *   FD_AVFORMAT_BRIDGE FD_AVCODEC_BRIDGE FD_AVUTIL_BRIDGE
 */
parse arg specPath
specPath=specPath~strip
if specPath='' then do; say 'usage: rexx make_fd_window_launch_spec.rex SPEC.tsv'; exit 64; end
sourcePath=value('FD_SOURCE_PATH',,'ENVIRONMENT'); outputPrefix=value('FD_OUTPUT_PREFIX',,'ENVIRONMENT'); stateDir=value('FD_STATE_DIR',,'ENVIRONMENT'); sourceEvidenceRef=value('FD_SOURCE_EVIDENCE_REF',,'ENVIRONMENT')
wallOrigin=value('FD_WALL_CLOCK_ORIGIN',,'ENVIRONMENT'); wallStart=value('FD_ANALYSIS_WALL_START',,'ENVIRONMENT'); wallEnd=value('FD_ANALYSIS_WALL_END',,'ENVIRONMENT')
profile=value('FD_PROFILE',,'ENVIRONMENT'); referenceMediaMs=value('FD_REFERENCE_MEDIA_MS',,'ENVIRONMENT')
formatBridge=value('FD_AVFORMAT_BRIDGE',,'ENVIRONMENT'); codecBridge=value('FD_AVCODEC_BRIDGE',,'ENVIRONMENT'); utilBridge=value('FD_AVUTIL_BRIDGE',,'ENVIRONMENT')
jobId=value('FD_JOB_ID',,'ENVIRONMENT'); partitionId=value('FD_PARTITION_ID',,'ENVIRONMENT'); startId=value('FD_START_ID',,'ENVIRONMENT'); sourceNodeId=value('FD_SOURCE_NODE_ID',,'ENVIRONMENT'); ownerNodeId=value('FD_OWNER_NODE_ID',,'ENVIRONMENT')
allowedDestinationNodes=value('FD_ALLOWED_DESTINATION_NODES',,'ENVIRONMENT'); migratableStateRoot=value('FD_MIGRATABLE_STATE_ROOT',,'ENVIRONMENT')
if value('FD_SOURCE_PLACEMENT_ID',,'ENVIRONMENT')<>'' | value('FD_SOURCE_OWNERSHIP_EPOCH',,'ENVIRONMENT')<>'' | value('FD_SOURCE_AUTHORITY_REF',,'ENVIRONMENT')<>'' then do
  say 'FD_LAUNCH_SPEC_ERROR dev7 forbids operator-supplied placement/ownership/authority fields; use migratable.job.placement/1'; exit 65
end
if sourcePath='' | outputPrefix='' | stateDir='' | sourceEvidenceRef='' | wallOrigin='' | wallStart='' | wallEnd='' | jobId='' | sourceNodeId='' then do
  say 'FD_LAUNCH_SPEC_ERROR required source/output/state/evidence/wall-clock origin/start/end plus FD_JOB_ID and FD_SOURCE_NODE_ID'; exit 65
end
if profile='' then profile='FD_NIGHT_F11'
if partitionId='' then partitionId=jobId
if startId='' then startId='FDNEW-'||jobId||'-1'
if ownerNodeId='' then ownerNodeId=sourceNodeId
if migratableStateRoot='' then migratableStateRoot=stateDir||'/migratable'
if formatBridge='' then formatBridge='camera_ffmpeg_avformat.bridge.json'
if codecBridge='' then codecBridge='camera_ffmpeg_avcodec.bridge.json'
if utilBridge='' then utilBridge='camera_ffmpeg_avutil.bridge.json'
call SysMkDir stateDir
s=.FDCheckpointState~new
s~put('job_id',jobId); s~put('partition_id',partitionId); s~put('start_id',startId); s~put('source_node_id',sourceNodeId); s~put('owner_node_id',ownerNodeId); s~put('allowed_destination_nodes',allowedDestinationNodes); s~put('migratable_state_root',migratableStateRoot)
s~put('placement_api','migratable.job.placement/1'); s~put('placement_receipt_api','migratable.job.placement.receipt/1'); s~put('starter_api','migratable.job.start/1')
s~put('source_path',sourcePath); s~put('profile',profile); s~put('output_prefix',outputPrefix); s~put('state_dir',stateDir); s~put('source_evidence_ref',sourceEvidenceRef); s~put('resume_checkpoint_path','')
s~put('wall_clock_origin',wallOrigin); s~put('analysis_wall_start',wallStart); s~put('analysis_wall_end',wallEnd)
if referenceMediaMs<>'' then s~put('reference_media_ms',referenceMediaMs)
s~put('format_bridge',formatBridge); s~put('codec_bridge',codecBridge); s~put('util_bridge',utilBridge)
countText=value('FD_EXCLUSION_COUNT',,'ENVIRONMENT'); if countText='' then countText='0'
count=countText+0; s~put('exclusion_count',count)
do i=1 to count
  envStem='FD_EXCLUSION_'||i||'_'; keyStem='exclusion_'||i||'_'
  xid=value(envStem||'ID',,'ENVIRONMENT'); xs=value(envStem||'WALL_START',,'ENVIRONMENT'); xe=value(envStem||'WALL_END',,'ENVIRONMENT'); xr=value(envStem||'REASON',,'ENVIRONMENT')
  if xid='' then xid='FDX'||right(i,4,'0')
  if xr='' then xr='USER_DECLARED_SCENE_OCCLUSION'
  if xs='' | xe='' then do; say 'FD_LAUNCH_SPEC_ERROR missing exclusion wall time' i; exit 65; end
  s~put(keyStem||'id',xid); s~put(keyStem||'wall_start',xs); s~put(keyStem||'wall_end',xe); s~put(keyStem||'reason',xr)
end
.FDControlFile~write(specPath,s)
say 'FD_LAUNCH_SPEC_OK' specPath
say 'PLACEMENT_API migratable.job.placement/1'
exit 0
::requires 'FDDoorMicroMotion.cls'
