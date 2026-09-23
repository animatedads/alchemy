#!/usr/bin/env rexx
/* Operator/task boundary for storage.fabric.host-filesystem/0.1.
 * This program performs only mechanical admission/copy/verify operations.
 * Selection, priority, retention and source cleanup are intentionally absent.
 */
numeric digits 50

parse arg payload
if word(payload,1)<>'SFHOSTARGS1' then call usage 2
argc=words(payload)-1
args=.array~new(argc)
do ai=1 to argc
  h=word(payload,ai+1)
  if h='' then args[ai]=''
  else args[ai]=x2c(h)
end
if argc<1 then call usage 2
command=args[1]~translate
helper=value('STORAGE_HOST_COMMIT_HELPER',,'ENVIRONMENT')
if helper='' then helper='build/storage-host-commit'

select
  when command='PREFLIGHT' then do
    if argc<3 then call usage 2
    sourceRoot=args[2]; destinationRoot=args[3]
    requireKernelRo=.false
    allowSame=.false
    if argc>=4 then requireKernelRo=asBool(args[4])
    if argc>=5 then allowSame=asBool(args[5])
    src=.StorageHostFilesystemMount~new('machine-source',sourceRoot,'READ_ONLY',helper)
    dst=.StorageHostFilesystemMount~new('backup-destination',destinationRoot,'WRITE_COMMIT',helper)
    /* argument five is ALLOW_SAME_FILESYSTEM, whereas the API takes REQUIRE_DISTINCT */
    if allowSame then r=.StorageHostBackupPreflight~run(src,dst,'.storage-fabric/checkpoints',requireKernelRo,.false)
    else r=.StorageHostBackupPreflight~run(src,dst,'.storage-fabric/checkpoints',requireKernelRo,.true)
    call emitPreflight r
    if r['ok'] then exit 0
    exit 1
  end
  when command='COPY' then do
    if argc<6 then call usage 2
    sourceRoot=args[2]; destinationRoot=args[3]; sourceRel=args[4]; destinationRel=args[5]; transferId=args[6]
    checkpointRel='.storage-fabric/checkpoints'
    if argc>=7 then if args[7]<>'' then checkpointRel=args[7]
    src=.StorageHostFilesystemMount~new('machine-source',sourceRoot,'READ_ONLY',helper)
    dst=.StorageHostFilesystemMount~new('backup-destination',destinationRoot,'WRITE_COMMIT',helper)
    if src~rootDevice==dst~rootDevice then do
      call emit 'FAILED','failure','SOURCE_DESTINATION_SAME_FILESYSTEM'
      exit 1
    end
    checkpointRoot=dst~ensureDirectory(checkpointRel)
    copier=.StorageHostVerifiedCopy~new
    r=copier~copyFile(src,sourceRel,dst,destinationRel,transferId,checkpointRoot)
    call emitCopy r
    if r~ok then exit 0
    if r~status='PAUSED' then exit 3
    if r~status='SOURCE_CHANGED' then exit 4
    exit 1
  end
  when command='VERIFY' then do
    if argc<5 then call usage 2
    sourceRoot=args[2]; destinationRoot=args[3]; sourceRel=args[4]; destinationRel=args[5]
    src=.StorageHostFilesystemMount~new('machine-source',sourceRoot,'READ_ONLY',helper)
    dst=.StorageHostFilesystemMount~new('backup-destination',destinationRoot,'WRITE_COMMIT',helper)
    before=src~entry(sourceRel)
    dest=dst~entry(destinationRel)
    if before==.nil then do; call emit 'FAILED','failure','SOURCE_MISSING'; exit 1; end
    if \before~regularFile then do; call emit 'FAILED','failure','SOURCE_NOT_REGULAR'; exit 1; end
    if \src~sameFilesystem(before) then do; call emit 'FAILED','failure','SOURCE_FILESYSTEM_BOUNDARY'; exit 1; end
    if dest==.nil then do; call emit 'FAILED','failure','DESTINATION_MISSING'; exit 1; end
    if \dest~regularFile then do; call emit 'FAILED','failure','DESTINATION_NOT_REGULAR'; exit 1; end
    sourceDigest=.StorageHostPosix~digestFile(before~hostPath)
    destinationDigest=.StorageHostPosix~digestFile(dest~hostPath)
    after=src~entry(sourceRel)
    if after==.nil then do; call emit 'SOURCE_CHANGED','failure','SOURCE_CHANGED_DURING_VERIFY'; exit 4; end
    if \before~sameVersion(after) then do; call emit 'SOURCE_CHANGED','failure','SOURCE_CHANGED_DURING_VERIFY'; exit 4; end
    if sourceDigest='' | destinationDigest='' then do; call emit 'FAILED','failure','DIGEST_FAILED'; exit 1; end
    if sourceDigest<>destinationDigest then do
      call emit 'MISMATCH','source_sha256',sourceDigest,'destination_sha256',destinationDigest
      exit 5
    end
    call emit 'MATCH','sha256',sourceDigest,'bytes',before~sizeBytes
    exit 0
  end
  otherwise call usage 2
end

emitPreflight:
  use arg d
  call emit d['status'],'failure',d['failure'],'source_root',d['sourceRoot'],'source_device',d['sourceDevice'],'source_kernel_ro',d['sourceKernelReadOnly'],'destination_root',d['destinationRoot'],'destination_device',d['destinationDevice'],'destination_kernel_rw',d['destinationKernelReadWrite'],'checkpoint_root',d['checkpointRoot']
  return

emitCopy:
  use arg r
  call emit r~status,'source',r~sourceRelative,'destination',r~destinationRelative,'bytes',r~bytes,'verification',r~verificationRef,'failure',r~failure
  return

/* SFHOST1 is a tab-framed machine surface.  Values are hex encoded so POSIX
 * path text containing whitespace/newlines cannot corrupt the record. */
emit:
  use arg status
  out='SFHOST1'||'09'x||status
  pairs=(arg()-1)%2
  idx=2
  do i=1 to pairs
    key=arg(idx); value=arg(idx+1); idx+=2
    if key==.nil then key=''
    if value==.nil then value=''
    out=out||'09'x||key||'='||c2x(value~string)
  end
  say out
  return

asBool:
  use arg value
  v=value~string~strip~translate
  return v='1' | v='TRUE' | v='YES' | v='REQUIRE'

usage:
  use arg code
  say 'usage:'
  say '  storage-host-backup-floor.rex preflight SOURCE_ROOT DEST_ROOT [REQUIRE_KERNEL_RO=0] [ALLOW_SAME_FILESYSTEM=0]'
  say '  storage-host-backup-floor.rex copy SOURCE_ROOT DEST_ROOT SOURCE_REL DEST_REL TRANSFER_ID CHECKPOINT_REL'
  say '  storage-host-backup-floor.rex verify SOURCE_ROOT DEST_ROOT SOURCE_REL DEST_REL'
  exit code

::requires 'src/StorageHostFilesystem.cls'
