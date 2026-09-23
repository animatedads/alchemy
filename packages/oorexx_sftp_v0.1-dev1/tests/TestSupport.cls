::class SftpTest public
::method assert class
  use strict arg ok,msg
  if \ok then raise syntax 88.900 array('ASSERT FAILED',msg)
::method request class
  use strict arg type,id,body=''
  return .SftpCodec~frame(d2c(type,1)||.SftpCodec~u32(id)||body)
::method init class
  use strict arg version=3
  return .SftpCodec~frame(d2c(.SftpTypes~INIT,1)||.SftpCodec~u32(version))
::method replyType class
  use strict arg frame
  p=.SftpCodec~payload(frame)
  return c2d(substr(p,1,1))
::method replyId class
  use strict arg frame
  p=.SftpCodec~payload(frame)
  return .SftpCodec~readU32(p,2)
::method statusCode class
  use strict arg frame
  p=.SftpCodec~payload(frame)
  return .SftpCodec~readU32(p,6)
::method handleValue class
  use strict arg frame
  p=.SftpCodec~payload(frame)
  s=.SftpCodec~readString(p,6)
  return s['value']
::method dataValue class
  use strict arg frame
  p=.SftpCodec~payload(frame)
  s=.SftpCodec~readString(p,6)
  return s['value']
::requires '../src/SftpCore.cls'
