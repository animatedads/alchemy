b=.SftpMemoryBackend~new
b~mkdir('/mail'); b~put('/mail/a.eml','A'); b~put('/mail/b.eml','BB')
e=.SftpEndpoint~new(b)
e~consume(.SftpTest~init)
r=e~consume(.SftpTest~request(.SftpTypes~OPENDIR,10,.SftpCodec~string('/mail')))
call assert .SftpTest~replyType(r)=.SftpTypes~HANDLE,'opendir handle'
h=.SftpTest~handleValue(r)
r=e~consume(.SftpTest~request(.SftpTypes~READDIR,11,.SftpCodec~string(h)))
call assert .SftpTest~replyType(r)=.SftpTypes~NAME,'readdir names'
r=e~consume(.SftpTest~request(.SftpTypes~READDIR,12,.SftpCodec~string(h)))
call assert .SftpTest~statusCode(r)=.SftpStatusCodes~EOF,'second readdir eof'
say 'PASS test_endpoint_dir'
exit 0
assert: procedure
  use strict arg ok,msg
  if \ok then do; say 'FAIL:' msg; exit 1; end
  return
::requires 'TestSupport.cls'
