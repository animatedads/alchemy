call assert .SftpCodec~readU32(.SftpCodec~u32(4294967295),1)=4294967295,'u32 round trip'
call assert .SftpCodec~readU64(.SftpCodec~u64(4294967297),1)=4294967297,'u64 round trip'
x='abc'||'00'x||'xyz'; s=.SftpCodec~readString(.SftpCodec~string(x),1)
call assert s['value']==x,'binary string round trip'
f=.SftpCodec~frame('hello')
call assert .SftpCodec~payload(f)=='hello','frame round trip'
say 'PASS test_codec'
exit 0
assert: procedure
  use strict arg ok,msg
  if \ok then do; say 'FAIL:' msg; exit 1; end
  return
::requires 'TestSupport.cls'
