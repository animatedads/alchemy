/* Storage Fabric optional advanced networking boundary.
 * Ordinary SocketProvider / TCP / UNIX / QueueRexx remain the default.
 * Named-service and multicast features are negotiated, never dependencies.
 * Storage identity, authenticated peer ACLs, digest verification, and durable
 * replication remain with their existing owners.
 */
::class StorageNetworkServicesBuild public
::constant API "storage.fabric.network/0.1"
::constant VERSION "0.2-service-admission"

/* An estate-authorised route binding, not a network address.  The actual
 * Service Descriptor Registry is the authority for service class and peer. */
::class StorageNamedServiceRoutes public
::method init
  expose names peers
  names=.directory~new; peers=.directory~new
::method bind
  expose names peers
  use strict arg nodeId,operation,serviceName,logicalRoutePeer
  if nodeId~string~strip="" | operation~string~strip="" | serviceName~string~strip="" | logicalRoutePeer~string~strip="" then raise syntax 88.900 array("named route requires node/operation/service/peer")
  k=nodeId~string||"1F"x||operation~string~upper
  names[k]=serviceName~string
  peers[k]=logicalRoutePeer~string
  return self
::method service
  expose names
  use strict arg nodeId,operation
  return names[nodeId~string||"1F"x||operation~string~upper]
::method routePeer
  expose peers
  use strict arg nodeId,operation
  return peers[nodeId~string||"1F"x||operation~string~upper]

/* Return the same socket shape the transport supplied; only the optional
 * governor can send when capacity limits are present.  It is responsible for
 * the real per-context rate and aggregate-bandwidth limits, not this facade. */
::class StorageGovernedSender public
::method init
  expose socket governor ticket closed
  use strict arg transportSocket,capacityGovernor,admissionTicket
  socket=transportSocket; governor=capacityGovernor; ticket=admissionTicket; closed=.false
::method send
  expose socket governor ticket closed
  use strict arg bytes
  if closed then return -1
  return governor~send(ticket,socket,bytes)
::method close
  expose socket governor ticket closed
  if closed then return 0
  closed=.true
  closeRc=socket~close
  governor~release(ticket)
  return closeRc

/* Optional named XTP service selection, selected BEFORE FIRST and context
 * establishment through XtpNamedServiceManager.  No direct libxtp calls.
 * Disabled/unregistered/wrong-peer names NEVER downgrade to a raw socket. */
::class StorageServiceNetworkPort public
::method init
  expose ordinary registry named routes planner state governor
  use strict arg ordinaryPort,registryArg=.nil,namedManager=.nil,routeMap=.nil,plannerObject=.nil,operatingState="normal",capacityGovernor=.nil
  if ordinaryPort==.nil then raise syntax 88.900 array("ordinary SocketProvider port required")
  ordinary=ordinaryPort; registry=registryArg; named=namedManager
  if routeMap==.nil then routes=.StorageNamedServiceRoutes~new; else routes=routeMap
  planner=plannerObject; state=operatingState; governor=capacityGovernor
::attribute routes get
::attribute state
::method sender
  expose ordinary registry named routes planner state governor
  use strict arg peerNodeId,operation="READ"
  service=routes~service(peerNodeId,operation)
  /* No advanced service advertised for this peer/operation: existing socket
   * or QueueRexx behaviour, including TCP/IP, remains unchanged. */
  if service==.nil then return ordinary~sender(peerNodeId)
  if registry==.nil | named==.nil | planner==.nil then return .nil
  d=registry~resolve(service,.false)
  if d==.nil then return .nil
  if \d~enabled then return .nil
  if d~routePeer<>routes~routePeer(peerNodeId,operation) then return .nil
  decision=planner~decide(d~operationalClass,state)
  if decision==.nil then return .nil
  if decision["TRANSMIT"]<>"1" | decision["TRANSFORM"]="1" then return .nil
  /* A policy with throughput/parallel limits may not be passed without an
   * actual governor.  XTP's built-in operational wrapper can gate/priority,
   * but its current ooRexx sender does not implement the bandwidth cap. */
  constrained=.false
  do k over .array~of("PER_CONTEXT_CAP_PERCENT","MAX_PARALLEL_CONTEXTS","AGGREGATE_CAP_PERCENT")
    n=decision[k]
    if n<>.nil then if datatype(n,"W") then if n>0 then constrained=.true
  end
  if constrained then if governor==.nil then return .nil
  s=named~sender(service)
  if s==.nil then return .nil
  ticket=.nil
  if constrained then do
    ticket=governor~acquire(d~operationalClass,decision,peerNodeId)
    if ticket==.nil then do
      s~close
      return .nil
    end
  end
  if ticket<>.nil then return .StorageGovernedSender~new(s,governor,ticket)
  return s
