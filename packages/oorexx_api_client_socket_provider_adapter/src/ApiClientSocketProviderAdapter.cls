/* ApiClientSocketProviderAdapter.cls
 * Optional API Client byte-carrier adapter over SocketProvider.
 * API Client continues to own HTTP/TLS. SocketProvider owns native acquisition.
 * The resolver supplies the exact current SocketAddress chosen by the lower
 * routing/Intention authority. This package does not choose XTP or any family.
 */
::class ApiClientSocketProviderAdapterBuild public
::constant VERSION "0.1-dev3"
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

/* Optional deployment-owned admission of the exact selected route.  This is
 * deliberately separate from SocketNegotiator: generic socket selection owns
 * capability truth, while deployment policy may require additional attested
 * evidence on the selected SocketAddress. */
::class ApiSocketRouteAdmissionPolicy public
::method admit abstract
::method denialCode
  return "SOCKET_ROUTE_POLICY_DENIED"

/* Generic exact-metadata policy.  It does not know what XTP, LDAP, a private
 * CA or any other evidence means; deployment supplies the required keys and
 * values, and the lower route authority supplies the address metadata. */
::class ApiSocketRequiredMetadataPolicy public subclass ApiSocketRouteAdmissionPolicy
::method init
  expose required lastAddress lastUrl lastRequest lastSession lastSelection missingKey mismatchedKey
  use strict arg requirements
  if requirements=.nil then raise syntax 88.900 array("route metadata requirements are required")
  required=requirements
  lastAddress=.nil; lastUrl=.nil; lastRequest=.nil; lastSession=.nil; lastSelection=.nil
  missingKey=""; mismatchedKey=""
::attribute lastAddress get
::attribute lastUrl get
::attribute lastRequest get
::attribute lastSession get
::attribute lastSelection get
::attribute missingKey get
::attribute mismatchedKey get
::method denialCode
  expose missingKey mismatchedKey
  if missingKey<>"" then return "SOCKET_ROUTE_METADATA_MISSING"
  if mismatchedKey<>"" then return "SOCKET_ROUTE_METADATA_MISMATCH"
  return "SOCKET_ROUTE_METADATA_REQUIRED"
::method admit
  expose required lastAddress lastUrl lastRequest lastSession lastSelection missingKey mismatchedKey
  use strict arg address, url, request=.nil, session=.nil, selection=.nil
  lastAddress=address; lastUrl=url; lastRequest=request; lastSession=session; lastSelection=selection
  missingKey=""; mismatchedKey=""
  if address=.nil then do; missingKey="ADDRESS"; return .false; end
  if \address~hasMethod("METADATA") then do; missingKey="METADATA"; return .false; end
  metadata=address~metadata
  if metadata=.nil then do; missingKey="METADATA"; return .false; end
  do key over required
    if \metadata~hasIndex(key) then do
      missingKey=key~string
      return .false
    end
    if metadata[key]<>required[key] then do
      mismatchedKey=key~string
      return .false
    end
  end
  return .true

::class ApiSocketIntentionRouteResolver public subclass ApiSocketProviderRouteResolver
::method init
  expose intentionPort logicalNameResolver allowedSchemes admissionPolicy lastSelection lastNegotiationRequest lastError generation
  use strict arg intentionPortArg, logicalNameResolverArg=.nil, allowedSchemesArg=.nil, admissionPolicyArg=.nil
  if intentionPortArg=.nil then raise syntax 88.900 array("Socket Intention port is required")
  intentionPort=intentionPortArg
  logicalNameResolver=logicalNameResolverArg
  if allowedSchemesArg=.nil then allowedSchemes=.array~of(.SocketScheme~XTP,.SocketScheme~TCP)
  else allowedSchemes=allowedSchemesArg
  admissionPolicy=admissionPolicyArg
  lastSelection=.nil
  lastNegotiationRequest=.nil
  lastError=""
  generation=0
::attribute lastSelection get
::attribute lastNegotiationRequest get
::attribute lastError get
::attribute generation get
::method resolve
  expose intentionPort logicalNameResolver allowedSchemes admissionPolicy lastSelection lastNegotiationRequest lastError generation
  use strict arg url, request=.nil, session=.nil
  lastError=""
  logicalName=""

  if request<>.nil then do
    md=request~metadata
    if md<>.nil then do
      x=md["socketLogicalName"]
      if x<>.nil then logicalName=x~string~strip
    end
  end

  if logicalName="" & logicalNameResolver<>.nil then
    logicalName=logicalNameResolver~resolve(url,request,session)

  if logicalName="" then logicalName=url~host
  logicalName=logicalName~string~strip
  if logicalName="" then do
    lastError="SOCKET_LOGICAL_NAME_UNAVAILABLE"
    return .nil
  end

  metadata=.directory~new
  metadata["apiUrl"]=url
  metadata["apiRequest"]=request
  metadata["apiSession"]=session
  if request<>.nil then metadata["apiRouteRequirement"]=request~routeRequirement

  negotiation=.SocketNegotiationRequest~new(logicalName,.SocketRole~SENDER,.true,.false,.false,.false,allowedSchemes,url~host,metadata)
  lastNegotiationRequest=negotiation
  generation+=1

  context=.directory~new
  context["apiUrl"]=url
  context["apiRequest"]=request
  context["apiSession"]=session
  if request<>.nil then context["apiRouteRequirement"]=request~routeRequirement

  selection=intentionPort~negotiate(negotiation,context)
  lastSelection=selection
  if selection=.nil then do
    lastError="SOCKET_NEGOTIATION_NO_RESULT"
    return .nil
  end
  if \selection~selected then do
    lastError="SOCKET_NEGOTIATION_" || selection~status
    return .nil
  end

  address=selection~address
  if admissionPolicy<>.nil then do
    if \admissionPolicy~admit(address,url,request,session,selection) then do
      lastError=admissionPolicy~denialCode
      return .nil
    end
  end
  return address

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
::requires "SocketIntentions.cls"
