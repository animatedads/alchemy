/*----------------------------------------------------------------------------*/
/* ADB -> JDWP transport seam. ADB owns Android transport; JDWP owns debug.    */
/*----------------------------------------------------------------------------*/

::class AdbJdwpTransport public
::attribute adbSession get
::attribute pid get
::attribute stream get
::attribute state get

::method init
  expose adbSession pid stream state incoming
  use strict arg adbSessionArg,pidArg
  adbSession=adbSessionArg; pid=pidArg+0; stream=.nil; state='NEW'; incoming=''

::method open
  expose adbSession pid stream state
  if state<>'NEW' then return state=='OPEN'
  stream=adbSession~openService('jdwp:'||pid)
  stream~on('ADB.STREAM.DATA',self,'onStreamData')
  stream~on('ADB.STREAM.CLOSED',self,'onStreamClosed')
  state='OPEN'
  return .true

::method onStreamData
  expose incoming
  use strict arg event
  data=event~data
  if data<>.nil & data~hasMethod('DATA') then incoming=incoming||data~data
  return self

::method onStreamClosed
  expose state
  use strict arg event
  state='CLOSED'; return self

::method write
  expose stream state
  use strict arg bytes
  if state<>'OPEN' then return .false
  return stream~write(bytes)

::method pump
  expose adbSession state
  use strict arg timeoutMs=0
  if state<>'OPEN' then return .false
  return adbSession~pump(timeoutMs)

::method available
  expose incoming
  return incoming~length

::method read
  expose incoming
  use strict arg count
  if incoming~length<count then return .nil
  out=substr(incoming,1,count); incoming=substr(incoming,count+1); return out

::method performHandshake
  expose incoming
  if \self~write(.JdwpProtocol~HANDSHAKE) then return .false
  do while incoming~length<.JdwpProtocol~HANDSHAKE~length
    if \self~pump(1000) then return .false
  end
  got=self~read(.JdwpProtocol~HANDSHAKE~length)
  return got==.JdwpProtocol~HANDSHAKE

::method readPacket
  expose incoming
  use strict arg timeoutMs=0
  do while incoming~length<4
    if \self~pump(timeoutMs) then return .nil
  end
  n=.JdwpPacketCodec~packetLength(incoming)
  do while incoming~length<n
    if \self~pump(timeoutMs) then return .nil
  end
  return .JdwpPacketCodec~decode(self~read(n))

::requires "JdwpWire.cls"
