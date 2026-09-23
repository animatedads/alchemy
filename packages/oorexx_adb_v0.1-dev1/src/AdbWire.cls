/*----------------------------------------------------------------------------*/
/* ooRexx ADB Wire v0.1-dev1                                                  */
/* Native ADB framing: 24-byte little-endian header + payload.                */
/*----------------------------------------------------------------------------*/

::class AdbWireBuild public
::constant RELEASE "0.1-dev1"
::constant API_VERSION "adb.wire/0.1"

::class AdbProtocol public
::constant VERSION_MIN 16777216          /* 0x01000000 */
::constant VERSION_SKIP_CHECKSUM 16777217 /* 0x01000001 */
::constant VERSION 16777217
::constant MAX_PAYLOAD_V1 4096
::constant MAX_PAYLOAD 1048576
::constant TOKEN_SIZE 20
::constant AUTH_TOKEN 1
::constant AUTH_SIGNATURE 2
::constant AUTH_RSAPUBLICKEY 3
::constant STLS_VERSION 16777216

::method commandValue class
  numeric digits 20
  use strict arg command
  c=command~string~upper
  if c~length<>4 then raise syntax 93.900 array('ADB command must be four bytes',c)
  return c2d(c~reverse)

::method commandFromValue class
  numeric digits 20
  use strict arg value
  return d2c(value,4)~reverse

::class AdbPacket public
::attribute command get
::attribute arg0 get
::attribute arg1 get
::attribute payload get
::attribute checksum get
::attribute magic get

::method init
  expose command arg0 arg1 payload checksum magic
  use strict arg commandArg,arg0Arg=0,arg1Arg=0,payloadArg='',checksumArg=.nil,magicArg=.nil
  command=commandArg~string~upper
  if command~length<>4 then raise syntax 93.900 array('ADB command must be four bytes',command)
  arg0=arg0Arg+0; arg1=arg1Arg+0
  payload=payloadArg
  if checksumArg==.nil then checksum=_adbChecksum(payload)
  else checksum=checksumArg+0
  if magicArg==.nil then magic=bitxor(command,'FFFFFFFF'x)
  else magic=magicArg

::method dataLength
  expose payload
  return payload~length

::method validMagic
  expose command magic
  return magic==bitxor(command,'FFFFFFFF'x)

::method validChecksum
  expose payload checksum
  return checksum==_adbChecksum(payload)

::method encode
  expose command arg0 arg1 payload checksum
  use strict arg useChecksum=.true
  check=checksum
  if \useChecksum then check=0
  header=command||_adbLe32(arg0)||_adbLe32(arg1)||_adbLe32(payload~length)||_adbLe32(check)||bitxor(command,'FFFFFFFF'x)
  return header||payload

::method string
  expose command arg0 arg1 payload
  return command||'('||arg0||','||arg1||') len='||payload~length

::class AdbPacketCodec public
::method decode class
  use strict arg bytes, verifyChecksum=.false
  if bytes~length<24 then raise syntax 93.900 array('ADB packet shorter than 24-byte header',bytes~length)
  command=substr(bytes,1,4)
  arg0=_adbUnle32(substr(bytes,5,4))
  arg1=_adbUnle32(substr(bytes,9,4))
  n=_adbUnle32(substr(bytes,13,4))
  checksum=_adbUnle32(substr(bytes,17,4))
  magic=substr(bytes,21,4)
  if bytes~length<>24+n then raise syntax 93.900 array('ADB packet length mismatch',n,bytes~length-24)
  packet=.AdbPacket~new(command,arg0,arg1,substr(bytes,25,n),checksum,magic)
  if \packet~validMagic then raise syntax 93.900 array('ADB command magic mismatch',command)
  if verifyChecksum & checksum<>0 & \packet~validChecksum then raise syntax 93.900 array('ADB payload checksum mismatch',command)
  return packet

::method decodeHeader class
  use strict arg header
  if header~length<>24 then raise syntax 93.900 array('ADB header must be exactly 24 bytes',header~length)
  d=.directory~new
  d['command']=substr(header,1,4)
  d['arg0']=_adbUnle32(substr(header,5,4))
  d['arg1']=_adbUnle32(substr(header,9,4))
  d['dataLength']=_adbUnle32(substr(header,13,4))
  d['checksum']=_adbUnle32(substr(header,17,4))
  d['magic']=substr(header,21,4)
  return d

::routine _adbLe32
  use strict arg n
  numeric digits 20
  v=n+0
  if v<0 then v+=4294967296
  if v<0 | v>4294967295 then raise syntax 93.900 array('Value outside uint32 range',n)
  return d2c(v,4)~reverse

::routine _adbUnle32
  use strict arg b
  if b~length<>4 then raise syntax 93.900 array('Expected four bytes',b~length)
  return c2d(b~reverse)

::routine _adbChecksum
  use strict arg data
  numeric digits 20
  s=0
  do i=1 to data~length
    s=s+c2d(substr(data,i,1))
  end
  return s//4294967296