::method listener
  expose ordinary named
  use strict arg logicalPeer=.nil
  /* No advanced peer requested: ordinary TCP/Unix/QueueRexx remains supported.
   * An explicit named peer request must NOT silently become an ordinary
   * listener when its manager is missing, even during startup/recovery. */
  if logicalPeer==.nil then return ordinary~listener
  if logicalPeer~string~strip="" then return .nil
  if named==.nil then return .nil
  /* XTP manager computes the admitted service set from registry and planner;
   * the caller cannot assign its operational class. */
  return named~listener(logicalPeer)
::method mode
  expose routes registry named planner
  use strict arg peerNodeId,operation="READ"
  if routes~service(peerNodeId,operation)==.nil then return "ORDINARY_SOCKET"
  if registry==.nil | named==.nil | planner==.nil then return "NAMED_NOT_READY"
  return "NAMED_SERVICE_CONFIGURED"

/* An authenticated transport owns peer identity.  Selected XTP service is
 * separately checked against operation before dispatch; a service name alone
 * is never sufficient authorisation to read a file. */
::class StorageNamedInboundGuard public
::method init
  expose peerService operationServices
  use strict arg storagePeerService
  peerService=storagePeerService; operationServices=.directory~new
::method bind
  expose operationServices
  use strict arg operation,canonicalServiceName
  operationServices[operation~string~upper]=canonicalServiceName~string
  return self
::method handle
  expose peerService operationServices
  use strict arg authenticatedNodeId,request,acceptedSocket=.nil
  if request==.nil then return self~reject("REQUEST_INVALID")
  if \request~isA(.Directory) then return self~reject("REQUEST_INVALID")
  op=request["operation"]
  if op==.nil then return self~reject("OPERATION_REQUIRED")
  required=operationServices[op~string~upper]
  /* A bound operation MUST arrive through an admitted named-service context.
   * Unbound operations continue over ordinary authenticated sockets.
   * No raw-socket fallback after named-service admission failure. */
  if required<>.nil then do
    if acceptedSocket==.nil then return self~reject("NAMED_CONTEXT_REQUIRED")
    if \acceptedSocket~hasMethod("SERVICENAME") then return self~reject("NAMED_CONTEXT_REQUIRED")
    if \acceptedSocket~hasMethod("AUTHENTICATEDPEERID") then return self~reject("PEER_CONTEXT_REQUIRED")
    if \acceptedSocket~hasMethod("SERVICEADMITTED") then return self~reject("SERVICE_ADMISSION_REQUIRED")
    if \acceptedSocket~serviceAdmitted then return self~reject("SERVICE_NOT_ADMITTED")
    if acceptedSocket~serviceName<>required then return self~reject("SERVICE_OPERATION_MISMATCH")
    if acceptedSocket~authenticatedPeerId~string~strip="" then return self~reject("AUTHENTICATED_PEER_REQUIRED")
    if authenticatedNodeId~string<>acceptedSocket~authenticatedPeerId~string then return self~reject("PEER_IDENTITY_MISMATCH")
  end
  else if acceptedSocket<>.nil then do
    if acceptedSocket~hasMethod("SERVICENAME") then return self~reject("SERVICE_OPERATION_MISMATCH")
  end
  if authenticatedNodeId~string~strip="" then return self~reject("AUTHENTICATED_PEER_REQUIRED")
  return peerService~handleFrom(authenticatedNodeId,request)
::method reject
  use strict arg code
  d=.directory~new
  d["status"]="ERROR"; d["code"]=code
  return d

/* Uses the ordinary selector's advertised capabilities, not guessed socket
 * types.  Native XTP providers may instead inject a sender obtained from
 * their XTP multicast API; both satisfy the same send contract. */
::class StorageMulticastSelection public
::method sender
  use strict arg socketSelector,logicalGroup
  if socketSelector==.nil then return .nil
  caps=socketSelector~capabilities(logicalGroup,"SENDER")
  if caps==.nil then return .nil
  if \caps~multicast then return .nil
  s=socketSelector~sender(logicalGroup)
  if s==.nil then return .nil
  if \s~hasMethod("SEND") then return .nil
  return s
