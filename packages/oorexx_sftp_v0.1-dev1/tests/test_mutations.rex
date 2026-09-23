b=.SftpMemoryBackend~new
e=.SftpEndpoint~new(b); e~consume(.SftpTest~init)
r=e~consume(.SftpTest~request(.SftpTypes~MKDIR,1,.SftpCodec~string('/x')||.SftpCodec~u32(0)))
call assert .SftpTest~statusCode(r)=0,'mkdir'
b~put('/x/a','abc')
r=e~consume(.SftpTest~request(.SftpTypes~RENAME,2,.SftpCodec~string('/x/a')||.SftpCodec~string('/x/b')))
call assert .SftpTest~statusCode(r)=0,'rename'
call assert b~content('/x/b')=='abc','rename content'
r=e~consume(.SftpTest~request(.SftpTypes~REMOVE,3,.SftpCodec~string('/x/b')))
call assert .SftpTest~statusCode(r)=0,'remove'
r=e~consume(.SftpTest~request(.SftpTypes~RMDIR,4,.SftpCodec~string('/x')))
call assert .SftpTest~statusCode(r)=0,'rmdir'
say 'PASS test_mutations'
exit 0
assert: procedure
  use strict arg ok,msg
  if \ok then do; say 'FAIL:' msg; exit 1; end
  return
::requires 'TestSupport.cls'
