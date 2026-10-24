/* ooRexx NORM Socket Provider v0.1-dev3
 *
 * NORM remains an ordinary SocketProvider transport.  NORM session,
 * multicast membership, FEC and event mechanics terminate here.
 *
 * dev2 made multicast membership explicit and independent of listener
 * lifetime.  dev3 adds descriptor-driven bounded readiness, nonblocking event
 * drain and qualification-only loss injection while keeping NORM mechanics
 * below the ordinary socket-provider boundary.
 */

::class NormSocketBackend public
::method init
  expose nativeApi configuration
  use strict arg nativeApi=.nil, configuration=.nil
  nativeApi=nativeApi
  configuration=configuration
::method requireNative private
  expose nativeApi
  if nativeApi=.nil then raise syntax 88.900 array('NORM native API is not configured; inject NormNativeApi from NormNativeBinding.cls')
  return nativeApi
::method sender
  use strict arg address
  return .NormProviderSocket~new(address,self~requireNative)
::method join
  use strict arg address, membershipRequest
  return .NormProviderMembership~new(address,membershipRequest,self~requireNative)
::method listenerOn
  use strict arg membership, address, backlog=32
  if membership=.nil then return .nil
  return .NormProviderListener~new(address,backlog,membership,.false)
::method listener
  use strict arg address, backlog=32
  request=.SocketMulticastMembershipRequest~new(address,address~normInterface,address~normSource)
  membership=.NormProviderMembership~new(address,request,self~requireNative)
  return .NormProviderListener~new(address,backlog,membership,.true)

::class NormProviderMembership public
::method init
  expose address request handle joined nativeApi
  use strict arg address, membershipRequest=.nil, api
  nativeApi=api
  address=address
  if membershipRequest=.nil then
    request=.SocketMulticastMembershipRequest~new(address,address~normInterface,address~normSource)
  else request=membershipRequest
  if request~address~canonical<>address~canonical then
    raise syntax 88.900 array('NORM membership request/address mismatch')
  if request~scope<>'' then
    raise syntax 88.900 array('NORM provider does not reinterpret generic multicast scope; use the group address and interface')
  iface=request~interfaceName
  if iface='' then iface=address~normInterface
  source=request~sourceAddress
  if source='' then source=address~normSource
  m=address~metadata
  rxBuffer=.NormConfig~number(m,'rxBufferBytes',1048576)
  loopback=.NormConfig~boolean(m,'loopback',.false)
  handle=nativeApi~listenerOpen(address~normGroup,address~port,address~normNodeId,iface,source,loopback,rxBuffer)
  if handle=0 then raise syntax 88.900 array('unable to join NORM multicast session')
  joined=.true
::attribute address get
::attribute request get
::method receive
  expose handle joined nativeApi
  if \joined then return .nil
  return nativeApi~listenerReceive(handle)
::method tryReceive
  expose handle joined nativeApi
  if \joined then return .nil
  return nativeApi~listenerTryReceive(handle)
::method waitReady
  expose handle joined nativeApi
  use strict arg timeoutMilliseconds=0
  if \joined then return .false
  return nativeApi~listenerWait(handle,timeoutMilliseconds)
::method descriptor
  expose handle joined nativeApi
  if \joined then return -1
  return nativeApi~listenerDescriptor(handle)
::method leave
  expose handle joined nativeApi
  if \joined then return 0
  rc=nativeApi~listenerClose(handle)
  if rc=0 then joined=.false
  return rc
::method joined
  expose joined
  return joined

::class NormProviderSocket public
::method init
  expose address handle closed nativeApi
  use strict arg address, api
  nativeApi=api
  address=address
  m=address~metadata
  ttl=.NormConfig~number(m,'ttl',1)
  txRate=.NormConfig~number(m,'txRate',2000000)
  segmentSize=.NormConfig~number(m,'segmentSize',1400)
  dataSymbols=.NormConfig~number(m,'dataSymbols',64)
  paritySymbols=.NormConfig~number(m,'paritySymbols',16)
  bufferBytes=.NormConfig~number(m,'txBufferBytes',1048576)
  loopback=.NormConfig~boolean(m,'loopback',.false)
  txLoss=.NormConfig~number(m,'qualificationTxLossPercent',0)
  fecSpec=segmentSize||":"||dataSymbols||":"||paritySymbols
  handle=nativeApi~senderOpen(address~normGroup,address~port,address~normNodeId,address~normInterface,address~normSource,ttl,loopback,txRate,bufferBytes,fecSpec)
  if txLoss>0 then nativeApi~senderSetLoss(handle,txLoss)
  if handle=0 then raise syntax 88.900 array('unable to open NORM sender')
  closed=.false
::attribute address get
::method send
  expose handle closed nativeApi
  use strict arg bytes
  if closed then return -1
  return nativeApi~senderSend(handle,bytes)
::method recv
  use strict arg maximumBytes
  return .nil
::method descriptor
  expose handle closed nativeApi
  if closed then return -1
  return nativeApi~senderDescriptor(handle)
::method waitDrained
  expose handle closed nativeApi
  use strict arg timeoutMilliseconds=5000
  if closed then return .true
  return nativeApi~senderWaitDrained(handle,timeoutMilliseconds)
::method close
  expose handle closed nativeApi
  if closed then return 0
  rc=nativeApi~senderClose(handle)
  closed=.true
  return rc

::class NormProviderListener public
::method init
  expose address membership ownsMembership closed backlog
  use strict arg endpointAddress, requestedBacklog=32, providerMembership=.nil, ownMembership=.true
  address=endpointAddress
  backlog=requestedBacklog
  membership=providerMembership
  ownsMembership=ownMembership
  if membership=.nil then raise syntax 88.900 array('NORM listener requires provider membership')
  if \membership~joined then raise syntax 88.900 array('NORM listener requires joined membership')
  closed=.false
::attribute address get
::attribute backlog get
::method membership
  expose membership
  return membership
::method accept
  expose membership closed address
  if closed then return .nil
  bytes=membership~receive
  if bytes=.nil then return .nil
  return .NormAcceptedSocket~new(address,bytes)
::method tryAccept
  expose membership closed address
  if closed then return .nil
  bytes=membership~tryReceive
  if bytes=.nil then return .nil
  return .NormAcceptedSocket~new(address,bytes)
::method waitReady
  expose membership closed
  use strict arg timeoutMilliseconds=0
  if closed then return .false
  return membership~waitReady(timeoutMilliseconds)
::method descriptor
  expose membership closed
  if closed then return -1
  return membership~descriptor
::method close
  expose membership ownsMembership closed
  if closed then return 0
  closed=.true
  if ownsMembership then return membership~leave
  return 0

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

::requires "SocketProvider.cls"
