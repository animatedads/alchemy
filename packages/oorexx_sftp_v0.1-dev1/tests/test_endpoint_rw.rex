b=.SftpMemoryBackend~new
b~mkdir('/inbox')
e=.SftpEndpoint~new(b,1024,1024)
r=e~consume(.SftpTest~init(3))
call assert .SftpTest~replyType(r)=.SftpTypes~VERSION,'version reply'
body=.SftpCodec~string('/inbox/mail.txt')||.SftpCodec~u32(.SftpOpenFlags~WRITE+.SftpOpenFlags~READ+.SftpOpenFlags~CREAT)||.SftpCodec~u32(0)
r=e~consume(.SftpTest~request(.SftpTypes~OPEN,1,body))
call assert .SftpTest~replyType(r)=.SftpTypes~HANDLE,'open handle'
h=.SftpTest~handleValue(r)
body=.SftpCodec~string(h)||.SftpCodec~u64(0)||.SftpCodec~string('hello mail')
r=e~consume(.SftpTest~request(.SftpTypes~WRITE,2,body))
call assert .SftpTest~statusCode(r)=.SftpStatusCodes~OK,'write ok'
body=.SftpCodec~string(h)||.SftpCodec~u64(0)||.SftpCodec~u32(64)
r=e~consume(.SftpTest~request(.SftpTypes~READ,3,body))
call assert .SftpTest~replyType(r)=.SftpTypes~DATA,'read data'
call assert .SftpTest~dataValue(r)=='hello mail','read exact bytes'
r=e~consume(.SftpTest~request(.SftpTypes~CLOSE,4,.SftpCodec~string(h)))
call assert .SftpTest~statusCode(r)=.SftpStatusCodes~OK,'close ok'
call assert b~content('/inbox/mail.txt')=='hello mail','backend bytes'
say 'PASS test_endpoint_rw'
exit 0
assert: procedure
  use strict arg ok,msg
  if \ok then do; say 'FAIL:' msg; exit 1; end
  return
::requires 'TestSupport.cls'
