/* XtpNamedServices.cls
 * Named service -> authoritative operational class -> logical XTP route peer.
 * Applications never pass IP addresses here.
 */

::class XtpNamedServiceAddress public
::method init
  expose descriptor
  use strict arg serviceDescriptor
  descriptor=serviceDescriptor
::attribute descriptor get
::method xtpAddress
  expose descriptor
  return descriptor~routePeer
::method multicast
  return .false
::method serviceName
  expose descriptor
  return descriptor~servicePoint

::class XtpNamedServiceManager public
::method init
  expose registry backend planner operatingState
  use strict arg serviceRegistry, xtpBackend=.nil, plannerObject=.nil, state='normal'
  registry=serviceRegistry
  if xtpBackend=.nil then backend=.XtpSocketBackend~new
  else backend=xtpBackend
  planner=plannerObject
  operatingState=state
::attribute operatingState

::method descriptor
  expose registry
  use strict arg serviceName
  d=registry~resolve(serviceName)
  if d=.nil then raise syntax 93.900 array('Unknown or disabled named service',serviceName)
  return d

::method sender
  expose backend planner operatingState
  use strict arg serviceName
  d=self~descriptor(serviceName)
  if d~routePeer='' then raise syntax 93.900 array('Named XTP service has no logical route peer',serviceName)
  a=.XtpNamedServiceAddress~new(d)
  s=backend~sender(a)~service(d~servicePoint)
  if planner=.nil then return s
  /* Class comes from the local service registry, never from the caller. */
  return .XtpOperationalSocket~new(s,planner,d~operationalClass,operatingState,.false,.true)

::method listener
  expose registry backend planner operatingState
  use strict arg logicalPeer, timeoutMs=0
  services=registry~servicesForPeer(logicalPeer)
  csv=''
  do d over services
    admit=.true
    if planner<>.nil then do
      decision=planner~decide(d~operationalClass,operatingState)
      if decision['TRANSMIT']<>'1' | decision['TRANSFORM']='1' then admit=.false
    end
    if admit then do
      if csv<>'' then csv=csv','
      csv=csv||d~servicePoint
    end
  end
  if csv='' then raise syntax 93.900 array('No named services admitted for logical XTP peer in current operating state',logicalPeer,operatingState)
  /* This address contains only the logical route key. */
  a=.XtpLogicalPeerAddress~new(logicalPeer)
  return .XtpNamedServiceListener~new(a,csv,timeoutMs)

::class XtpLogicalPeerAddress public
::method init
  expose peer
  use strict arg logicalPeer
  peer=logicalPeer
::method xtpAddress
  expose peer
  return peer
::method multicast
  return .false

::requires "XtpSocketProvider.cls"
