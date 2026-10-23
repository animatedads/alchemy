/* BoshSocketProviderAdapter.cls
 * Optional adapter: core BOSH remains SocketProvider-independent.
 */
::class BoshSocketFamily public subclass SocketFamily
::method init
  caps=.SocketCapabilities~new("bosh","HTTP_STREAM",.true,.false,.true,.false,.false)
  self~init:super("BOSH","bosh","HTTP_STREAM",caps)

::class BoshSocketAddress public
::method init
  expose endpoint logicalName family
  use strict arg endpoint, logicalName=""
  if endpoint=.nil then raise syntax 88.900 array("BOSH endpoint required")
  logicalName=logicalName~string~strip
  family=.BoshSocketFamily~new
::attribute endpoint get
::attribute logicalName get
::method transport; return "BOSH"
::method scheme; return "bosh"
::method addressFamily; return "HTTP_STREAM"
::method multicast; return .false
::method securityProfile; return ""
::method family; expose family; return family
::method canonical
  expose logicalName endpoint
  return "transport=BOSH;name="||logicalName||";uri="||endpoint~uri

::class BoshSocketBinding public subclass SocketTransportBinding
::method init
  expose provider
  use strict arg boshStreamProvider
  provider=boshStreamProvider
::method sender
  expose provider
  use strict arg address
  if address~transport<>"BOSH" then raise syntax 88.900 array("BOSH binding requires BOSH address")
  stream=provider~connect(address~endpoint)
  if stream=.nil then return .nil
  return .ProviderSocketConnection~new(stream,address)
::method listener
  use strict arg address, backlog=32
  return .nil

::requires "SocketProvider.cls"
::requires "BoshTransport.cls"
