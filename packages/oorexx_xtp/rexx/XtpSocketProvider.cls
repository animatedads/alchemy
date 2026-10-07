/* XtpSocketProvider.cls
 * ooRexx Socket Provider binding for libxtp v0.1-dev18.
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
::method listener
  use strict arg address, backlog=32
  if address~multicast then return .XtpMulticastListener~new(address,0)
  return .XtpProviderListener~new(address,backlog)
::method multicastSender
  use strict arg address, expectedReceivers=1, reliableMode=.true, segment=1200, timeout=250, retryCount=12, allocationPace=.true, ratePace=.true
  return .XtpMulticastSocket~new(address,expectedReceivers,reliableMode,segment,timeout,retryCount,allocationPace,ratePace)
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
  expose address closed lastResult
  use strict arg address
  closed=.false
  lastResult=.directory~new
::attribute address get
::attribute lastResult get
::method send
  expose address closed lastResult
  use strict arg bytes
  if closed then return -1
  peer=address~xtpAddress
  n=xtpNativeSend(peer,bytes)
  lastResult=.directory~new
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
  expose address handle closed backlog
  use strict arg endpointAddress, requestedBacklog=32
  address=endpointAddress
  backlog=requestedBacklog
  handle=xtpNativeListenerOpen(address~xtpAddress,0)
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



::class XtpMulticastSocket public
::method init
  expose address closed expected reliable segmentBytes timeoutMs retries allocationPacing ratePacing
  use strict arg address, expectedReceivers=1, reliableMode=.true, segment=1200, timeout=250, retryCount=12, pace=.true, ratePace=.true
  expected=expectedReceivers
  reliable=reliableMode
  segmentBytes=segment
  timeoutMs=timeout
  retries=retryCount
  allocationPacing=pace
  ratePacing=ratePace
  closed=.false
::attribute address get
::method send
  expose address closed expected reliable segmentBytes timeoutMs retries allocationPacing ratePacing
  use strict arg bytes
  if closed then return -1
  return xtpNativeMulticastSendRate(address~xtpAddress,bytes,expected,reliable,segmentBytes,timeoutMs,retries,allocationPacing,ratePacing)
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
::routine xtpNativeListenerReceive external "library oorexx_xtp_native xtpNativeListenerReceive"
::routine xtpNativeListenerClose external "library oorexx_xtp_native xtpNativeListenerClose"
::routine xtpNativeSend external "library oorexx_xtp_native xtpNativeSend"
::routine xtpNativeMulticastListenerOpen external "library oorexx_xtp_native xtpNativeMulticastListenerOpen"
::routine xtpNativeMulticastListenerOpenEx external "library oorexx_xtp_native xtpNativeMulticastListenerOpenEx"
::routine xtpNativeMulticastListenerOpenRate external "library oorexx_xtp_native xtpNativeMulticastListenerOpenRate"
::routine xtpNativeMulticastListenerReceive external "library oorexx_xtp_native xtpNativeMulticastListenerReceive"
::routine xtpNativeMulticastListenerClose external "library oorexx_xtp_native xtpNativeMulticastListenerClose"
::routine xtpNativeMulticastSend external "library oorexx_xtp_native xtpNativeMulticastSend"
::routine xtpNativeMulticastSendEx external "library oorexx_xtp_native xtpNativeMulticastSendEx"
::routine xtpNativeMulticastSendRate external "library oorexx_xtp_native xtpNativeMulticastSendRate"
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
