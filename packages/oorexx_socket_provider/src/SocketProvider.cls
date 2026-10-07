/* SocketProvider.cls
 * ooRexx Socket Provider v0.1-dev14
 *
 * Core contracts only. Native transport bindings live in separate files so
 * loading this class never requires RxSock, Unix Socket, OpenSSL or libxtp.
 * The XTP dev14 adapter is shipped separately as XtpSocketProvider.cls.
 */

::class SocketProviderBuild public
::constant VERSION "0.1-dev14"
::constant PROVIDER_API "socket.provider/0.1"
::constant ADDRESS_API "socket.address.provider/0.1"
::constant FAMILY_API "socket.family/0.1"
::constant INTENTION_API "socket.intention/0.1"
::constant NEGOTIATION_API "socket.negotiation/0.1"
::constant MULTICAST_MEMBERSHIP_API "socket.multicast.membership/0.1"

::class SocketTransportKind public
::constant TCP "TCP"
::constant UDP "UDP"
::constant UNIX "UNIX"
::constant TLS "TLS"
::constant XTP "XTP"
::constant NORM "NORM"

::class SocketRole public
::constant LISTENER "LISTENER"
::constant SENDER "SENDER"

::class SocketScheme public
::constant TCP "tcp"
::constant UDP "udp"
::constant UNIX "unix"
::constant TLS "tls"
::constant XTP "xtp"
::constant NORM "norm"

::class SocketAddressFamily public
::constant INET "INET"
::constant UNIX "UNIX"
::constant TLS_INET "TLS_INET"
::constant XTP "XTP"
::constant NORM "NORM"

::class SocketCapabilities public
::method init
  expose scheme addressFamily stream listener sender secure multicast
  use strict arg scheme, addressFamily, stream=.true, listener=.true, sender=.true, secure=.false, multicast=.false
  scheme=scheme~string~strip~lower
  addressFamily=addressFamily~string~strip~upper
  stream=stream
  listener=listener
  sender=sender
  secure=secure
  multicast=multicast
::attribute scheme get
::attribute addressFamily get
::attribute stream get
::attribute listener get
::attribute sender get
::attribute secure get
::attribute multicast get


::class SocketMembershipState public
::constant JOINED "JOINED"
::constant LEFT "LEFT"

/* Provider-neutral multicast membership request.  It is deliberately
 * separate from SocketAddress and from listener/socket lifetime. */
::class SocketMulticastMembershipRequest public
::method init
  expose address interfaceName sourceAddress scope metadata
  use strict arg address, interfaceName="", sourceAddress="", scope="", metadata=.nil
  if address=.nil then raise syntax 88.900 array("multicast membership requires address")
  if \address~multicast then raise syntax 88.900 array("multicast membership requires multicast address")
  interfaceName=interfaceName~string~strip
  sourceAddress=sourceAddress~string~strip
  scope=scope~string~strip
  if metadata=.nil then metadata=.directory~new
  else metadata=metadata
::attribute address get
::attribute interfaceName get
::attribute sourceAddress get
::attribute scope get
::attribute metadata get

::class SocketMulticastMembership public
::method init
  expose request nativeMembership state
  use strict arg request, nativeMembership
  if request=.nil then raise syntax 88.900 array("membership requires request")
  if nativeMembership=.nil then raise syntax 88.900 array("membership requires native provider membership")
  request=request
  nativeMembership=nativeMembership
  state=.SocketMembershipState~JOINED
::attribute request get
::method address
  expose request
  return request~address
::method interfaceName
  expose request
  return request~interfaceName
::method sourceAddress
  expose request
  return request~sourceAddress
::method scope
  expose request
  return request~scope
::method raw
  expose nativeMembership
  return nativeMembership
::method descriptor
  expose nativeMembership state
  if state=.SocketMembershipState~LEFT then return -1
  if nativeMembership~hasMethod("DESCRIPTOR") then return nativeMembership~descriptor
  return -1
::method state
  expose state
  return state
::method joined
  expose state
  return state=.SocketMembershipState~JOINED
::method leave
  expose nativeMembership state
  if state=.SocketMembershipState~LEFT then return .true
  if \nativeMembership~hasMethod("LEAVE") then return .false
  rc=nativeMembership~leave
  if datatype(rc,"W") then do
    if rc<>0 then return .false
  end
  else do
    if rc<>.true then return .false
  end
  state=.SocketMembershipState~LEFT
  return .true

