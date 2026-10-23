/* XtpSocketProvider.cls
 * ooRexx Socket Provider binding for libxtp v0.1-dev22.
 *
 * Sender and persistent listener are both native bindings.  The Rexx objects
 * retain the transport object shape while libxtp owns XTP routing, filters,
 * replay state and carrier selection.
 */

::class XtpSocketBackend public
::method init
  use strict arg ignoredConnector=.nil
::method sender
  use strict arg address
  if address~multicast then return .XtpMulticastSocket~new(address)
  return .XtpProviderSocket~new(address)
::method prioritySender
  use strict arg address, mode, sortValue
  s=.XtpProviderSocket~new(address)
  return s~priority(mode,sortValue)
::method routeSender
  use strict arg address, routeValue
  s=.XtpProviderSocket~new(address)
  return s~route(routeValue)
::method routeListener
  use strict arg address, exchangeRoute, backlog=32
  return .XtpProviderListener~new(address,backlog,exchangeRoute)
::method listener
  use strict arg address, backlog=32
  if address~multicast then return .XtpMulticastListener~new(address,0)
  return .XtpProviderListener~new(address,backlog)
::method multicastSender
  use strict arg address, expectedReceivers=1, reliableMode=.true, segment=1200, timeout=250, retryCount=12, allocationPace=.true, ratePace=.true
  return .XtpMulticastSocket~new(address,expectedReceivers,reliableMode,segment,timeout,retryCount,allocationPace,ratePace)
::method priorityMulticastSender
  use strict arg address, mode, sortValue, expectedReceivers=1, reliableMode=.true, segment=1200, timeout=250, retryCount=12, allocationPace=.true, ratePace=.true
  s=.XtpMulticastSocket~new(address,expectedReceivers,reliableMode,segment,timeout,retryCount,allocationPace,ratePace)
  return s~priority(mode,sortValue)
::method multicastListener
  use strict arg address, timeoutMs=0, receiveWindow=1048576, rejectSuppressionMs=20, advertisedRate=4294967295, advertisedBurst=4294967295
  return .XtpMulticastListener~new(address,timeoutMs,receiveWindow,rejectSuppressionMs,advertisedRate,advertisedBurst)
::method multipathSender
  use strict arg address, chunkBytes=16384, maxPaths=2, generation=0
  return .XtpMultipathSocket~new(address,chunkBytes,maxPaths,generation)
::method multipathListener
  use strict arg address, maxPaths=2, timeoutMs=0
  return .XtpMultipathListener~new(address,maxPaths,timeoutMs)

::class XtpProviderSocket public
::method init
  expose address closed lastResult priorityMode prioritySort routeValue serviceName
  use strict arg address
  closed=.false
  lastResult=.directory~new
  priorityMode="disabled"
  prioritySort=0
  routeValue=0
  serviceName=''
::attribute address get
::attribute lastResult get
::method priority
  expose priorityMode prioritySort
  use strict arg mode="disabled", sortValue=0
  priorityMode=mode
  prioritySort=sortValue
  return self
::method route
  expose routeValue
  use strict arg value=0
  routeValue=value
  return self
::method service
  expose serviceName
  use strict arg name
  serviceName=name
  return self
::method send
  expose address closed lastResult priorityMode prioritySort routeValue serviceName
  use strict arg bytes
  if closed then return -1
  peer=address~xtpAddress
  lastResult=.directory~new
  if serviceName<>'' then do
    n=xtpNativeSendService(peer,bytes,serviceName)
    lastResult['SERVICE']=serviceName
  end
  else if routeValue<>0 then do
    peerXroute=xtpNativeSendRoute(peer,bytes,routeValue)
    n=length(bytes)
    lastResult['XROUTE']=peerXroute
  end
  else if priorityMode="disabled" then n=xtpNativeSend(peer,bytes)
  else n=xtpNativeSendPriority(peer,bytes,priorityMode,prioritySort)
  lastResult['RC']=n
  return n
::method recv
  use strict arg maximumBytes
  return .nil
::method close
  expose closed
  closed=.true
  return 0

::class XtpProviderListener public
::method init
  expose address handle closed backlog exchangeRoute
  use strict arg endpointAddress, requestedBacklog=32, requestedExchangeRoute=0
  address=endpointAddress
  backlog=requestedBacklog
  exchangeRoute=requestedExchangeRoute
  if exchangeRoute<>0 then handle=xtpNativeListenerOpenRoute(address~xtpAddress,0,exchangeRoute)
  else handle=xtpNativeListenerOpen(address~xtpAddress,0)
  closed=.false
::attribute address get
::attribute backlog get
::method accept
  expose handle closed address
  if closed then return .nil
  bytes=xtpNativeListenerReceive(handle)
  return .XtpAcceptedSocket~new(address,bytes)
