/* ooRexx NORM Socket Provider v0.1-dev1
 * NORM is exposed as an ordinary SocketProvider transport.  libnorm session,
 * multicast, FEC and event mechanics terminate here.
 */

::class NormSocketBackend public
::method init
  use strict arg configuration=.nil
::method sender
  use strict arg address
  return .NormProviderSocket~new(address)
::method listener
  use strict arg address, backlog=32
  return .NormProviderListener~new(address,backlog)

::class NormProviderSocket public
::method init
  expose address handle closed
  use strict arg address
  address=address
  m=address~metadata
  ttl=.NormConfig~number(m,'ttl',1)
  txRate=.NormConfig~number(m,'txRate',2000000)
  segmentSize=.NormConfig~number(m,'segmentSize',1400)
  dataSymbols=.NormConfig~number(m,'dataSymbols',64)
  paritySymbols=.NormConfig~number(m,'paritySymbols',16)
  bufferBytes=.NormConfig~number(m,'txBufferBytes',1048576)
  loopback=.NormConfig~boolean(m,'loopback',.false)
  fecSpec=segmentSize||":"||dataSymbols||":"||paritySymbols
  handle=normNativeSenderOpen(address~normGroup,address~port,address~normNodeId,address~normInterface,address~normSource,ttl,loopback,txRate,bufferBytes,fecSpec)
  if handle=0 then raise syntax 88.900 array('unable to open NORM sender')
  closed=.false
::attribute address get
::method send
  expose handle closed
  use strict arg bytes
  if closed then return -1
  return normNativeSenderSend(handle,bytes)
::method recv
  use strict arg maximumBytes
  return .nil
::method descriptor
  expose handle closed
  if closed then return -1
  return normNativeSenderDescriptor(handle)
::method close
  expose handle closed
  if closed then return 0
  rc=normNativeSenderClose(handle)
  closed=.true
  return rc

::class NormProviderListener public
::method init
  expose address handle closed backlog
  use strict arg endpointAddress, requestedBacklog=32
  address=endpointAddress
  backlog=requestedBacklog
  m=address~metadata
  rxBuffer=.NormConfig~number(m,'rxBufferBytes',1048576)
  loopback=.NormConfig~boolean(m,'loopback',.false)
  handle=normNativeListenerOpen(address~normGroup,address~port,address~normNodeId,address~normInterface,address~normSource,loopback,rxBuffer)
  if handle=0 then raise syntax 88.900 array('unable to open NORM listener')
  closed=.false
::attribute address get
::attribute backlog get
::method accept
  expose handle closed address
  if closed then return .nil
  bytes=normNativeListenerReceive(handle)
  if bytes=.nil then return .nil
  return .NormAcceptedSocket~new(address,bytes)
::method descriptor
  expose handle closed
  if closed then return -1
  return normNativeListenerDescriptor(handle)
::method close
  expose handle closed
  if closed then return 0
  rc=normNativeListenerClose(handle)
  closed=.true
  return rc

::class NormAcceptedSocket public
::method init
  expose address buffer closed
  use strict arg endpointAddress, bytes
  address=endpointAddress
  buffer=bytes
  closed=.false
::attribute address get
::method send
  use strict arg bytes
  return -1
::method recv
  expose buffer closed
  use strict arg maximumBytes
  if closed then return .nil
  if maximumBytes<1 then return ''
  if length(buffer)=0 then return .nil
  take=maximumBytes
  if take>length(buffer) then take=length(buffer)
  out=substr(buffer,1,take)
  buffer=substr(buffer,take+1)
  return out
::method close
  expose closed buffer
  closed=.true
  buffer=''
  return 0

::class NormConfig private
::method number class
  use strict arg d,key,defaultValue
  if d=.nil then return defaultValue
  v=d[key]
  if v=.nil then return defaultValue
  return v+0
::method boolean class
  use strict arg d,key,defaultValue
  if d=.nil then return defaultValue
  v=d[key]
  if v=.nil then return defaultValue
  if v=.true | v=1 | v~string~strip~upper='TRUE' then return .true
  return .false

::routine normNativeVersion external "library oorexx_norm_native normNativeVersion"
::routine normNativeSenderOpen external "library oorexx_norm_native normNativeSenderOpen"
::routine normNativeSenderSend external "library oorexx_norm_native normNativeSenderSend"
::routine normNativeSenderDescriptor external "library oorexx_norm_native normNativeSenderDescriptor"
::routine normNativeSenderClose external "library oorexx_norm_native normNativeSenderClose"
::routine normNativeListenerOpen external "library oorexx_norm_native normNativeListenerOpen"
::routine normNativeListenerReceive external "library oorexx_norm_native normNativeListenerReceive"
::routine normNativeListenerDescriptor external "library oorexx_norm_native normNativeListenerDescriptor"
::routine normNativeListenerClose external "library oorexx_norm_native normNativeListenerClose"

::requires "SocketProvider.cls"
