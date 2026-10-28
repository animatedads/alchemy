/* ApiClientSocketProviderAdapter.cls
 * Optional API Client byte-carrier adapter over SocketProvider.
 * API Client continues to own HTTP/TLS. SocketProvider owns native acquisition.
 * The resolver supplies the exact current SocketAddress chosen by the lower
 * routing/Intention authority. This package does not choose XTP or any family.
 */
::class ApiClientSocketProviderAdapterBuild public
::constant VERSION "0.1-dev1"
::constant API "api.client.socket-provider/0.1"

::class ApiSocketProviderRouteResolver public
::method resolve abstract

::class ApiDelegatingSocketProviderRouteResolver public subclass ApiSocketProviderRouteResolver
::method init
  expose resolver
  use strict arg resolver
  resolver=resolver
::method resolve
  expose resolver
  use strict arg url, request=.nil, session=.nil
  return resolver~resolve(url,request,session)

::class ApiSocketProviderConnector public subclass ApiSocketConnector
::method init
  expose socketProvider routeResolver lastError
  use strict arg socketProviderArg, routeResolverArg
  if socketProviderArg=.nil then raise syntax 88.900 array("SocketProvider is required")
  if routeResolverArg=.nil then raise syntax 88.900 array("route resolver is required")
  socketProvider=socketProviderArg
  routeResolver=routeResolverArg
  lastError=""
::attribute lastError get
::method connect
  expose socketProvider routeResolver lastError
  use strict arg url, config, request=.nil, session=.nil
  lastError=""
  address=routeResolver~resolve(url,request,session)
  if address=.nil then do
    lastError="SOCKET_ROUTE_UNAVAILABLE"
    return .nil
  end
  if \address~hasMethod("TRANSPORT") then do
    lastError="SOCKET_ROUTE_INVALID"
    return .nil
  end
  stream=socketProvider~streamSenderAt(address)
  if stream=.nil then do
    lastError="SOCKET_PROVIDER_ACQUIRE_FAILED"
    return .nil
  end
  carrier=.ApiSocketProviderCarrier~new(stream)
  if \carrier~readinessCapable then do
    ignore=stream~close
    lastError="SOCKET_READINESS_UNAVAILABLE"
    return .nil
  end
  return carrier

::class ApiSocketProviderCarrier public
::method init
  expose stream raw closed lastError
  use strict arg selectedStream
  if selectedStream=.nil then raise syntax 88.900 array("selected stream is required")
  stream=selectedStream
  raw=.nil
  if stream~hasMethod("RAW") then raw=stream~raw
  closed=.false
  lastError=""
::attribute lastError get
::method socketAddress
  expose stream
  if stream~hasMethod("SOCKETADDRESS") then return stream~socketAddress
  return .nil
::method readinessCapable
  expose raw
  if raw=.nil then return .false
  return raw~hasMethod("SELECT") | raw~hasMethod("PUMP") | raw~hasMethod("POLL")
::method errno
  expose raw
  if raw<>.nil then if raw~hasMethod("ERRNO") then return raw~errno
  return 0
::method send
  expose stream closed lastError
  use strict arg data
  if closed then return -1
  ok=stream~write(data)
  if ok=.nil | ok=.false then do
    lastError="SOCKET_PROVIDER_WRITE_FAILED"
    return -1
  end
  if ok=.true then return length(data)
  if datatype(ok,"W") then return ok
  return length(data)
::method recv
  expose stream closed lastError
  use strict arg maximumBytes
  if closed then return ""
  data=stream~read(maximumBytes)
  if data=.nil then lastError="SOCKET_PROVIDER_READ_RETRY"
  return data
::method select
  expose stream raw closed lastError
  use strict arg reads, writes, excepts, timeoutSeconds
  if closed then return 0
  if raw=.nil then do; lastError="SOCKET_READINESS_UNAVAILABLE"; return .nil; end

  if raw~hasMethod("SELECT") then do
    rr=.array~new; ww=.array~new; ee=.array~new
    if reads<>.nil then if reads~items>0 then rr~append(raw)
    if writes<>.nil then if writes~items>0 then ww~append(raw)
    if excepts<>.nil then if excepts~items>0 then ee~append(raw)
    return raw~select(rr,ww,ee,timeoutSeconds)
  end

  timeoutMs=trunc(timeoutSeconds*1000)
  if timeoutMs<0 then timeoutMs=0
  if raw~hasMethod("PUMP") then rc=raw~pump(timeoutMs)
  else if raw~hasMethod("POLL") then rc=raw~poll(timeoutMs)
  else do; lastError="SOCKET_READINESS_UNAVAILABLE"; return .nil; end

  if rc=.nil | rc=.false then return 0
  if datatype(rc,"W") then do
    if rc<=0 then return 0
  end
  return 1
::method close
  expose stream closed
  if closed then return 0
  ignore=stream~close
  closed=.true
  return 0

::requires "ApiHttpTransport.cls"
::requires "SocketProvider.cls"