::class SocketFamily public
::method init
  expose transport scheme addressFamily capabilities
  use strict arg transport, scheme, addressFamily, capabilities
  transport=transport~string~strip~upper
  scheme=scheme~string~strip~lower
  addressFamily=addressFamily~string~strip~upper
  capabilities=capabilities
::attribute transport get
::attribute scheme get
::attribute addressFamily get
::attribute capabilities get

::class SocketFamilies public
::method tcp class
  return .SocketFamily~new(.SocketTransportKind~TCP,.SocketScheme~TCP,.SocketAddressFamily~INET,.SocketCapabilities~new(.SocketScheme~TCP,.SocketAddressFamily~INET,.true,.true,.true,.false,.false))
::method udp class
  return .SocketFamily~new(.SocketTransportKind~UDP,.SocketScheme~UDP,.SocketAddressFamily~INET,.SocketCapabilities~new(.SocketScheme~UDP,.SocketAddressFamily~INET,.false,.true,.true,.false,.true))
::method unix class
  return .SocketFamily~new(.SocketTransportKind~UNIX,.SocketScheme~UNIX,.SocketAddressFamily~UNIX,.SocketCapabilities~new(.SocketScheme~UNIX,.SocketAddressFamily~UNIX,.true,.true,.true,.false,.false))
::method tls class
  return .SocketFamily~new(.SocketTransportKind~TLS,.SocketScheme~TLS,.SocketAddressFamily~TLS_INET,.SocketCapabilities~new(.SocketScheme~TLS,.SocketAddressFamily~TLS_INET,.true,.true,.true,.true,.false))
::method xtp class
  return .SocketFamily~new(.SocketTransportKind~XTP,.SocketScheme~XTP,.SocketAddressFamily~XTP,.SocketCapabilities~new(.SocketScheme~XTP,.SocketAddressFamily~XTP,.true,.true,.true,.false,.true))
::method norm class
  return .SocketFamily~new(.SocketTransportKind~NORM,.SocketScheme~NORM,.SocketAddressFamily~NORM,.SocketCapabilities~new(.SocketScheme~NORM,.SocketAddressFamily~NORM,.false,.true,.true,.false,.true))

/* Address is a value object. For TLS it contains only securityProfile, never
 * private key/certificate/trust bytes or filenames.
 */
::class SocketAddress public
::method init
  expose transport scheme addressFamily logicalName host port path xtpAddress multicast securityProfile metadata normGroup normInterface normSource normNodeId
  use strict arg transport, logicalName="", host="", port=0, path="", xtpAddress="", multicast=.false, securityProfile="", metadata=.nil, normGroup="", normInterface="", normSource="", normNodeId=0
  transport=transport~string~strip~upper
  scheme=""; addressFamily=""
  logicalName=logicalName~string~strip
  host=host~string~strip
  port=port+0
  path=path~string
  xtpAddress=xtpAddress~string~strip
  multicast=multicast
  securityProfile=securityProfile~string~strip
  normGroup=normGroup~string~strip
  normInterface=normInterface~string~strip
  normSource=normSource~string~strip
  normNodeId=normNodeId+0
  if metadata=.nil then metadata=.directory~new
  else metadata=metadata

  select
    when transport=.SocketTransportKind~TCP then do
      scheme=.SocketScheme~TCP; addressFamily=.SocketAddressFamily~INET
      if host="" then raise syntax 88.900 array("TCP address requires dotted IP address")
      if port<1 | port>65535 then raise syntax 88.900 array("TCP address requires valid port")
    end
    when transport=.SocketTransportKind~UDP then do
      scheme=.SocketScheme~UDP; addressFamily=.SocketAddressFamily~INET
      if host="" then raise syntax 88.900 array("UDP address requires IPv4 address")
      if port<0 | port>65535 then raise syntax 88.900 array("UDP address requires port 0..65535")
    end
    when transport=.SocketTransportKind~UNIX then do
      scheme=.SocketScheme~UNIX; addressFamily=.SocketAddressFamily~UNIX
      if path="" | left(path,1)<>"/" then raise syntax 88.900 array("UNIX address requires absolute pathname")
    end
    when transport=.SocketTransportKind~TLS then do
      scheme=.SocketScheme~TLS; addressFamily=.SocketAddressFamily~TLS_INET
      if host="" then raise syntax 88.900 array("TLS address requires dotted IP address")
      if port<1 | port>65535 then raise syntax 88.900 array("TLS address requires valid port")
      if securityProfile="" then raise syntax 88.900 array("TLS address requires securityProfile")
    end
    when transport=.SocketTransportKind~XTP then do
      scheme=.SocketScheme~XTP; addressFamily=.SocketAddressFamily~XTP
      if xtpAddress="" then raise syntax 88.900 array("XTP address requires xtpAddress")
    end
    when transport=.SocketTransportKind~NORM then do
      scheme=.SocketScheme~NORM; addressFamily=.SocketAddressFamily~NORM
      multicast=.true
      if normGroup="" then raise syntax 88.900 array("NORM address requires group/session address")
      if port<1 | port>65535 then raise syntax 88.900 array("NORM address requires valid port")
      if normNodeId<0 then raise syntax 88.900 array("NORM node id must not be negative")
    end
    otherwise raise syntax 88.900 array("unsupported socket transport")
  end
