/*----------------------------------------------------------------------------*/
/* JDWP wire codec. 11-byte big-endian headers plus the standard handshake.   */
/*----------------------------------------------------------------------------*/

::class JdwpBuild public
::constant RELEASE "0.1-dev1"
::constant API_VERSION "debug.provider.jdwp.wire/0.1"

::class JdwpProtocol public
::constant HANDSHAKE "JDWP-Handshake"
::constant REPLY_FLAG 128

::class JdwpPacket public
::attribute id get
::attribute flags get
::attribute commandSet get
::attribute command get
::attribute errorCode get
::attribute payload get

::method init
  expose id flags commandSet command errorCode payload
  use strict arg idArg,flagsArg=0,commandSetArg=0,commandArg=0,errorCodeArg=0,payloadArg=''
  id=idArg+0; flags=flagsArg+0; commandSet=commandSetArg+0; command=commandArg+0; errorCode=errorCodeArg+0; payload=payloadArg

::method isReply
  expose flags
  return bitand(d2c(flags,1),'80'x)=='80'x

::method length
  expose payload
  return 11+payload~length

::method encode
  expose id flags commandSet command errorCode payload
  h=_jdwpBe32(11+payload~length)||_jdwpBe32(id)||d2c(flags,1)
  if self~isReply then h=h||_jdwpBe16(errorCode)
  else h=h||d2c(commandSet,1)||d2c(command,1)
  return h||payload

::class JdwpPacketCodec public
::method decode class
  use strict arg bytes
  if bytes~length<11 then raise syntax 93.900 array('JDWP packet shorter than 11-byte header',bytes~length)
  n=_jdwpUnbe32(substr(bytes,1,4)); if n<>bytes~length then raise syntax 93.900 array('JDWP packet length mismatch',n,bytes~length)
  id=_jdwpUnbe32(substr(bytes,5,4)); flags=c2d(substr(bytes,9,1))
  if bitand(substr(bytes,9,1),'80'x)=='80'x then return .JdwpPacket~new(id,flags,0,0,_jdwpUnbe16(substr(bytes,10,2)),substr(bytes,12))
  return .JdwpPacket~new(id,flags,c2d(substr(bytes,10,1)),c2d(substr(bytes,11,1)),0,substr(bytes,12))

::method packetLength class
  use strict arg bytes
  if bytes~length<4 then return 0
  return _jdwpUnbe32(substr(bytes,1,4))

::routine _jdwpBe16
  use strict arg n
  return d2c(n,2)
::routine _jdwpUnbe16
  use strict arg b
  return c2d(b)
::routine _jdwpBe32
  use strict arg n
  numeric digits 20
  return d2c(n,4)
::routine _jdwpUnbe32
  use strict arg b
  numeric digits 20
  return c2d(b)
