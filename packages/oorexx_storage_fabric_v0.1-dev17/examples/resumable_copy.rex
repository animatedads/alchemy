/* Usage: rexx examples/resumable_copy.rex source-file target-file [checkpoint-root]
 *
 * Copies in bounded chunks, persists restart evidence, verifies SHA-256, and
 * leaves StorageTransfer in VERIFIED (not COMMITTED).  Commit remains a
 * provider/catalogue decision.
 */
parse arg sourcePath targetPath checkpointRoot
if sourcePath='' | targetPath='' then do
  say 'Usage: rexx examples/resumable_copy.rex source-file target-file [checkpoint-root]'
  exit 2
end
if checkpointRoot='' then checkpointRoot=targetPath||'.storage-transfer'
source=.StorageLocalFileByteSource~new(sourcePath)
ref=.StorageRef~new('local:'||sourcePath)
loc=.StorageLocation~new('local-source',sourcePath,'',.StorageLocationState~AVAILABLE)
transfer=.StorageTransfer~new('copy:'||sourcePath||'->'||targetPath,ref,loc,'local-target',targetPath,source~sizeBytes)
engine=.StorageResumableTransferEngine~new(8388608)
result=engine~copy(transfer,source,.StorageLocalFileByteSink~new(targetPath),checkpointRoot,0,.StoragePosixSha256Verifier~new)
say 'status='result~status
say 'bytes='result~bytesTransferred
say 'chunks_this_run='result~chunks
say 'resumed='result~resumed
say 'transfer_state='transfer~state
if result~verificationRef<>'' then say 'verification='result~verificationRef
if result~failure<>'' then say 'failure='result~failure
if result~completed then exit 0
exit 1
::requires "src/StorageStreaming.cls"