::attribute transport get
::attribute scheme get
::attribute addressFamily get
::attribute logicalName get
::attribute host get
::attribute port get
::attribute path get
::attribute xtpAddress get
::attribute multicast get
::attribute securityProfile get
::attribute normGroup get
::attribute normInterface get
::attribute normSource get
::attribute normNodeId get
::attribute metadata get
::method family
  expose transport
  select
    when transport=.SocketTransportKind~TCP then return .SocketFamilies~tcp
    when transport=.SocketTransportKind~UDP then return .SocketFamilies~udp
    when transport=.SocketTransportKind~UNIX then return .SocketFamilies~unix
    when transport=.SocketTransportKind~TLS then return .SocketFamilies~tls
    when transport=.SocketTransportKind~XTP then return .SocketFamilies~xtp
    when transport=.SocketTransportKind~NORM then return .SocketFamilies~norm
    otherwise return .nil
  end
::method canonical
  expose transport scheme addressFamily logicalName host port path xtpAddress multicast securityProfile normGroup normInterface normSource normNodeId
  select
    when transport=.SocketTransportKind~TCP | transport=.SocketTransportKind~TLS | transport=.SocketTransportKind~UDP then where=host||":"||port
    when transport=.SocketTransportKind~UNIX then where=path
    when transport=.SocketTransportKind~XTP then where=xtpAddress
    otherwise where=normGroup||":"||port
  end
  answer="scheme="||scheme||";family="||addressFamily||";transport="||transport||";name="||logicalName||";address="||where||";multicast="||multicast||";securityProfile="||securityProfile
  if transport=.SocketTransportKind~NORM then answer=answer||";interface="||normInterface||";source="||normSource||";nodeId="||normNodeId
  return answer

::class SocketAddresses public
::method tcp class
  use strict arg host, port, logicalName="", metadata=.nil
  return .SocketAddress~new(.SocketTransportKind~TCP,logicalName,host,port,"","",.false,"",metadata)
::method udp class
  use arg host, port, third="", fourth=.nil, fifth=.nil
  multicast=.false; logicalName=""; metadata=.nil
  argc=arg()
  if argc>=3 then do
    if third=.true | third=.false then do
      multicast=third
      if argc>=4 then logicalName=fourth
      if argc>=5 then metadata=fifth
    end
    else do
      logicalName=third
      if argc>=4 then metadata=fourth
    end
  end
  return .SocketAddress~new(.SocketTransportKind~UDP,logicalName,host,port,"","",multicast,"",metadata)
::method ipMulticast class
  use arg group, port, third="", fourth=.nil, fifth="", sixth=.nil
  interfaceName=""; sourceAddress=""; logicalName=""; metadata=.nil
  argc=arg()
  if argc=3 then logicalName=third
  else if argc=4 then do
    if fourth~isInstanceOf(.Directory) then do
      logicalName=third; metadata=fourth
    end
    else do
      interfaceName=third; sourceAddress=fourth
    end
  end
  else if argc>=5 then do
    interfaceName=third; sourceAddress=fourth; logicalName=fifth
    if argc>=6 then metadata=sixth
  end
  if metadata=.nil then metadata=.directory~new
  if interfaceName<>"" then metadata["interface"]=interfaceName
  if sourceAddress<>"" then metadata["source"]=sourceAddress
  return .SocketAddress~new(.SocketTransportKind~UDP,logicalName,group,port,"","",.true,"",metadata)
