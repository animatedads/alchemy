/* Consume one committed Migratable Job file handoff through the v0.2.5
 * standard HANDOFF starter and start the FD destination worker exactly once.
 *
 * Usage:
 *   rexx start_fd_file_handoff.rex DESTINATION-LAUNCH.tsv HANDOFF.mjob ACK.mjob [CHECKPOINT-OVERRIDE]
 *
 * DESTINATION-LAUNCH.tsv carries local source/output/state paths but MUST have
 * the same scientific/job/definition/partition binding as the source job.
 */
parse arg specPath handoffPath ackPath checkpointOverride
specPath=specPath~strip; handoffPath=handoffPath~strip; ackPath=ackPath~strip; checkpointOverride=checkpointOverride~strip
if specPath='' | handoffPath='' | ackPath='' then do
  say 'usage: rexx start_fd_file_handoff.rex DESTINATION-LAUNCH.tsv HANDOFF.mjob ACK.mjob [CHECKPOINT-OVERRIDE]'
  exit 64
end
spec=.FDControlFile~read(specPath)
if spec==.nil then do; say 'FD_HANDOFF_START_ERROR cannot read destination spec' specPath; exit 65; end
parse source . . thisFile
here=filespec('LOCATION',thisFile)
runnerScript=here||'run_fd_worker.rex'
stateDir=spec~get('state_dir',''); if stateDir='' then do; say 'FD_HANDOFF_START_ERROR state_dir missing'; exit 65; end
stateRoot=spec~get('migratable_state_root',stateDir||'/migratable')
app=.FDDoorMicroMotionStarterApplication~new(specPath,runnerScript,stateRoot,'rexx')
layout=app~layout
adapter=.FDDoorMicroMotionMigratableExecutionAdapter~new(stateDir,spec~require('source_path'),spec~require('output_prefix'),stateDir,spec~require('source_evidence_ref'),runnerScript,spec~get('profile','FD_NIGHT_F11'),'rexx',120000,120000,250,spec~get('format_bridge','camera_ffmpeg_avformat.bridge.json'),spec~get('codec_bridge','camera_ffmpeg_avcodec.bridge.json'),spec~get('util_bridge','camera_ffmpeg_avutil.bridge.json'),'MIGRATABLE_HANDOFF')
fdExecutor=.FDDoorMicroMotionHandoffExecutor~new(app,adapter)
destinationRunner=.MigratableJobDestinationRunner~new(fdExecutor)
receiptStore=.MigratableJobStartReceiptStore~new(layout~startReceipts)
starter=.MigratableJobStarter~new(app,receiptStore,.nil,destinationRunner)
starterBridge=.MigratableJobStarterDestinationRunner~new(starter)
fileTransport=.MigratableJobFileHandoffTransport~new(layout~handoffRoot)
manual=.MigratableJobFileManualStarter~new(fileTransport,starterBridge)
ack=manual~start(handoffPath,time('T')*1000,checkpointOverride,ackPath)
if ack==.nil then do; say 'FD_HANDOFF_START_ERROR invalid/unreadable handoff'; exit 1; end
if \ack~ok then do; say 'FD_HANDOFF_START_ERROR' ack~code ack~detail; exit 1; end
say 'FD_HANDOFF_START_OK handoff='ack~handoffId 'migration='ack~migrationId 'job='ack~jobId
say 'EXECUTION_REF' ack~executionRef
say 'ACK' ackPath
say 'START_RECEIPTS' layout~startReceipts
exit 0
::requires 'FDDoorMicroMotionHandoff.cls'
