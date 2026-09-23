/* Regression for the dev20 >9-digit file-size defect.
 * Run the caller at ooRexx's ordinary 9-digit precision: Storage packages
 * themselves must retain exact byte counts and offsets. */
numeric digits 9

path='/tmp/oorexx-storage-large-precision.bin'
ck='/tmp/oorexx-storage-large-precision.ckpt'
call cleanup path,ck

/* Sparse file: exact failing production size, negligible physical allocation. */
address system "/usr/bin/truncate -s 2005735208 -- "||shellQuote(path)
call assertEq 0,rc,'create sparse >9-digit source'

src=.StorageLocalFileByteSource~new(path)
call assertTrue pos('|2005735208|',src~resumeIdentity)>0,'source identity preserves exact 10-digit size'

/* Read the final eight bytes while the caller remains at DIGITS 9.  dev20
 * rounded the source size and could request bytes past the real EOF here. */
src~openAt('2005735200')
chunk=src~readChunk(16)
call assertEq 8,chunk~size,'tail read uses exact remaining byte count'
call assertTrue chunk~eof,'tail read reaches exact EOF'
call assertEq copies('00'x,8),chunk~data,'sparse tail bytes preserved'
src~close

/* Transfer state must also keep exact byte counters independent of caller
 * precision; otherwise checkpoints can drift before I/O even begins. */
ref=.StorageRef~new('test:large-file')
loc=.StorageLocation~new('local',path,'',.StorageLocationState~AVAILABLE)
t=.StorageTransfer~new('large-transfer',ref,loc,'dest','file','2005735208')
call assertTrue t~begin,'large transfer begin'
call assertTrue t~progress('2005735207'),'large transfer penultimate progress'
call assertTrue \t~copied,'penultimate byte count is not complete'
call assertTrue t~progress('2005735208'),'large transfer final progress'
call assertTrue t~copied,'exact large transfer completes'

cp=.StorageTransferCheckpoint~new('large-ckpt','source-id','target-id','2005735208',8388608)
cp~advance('2005735207',.StorageTransferState~COPYING)
cp~save(ck)
/* Durable numeric fields, including the Adler-32 trailer, must be canonical
 * decimal text.  dev20 emitted values such as 2.18468359E+9 here. */
slot=ck||'.b'
line=linein(slot); call stream slot,'c','close'
f=.StorageCodec~splitTabs(line)
call assertEq 12,f~items,'checkpoint field count including checksum'
call assertEq '1',f[2],'checkpoint sequence canonical'
call assertEq '2005735208',f[6],'checkpoint total canonical'
call assertEq '2005735207',f[7],'checkpoint progress canonical'
call assertEq '8388608',f[8],'checkpoint chunk canonical'
call assertTrue .StorageCodec~isCanonicalUnsigned(f[12]),'checkpoint checksum canonical decimal'
call assertTrue pos('E',f[12]~upper)=0,'checkpoint checksum has no exponent'

/* A legacy/scientific checksum token is untrusted evidence and must fail
 * closed instead of being numerically rounded back into apparent validity. */
bad=ck||'-legacy'
body=left(line,lastpos('09'x,line)-1)
call lineout bad||'.b',body||'09'x||'2.18468359E+9'
call lineout bad||'.b'
call assertTrue .StorageTransferCheckpoint~loadLatest(bad)==.nil,'legacy exponent checkpoint rejected'
call stream bad||'.b','c','close'; call SysFileDelete bad||'.b'

loaded=.StorageTransferCheckpoint~loadLatest(ck)
call assertTrue loaded<>.nil,'large checkpoint reload'
call assertTrue loaded~matches('large-ckpt','source-id','target-id','2005735208'),'checkpoint exact total matches'
call assertEq '2005735207',loaded~bytesTransferred~string,'checkpoint exact progress retained'

/* Host metadata must not round the source fence before StorageStreaming sees it. */
e=.StorageHostEntry~new('video.avi',path,'regular file','644',1000,1000,'2005735208','1','2','42','273',1)
call assertTrue pos('|2005735208|',e~fingerprint)>0,'host entry fingerprint preserves exact size'

call cleanup path,ck
say 'PASS large-file exact byte precision and tail read'
exit 0

cleanup: procedure
  use arg path,ck
  call stream path,'c','close'
  call stream ck||'.a','c','close'; call stream ck||'.b','c','close'
  call SysFileDelete path
  call SysFileDelete ck||'.a'; call SysFileDelete ck||'.b'
  return

shellQuote: procedure
  use arg s
  sq="'"; dq='"'; replacement=sq||dq||sq||dq||sq
  return sq||changestr(sq,s,replacement)||sq

::routine assertTrue
  use arg value,label
  if \value then do; say 'FAIL' label; raise syntax 88.900 array('test assertion failed'); end
::routine assertEq
  use arg expected,actual,label
  if expected<>actual then do; say 'FAIL' label 'expected='expected 'actual='actual; raise syntax 88.900 array('test assertion failed'); end

::requires "src/StorageHostFilesystem.cls"