::method unix class
  use strict arg path, logicalName="", metadata=.nil
  return .SocketAddress~new(.SocketTransportKind~UNIX,logicalName,"",0,path,"",.false,"",metadata)
::method tls class
  use strict arg host, port, securityProfile, logicalName="", metadata=.nil
  return .SocketAddress~new(.SocketTransportKind~TLS,logicalName,host,port,"","",.false,securityProfile,metadata)
::method xtp class
  use strict arg xtpAddress, multicast=.false, logicalName="", metadata=.nil
  return .SocketAddress~new(.SocketTransportKind~XTP,logicalName,"",0,"",xtpAddress,multicast,"",metadata)
::method norm class
  use strict arg group, port, interface="", source="", nodeId=0, logicalName="", metadata=.nil
  return .SocketAddress~new(.SocketTransportKind~NORM,logicalName,"",port,"","",.true,"",metadata,group,interface,source,nodeId)

::class SocketAddressProvider public
::method resolve abstract
::method listenerAddress
  use strict arg logicalName
  return self~resolve(logicalName,.SocketRole~LISTENER)
::method senderAddress
  use strict arg logicalName
  return self~resolve(logicalName,.SocketRole~SENDER)

::class RegisteredSocketAddressProvider public subclass SocketAddressProvider
::method init
  expose listeners senders
  listeners=.directory~new
  senders=.directory~new
::method register
  expose listeners senders
  use strict arg logicalName, address, role="BOTH"
  name=logicalName~string~strip
  r=role~string~strip~upper
  if name="" then raise syntax 88.900 array("logical socket address name must not be empty")
  if r="BOTH" | r=.SocketRole~LISTENER then listeners[name]=address
  if r="BOTH" | r=.SocketRole~SENDER then senders[name]=address
  if r<>"BOTH" & r<>.SocketRole~LISTENER & r<>.SocketRole~SENDER then raise syntax 88.900 array("invalid role")
  return self
::method resolve
  expose listeners senders
  use strict arg logicalName, role="SENDER"
  name=logicalName~string~strip
  r=role~string~strip~upper
  if r=.SocketRole~LISTENER then return listeners[name]
  if r=.SocketRole~SENDER then return senders[name]
  raise syntax 88.900 array("invalid socket role")

::class DelegatingSocketAddressProvider public subclass SocketAddressProvider
::method init
  expose resolver
  use strict arg resolver
  resolver=resolver
::method resolve
  expose resolver
  use strict arg logicalName, role="SENDER"
  return resolver~resolve(logicalName,role)

/* Queue transport terminology: an endpoint is a resolved role+address+native
 * handle. Provider connection/listener wrappers retain compatibility methods.
 */
::class SocketEndpoint public
::method init
  expose role address nativeHandle
  use strict arg role, address, nativeHandle
  role=role~string~strip~upper
  address=address
  nativeHandle=nativeHandle
::attribute role get
::attribute address get
::method raw
  expose nativeHandle
  return nativeHandle
::method capabilities
  expose address
  return address~family~capabilities

::class ProviderDatagramEndpoint public subclass SocketEndpoint
::method init
  expose transportSocket defaultPeerAddress defaultPeerPort localAddress localPort closed
  use strict arg transportSocketArg, address, role, defaultPeerAddress="", defaultPeerPort=0, localAddress="", localPort=0
  transportSocket=transportSocketArg
  defaultPeerAddress=defaultPeerAddress~string
  defaultPeerPort=defaultPeerPort+0
  localAddress=localAddress~string
  localPort=localPort+0
  closed=.false
  self~init:super(role,address,transportSocket)
::attribute localAddress get
::attribute localPort get
::attribute defaultPeerAddress get
::attribute defaultPeerPort get
::method descriptor
  expose transportSocket closed
  if closed then return -1
  if datatype(transportSocket,"W") then return transportSocket
  if transportSocket~hasMethod("DESCRIPTOR") then return transportSocket~descriptor
  return -1
::method sendTo
  expose transportSocket closed
  use strict arg bytes, host, port
  if closed then return -1
  peer.!family="AF_INET"
  peer.!addr=host
  peer.!port=port
  return SockSendTo(transportSocket,bytes,"","peer.!")
