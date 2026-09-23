b=.SftpMemoryBackend~new; b~put('/f','abc')
e=.SftpEndpoint~new(b,4,4); e~consume(.SftpTest~init)
body=.SftpCodec~string('/f')||.SftpCodec~u32(.SftpOpenFlags~READ+.SftpOpenFlags~WRITE)||.SftpCodec~u32(0)
r=e~consume(.SftpTest~request(.SftpTypes~OPEN,1,body)); h=.SftpTest~handleValue(r)
body=.SftpCodec~string(h)||.SftpCodec~u64(0)||.SftpCodec~u32(5)
r=e~consume(.SftpTest~request(.SftpTypes~READ,2,body))
call assert .SftpTest~statusCode(r)=.SftpStatusCodes~FAILURE,'read bound enforced'
body=.SftpCodec~string(h)||.SftpCodec~u64(0)||.SftpCodec~string('12345')
r=e~consume(.SftpTest~request(.SftpTypes~WRITE,3,body))
call assert .SftpTest~statusCode(r)=.SftpStatusCodes~FAILURE,'write bound enforced'
say 'PASS test_bounds'
exit 0
assert: procedure
  use strict arg ok,msg
  if \ok then do; say 'FAIL:' msg; exit 1; end
  return
::requires 'TestSupport.cls'
