numeric digits 30

core=.StorageFuseOperationCore~new
call assertOk core~mkdir("/remote"),"create Storage SFTP root"
factory=.StorageSftpBackendFactory~new(core,"/remote",.true)
handler=factory~subsystemHandler
registry=.SshEndpointRegistry~new
registry~registerSubsystem("sftp",handler)
decision=registry~resolve(.SshEndpointRequest~new(.SshRequestKinds~subsystem,"sftp"))
call assertTrue decision~allowed,"SSH registry resolves Storage-backed sftp subsystem"
call assertEq decision~handler~subsystemName,"sftp","resolved subsystem handler"
endpoint=decision~handler~endpoint

/* INIT negotiates SFTP v3. */
r=endpoint~consume(.SftpCodec~frame(d2c(.SftpTypes~INIT,1)||.SftpCodec~u32(3)))
p=.SftpCodec~payload(r)
call assertEq c2d(substr(p,1,1)),.SftpTypes~VERSION,"INIT response type"
call assertEq .SftpCodec~readU32(p,2),3,"negotiated version"

/* Make a directory through the SFTP protocol and verify Storage sees it. */
r=send(endpoint,.SftpTypes~MKDIR,1,.SftpCodec~string("/incoming")||.SftpCodec~u32(0))
call assertStatus r,.SftpStatusCodes~OK,"MKDIR"
call assertTrue core~getattr("/remote/incoming")~ok,"Storage sees SFTP directory"

/* Create/open/write/close a file. */
flags=.SftpOpenFlags~WRITE+.SftpOpenFlags~CREAT+.SftpOpenFlags~TRUNC
r=send(endpoint,.SftpTypes~OPEN,2,.SftpCodec~string("/incoming/a.txt")||.SftpCodec~u32(flags)||.SftpCodec~u32(0))
handle=parseHandle(r)
call assertTrue handle<>"","OPEN returned handle"
r=send(endpoint,.SftpTypes~WRITE,3,.SftpCodec~string(handle)||.SftpCodec~u64(0)||.SftpCodec~string("alpha"))
call assertStatus r,.SftpStatusCodes~OK,"WRITE"
r=send(endpoint,.SftpTypes~CLOSE,4,.SftpCodec~string(handle))
call assertStatus r,.SftpStatusCodes~OK,"CLOSE"

opened=core~open("/remote/incoming/a.txt","READ")
call assertTrue opened~ok,"Storage can open SFTP-created file"
rr=core~read(opened~value,0,64)
ignore=core~release(opened~value)
call assertEq rr~value,"alpha","Storage reads SFTP bytes"

/* Reopen through SFTP, read the Storage-owned bytes, then append. */
r=send(endpoint,.SftpTypes~OPEN,5,.SftpCodec~string("/incoming/a.txt")||.SftpCodec~u32(.SftpOpenFlags~READ)||.SftpCodec~u32(0))
handle=parseHandle(r)
r=send(endpoint,.SftpTypes~READ,6,.SftpCodec~string(handle)||.SftpCodec~u64(0)||.SftpCodec~u32(64))
call assertEq parseData(r),"alpha","SFTP reads Storage bytes"
ignore=send(endpoint,.SftpTypes~CLOSE,7,.SftpCodec~string(handle))

flags=.SftpOpenFlags~WRITE+.SftpOpenFlags~APPEND
r=send(endpoint,.SftpTypes~OPEN,8,.SftpCodec~string("/incoming/a.txt")||.SftpCodec~u32(flags)||.SftpCodec~u32(0))
handle=parseHandle(r)
r=send(endpoint,.SftpTypes~WRITE,9,.SftpCodec~string(handle)||.SftpCodec~u64(0)||.SftpCodec~string("-beta"))
call assertStatus r,.SftpStatusCodes~OK,"APPEND write"
ignore=send(endpoint,.SftpTypes~CLOSE,10,.SftpCodec~string(handle))
opened=core~open("/remote/incoming/a.txt","READ"); rr=core~read(opened~value,0,64); ignore=core~release(opened~value)
call assertEq rr~value,"alpha-beta","append follows Storage-visible length"

