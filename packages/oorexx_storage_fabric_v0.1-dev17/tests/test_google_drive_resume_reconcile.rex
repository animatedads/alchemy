base='/tmp/oorexx-storage-drive-reconcile'
src=base||'.src'; ck=base||'.ckpt'
call cleanup src,ck
call charout src,copies('Q',800000)
call stream src,'c','close'
size=800000

auth=.GoogleDriveTestAuthProvider~new('resume-token')
http=.FakeHttpExecutor~new
adapter=.GoogleDriveApiAdapter~new(http,auth,'google-drive:test','https://api.example/drive/v3','https://upload.example/drive/v3')
store=.GoogleDriveMemoryUploadSessionStore~new
h=.directory~new; h['location']='https://upload.example/resume-capability'
http~enqueue(.FakeHttpResponse~new(200,h,''))
h1=.directory~new; h1['range']='bytes=0-524287'
http~enqueue(.FakeHttpResponse~new(308,h1,''))

ref=.StorageRef~new('obj:reconcile')
loc=.StorageLocation~new('local',src,'posix:test')
t1=.StorageTransfer~new('drive-reconcile',ref,loc,'google-drive:test','',size)
sink1=.GoogleDriveResumableByteSink~new(adapter,store,'resume-key','google-drive:test','root','resume.bin')
engine=.StorageResumableTransferEngine~new(524288)
r1=engine~copy(t1,.StorageLocalFileByteSource~new(src),sink1,ck,1)
call assertEq .StorageTransferRunStatus~PAUSED,r1~status,'first run paused'
call assertEq 524288,r1~bytesTransferred,'provider acknowledged first request'

/* Simulate loss/torn newest local checkpoint: retain the older zero-byte slot.
 * The provider session still knows 524288 bytes. */
latest=.StorageTransferCheckpoint~loadLatest(ck)
call assertEq 524288,latest~bytesTransferred,'latest checkpoint has provider progress'
if latest~sequence//2=0 then call SysFileDelete ck||'.a'
else call SysFileDelete ck||'.b'
old=.StorageTransferCheckpoint~loadLatest(ck)
call assertEq 0,old~bytesTransferred,'older local checkpoint is zero'

/* Reconciliation query advances the stale local checkpoint from authoritative
 * Drive Range evidence; only the remaining 275712 bytes are sent. */
hq=.directory~new; hq['range']='bytes=0-524287'
http~enqueue(.FakeHttpResponse~new(308,hq,''))
sha=.StoragePosixSha256Verifier~new~digestFile(src)
body='{"id":"drive-reconciled","sha256Checksum":"'||sha||'"}'
http~enqueue(.FakeHttpResponse~new(200,.directory~new,body))
t2=.StorageTransfer~new('drive-reconcile',ref,loc,'google-drive:test','',size)
sink2=.GoogleDriveResumableByteSink~new(adapter,store,'resume-key','google-drive:test','root','resume.bin')
r2=engine~copy(t2,.StorageLocalFileByteSource~new(src),sink2,ck,0,.GoogleDriveSha256Verifier~new)
call assertEq .StorageTransferRunStatus~COMPLETED,r2~status,'reconciled resume completes'
call assertTrue r2~resumed,'provider progress recognized as resume'
call assertEq 1,r2~chunks,'only remaining final chunk uploaded'
call assertEq size,r2~bytesTransferred,'all bytes complete'
call assertEq .StorageTransferState~VERIFIED,t2~state,'reconciled result verified'

call cleanup src,ck
say 'PASS provider-authoritative Drive resume reconciliation'
exit 0

cleanup: procedure
  use arg src,ck
  call stream src,'c','close'; call SysFileDelete src
  call stream ck||'.a','c','close'; call stream ck||'.b','c','close'
  call SysFileDelete ck||'.a'; call SysFileDelete ck||'.b'
  return
::class FakeHttpResponse public
::attribute status get
::attribute headers get
::attribute body get
::attribute errorCode get
::method init
  expose status headers body errorCode
  use arg statusArg=0,headersArg=.nil,bodyArg='',errorArg=''
  status=statusArg+0; if headersArg==.nil then headers=.directory~new; else headers=headersArg
  body=bodyArg; errorCode=errorArg~string
::class FakeHttpExecutor subclass StorageHttpExecutor public
::method init
  expose planned
  planned=.queue~new
::method enqueue
  expose planned
  use arg r
  planned~queue(r); return self
::method execute
  expose planned
  use arg methodArg,urlArg,headersArg=.nil,bodyArg='',trafficArg=''
  if planned~items=0 then return .FakeHttpResponse~new(0,.nil,'','NO_PLANNED_RESPONSE')
  return planned~pull
::routine assertTrue
  use arg v,l
  if \v then do; say 'FAIL' l; raise syntax 88.900 array('test assertion failed'); end
::routine assertEq
  use arg e,a,l
  if e<>a then do; say 'FAIL' l 'expected='e 'actual='a; raise syntax 88.900 array('test assertion failed'); end
::requires "src/StorageGoogleDrive.cls"