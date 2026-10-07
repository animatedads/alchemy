/* QuicSocketProvider.cls
 * ooRexx QUIC Socket Provider v0.1-dev2
 *
 * Real QUIC socket family behind the common SocketProvider boundary.
 * Native transport is OpenSSL QUIC; address objects contain references to
 * security profiles, never certificate/private-key material.
 */

::class QuicSocketProviderBuild public
::constant VERSION "0.1-dev2"
::constant API "quic.socket.provider/0.1"
::constant TRANSPORT "QUIC"
::constant SCHEME "quic"
::constant ADDRESS_FAMILY "QUIC_INET"

::class QuicSecurityProfile public
::method init
  expose name serverName alpn caFile certFile keyFile verifyPeer
  use strict arg name, serverName="", alpn="oorexx-quic/0.1", caFile="", certFile="", keyFile="", verifyPeer=.true
  name=name~string~strip
  serverName=serverName~string~strip
  alpn=alpn~string
  caFile=caFile~string
  certFile=certFile~string
  keyFile=keyFile~string
  verifyPeer=verifyPeer
  if name="" then raise syntax 88.900 array("QUIC security profile requires a name")
  if alpn="" | length(alpn)>255 then raise syntax 88.900 array("QUIC ALPN must contain 1..255 bytes")
::attribute name get
::attribute serverName get
::attribute alpn get
::attribute caFile get
::attribute certFile get
::attribute keyFile get
::attribute verifyPeer get

::class QuicSecurityProfileRegistry public
::method init
  expose profiles
  profiles=.directory~new
::method register
  expose profiles
  use strict arg profile
  profiles[profile~name]=profile
  return self
::method resolve
  expose profiles
  use strict arg name
  return profiles[name~string~strip]

::class QuicSocketAddress public
::method init
  expose host port securityProfile logicalName metadata
  use strict arg host, port, securityProfile, logicalName="", metadata=.nil
  host=host~string~strip
  port=port+0
  securityProfile=securityProfile~string~strip
  logicalName=logicalName~string~strip
  if metadata=.nil then metadata=.directory~new
  else metadata=metadata
  if host="" then raise syntax 88.900 array("QUIC address requires host")
  if port<1 | port>65535 then raise syntax 88.900 array("QUIC address requires valid port")
  if securityProfile="" then raise syntax 88.900 array("QUIC address requires securityProfile")
::method transport
  return .QuicSocketProviderBuild~TRANSPORT
::method scheme
  return .QuicSocketProviderBuild~SCHEME
::method addressFamily
  return .QuicSocketProviderBuild~ADDRESS_FAMILY
::attribute host get
::attribute port get
::attribute securityProfile get
::attribute logicalName get
::attribute metadata get
::method multicast
  return .false
::method family
  return .SocketFamily~new(.QuicSocketProviderBuild~TRANSPORT,.QuicSocketProviderBuild~SCHEME,.QuicSocketProviderBuild~ADDRESS_FAMILY,-
      .SocketCapabilities~new(.QuicSocketProviderBuild~SCHEME,.QuicSocketProviderBuild~ADDRESS_FAMILY,.true,.true,.true,.true,.false))
::method canonical
  expose host port securityProfile logicalName
  return "scheme=quic;family=QUIC_INET;transport=QUIC;name="||logicalName||";address="||host||":"||port||";multicast=0;securityProfile="||securityProfile

::class QuicSocketBackend public
::method init
  expose profiles
  use strict arg securityProfiles
  profiles=securityProfiles
::method sender
  expose profiles
  use strict arg address
  profile=profiles~resolve(address~securityProfile)
  if profile=.nil then raise syntax 88.900 array("unknown QUIC security profile: "||address~securityProfile)
  serverName=profile~serverName
  if serverName="" then serverName=address~host
  verify=0
  if profile~verifyPeer then verify=1
  handle=quicNativeClientOpen(address~host,address~port,serverName,profile~alpn,profile~caFile,verify,1)
  return .QuicSocket~new(handle,address)
::method listener
  expose profiles
  use strict arg address, backlog=32
  profile=profiles~resolve(address~securityProfile)
  if profile=.nil then raise syntax 88.900 array("unknown QUIC security profile: "||address~securityProfile)
  if profile~certFile="" | profile~keyFile="" then raise syntax 88.900 array("QUIC listener profile requires certificate and key")
  handle=quicNativeListenerOpen(address~host,address~port,profile~certFile,profile~keyFile,profile~alpn,backlog)
  return .QuicSocketListener~new(handle,address,profile)

::class RexxQuicSocketBinding public subclass SocketTransportBinding
::method init
  expose backend
  use strict arg backend
  backend=backend
::method sender
  expose backend
  use strict arg address
  if address~transport<>.QuicSocketProviderBuild~TRANSPORT then raise syntax 88.900 array("QUIC binding requires QUIC address")
  return backend~sender(address)
::method listener
  expose backend
  use strict arg address, backlog=32
  if address~transport<>.QuicSocketProviderBuild~TRANSPORT then raise syntax 88.900 array("QUIC binding requires QUIC address")
  return backend~listener(address,backlog)

/* Dynamic negotiation projection for SocketProvider dev13+.  QUIC remains a
 * sibling provider: this class only publishes current capability evidence; it
 * does not add QUIC-specific fields to the common negotiation request. */
::class QuicSocketOfferProvider public subclass SocketOfferProvider
::method init
  expose delegate
  delegate=.RegisteredSocketOfferProvider~new
