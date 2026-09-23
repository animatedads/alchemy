base='/tmp/oorexx-storage-drive-sink'
src=base||'.src'; ck=base||'.ckpt'
call cleanup src,ck

/* 900,000 bytes: first 512 KiB request is deliberately acknowledged only
 * halfway after an uncertain transport result.  The engine must re-read the
 * unacknowledged source suffix and continue from provider evidence. */
block=copies('0123456789abcdef',4096)
left=900000
do while left>0
  n=length(block); if n>left then n=left
  call charout src,left(block,n)
  left-=n
end
call stream src,'c','close'
size=stream(src,'c','query size')+0
localSha=.StoragePosixSha256Verifier~new~digestFile(src)
call assertEq 64,length(localSha),'local sha available'

auth=.GoogleDriveTestAuthProvider~new('fixture-token-never-persist')
http=.FakeHttpExecutor~new
adapter=.GoogleDriveApiAdapter~new(http,auth,'google-drive:bashqueues-test','https://api.example/drive/v3','https://upload.example/drive/v3')
store=.GoogleDriveMemoryUploadSessionStore~new

/* start session */
h=.directory~new; h['location']='https://upload.example/session-capability-MUST-NOT-PERSIST'
http~enqueue(.FakeHttpResponse~new(200,h,''))
/* first 512 KiB PUT has uncertain outcome */
http~enqueue(.FakeHttpResponse~new(0,.directory~new,'','NETWORK_LOST'))
/* status probe says only 256 KiB arrived */
hq=.directory~new; hq['range']='bytes=0-262143'
http~enqueue(.FakeHttpResponse~new(308,hq,''))
/* retried source suffix: full 512 KiB acknowledgement from offset 256 KiB */
h2=.directory~new; h2['range']='bytes=0-786431'
http~enqueue(.FakeHttpResponse~new(308,h2,''))
/* final 113,568 bytes completes and returns remote digest */
finalBody='{"id":"drive-object-900k","sha256Checksum":"'||localSha||'","md5Checksum":"'||copies('c',32)||'"}'
http~enqueue(.FakeHttpResponse~new(200,.directory~new,finalBody))

ref=.StorageRef~new('sha256:'||localSha,'sha256:'||localSha)
loc=.StorageLocation~new('local',src,'posix:test',.StorageLocationState~AVAILABLE,'',.true,'sha256:'||localSha)
obj=.StorageObject~new(ref,'drive-stream.bin',size,'application/octet-stream')
obj~addLocation(loc)
transfer=.StorageTransfer~new('drive-xfer-partial-ack',ref,loc,'google-drive:bashqueues-test','',size)
source=.StorageLocalFileByteSource~new(src)
sink=.GoogleDriveResumableByteSink~new(adapter,store,'session-key-1','google-drive:bashqueues-test','root','drive-stream.bin','application/octet-stream')
engine=.StorageResumableTransferEngine~new(524288)
verify=.GoogleDriveSha256Verifier~new
r=engine~copy(transfer,source,sink,ck,0,verify)
call assertEq .StorageTransferRunStatus~COMPLETED,r~status,'Drive transfer completed'
call assertEq .StorageTransferState~VERIFIED,transfer~state,'Drive transfer verified'
call assertEq size,r~bytesTransferred,'all bytes acknowledged'
call assertEq 'drive-object-900k',sink~remoteFileId,'remote id retained'
call assertEq localSha,sink~remoteSha256,'remote digest retained'
call assertTrue r~chunks>=3,'partial acknowledgement caused re-read/retry'

/* Generic checkpoints must not persist bearer token or resumable capability. */
do suffix over .array~of('.a','.b')
  p=ck||suffix
  if stream(p,'c','query exists')<>'' then do
    text=linein(p); call stream p,'c','close'
    call assertTrue pos('fixture-token-never-persist',text)=0,'bearer absent from checkpoint'
    call assertTrue pos('session-capability-MUST-NOT-PERSIST',text)=0,'session URI absent from checkpoint'
  end
end

/* BashQueues Drive is deliberately a disposable TEST provider here: commit is
 * valid catalogue evidence but does NOT become durable safety. */
lifecycle=.StorageServiceLifecycle~new(.StorageSafetyClass~DISPOSABLE,.StorageLifecycleState~TEMPORARY,'','qualification account')
provider=.GoogleDriveStorageProvider~new('google-drive:bashqueues-test','bashqueues-test','root',lifecycle)
committer=.GoogleDriveStorageCommitter~new
call assertTrue committer~commit(transfer,obj,sink,provider),'verified Drive result committed'
call assertEq .StorageTransferState~COMMITTED,transfer~state,'transfer committed'
call assertEq 2,obj~locations~items,'Drive location added'
driveLoc=obj~locations[2]
call assertEq 'drive-object-900k',driveLoc~locator,'Drive file id is provider locator'
call assertFalse driveLoc~countsAsDurable,'disposable test account is not safety'
call assertTrue store~get('session-key-1')==.nil,'session capability retired after commit'
call assertEq auth~acquisitions,auth~retirements,'all bearer leases retired'

call cleanup src,ck
say 'PASS Google Drive bounded sink partial-ack recovery / verify / commit safety'
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
  use arg value,label
  if \value then do; say 'FAIL' label; raise syntax 88.900 array('test assertion failed'); end
::routine assertFalse
  use arg value,label
  if value then do; say 'FAIL' label; raise syntax 88.900 array('test assertion failed'); end
::routine assertEq
  use arg expected,actual,label
  if expected<>actual then do; say 'FAIL' label 'expected='expected 'actual='actual; raise syntax 88.900 array('test assertion failed'); end
::requires "src/StorageGoogleDrive.cls"
