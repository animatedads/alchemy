/* RxSock6SocketBinding.cls
 * ooRexx Socket Provider RxSock6 binding v0.1-dev1
 *
 * Requires:
 *   - estate SocketProvider.cls
 *   - rxsock6 0.1.1 socket6.cls
 *
 * TCP remains the semantic scheme.  TCP6 is only the provider binding key,
 * while the address family is INET6.
 */

::class RxSock6BindingBuild public
::constant VERSION "0.1-dev1"
::constant API "socket.binding.rxsock6/0.1"
::constant TRANSPORT "TCP6"
::constant SCHEME "tcp"
::constant ADDRESS_FAMILY "INET6"


/* Preserve the actual Inet6Address ooRexx object. */
::class Inet6SocketAddress public

::method init
  expose logicalName nativeAddress metadata family
  use strict arg nativeAddress, logicalName="", metadata=.nil
  if nativeAddress=.nil then raise syntax 88.900 array("Inet6SocketAddress requires Inet6Address")
  if \nativeAddress~isInstanceOf(.Inet6Address) then
    raise syntax 88.900 array("nativeAddress must be Inet6Address")

  logicalName=logicalName~string~strip
  if metadata=.nil then metadata=.directory~new
  selfMetadata=metadata
  metadata=selfMetadata
  family=.Tcp6SocketFamily~new
  selfNative=nativeAddress
  nativeAddress=selfNative

::attribute logicalName get
::attribute nativeAddress get
::attribute metadata get

::method transport
  return .RxSock6BindingBuild~TRANSPORT

::method scheme
  return .RxSock6BindingBuild~SCHEME

::method addressFamily
  return .RxSock6BindingBuild~ADDRESS_FAMILY

::method multicast
  return .false

::method securityProfile
  return ""

::method host
  expose nativeAddress
  return nativeAddress~address

::method port
  expose nativeAddress
  return nativeAddress~port

::method scopeId
  expose nativeAddress
  return nativeAddress~scopeId

::method flowInfo
  expose nativeAddress
  return nativeAddress~flowInfo

::method family
  expose family
  return family

::method canonical
  expose logicalName nativeAddress
  return "transport=TCP6;scheme=tcp;family=INET6;name="||logicalName||";address=["||nativeAddress~address||"]:"||nativeAddress~port


::class Tcp6SocketFamily public subclass SocketFamily

::method init
  caps=.SocketCapabilities~new("tcp","INET6",.true,.true,.true,.false,.false)
  self~init:super("TCP6","tcp","INET6",caps)


::class RxSock6SocketBinding public subclass SocketTransportBinding

::method listener
  use strict arg address, backlog=32
  ignore=self~validateAddress(address)

  socket=.Socket6~new("SOCK_STREAM","IPPROTO_TCP")
  if socket~string<0 then return .nil

  rc=socket~setV6Only(1)
  if rc<>0 then do
    socket~close
    return .nil
  end

  rc=socket~bind(address~nativeAddress)
  if rc<>0 then do
    socket~close
    return .nil
  end

  rc=socket~listen(backlog)
  if rc<>0 then do
    socket~close
    return .nil
  end

  return .ProviderSocketListener~new(socket,address)


::method sender
  use strict arg address
  ignore=self~validateAddress(address)

  socket=.Socket6~new("SOCK_STREAM","IPPROTO_TCP")
  if socket~string<0 then return .nil

  rc=socket~connect(address~nativeAddress)
  if rc<>0 then do
    socket~close
    return .nil
  end

  return .ProviderSocketConnection~new(socket,address)


::method validateAddress private
  use strict arg address
  if address=.nil then raise syntax 88.900 array("TCP6 binding requires address")
  if address~transport<>.RxSock6BindingBuild~TRANSPORT then
    raise syntax 88.900 array("RxSock6SocketBinding requires TCP6 address")
  if address~addressFamily<>.RxSock6BindingBuild~ADDRESS_FAMILY then
    raise syntax 88.900 array("RxSock6SocketBinding requires INET6 family")
  if \address~nativeAddress~isInstanceOf(.Inet6Address) then
    raise syntax 88.900 array("TCP6 address must retain Inet6Address")
  return .true


::class RxSock6AddressFactory public

::method tcp class
  use strict arg host, port, logicalName="", scopeId=0, flowInfo=0, metadata=.nil
  native=.Inet6Address~new(host,port,scopeId,flowInfo)
  return .Inet6SocketAddress~new(native,logicalName,metadata)

::method fromNative class
  use strict arg nativeAddress, logicalName="", metadata=.nil
  return .Inet6SocketAddress~new(nativeAddress,logicalName,metadata)

::method resolve class
  use strict arg host, port, logicalName="", metadata=.nil
  results=.Socket6~resolve(host,port)
  if results=.nil then return .array~new
  out=.array~new
  do native over results
    out~append(.Inet6SocketAddress~new(native,logicalName,metadata))
  end
  return out


::requires "SocketProvider.cls"
::requires "socket6.cls"