::method register
  expose delegate
  use strict arg logicalName, offerId, address, priority=100, localityClass="REMOTE", available=.true, evidence="QUIC/TLS 1.3 stream available", providerId="quic-dev2"
  if address~transport<>.QuicSocketProviderBuild~TRANSPORT then raise syntax 88.900 array("QuicSocketOfferProvider requires QUIC address")
  caps=.SocketCapabilities~new(.QuicSocketProviderBuild~SCHEME,.QuicSocketProviderBuild~ADDRESS_FAMILY,.true,.true,.true,.true,.false)
  offer=.SocketNegotiationOffer~new(offerId,address,priority,localityClass,available,evidence,providerId,caps)
  delegate~register(logicalName,offer)
  return self
::method offers
  expose delegate
  use strict arg request, context=.nil
  return delegate~offers(request,context)

::class QuicSocket public
::method init
  expose handle address closed
  use strict arg nativeHandle, socketAddress
  handle=nativeHandle
  address=socketAddress
  closed=.false
::attribute address get
::method socketAddress
  expose address
  return address
::method raw
  return self
::method nativeHandle
  expose handle
  return handle
::method descriptor
  expose handle closed
  if closed then return -1
  return quicNativeDescriptor(handle)
::method waitReady
  expose handle closed
  use strict arg timeoutMilliseconds=0
  if closed then return .false
  return quicNativePump(handle,timeoutMilliseconds)<>0
::method send
  expose handle closed
  use strict arg bytes
  if closed then return -1
  return quicNativeSend(handle,bytes)
::method sendAll
  expose handle closed
  use strict arg bytes
  if closed then return -1
  remaining=bytes; total=0
  do while length(remaining)>0
    n=quicNativeSend(handle,remaining)
    if n<1 then return -1
    total+=n
    remaining=substr(remaining,n+1)
  end
  return total
::method recv
  expose handle closed
  use strict arg maximumBytes
  if closed then return .nil
  bytes=quicNativeRecv(handle,maximumBytes)
  if bytes=.nil | length(bytes)=0 then return .nil
  return bytes
::method pump
  expose handle closed
  use strict arg timeoutMs=0
  if closed then return .false
  return quicNativePump(handle,timeoutMs)<>0
::method waitDrained
  expose handle closed
  use strict arg timeoutMilliseconds=0
  if closed then return .false
  return quicNativePump(handle,timeoutMilliseconds)<>0
::method close
  expose handle closed
  if closed then return 0
  rc=quicNativeClose(handle)
  if rc=0 then closed=.true
  return rc
::method asStream
  return .SocketStreamAdapter~new(self)

::class QuicSocketListener public
::method init
  expose handle address profile closed
  use strict arg nativeHandle, listenerAddress, securityProfile
  handle=nativeHandle
  address=listenerAddress
  profile=securityProfile
  closed=.false
::attribute address get
::method raw
  return self
::method nativeHandle
  expose handle
  return handle
::method descriptor
  expose handle closed
  if closed then return -1
  return quicNativeListenerDescriptor(handle)
::method waitReady
  expose handle closed
  use strict arg timeoutMilliseconds=0
  if closed then return .false
  return quicNativeListenerWaitReady(handle,timeoutMilliseconds)<>0
::method tryAccept
  expose handle address closed
  if closed then return .nil
  ch=quicNativeTryAccept(handle)
  if ch=0 then return .nil
  return self~socketFor(ch)
::method socketFor private
  expose address
  use strict arg ch
  peerHost=quicNativePeerHost(ch)
  peerPort=quicNativePeerPort(ch)
  if peerHost="" then peerHost=address~host
  if peerPort<1 then peerPort=address~port
  peerMeta=.directory~new
  peerMeta['LISTENER_ADDRESS']=address
  peerAddress=.QuicSocketAddress~new(peerHost,peerPort,address~securityProfile,address~logicalName,peerMeta)
  return .QuicSocket~new(ch,peerAddress)
::method accept
  expose handle closed
  if closed then return .nil
  ch=quicNativeAccept(handle)
  if ch=0 then return .nil
  return self~socketFor(ch)
::method close
  expose handle closed
  if closed then return 0
  rc=quicNativeListenerClose(handle)
  if rc=0 then closed=.true
  return rc

::routine quicNativeClientOpen external "library oorexx_quic_native quicNativeClientOpen"
::routine quicNativeListenerOpen external "library oorexx_quic_native quicNativeListenerOpen"
::routine quicNativeAccept external "library oorexx_quic_native quicNativeAccept"
::routine quicNativeTryAccept external "library oorexx_quic_native quicNativeTryAccept"
::routine quicNativeDescriptor external "library oorexx_quic_native quicNativeDescriptor"
::routine quicNativePump external "library oorexx_quic_native quicNativePump"
::routine quicNativeListenerDescriptor external "library oorexx_quic_native quicNativeListenerDescriptor"
::routine quicNativeListenerWaitReady external "library oorexx_quic_native quicNativeListenerWaitReady"
::routine quicNativeSend external "library oorexx_quic_native quicNativeSend"
::routine quicNativeRecv external "library oorexx_quic_native quicNativeRecv"
::routine quicNativeClose external "library oorexx_quic_native quicNativeClose"
::routine quicNativeListenerClose external "library oorexx_quic_native quicNativeListenerClose"
::routine quicNativePeerHost external "library oorexx_quic_native quicNativePeerHost"
::routine quicNativePeerPort external "library oorexx_quic_native quicNativePeerPort"

::requires "SocketProvider.cls"
::requires "SocketIntentions.cls"
