/* Mechanical one-file example only.  A real backup task owns enumeration,
 * priority and retention policy. */
parse arg sourceRoot destinationRoot sourceRelative destinationRelative checkpointRoot
if sourceRoot='' | destinationRoot='' | sourceRelative='' | destinationRelative='' then do
  say 'usage: rexx examples/host_backup_floor.rex SOURCE_ROOT DEST_ROOT SOURCE_REL DEST_REL CHECKPOINT_ROOT'
  exit 2
end
if checkpointRoot='' then checkpointRoot='./storage-host-copy-checkpoint'
helper=value('STORAGE_HOST_COMMIT_HELPER',,'ENVIRONMENT')
if helper='' then helper='build/storage-host-commit'

source=.StorageHostFilesystemMount~new('linux-source',sourceRoot,'READ_ONLY',helper)
destination=.StorageHostFilesystemMount~new('backup-destination',destinationRoot,'WRITE_COMMIT',helper)

say 'source policy read-only =' source~readOnly
say 'source kernel read-only =' source~kernelReadOnly
say 'destination kernel rw  =' destination~kernelReadWrite

copy=.StorageHostVerifiedCopy~new
result=copy~copyFile(source,sourceRelative,destination,destinationRelative,'example:'||sourceRelative,checkpointRoot)
say 'status='result~status 'bytes='result~bytes 'verify='result~verificationRef
if result~ok then exit 0
if result~status='PAUSED' then exit 3
say 'failure='result~failure
exit 1

::requires 'src/StorageHostFilesystem.cls'