::method close
  expose handle closed
  if closed then return 0
  rc=xtpNativeListenerClose(handle)
  closed=.true
  return rc




::class XtpNamedServiceListener public
::method init
  expose address handle closed allowed
  use strict arg endpointAddress, serviceNames, timeoutMs=0
  address=endpointAddress
  allowed=serviceNames
  handle=xtpNativeListenerOpenServices(address~xtpAddress,timeoutMs,serviceNames)
  closed=.false
::attribute address get
::attribute allowed get
::method accept
  expose address handle closed
  if closed then return .nil
  bytes=xtpNativeListenerReceive(handle)
  service=xtpNativeListenerLastService(handle)
  return .XtpNamedAcceptedSocket~new(address,service,bytes)
::method close
  expose handle closed
  if closed then return 0
  rc=xtpNativeListenerClose(handle);closed=.true;return rc

::class XtpNamedAcceptedSocket public subclass XtpAcceptedSocket
::method init
  expose serviceName
  use strict arg address, namedService, bytes
  self~init:super(address,bytes)
  serviceName=namedService
::attribute serviceName get

::class XtpMulticastSocket public
::method init
  expose address closed expected reliable segmentBytes timeoutMs retries allocationPacing ratePacing priorityMode prioritySort
  use strict arg address, expectedReceivers=1, reliableMode=.true, segment=1200, timeout=250, retryCount=12, pace=.true, ratePace=.true
  expected=expectedReceivers
  reliable=reliableMode
  segmentBytes=segment
  timeoutMs=timeout
  retries=retryCount
  allocationPacing=pace
  ratePacing=ratePace
  priorityMode="disabled"
  prioritySort=0
  closed=.false
::attribute address get
::method priority
  expose priorityMode prioritySort
  use strict arg mode="disabled", sortValue=0
  priorityMode=mode
  prioritySort=sortValue
  return self
::method route
  expose routeValue
  use strict arg value=0
  routeValue=value
  return self
::method send
  expose address closed expected reliable segmentBytes timeoutMs retries allocationPacing ratePacing priorityMode prioritySort
  use strict arg bytes
  if closed then return -1
  if priorityMode="disabled" then return xtpNativeMulticastSendRate(address~xtpAddress,bytes,expected,reliable,segmentBytes,timeoutMs,retries,allocationPacing,ratePacing)
  spec=priorityMode":"prioritySort
  return xtpNativeMulticastSendPriority(address~xtpAddress,bytes,expected,reliable,segmentBytes,timeoutMs,retries,allocationPacing,ratePacing,spec)
::method recv
  use strict arg maximumBytes
  return .nil
::method close
  expose closed
  closed=.true
  return 0

::class XtpMulticastListener public
::method init
  expose address handle closed
  use strict arg endpointAddress, timeoutMs=0, receiveWindow=1048576, rejectSuppressionMs=20, advertisedRate=4294967295, advertisedBurst=4294967295
  address=endpointAddress
  handle=xtpNativeMulticastListenerOpenRate(address~xtpAddress,timeoutMs,receiveWindow,rejectSuppressionMs,advertisedRate,advertisedBurst)
  closed=.false
::attribute address get
::method accept
  expose address handle closed
  if closed then return .nil
  bytes=xtpNativeMulticastListenerReceive(handle)
  return .XtpAcceptedSocket~new(address,bytes)
::method close
  expose handle closed
  if closed then return 0
  rc=xtpNativeMulticastListenerClose(handle)
  closed=.true
  return rc

::class XtpAcceptedSocket public
::method init
  expose address buffer closed
  use strict arg address, bytes
  buffer=bytes
  closed=.false
::attribute address get
::method send
  expose address closed
  use strict arg bytes
  if closed then return -1
  return xtpNativeSend(address~xtpAddress,bytes)
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