/* Directory listing and rename stay Storage-native. */
r=send(endpoint,.SftpTypes~OPENDIR,11,.SftpCodec~string("/incoming")); dh=parseHandle(r)
r=send(endpoint,.SftpTypes~READDIR,12,.SftpCodec~string(dh))
call assertNameContains r,"a.txt","READDIR contains Storage file"
ignore=send(endpoint,.SftpTypes~CLOSE,13,.SftpCodec~string(dh))
r=send(endpoint,.SftpTypes~RENAME,14,.SftpCodec~string("/incoming/a.txt")||.SftpCodec~string("/incoming/b.txt"))
call assertStatus r,.SftpStatusCodes~OK,"RENAME"
call assertTrue core~getattr("/remote/incoming/b.txt")~ok,"Storage sees renamed file"

/* Removal cannot recursively consume Storage namespace state. */
r=send(endpoint,.SftpTypes~RMDIR,15,.SftpCodec~string("/incoming"))
call assertStatus r,.SftpStatusCodes~FAILURE,"non-empty RMDIR denied"
r=send(endpoint,.SftpTypes~REMOVE,16,.SftpCodec~string("/incoming/b.txt"))
call assertStatus r,.SftpStatusCodes~OK,"REMOVE"
r=send(endpoint,.SftpTypes~RMDIR,17,.SftpCodec~string("/incoming"))
call assertStatus r,.SftpStatusCodes~OK,"empty RMDIR"
call assertFalse core~getattr("/remote/incoming")~ok,"Storage directory removed"

/* Default policy is read-only. */
ro=.StorageSftpBackendFactory~new(core,"/remote",.false)~newBackend
call assertFalse ro~mkdir("/denied"),"read-only adapter rejects mutation"
call assertFalse ro~open("/denied.txt",.SftpOpenFlags~CREAT+.SftpOpenFlags~WRITE),"read-only adapter rejects create"

say "PASS Storage Fabric SFTP backend"
exit 0

send:
  procedure
  use arg endpoint,type,id,body=""
  return endpoint~consume(.SftpCodec~response(type,id,body))

payload:
  procedure
  use arg frame
  return .SftpCodec~payload(frame)

parseHandle:
  procedure
  use arg frame
  p=.SftpCodec~payload(frame)
  if c2d(substr(p,1,1))<>.SftpTypes~HANDLE then return ""
  s=.SftpCodec~readString(p,6)
  return s["value"]

parseData:
  procedure
  use arg frame
  p=.SftpCodec~payload(frame)
  if c2d(substr(p,1,1))<>.SftpTypes~DATA then return ""
  s=.SftpCodec~readString(p,6)
  return s["value"]

assertStatus:
  procedure
  use arg frame,expected,label
  p=.SftpCodec~payload(frame)
  if c2d(substr(p,1,1))<>.SftpTypes~STATUS then do; say "FAIL" label "not STATUS"; exit 1; end
  actual=.SftpCodec~readU32(p,6)
  if actual<>expected then do; say "FAIL" label "expected="expected "actual="actual; exit 1; end
  return

assertNameContains:
  procedure
  use arg frame,wanted,label
  p=.SftpCodec~payload(frame)
  if c2d(substr(p,1,1))<>.SftpTypes~NAME then do; say "FAIL" label "not NAME"; exit 1; end
  count=.SftpCodec~readU32(p,6); o=10; found=.false
  do i=1 to count
    s=.SftpCodec~readString(p,o); name=s["value"]; o=s["next"]
    s=.SftpCodec~readString(p,o); o=s["next"]
    /* Skip ATTRS subset emitted by StorageSftpBackend: flags + optional fields. */
    flags=.SftpCodec~readU32(p,o); o=o+4
    if flags//2=1 then o=o+8
    if c2d(d2c(flags,4)~bitand(d2c(4,4)))<>0 then o=o+4
    if c2d(d2c(flags,4)~bitand(d2c(8,4)))<>0 then o=o+8
    if name=wanted then found=.true
  end
  if \found then do; say "FAIL" label; exit 1; end
  return

assertOk:
  procedure
  use arg result,label
  if \result~ok then do; say "FAIL" label "errno="result~errno result~detail; exit 1; end
  return
assertTrue:
  procedure
  use arg v,label
  if \v then do; say "FAIL" label; exit 1; end
  return
assertFalse:
  procedure
  use arg v,label
  if v then do; say "FAIL" label; exit 1; end
  return
assertEq:
  procedure
  use arg actual,expected,label
  if actual<>expected then do; say "FAIL" label "expected="expected "actual="actual; exit 1; end
  return

::requires "StorageSftp.cls"