::method send
  expose defaultPeerAddress defaultPeerPort
  use strict arg bytes
  if defaultPeerAddress="" | defaultPeerPort<1 then raise syntax 88.900 array("UDP endpoint has no default peer")
  return self~sendTo(bytes,defaultPeerAddress,defaultPeerPort)
::method recvFrom
  expose transportSocket closed
  use strict arg maximumBytes=65535, timeoutSeconds=1
  if closed then return .nil
  reads.0=1; reads.1=transportSocket
  writes.0=0; excepts.0=0
  ready=SockSelect("reads.","writes.","excepts.",timeoutSeconds)
  if ready<0 then raise syntax 88.900 array("SockSelect failed errno" SockSock_Errno())
  if ready=0 then return .nil
  count=SockRecvFrom(transportSocket,"packet",maximumBytes,"","peer.!")
  if count<0 then raise syntax 88.900 array("SockRecvFrom failed errno" SockSock_Errno())
  return .array~of(packet,peer.!addr,peer.!port,count)
::method recv
  use strict arg maximumBytes=65535
  datagram=self~recvFrom(maximumBytes,1)
  if datagram=.nil then return .nil
  return datagram[1]
::method close
  expose transportSocket closed
  if closed then return 0
  resultCode=SockClose(transportSocket)
  closed=.true
  return resultCode
::method isOpen
  expose closed
  return \closed

::class ProviderSocketConnection public subclass SocketEndpoint
::method init
  expose transportSocket
  use strict arg transportSocketArg, address
  transportSocket=transportSocketArg
  self~init:super(.SocketRole~SENDER,address,transportSocket)
::method descriptor
  expose transportSocket
  if transportSocket~hasMethod("DESCRIPTOR") then return transportSocket~descriptor
  return -1
::method waitDrained
  expose transportSocket
  use strict arg timeoutMilliseconds=5000
  if transportSocket~hasMethod("WAITDRAINED") then return transportSocket~waitDrained(timeoutMilliseconds)
  return .false
::method send
  expose transportSocket
  use strict arg bytes
  return transportSocket~send(bytes)
::method sendAll
  expose transportSocket
  use strict arg bytes
  remaining=bytes; total=0
  do while length(remaining)>0
    n=transportSocket~send(remaining)
    if n=.nil | n<1 then return -1
    total+=n
    remaining=substr(remaining,n+1)
  end
  return total
::method recv
  expose transportSocket
  use strict arg maximumBytes
  return transportSocket~recv(maximumBytes)
::method close
  expose transportSocket
  return transportSocket~close
::method asStream
  return .SocketStreamAdapter~new(self)


/* Application-neutral stream view for consumers such as DebugSocketTransport.
 * It does not select, reopen or reinterpret a socket family. */
::class SocketStreamAdapter public
::method init
  expose endpoint address closed
  use strict arg endpointArg
  if endpointArg=.nil then raise syntax 88.900 array("SocketStreamAdapter requires an endpoint")
  if \endpointArg~hasMethod("SEND") | \endpointArg~hasMethod("RECV") then
    raise syntax 88.900 array("endpoint must provide SEND and RECV")
  endpoint=endpointArg
  address=endpointArg~address
  closed=.false
::attribute address get
::method socketAddress
  expose address
  return address
::method endpoint
  expose endpoint
  return endpoint
::method raw
  expose endpoint
  return endpoint~raw
::method write
  expose endpoint closed
  use strict arg bytes
  if closed then return .false
  if endpoint~hasMethod("SENDALL") then n=endpoint~sendAll(bytes)
  else n=endpoint~send(bytes)
  if n=.nil then return .false
  if datatype(n,"W") then return n=length(bytes)
  return n<>.false
::method read
  expose endpoint closed
  use strict arg maximumBytes
  if closed then return .nil
  return endpoint~recv(maximumBytes)
::method pump
  expose endpoint closed
  use strict arg timeoutMs=0
  if closed then return .false
  rawEndpoint=endpoint~raw
  if rawEndpoint<>.nil then do
    if rawEndpoint~hasMethod("PUMP") then return rawEndpoint~pump(timeoutMs)
    if rawEndpoint~hasMethod("POLL") then return rawEndpoint~poll(timeoutMs)
  end
  return .true
::method close
  expose endpoint closed
  if closed then return .true
  ignore=endpoint~close
  closed=.true
  return .true
::method isOpen
  expose closed
  return \closed