::routine xtpNativeListenerOpen external "library oorexx_xtp_native xtpNativeListenerOpen"
::routine xtpNativeListenerOpenServices external "library oorexx_xtp_native xtpNativeListenerOpenServices"
::routine xtpNativeListenerLastService external "library oorexx_xtp_native xtpNativeListenerLastService"
::routine xtpNativeListenerOpenRoute external "library oorexx_xtp_native xtpNativeListenerOpenRoute"
::routine xtpNativeListenerReceive external "library oorexx_xtp_native xtpNativeListenerReceive"
::routine xtpNativeListenerClose external "library oorexx_xtp_native xtpNativeListenerClose"
::routine xtpNativeSendPriority external "library oorexx_xtp_native xtpNativeSendPriority"
::routine xtpNativeSend external "library oorexx_xtp_native xtpNativeSend"
::routine xtpNativeSendService external "library oorexx_xtp_native xtpNativeSendService"
::routine xtpNativeSendRoute external "library oorexx_xtp_native xtpNativeSendRoute"
::routine xtpNativeMulticastListenerOpen external "library oorexx_xtp_native xtpNativeMulticastListenerOpen"
::routine xtpNativeMulticastListenerOpenEx external "library oorexx_xtp_native xtpNativeMulticastListenerOpenEx"
::routine xtpNativeMulticastListenerOpenRate external "library oorexx_xtp_native xtpNativeMulticastListenerOpenRate"
::routine xtpNativeMulticastListenerReceive external "library oorexx_xtp_native xtpNativeMulticastListenerReceive"
::routine xtpNativeMulticastListenerClose external "library oorexx_xtp_native xtpNativeMulticastListenerClose"
::routine xtpNativeMulticastSend external "library oorexx_xtp_native xtpNativeMulticastSend"
::routine xtpNativeMulticastSendEx external "library oorexx_xtp_native xtpNativeMulticastSendEx"
::routine xtpNativeMulticastSendRate external "library oorexx_xtp_native xtpNativeMulticastSendRate"
::routine xtpNativeMulticastSendPriority external "library oorexx_xtp_native xtpNativeMulticastSendPriority"
::requires "SocketProvider.cls"

/* dev12 multipath hooks. Generation 0 delegates generation choice to libxtp
 * path-health state, so a recovered path cannot silently rejoin an old stripe.
 * The ordinary SocketSelector send/listener contract remains unchanged.
 *
 * dev11 explicit multipath hooks.  The ordinary SocketSelector send/listener
 * methods remain protocol-independent; callers which request XTP multipath can
 * opt into these without learning carrier details. */
::class XtpMultipathSocket public
::method init
  expose address chunkBytes maxPaths generation closed
  use strict arg address, chunk=16384, paths=2, pathGeneration=0
  chunkBytes=chunk
  maxPaths=paths
  generation=pathGeneration
  closed=.false
::method send
  expose address chunkBytes maxPaths generation closed
  use strict arg bytes
  if closed then return -1
  return xtpNativeMultipathSend(address~xtpAddress,bytes,chunkBytes,maxPaths,generation)
::method close
  expose closed
  closed=.true
  return 0

::class XtpMultipathListener public
::method init
  expose address handle closed maxPaths
  use strict arg endpointAddress, paths=2, timeoutMs=0
  address=endpointAddress
  maxPaths=paths
  handle=xtpNativeMultipathListenerOpen(address~xtpAddress,maxPaths,timeoutMs)
  closed=.false
::method accept
  expose address handle closed
  if closed then return .nil
  bytes=xtpNativeMultipathListenerReceive(handle)
  return .XtpAcceptedSocket~new(address,bytes)
::method close
  expose handle closed
  if closed then return 0
  rc=xtpNativeMultipathListenerClose(handle)
  closed=.true
  return rc

::routine xtpNativeMultipathListenerOpen external "library oorexx_xtp_native xtpNativeMultipathListenerOpen"
::routine xtpNativeMultipathListenerReceive external "library oorexx_xtp_native xtpNativeMultipathListenerReceive"
::routine xtpNativeMultipathListenerClose external "library oorexx_xtp_native xtpNativeMultipathListenerClose"
::routine xtpNativeMultipathSend external "library oorexx_xtp_native xtpNativeMultipathSend"

/* dev21 operational degradation adapter.
 * The planner is transport-neutral. XTP consumes its decision and uses XTP
 * priority/fallback controls where available. SAMPLE/AGGREGATE never pass the
 * untransformed original payload. */
::class XtpOperationalSocket public
::method init
  expose socket planner className operatingState fallback protectedPath
  use strict arg endpointSocket, plannerObject, registeredClass, state='normal', isFallback=.false, isProtected=.true
  socket=endpointSocket; planner=plannerObject; className=registeredClass; operatingState=state; fallback=isFallback; protectedPath=isProtected
::method operatingState
  expose operatingState
  use strict arg value
  operatingState=value
  return self
::method send
  expose socket planner className operatingState fallback protectedPath
  use strict arg bytes
  d=planner~decide(className,operatingState)
  action=d['ACTION']; fallbackPolicy=d['FALLBACK']; protectedOnly=d['PROTECTED_ONLY']
  if d['TRANSMIT']<>'1' then return -2
  if d['TRANSFORM']='1' then return -3
  if fallback then do
    if fallbackPolicy='forbid' then return -4
  end
  else do
    if fallbackPolicy='require' then return -5
  end
  if protectedOnly='1' then do
    if \protectedPath then return -6
  end
  if d~hasIndex('SORT') then socket~priority('static',d['SORT'])
  return socket~send(bytes)
::method close
  expose socket
  return socket~close