::method receiver
  use strict arg socketSelector,logicalGroup
  if socketSelector==.nil then return .nil
  caps=socketSelector~capabilities(logicalGroup,"LISTENER")
  if caps==.nil then return .nil
  if \caps~multicast then return .nil
  membership=socketSelector~join(logicalGroup)
  if membership==.nil then return .nil
  listener=socketSelector~listenerOn(membership)
  if listener==.nil then do
    membership~leave
    return .nil
  end
  return listener

/* Optional multicast discovery.  The sender is a negotiated native socket
 * (XTP, UDP/IP, NORM, etc.), not a second networking implementation.
 * Only digests and bounded opaque challenge strings may be published.
 * Results are UNTRUSTED HINTS; HAVE/STAT over authenticated unicast and
 * complete SHA-256 validation remain mandatory before replica admission. */
::class StorageMulticastDiscovery public
::method init
  expose sender
  use strict arg multicastSender=.nil
  sender=multicastSender
::method available
  expose sender
  return sender<>.nil
::method probe
  expose sender
  use strict arg sha256Digest,challenge
  if sender==.nil then return .false
  digest=self~digest(sha256Digest)
  if digest="" then return .false
  c=challenge~string
  /* Text frames carry exactly one printable, bounded challenge token. */
  if length(c)<1 | length(c)>128 then return .false
  if verify(c,"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_.:=")<>0 then return .false
  frame="STORAGE-DISCOVERY/1 SEARCH "||digest||" "||c
  sentBytes=sender~send(frame)
  if sentBytes==.nil then return .false
  if \datatype(sentBytes,"N") then return .false
  /* A short write is not a successfully emitted discovery frame. */
  return sentBytes=length(frame)
::method advertise
  expose sender
  use strict arg sha256Digest,challenge
  if sender==.nil then return .false
  digest=self~digest(sha256Digest)
  if digest="" then return .false
  c=challenge~string
  /* Text frames carry exactly one printable, bounded challenge token. */
  if length(c)<1 | length(c)>128 then return .false
  if verify(c,"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_.:=")<>0 then return .false
  frame="STORAGE-DISCOVERY/1 OFFER "||digest||" "||c
  sentBytes=sender~send(frame)
  if sentBytes==.nil then return .false
  if \datatype(sentBytes,"N") then return .false
  /* A short write is not a successfully emitted discovery frame. */
  return sentBytes=length(frame)
::method parseHint
  use strict arg receivedBytes
  p=.directory~new; p["status"]="INVALID"
  parse var receivedBytes schema kind digest challenge
  if schema<>"STORAGE-DISCOVERY/1" then return p
  if kind="SEARCH" then nop
  else if kind="OFFER" then nop
  else return p
  if self~digest(digest)="" then return p
  if length(challenge)<1 | length(challenge)>128 then return p
  if verify(challenge,"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_.:=")<>0 then return p
  p["status"]="UNTRUSTED_HINT"
  p["kind"]=kind; p["digest"]=digest; p["challenge"]=challenge
  return p
::method digest
  use strict arg value
  d=value~string~strip~lower
  if left(d,7)="sha256:" then d=substr(d,8)
  if length(d)<>64 then return ""
  do i=1 to length(d)
    if pos(substr(d,i,1),"0123456789abcdef")=0 then return ""
  end
  return d

/* An immutable offered range is scoped to a pinned digest.  This is a
 * placement/scheduling proposal, not a replica or transfer authorisation. */
::class StorageSourceRangeOffer public
::attribute digest get
::attribute offset get
::attribute byteCount get
::attribute sourceNode get
::method init
  expose digest offset byteCount sourceNode
  use strict arg source,sha256Digest,byteOffset,rangeBytes
  if source~string~strip="" then raise syntax 88.900 array("range source required")
  sourceNode=source~string
  digest=sha256Digest~string~lower
  if left(digest,7)="sha256:" then digest=substr(digest,8)
  if length(digest)<>64 then raise syntax 88.900 array("sha256 digest required")
  do i=1 to 64
    if pos(substr(digest,i,1),"0123456789abcdef")=0 then raise syntax 88.900 array("invalid sha256 digest")
  end
  numeric digits 50
  if \datatype(byteOffset,"W") | \datatype(rangeBytes,"W") then raise syntax 88.900 array("integer byte range required")
  if byteOffset<0 | rangeBytes<1 then raise syntax 88.900 array("invalid byte range")
  offset=byteOffset; byteCount=rangeBytes