::class ProviderSocketListener public subclass SocketEndpoint
::method init
  expose transportListener
  use strict arg transportListenerArg, address
  transportListener=transportListenerArg
  self~init:super(.SocketRole~LISTENER,address,transportListener)
::method descriptor
  expose transportListener
  if transportListener~hasMethod("DESCRIPTOR") then return transportListener~descriptor
  return -1
::method waitReady
  expose transportListener
  use strict arg timeoutMilliseconds=0
  if transportListener~hasMethod("WAITREADY") then return transportListener~waitReady(timeoutMilliseconds)
  return .false
::method tryAccept
  expose transportListener address
  if \transportListener~hasMethod("TRYACCEPT") then return .nil
  peer=transportListener~tryAccept
  if peer=.nil then return .nil
  peerAddress=address
  if peer~hasMethod("ADDRESS") then peerAddress=peer~address
  return .ProviderSocketConnection~new(peer,peerAddress)
::method accept
  expose transportListener address
  peer=transportListener~accept
  if peer=.nil then return .nil
  peerAddress=address
  if peer~hasMethod("ADDRESS") then peerAddress=peer~address
  return .ProviderSocketConnection~new(peer,peerAddress)
::method close
  expose transportListener
  return transportListener~close

::class SocketTransportBinding public
::method listener abstract
::method sender abstract

/* UDP is an ordinary SocketProvider family.  The injected backend owns the
 * POSIX/COTS datagram implementation and, for explicitly multicast addresses,
 * the standard multicast membership interface. */
::class RexxUdpSocketBinding public subclass SocketTransportBinding
::method init
  expose backend
  use strict arg backend
  backend=backend
::method listener
  expose backend
  use strict arg address, backlog=32
  if address~transport<>.SocketTransportKind~UDP then raise syntax 88.900 array("UDP binding requires UDP address")
  return backend~listener(address,backlog)
::method sender
  expose backend
  use strict arg address
  if address~transport<>.SocketTransportKind~UDP then raise syntax 88.900 array("UDP binding requires UDP address")
  return backend~sender(address)
::method join
  expose backend
  use strict arg address, membershipRequest
  if address~transport<>.SocketTransportKind~UDP then raise syntax 88.900 array("UDP binding requires UDP address")
  if \address~multicast then raise syntax 88.900 array("UDP multicast join requires multicast address")
  if \backend~hasMethod("JOIN") then return .nil
  return backend~join(address,membershipRequest)
::method listenerOn
  expose backend
  use strict arg nativeMembership, address, backlog=32
  if address~transport<>.SocketTransportKind~UDP then raise syntax 88.900 array("UDP binding requires UDP address")
  if \backend~hasMethod("LISTENERON") then return .nil
  return backend~listenerOn(nativeMembership,address,backlog)

/* Generic XTP binding.  The current concrete adapter is XtpSocketProvider.cls,
 * merged from current XTP provider line (dev17).  libxtp remains the authority for routes, carriers,
 * replay state, wire filters, path health and multipath. */
::class RexxXtpSocketBinding public subclass SocketTransportBinding
::method init
  expose backend
  use strict arg backend
  backend=backend
::method listener
  expose backend
  use strict arg address, backlog=32
  if address~transport<>.SocketTransportKind~XTP then raise syntax 88.900 array("XTP binding requires XTP address")
  return backend~listener(address,backlog)
::method sender
  expose backend
  use strict arg address
  if address~transport<>.SocketTransportKind~XTP then raise syntax 88.900 array("XTP binding requires XTP address")
  return backend~sender(address)

::class RexxNormSocketBinding public subclass SocketTransportBinding
::method init
  expose backend
  use strict arg backend
  backend=backend
::method listener
  expose backend
  use strict arg address, backlog=32
  if address~transport<>.SocketTransportKind~NORM then raise syntax 88.900 array("NORM binding requires NORM address")
  return backend~listener(address,backlog)
::method sender
  expose backend
  use strict arg address
  if address~transport<>.SocketTransportKind~NORM then raise syntax 88.900 array("NORM binding requires NORM address")
  return backend~sender(address)

::method join
  expose backend
  use strict arg address, membershipRequest
  if address~transport<>.SocketTransportKind~NORM then raise syntax 88.900 array("NORM binding requires NORM address")
  return backend~join(address,membershipRequest)
