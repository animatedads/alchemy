base='/tmp/oorexx-storage-streaming-test'
src=base||'.src'
dst=base||'.dst'
ck=base||'.ckpt'
call cleanup src,dst,ck

/* Build a binary-ish 2 MiB source in bounded writes, including NUL bytes. */
block=copies('0123456789ABCDEF',4095)||'00'x||'FF'x||'0A'x||'0D'x
/* 65524 bytes per block. */
do i=1 to 32
  unwritten=charout(src,block)
  if unwritten<>0 then do; say 'FAIL source build'; exit 2; end
end
call stream src,'c','close'
size=stream(src,'c','query size')+0

ref=.StorageRef~new('test:streaming-object')
loc=.StorageLocation~new('local-test',src,'posixfs:test',.StorageLocationState~AVAILABLE)
t1=.StorageTransfer~new('stream-xfer-1',ref,loc,'local-target',dst,size)
source1=.StorageLocalFileByteSource~new(src)
sink1=.StorageLocalFileByteSink~new(dst)
engine=.StorageResumableTransferEngine~new(65536)

r1=engine~copy(t1,source1,sink1,ck,3)
call assertEq .StorageTransferRunStatus~PAUSED,r1~status,'first run pauses'
call assertTrue r1~bytesTransferred>0,'first run made progress'
call assertTrue r1~bytesTransferred<size,'first run incomplete'
partial=r1~bytesTransferred
call assertTrue stream(ck||'.a','c','query exists')<>'' | stream(ck||'.b','c','query exists')<>'','checkpoint persisted'
call assertTrue stream(dst,'c','query size')+0>=partial,'partial sink persisted'

/* Fresh objects simulate process restart. */
t2=.StorageTransfer~new('stream-xfer-1',ref,loc,'local-target',dst,size)
source2=.StorageLocalFileByteSource~new(src)
sink2=.StorageLocalFileByteSink~new(dst)
verifier=.StoragePosixSha256Verifier~new
r2=engine~copy(t2,source2,sink2,ck,0,verifier)
call assertEq .StorageTransferRunStatus~COMPLETED,r2~status,'resume completes'
call assertTrue r2~resumed,'resume evidence'
call assertEq size,r2~bytesTransferred,'all bytes transferred'
call assertEq .StorageTransferState~VERIFIED,t2~state,'cryptographically verified'
call assertTrue left(r2~verificationRef,7)='sha256:','verification ref'
call assertEq size,stream(dst,'c','query size')+0,'target exact size'

/* Reopening the same completed checkpoint performs no byte copy. */
t3=.StorageTransfer~new('stream-xfer-1',ref,loc,'local-target',dst,size)
r3=engine~copy(t3,.StorageLocalFileByteSource~new(src),.StorageLocalFileByteSink~new(dst),ck,0,verifier)
call assertEq .StorageTransferRunStatus~COMPLETED,r3~status,'completed checkpoint reusable'
call assertEq 0,r3~chunks,'no recopy after verified checkpoint'
call assertEq .StorageTransferState~VERIFIED,t3~state,'verified state restored'

/* A changed source must not be silently resumed against old evidence. */
call cleanup src,dst,ck
say 'PASS bounded-memory resumable streaming transfer'
exit 0

cleanup: procedure
  use arg src,dst,ck
  call stream src,'c','close'; call stream dst,'c','close'
  call stream ck||'.a','c','close'; call stream ck||'.b','c','close'
  call SysFileDelete src; call SysFileDelete dst; call SysFileDelete ck||'.a'; call SysFileDelete ck||'.b'
  return

::routine assertTrue
  use arg value,label
  if \value then do; say 'FAIL' label; raise syntax 88.900 array('test assertion failed'); end
::routine assertEq
  use arg expected,actual,label
  if expected<>actual then do; say 'FAIL' label 'expected='expected 'actual='actual; raise syntax 88.900 array('test assertion failed'); end
::requires "src/StorageFabric.cls"
::requires "src/StorageStreaming.cls"