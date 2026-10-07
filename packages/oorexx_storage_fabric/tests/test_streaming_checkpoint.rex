base='/tmp/oorexx-storage-checkpoint-test'
src=base||'.src'; dst=base||'.dst'; ck=base||'.ckpt'
call cleanup src,dst,ck
block=copies('checkpoint-data-',4096)
do i=1 to 12; call charout src,block; end
call stream src,'c','close'
size=stream(src,'c','query size')+0
ref=.StorageRef~new('test:checkpoint')
loc=.StorageLocation~new('local-test',src,'posixfs:test',.StorageLocationState~AVAILABLE)
engine=.StorageResumableTransferEngine~new(32768)
t1=.StorageTransfer~new('checkpoint-xfer',ref,loc,'local-target',dst,size)
r1=engine~copy(t1,.StorageLocalFileByteSource~new(src),.StorageLocalFileByteSink~new(dst),ck,4)
call assertEq .StorageTransferRunStatus~PAUSED,r1~status,'paused'
latest=.StorageTransferCheckpoint~loadLatest(ck)
call assertTrue latest<>.nil,'checkpoint load'
seq=latest~sequence
/* Corrupt the newest slot.  The older slot must still be usable. */
if seq//2=0 then newest=ck||'.a'; else newest=ck||'.b'
call SysFileDelete newest
call lineout newest,'TORN-CHECKPOINT'
call lineout newest
fallback=.StorageTransferCheckpoint~loadLatest(ck)
call assertTrue fallback<>.nil,'fallback checkpoint survives'
call assertTrue fallback~sequence<seq,'fallback is previous generation'

t2=.StorageTransfer~new('checkpoint-xfer',ref,loc,'local-target',dst,size)
r2=engine~copy(t2,.StorageLocalFileByteSource~new(src),.StorageLocalFileByteSink~new(dst),ck,0,.StoragePosixSha256Verifier~new)
call assertEq .StorageTransferRunStatus~COMPLETED,r2~status,'resume from older checkpoint'
call assertEq .StorageTransferState~VERIFIED,t2~state,'verified after fallback resume'

/* Create a new interrupted transfer, then alter the source before restart.
 * Same transfer/checkpoint evidence must not be accepted. */
call cleanup dst,ck||'.dummy',ck
/* keep source, clear target/checkpoints only */
t3=.StorageTransfer~new('identity-xfer',ref,loc,'local-target',dst,size)
r3=engine~copy(t3,.StorageLocalFileByteSource~new(src),.StorageLocalFileByteSink~new(dst),ck,2)
call assertEq .StorageTransferRunStatus~PAUSED,r3~status,'identity test paused'
call SysSleep 1
call charout src,'X',1
call stream src,'c','close'
t4=.StorageTransfer~new('identity-xfer',ref,loc,'local-target',dst,size)
r4=engine~copy(t4,.StorageLocalFileByteSource~new(src),.StorageLocalFileByteSink~new(dst),ck)
call assertEq .StorageTransferRunStatus~FAILED,r4~status,'changed source rejected'
call assertEq 'CHECKPOINT_IDENTITY_MISMATCH',r4~failure,'identity mismatch reason'

call cleanup src,dst,ck
say 'PASS transfer checkpoint recovery/identity fencing'
exit 0

cleanup: procedure
  use arg a,b,ck
  call stream a,'c','close'; call stream b,'c','close'
  call stream ck||'.a','c','close'; call stream ck||'.b','c','close'
  call SysFileDelete a; call SysFileDelete b; call SysFileDelete ck||'.a'; call SysFileDelete ck||'.b'
  return
::routine assertTrue
  use arg value,label
  if \value then do; say 'FAIL' label; raise syntax 88.900 array('test assertion failed'); end
::routine assertEq
  use arg expected,actual,label
  if expected<>actual then do; say 'FAIL' label 'expected='expected 'actual='actual; raise syntax 88.900 array('test assertion failed'); end
::requires "src/StorageStreaming.cls"