::method listenerOn
  expose backend
  use strict arg nativeMembership, address, backlog=32
  if address~transport<>.SocketTransportKind~NORM then raise syntax 88.900 array("NORM binding requires NORM address")
  return backend~listenerOn(nativeMembership,address,backlog)

::class SocketProvider public
::method init
  expose addressProvider bindings defaultBacklog
  use strict arg addressProvider, defaultBacklog=32
  addressProvider=addressProvider
  defaultBacklog=defaultBacklog+0
  if defaultBacklog<1 then raise syntax 88.900 array("defaultBacklog must be positive")
  bindings=.directory~new
::attribute addressProvider get
::method registerBinding
  expose bindings
  use strict arg transport, binding
  bindings[transport~string~strip~upper]=binding
  return self
::method binding
  expose bindings
  use strict arg transport
  return bindings[transport~string~strip~upper]
::method family
  expose addressProvider
  use strict arg logicalName, role="SENDER"
  address=addressProvider~resolve(logicalName,role)
  if address=.nil then return .nil
  return address~family
::method capabilities
  use strict arg logicalName, role="SENDER"
  family=self~family(logicalName,role)
  if family=.nil then return .nil
  return family~capabilities
::method listener
  expose addressProvider defaultBacklog
  use strict arg logicalName, backlog=.nil
  address=addressProvider~listenerAddress(logicalName)
  if address=.nil then return .nil
  if backlog=.nil then backlog=defaultBacklog
  return self~listenerAt(address,backlog)
::method sender
  expose addressProvider
  use strict arg logicalName
  address=addressProvider~senderAddress(logicalName)
  if address=.nil then return .nil
  return self~senderAt(address)

/* Resolved-address entry points used by Socket Intention negotiation.  They
 * preserve SocketProvider as the sole native socket acquisition authority. */
::method listenerAt
  expose bindings defaultBacklog
  use strict arg address, backlog=.nil
  if address=.nil then return .nil
  binding=bindings[address~transport]
  if binding=.nil then return .nil
  if backlog=.nil then backlog=defaultBacklog
  return binding~listener(address,backlog)
::method senderAt
  expose bindings
  use strict arg address
  if address=.nil then return .nil
  binding=bindings[address~transport]
  if binding=.nil then return .nil
  return binding~sender(address)

/* Explicit multicast membership is independent of a listener/socket.
 * Bindings which do not implement JOIN fail closed by returning .nil. */
::method join
  expose addressProvider
  use strict arg logicalName, role="LISTENER", membershipRequest=.nil
  address=addressProvider~resolve(logicalName,role)
  if address=.nil then return .nil
  return self~joinAt(address,membershipRequest)

::method joinAt
  expose bindings
  use strict arg address, membershipRequest=.nil
  if address=.nil then return .nil
  if \address~multicast then return .nil
  binding=bindings[address~transport]
  if binding=.nil then return .nil
  if \binding~hasMethod("JOIN") then return .nil
  if membershipRequest=.nil then do
    interfaceName=""; sourceAddress=""
    if address~transport=.SocketTransportKind~NORM then do
      interfaceName=address~normInterface
      sourceAddress=address~normSource
    end
    membershipRequest=.SocketMulticastMembershipRequest~new(address,interfaceName,sourceAddress)
  end
  nativeMembership=binding~join(address,membershipRequest)
  if nativeMembership=.nil then return .nil
  return .SocketMulticastMembership~new(membershipRequest,nativeMembership)

::method listenerOn
  expose bindings defaultBacklog
  use strict arg membership, backlog=.nil
  if membership=.nil then return .nil
  if \membership~joined then return .nil
  address=membership~address
  binding=bindings[address~transport]
  if binding=.nil then return .nil
  if \binding~hasMethod("LISTENERON") then return .nil
  if backlog=.nil then backlog=defaultBacklog
  nativeListener=binding~listenerOn(membership~raw,address,backlog)
  if nativeListener=.nil then return .nil
  return .ProviderSocketListener~new(nativeListener,address)

/* Name used by Optimised Queue Transport. It is deliberately the same
 * provider behaviour, not a second selection authority.
 */
::method streamSender
  use strict arg logicalName
  endpoint=self~sender(logicalName)
  if endpoint=.nil then return .nil
  return endpoint~asStream

::method streamSenderAt
  use strict arg address
  endpoint=self~senderAt(address)
  if endpoint=.nil then return .nil
  return endpoint~asStream

::class SocketSelector public subclass SocketProvider
