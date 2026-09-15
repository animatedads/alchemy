/* QueueRexxAuthority.cls - QueueRexx v0.1-dev12 authority-server composition.
 *
 * QueueRexx owns the authority host lifecycle and Queue Fabric mesh.  The
 * network protocol itself is the exact Job-to-Node network1 implementation:
 *
 *   JobNodeAllocator v0.6                  placement/admission/ownership
 *   JobNodeNetworkAllocatorService         job.node.allocator.network/0.1
 *   JobNodeNetworkRequestLedger            durable request replay
 *   JobNodeNetworkAccessPolicy             client operation/owner ACL
 *   QueueRexxPeerMeshRuntime               general node connectivity/trust
 *   Queue Fabric queue.transport/2         inter-node transport only
 *
 * No QueueRexx placement protocol or second lease format exists here.
 */

::class QueueRexxJobNodeNetworkOperation public
::constant PLAN "PLAN"
::constant ALLOCATE "ALLOCATE"
::constant CHECK "CHECK"
::constant RENEW "RENEW"
::constant RELEASE "RELEASE"
::method valid class
  use strict arg operation
  op=operation~string~upper
  return op=self~PLAN | op=self~ALLOCATE | op=self~CHECK | op=self~RENEW | op=self~RELEASE
::method mutating class
  use strict arg operation
  op=operation~string~upper
  return op=self~ALLOCATE | op=self~RENEW | op=self~RELEASE

/* QueueRexx-owned administrative binding evidence.  This is transport and
 * ACL configuration only; it is never placement authority. */
::class QueueRexxAuthorityClientBinding public
::attribute clientId get
::attribute peerNodeId get
::attribute ownerNodeId get
::attribute replyAlias get
::attribute senderChannel get
::attribute transportPrincipal get
::attribute operations get
::method init
  expose clientId peerNodeId ownerNodeId replyAlias senderChannel transportPrincipal operations
  use strict arg clientIdArg, peerNodeArg, ownerArg, replyAliasArg, senderArg, principalArg, operationsArg
  clientId=clientIdArg~string; peerNodeId=peerNodeArg~string; ownerNodeId=ownerArg~string
  replyAlias=replyAliasArg~string; senderChannel=senderArg~string; transportPrincipal=principalArg~string; operations=operationsArg

/* Synchronous allocator-shaped view over the exact network1 client.  The
 * wrapped object remains JobNodeNetworkAllocatorClient; this adapter merely
 * pumps the already-configured Queue Fabric peer route and converts exact
 * network responses back into the JobNodeAllocator method shapes required by
 * MigratableJobManagedPlacementTool. */
::class QueueRexxJobNodeNetworkAllocatorProxy public
::attribute client get
::method init
  expose client channels senderChannel listener adminPrincipal idPrefix sequence
  use strict arg clientArg, channelsArg, senderChannelArg, listenerArg=.nil, adminArg="queue-admin", idPrefixArg="QRX-JNA"
  if clientArg==.nil | channelsArg==.nil | senderChannelArg~string~strip="" then raise syntax 88.900 array("network client, fabric and sender channel required")
  client=clientArg; channels=channelsArg; senderChannel=senderChannelArg~string; listener=listenerArg; adminPrincipal=adminArg~string
  idPrefix=idPrefixArg~string; sequence=0

::method nextRequestId private guarded
  expose idPrefix sequence
  sequence+=1
  return idPrefix||"-"||date("S")||"-"||time("L")~translate("",":.")||"-"||sequence

::method request private
  expose client channels senderChannel listener adminPrincipal
  use strict arg operation, placementRequest=.nil, lease=.nil, nowEpochMs=0, leaseDurationMs=30000, requestId=""
  if requestId="" then requestId=self~nextRequestId
  sent=client~submit(requestId,operation,placementRequest,lease,nowEpochMs,leaseDurationMs)
  if \sent~ok then return sent
  pumped=channels~pump(senderChannel,1,adminPrincipal)
  if \pumped~ok then return .QueueOperationResult~failure("NETWORK_REQUEST_PUMP_FAILED",pumped~code||":"||pumped~detail)
  if listener<>.nil then do
    received=listener~serveOne
    if \received~ok then return .QueueOperationResult~failure("NETWORK_REPLY_TRANSPORT_FAILED",received~code||":"||received~detail)
  end
  return client~receive

::method plan
  use strict arg placementRequest, nowEpochMs=0
  return self~request(.QueueRexxJobNodeNetworkOperation~PLAN,placementRequest,.nil,nowEpochMs,30000)

::method allocate
  use strict arg placementRequest, nowEpochMs=0, leaseDurationMs=30000
  rr=self~request(.QueueRexxJobNodeNetworkOperation~ALLOCATE,placementRequest,.nil,nowEpochMs,leaseDurationMs)
  if rr==.nil | \rr~ok then return .JobNodePlacementDecision~new(.false,"NETWORK_UNAVAILABLE")
  response=rr~value; data=response["data"]
  lease=.nil; score=0
  if data<>.nil then do
    lease=.JobNodeNetworkCodec~decodeLease(data["lease"])
    if data["selectedScore"]<>.nil then score=data["selectedScore"]+0
  end
  return .JobNodePlacementDecision~new(response["status"]="OK",response["code"],lease,.nil,score)

::method verifyLease
  use strict arg lease, placementRequest, nowEpochMs=0
  rr=self~request(.QueueRexxJobNodeNetworkOperation~CHECK,placementRequest,lease,nowEpochMs,30000)
  if rr==.nil | \rr~ok then return .false
  return rr~value["status"]="OK" & rr~value["code"]="LEASE_VALID"

::method renewPlacement
  use strict arg lease, placementRequest, nowEpochMs=0, leaseDurationMs=30000
  rr=self~request(.QueueRexxJobNodeNetworkOperation~RENEW,placementRequest,lease,nowEpochMs,leaseDurationMs)
  if rr==.nil | \rr~ok then return .JobNodePlacementDecision~new(.false,"NETWORK_UNAVAILABLE")
  response=rr~value; data=response["data"]
  renewed=.nil; score=0
  if data<>.nil then do
    renewed=.JobNodeNetworkCodec~decodeLease(data["lease"])
    if data["selectedScore"]<>.nil then score=data["selectedScore"]+0
  end
  return .JobNodePlacementDecision~new(response["status"]="OK",response["code"],renewed,.nil,score)

::method releasePlacement
  use strict arg lease
  rr=self~request(.QueueRexxJobNodeNetworkOperation~RELEASE,.nil,lease,0,30000)
  if rr==.nil | \rr~ok then return .false
  return rr~value["status"]="OK" & rr~value["code"]="RELEASED"

/* Build the exact upstream client on a service route carried by an existing
 * QueueRexx peer.  No new socket or trust relationship is introduced. */
::class QueueRexxJobNodePeerClientFactory public
::method create class
  use strict arg peerMesh, peerNodeId, clientId, localReplyQueue="", principal="jna-client", remoteRequestQueue="JNA.REQUEST"
  if peerMesh==.nil then return .QueueOperationResult~failure("PEER_MESH_REQUIRED")
  if localReplyQueue="" then localReplyQueue="JNA.REPLY."||clientId~string~translate
  route=peerMesh~bindServiceRoute(peerNodeId,"JNA.REQUEST."||clientId,localReplyQueue,remoteRequestQueue,"JNA",principal)
  if \route~ok then return route
  ignore=peerMesh~queueManager~grant(localReplyQueue,principal,.QueueAccess~GET,peerMesh~adminPrincipal)
  d=route~value
  exact=.JobNodeNetworkAllocatorClient~new(peerMesh~channels,d["remote_alias"],peerMesh~queueManager,localReplyQueue,clientId,principal)
  proxy=.QueueRexxJobNodeNetworkAllocatorProxy~new(exact,peerMesh~channels,d["sender_channel"],peerMesh~listener,peerMesh~adminPrincipal,"JNA-"||clientId)
  out=.directory~new; out["client"]=exact; out["allocator_proxy"]=proxy; out["route"]=d
  return .QueueOperationResult~success(out,"exact JobNodeNetworkAllocatorClient bound over QueueRexx peer mesh")

::class QueueRexxAuthorityStack public
::attribute allocator get
::attribute rawAllocator get
::attribute ownership get
::attribute admission get
::attribute registry get
::attribute eligibilityPolicy get
::attribute placementPolicy get
::attribute queueManager get
::attribute channels get
::attribute transport get
::attribute listener get
::attribute accessPolicy get
::attribute networkLedger get
::attribute networkService get
::attribute managerName get
::attribute adminPrincipal get
::attribute peerMesh get
::attribute clientBindings get
::attribute requestQueue get
::method init
  expose root allocator rawAllocator ownership admission registry eligibilityPolicy placementPolicy queueManager channels transport listener accessPolicy networkLedger networkService managerName adminPrincipal peerMesh clientBindings requestQueue servicePrincipal
  use strict arg rootArg, registryArg, eligibilityArg=.nil, wluAuthorityArg=.nil, wluIdentityArg="QUEUEREXX", wluScopeArg="queue", policyGenerationArg="1", managerNameArg="QUEUEREXX.AUTHORITY", bindHostArg="127.0.0.1", portArg=0, adminArg="queue-admin", nowEpochMsArg=0, digestArg=.nil, proofArg=.nil
  root=rootArg~string; registry=registryArg; adminPrincipal=adminArg~string; managerName=managerNameArg~string; peerMesh=.nil
  requestQueue="JNA.REQUEST"; servicePrincipal="jna-service"; clientBindings=.directory~new
  if root="" | registry==.nil then raise syntax 88.900 array("authority root and NodeCapabilityRegistry required")
  if eligibilityArg==.nil then eligibilityPolicy=.JobNodeEligibilityPolicy~new; else eligibilityPolicy=eligibilityArg
  placementPolicy=.JobNodePlacementPolicy~new; ownership=.JobNodeOwnershipRegistry~new
  if wluAuthorityArg==.nil then admission=.nil
  else admission=.QueueJobNodeWLUAdmission~new(wluAuthorityArg,root,wluIdentityArg,wluScopeArg)
  rawAllocator=.JobNodeAllocator~new(registry,eligibilityPolicy,placementPolicy,digestArg,proofArg,policyGenerationArg,admission,ownership)
  allocator=.QueueDurableJobNodeAllocator~new(rawAllocator,ownership,root,admission,digestArg,proofArg)
  recovery=allocator~restore(nowEpochMsArg)
  if recovery==.nil | \recovery~ok then raise syntax 88.900 array("Job-to-Node durable authority restore failed")

  fabricRoot=root||"/logs/queuerexx-authority/queue-fabric"
  address system "mkdir -p " || fabricRoot
  codec=.QueueGraphPayloadCodec~new
  queueManager=.ObjectQueueManager~new(fabricRoot,codec,adminPrincipal)
  transport=.QueueSocketClientTransport~new(adminPrincipal,queueManager~payloadCodec)
  channels=.QueueChannelFabric~new(managerName,queueManager,transport,adminPrincipal)
  listener=.QueueSocketListener~new(managerName,bindHostArg,portArg,channels,queueManager~payloadCodec)

  if queueManager~queue(requestQueue)==.nil then do
    created=queueManager~createQueue(requestQueue,.QueueLifecycle~PERMANENT,"JNA",5000,adminPrincipal)
    if \created~ok then raise syntax 88.900 array("Job-to-Node request queue creation failed")
  end
  ignore=queueManager~grant(requestQueue,servicePrincipal,.QueueAccess~GET,adminPrincipal)
  accessPolicy=.JobNodeNetworkAccessPolicy~new
  ledgerPath=root||"/logs/queuerexx-authority/job-node-network.requests"
  /* The upstream ledger raises on corrupt durable data; construction therefore
   * fails closed before the listener can be started. */
  networkLedger=.JobNodeNetworkRequestLedger~new(ledgerPath,queueManager~payloadCodec)
  networkService=.JobNodeNetworkAllocatorService~new(allocator,registry,eligibilityPolicy,placementPolicy,queueManager,requestQueue,channels,servicePrincipal,accessPolicy,networkLedger,digestArg,managerName)

::method enablePeerMesh
  expose root managerName queueManager channels transport listener adminPrincipal peerMesh
  use strict arg localNodeId, digestArg=.nil
  if peerMesh==.nil then peerMesh=.QueueRexxPeerMeshRuntime~new(localNodeId,root,managerName,queueManager,channels,transport,listener,adminPrincipal,digestArg)
  return peerMesh

::method enableStandardPeerChecks
  expose root registry peerMesh
  use strict arg localNodeId, jobNodeId="", policyProvider=.nil, digestArg=.nil
  if jobNodeId="" then jobNodeId=localNodeId~string
  if peerMesh==.nil then peerMesh=self~enablePeerMesh(localNodeId,digestArg)
  ignore=.QueueRexxPeerStandardHandlers~install(peerMesh~service,root,registry,jobNodeId,policyProvider)
  return peerMesh

/* Preferred dev12 authority binding: the node is already a QueueRexx mesh
 * peer.  JNA gets a service route over that exact transport relationship. */
::method bindPeerClient
  expose queueManager accessPolicy networkService clientBindings requestQueue servicePrincipal peerMesh adminPrincipal
  use strict arg clientId, peerNodeId, clientReplyQueue, operations, ownerNodeId=""
  if peerMesh==.nil then return .QueueOperationResult~failure("PEER_MESH_REQUIRED",clientId)
  pb=peerMesh~trustPolicy~binding(peerNodeId)
  if pb==.nil then return .QueueOperationResult~failure("PEER_NOT_BOUND",peerNodeId)
  route=peerMesh~bindServiceRoute(peerNodeId,"JNA.REPLY."||clientId,requestQueue,clientReplyQueue,"JNA",servicePrincipal)
  if \route~ok then return route
  ignore=queueManager~grant(requestQueue,servicePrincipal,.QueueAccess~GET,adminPrincipal)
  ignore=accessPolicy~grant(clientId,operations,ownerNodeId)
  d=route~value; ignore=networkService~bindClientReply(clientId,d["remote_alias"])
  binding=.QueueRexxAuthorityClientBinding~new(clientId,peerNodeId,ownerNodeId,d["remote_alias"],d["sender_channel"],pb~transportPrincipal,operations)
  clientBindings[clientId~string~upper]=binding
  out=.directory~new; out["binding"]=binding; out["request_queue"]=requestQueue; out["reply_alias"]=d["remote_alias"]; out["sender_channel"]=d["sender_channel"]
  return .QueueOperationResult~success(out,"Job-to-Node network1 service bound over QueueRexx peer mesh")

/* Compatibility/bootstrap binding for a client that has not yet been loaded
 * from peer-mesh configuration.  It creates the general peer first, then the
 * JNA service route over it. */
::method bindClient
  expose managerName peerMesh
  use strict arg clientId, clientManager, transportPrincipal, keyId, keyHex, allowedSourceIps, remoteHost, remotePort, clientReplyQueue, clientReplyReceiverChannel, operations, ownerNodeId=""
  if peerMesh==.nil then peerMesh=self~enablePeerMesh(managerName)
  peer=peerMesh~bindSocketPeer(clientId,clientManager,remoteHost,remotePort,transportPrincipal,keyId,keyHex,allowedSourceIps,.array~new)
  if \peer~ok then return peer
  return self~bindPeerClient(clientId,clientId,clientReplyQueue,operations,ownerNodeId)

::method startListener
  expose listener
  return listener~start
::method serveTransportOne
  expose listener
  return listener~serveOne

::method processNetworkOne
  expose networkService clientBindings channels adminPrincipal
  r=networkService~processOne
  if \r~ok then return r
  response=r~value
  /* network1 has already staged the exact response into the durable service
   * xmit queue before it acknowledges the request.  Delivery is therefore a
   * retryable transport concern, not part of allocator commit.  An offline
   * client must never make authority recovery/startup fail after the request
   * has been durably applied. */
  if response<>.nil then do
    clientId=response["clientId"]
    if clientId<>.nil then do
      b=clientBindings[clientId~string~upper]
      if b<>.nil then do
        p=channels~pump(b~senderChannel,0,adminPrincipal)
        if \p~ok then return .QueueOperationResult~success(response,"reply queued for retry; "||clientId||":"||p~code||":"||p~detail)
      end
    end
  end
  return r

/* Retry every durable network1 reply route.  Failures remain queued and are
 * reported as delivery backlog rather than authority failure. */
::method pumpClientReplies
  expose clientBindings channels adminPrincipal
  delivered=0; failures=.array~new
  sup=clientBindings~supplier
  do while sup~available
    b=sup~item
    p=channels~pump(b~senderChannel,0,adminPrincipal)
    if p~ok then do
      pd=p~detail; sentPos=pd~pos("sent=")
      if sentPos>0 then do
        sentText=pd~substr(sentPos+5); semi=sentText~pos(";")
        if semi>0 then sentText=sentText~left(semi-1)
        sentText=sentText~strip
        if datatype(sentText,"W") then delivered+=sentText+0
      end
    end
    else failures~append(b~clientId||":"||p~code||":"||p~detail)
    sup~next
  end
  detail="delivered="||delivered||";backlog_routes="||failures~items
  if failures~items>0 then do
    do failure over failures
      detail=detail||";"||failure
    end
  end
  return .QueueOperationResult~success(delivered,detail)

::method drainNetwork
  expose networkService
  use strict arg maxMessages=0
  served=0
  do while maxMessages=0 | served<maxMessages
    r=self~processNetworkOne
    if \r~ok then do
      if r~code="QUEUE_EMPTY" then leave
      return r
    end
    served+=1
  end
  return .QueueOperationResult~success(served,"served="||served)

::method drainPeerControl
  expose peerMesh
  if peerMesh==.nil then return .QueueOperationResult~success(0,"served=0")
  total=0
  do binding over peerMesh~trustPolicy~peers
    r=peerMesh~servePeer(binding~peerNodeId,0)
    if \r~ok then return r
    detail=r~detail; p=detail~pos("served=")
    if p>0 then do
      n=word(detail~substr(p+7),1); if datatype(n,"W") then total+=n
    end
  end
  return .QueueOperationResult~success(total,"served="||total)

/* ---------------------------------------------------------------------- */
/* Durable administrator-owned client configuration.                      */
/* ---------------------------------------------------------------------- */
::class QueueRexxAuthorityClientSpec public
::attribute clientId get
::attribute clientManager get
::attribute transportPrincipal get
::attribute keyId get
::attribute keyHex get
::attribute allowedSourceIps get
::attribute remoteHost get
::attribute remotePort get
::attribute clientReplyQueue get
::attribute clientReplyReceiverChannel get
::attribute operations get
::attribute ownerNodeId get
::method init
  expose clientId clientManager transportPrincipal keyId keyHex allowedSourceIps remoteHost remotePort clientReplyQueue clientReplyReceiverChannel operations ownerNodeId
  use strict arg clientIdArg, managerArg, principalArg, keyIdArg, keyHexArg, sourceIpsArg, remoteHostArg, remotePortArg, replyQueueArg, replyReceiverArg, operationsArg, ownerArg=""
  clientId=clientIdArg~string; clientManager=managerArg~string; transportPrincipal=principalArg~string; keyId=keyIdArg~string; keyHex=keyHexArg~string
  allowedSourceIps=sourceIpsArg; remoteHost=remoteHostArg~string; remotePort=remotePortArg+0; clientReplyQueue=replyQueueArg~string; clientReplyReceiverChannel=replyReceiverArg~string; operations=operationsArg; ownerNodeId=ownerArg~string

::class QueueRexxAuthorityClientConfig public
::attribute path get
::method init
  expose path
  use strict arg pathArg
  path=pathArg~string
  if path="" then raise syntax 88.900 array("authority client configuration path required")
::method load
  expose path
  if stream(path,"c","query exists")="" then return .QueueOperationResult~failure("AUTHORITY_CLIENT_CONFIG_MISSING",path)
  signal on syntax name configFailure
  doc=.QueueSerialization~fromJsonFile(path)
  signal off syntax
  if doc==.nil | \doc~isA(.Directory) then return .QueueOperationResult~failure("AUTHORITY_CLIENT_CONFIG_INVALID","JSON object required")
  schema=doc["schema"]
  if schema==.nil | schema~string<>"queuerexx.job-node.authority-clients/1" then return .QueueOperationResult~failure("AUTHORITY_CLIENT_CONFIG_SCHEMA",schema)
  rows=doc["clients"]
  if rows==.nil | \rows~isA(.Array) then return .QueueOperationResult~failure("AUTHORITY_CLIENT_CONFIG_INVALID","clients array required")
  specs=.array~new
  do row over rows
    v=self~specFrom(row); if \v~ok then return v; specs~append(v~value)
  end
  return .QueueOperationResult~success(specs,"clients="||specs~items)
configFailure:
  signal off syntax
  return .QueueOperationResult~failure("AUTHORITY_CLIENT_CONFIG_READ_FAILED",condition("D"))
::method apply
  use strict arg stack
  loaded=self~load; if \loaded~ok then return loaded
  count=0
  do spec over loaded~value
    r=stack~bindClient(spec~clientId,spec~clientManager,spec~transportPrincipal,spec~keyId,spec~keyHex,spec~allowedSourceIps,spec~remoteHost,spec~remotePort,spec~clientReplyQueue,spec~clientReplyReceiverChannel,spec~operations,spec~ownerNodeId)
    if \r~ok then return .QueueOperationResult~failure("AUTHORITY_CLIENT_BIND_FAILED",spec~clientId||":"||r~code||":"||r~detail)
    count+=1
  end
  return .QueueOperationResult~success(count,"clients="||count)
::method specFrom private
  use strict arg row
  if row==.nil | \row~isA(.Directory) then return .QueueOperationResult~failure("AUTHORITY_CLIENT_CONFIG_INVALID","client entry must be object")
  clientId=self~required(row,"client_id"); if clientId==.nil then return self~missing("client_id")
  manager=self~required(row,"client_manager"); if manager==.nil then return self~missing("client_manager")
  principal=self~required(row,"transport_principal"); if principal==.nil then return self~missing("transport_principal")
  keyId=self~required(row,"key_id"); if keyId==.nil then return self~missing("key_id")
  keyHex=self~required(row,"key_hex"); if keyHex==.nil then return self~missing("key_hex")
  remoteHost=self~required(row,"remote_host"); if remoteHost==.nil then return self~missing("remote_host")
  remotePort=row["remote_port"]; if remotePort==.nil | \datatype(remotePort,"W") | remotePort<1 | remotePort>65535 then return .QueueOperationResult~failure("AUTHORITY_CLIENT_CONFIG_INVALID",clientId||":remote_port")
  replyQueue=self~required(row,"client_reply_queue"); if replyQueue==.nil then return self~missing("client_reply_queue")
  replyReceiver=self~required(row,"client_reply_receiver_channel"); if replyReceiver==.nil then return self~missing("client_reply_receiver_channel")
  operations=row["operations"]; if operations==.nil | \operations~isA(.Array) | operations~items=0 then return .QueueOperationResult~failure("AUTHORITY_CLIENT_CONFIG_INVALID",clientId||":operations")
  do op over operations
    if \.QueueRexxJobNodeNetworkOperation~valid(op) then return .QueueOperationResult~failure("AUTHORITY_CLIENT_CONFIG_INVALID",clientId||":operation:"||op)
  end
  ips=row["allowed_source_ips"]; if ips==.nil then ips=.array~new; else if \ips~isA(.Array) then return .QueueOperationResult~failure("AUTHORITY_CLIENT_CONFIG_INVALID",clientId||":allowed_source_ips")
  owner=row["owner_node_id"]; if owner==.nil then owner=""
  return .QueueOperationResult~success(.QueueRexxAuthorityClientSpec~new(clientId,manager,principal,keyId,keyHex,ips,remoteHost,remotePort,replyQueue,replyReceiver,operations,owner))
::method required private
  use strict arg row,key
  v=row[key]; if v==.nil then return .nil; if v~string~strip="" then return .nil; return v~string
::method missing private
  use strict arg field
  return .QueueOperationResult~failure("AUTHORITY_CLIENT_CONFIG_INVALID","missing "||field)

/* Preferred service binding for an authority client that already exists as a
 * QueueRexx mesh peer.  Connectivity, keys and endpoint trust live exclusively
 * in queuerexx.peer.mesh.config/1; this document grants network1 semantics. */
::class QueueRexxAuthorityPeerClientSpec public
::attribute clientId get
::attribute peerNodeId get
::attribute clientReplyQueue get
::attribute operations get
::attribute ownerNodeId get
::method init
  expose clientId peerNodeId clientReplyQueue operations ownerNodeId
  use strict arg clientArg, peerArg, replyArg, operationsArg, ownerArg=""
  clientId=clientArg~string; peerNodeId=peerArg~string; clientReplyQueue=replyArg~string
  operations=operationsArg; ownerNodeId=ownerArg~string

::class QueueRexxAuthorityPeerClientConfig public
::constant SCHEMA "queuerexx.job-node.authority-peer-clients/1"
::attribute path get
::method init
  expose path
  use strict arg pathArg
  path=pathArg~string
  if path="" then raise syntax 88.900 array("authority peer-client configuration path required")
::method load
  expose path
  if stream(path,"c","query exists")="" then return .QueueOperationResult~failure("AUTHORITY_PEER_CLIENT_CONFIG_MISSING",path)
  signal on syntax name configFailure
  doc=.QueueSerialization~fromJsonFile(path)
  signal off syntax
  if doc==.nil | \doc~isA(.Directory) then return .QueueOperationResult~failure("AUTHORITY_PEER_CLIENT_CONFIG_INVALID","JSON object required")
  if doc["schema"]==.nil | doc["schema"]~string<>self~SCHEMA then return .QueueOperationResult~failure("AUTHORITY_PEER_CLIENT_CONFIG_SCHEMA",doc["schema"])
  rows=doc["clients"]
  if rows==.nil | \rows~isA(.Array) then return .QueueOperationResult~failure("AUTHORITY_PEER_CLIENT_CONFIG_INVALID","clients array required")
  specs=.array~new
  do row over rows
    v=self~specFrom(row); if \v~ok then return v; specs~append(v~value)
  end
  return .QueueOperationResult~success(specs,"clients="||specs~items)
configFailure:
  signal off syntax
  return .QueueOperationResult~failure("AUTHORITY_PEER_CLIENT_CONFIG_READ_FAILED",condition("D"))
::method apply
  use strict arg stack
  if stack~peerMesh==.nil then return .QueueOperationResult~failure("PEER_MESH_REQUIRED","apply queuerexx.peer.mesh.config/1 before authority service bindings")
  loaded=self~load; if \loaded~ok then return loaded
  count=0
  do spec over loaded~value
    r=stack~bindPeerClient(spec~clientId,spec~peerNodeId,spec~clientReplyQueue,spec~operations,spec~ownerNodeId)
    if \r~ok then return .QueueOperationResult~failure("AUTHORITY_PEER_CLIENT_BIND_FAILED",spec~clientId||":"||r~code||":"||r~detail)
    count+=1
  end
  return .QueueOperationResult~success(count,"clients="||count)
::method specFrom private
  use strict arg row
  if row==.nil | \row~isA(.Directory) then return .QueueOperationResult~failure("AUTHORITY_PEER_CLIENT_CONFIG_INVALID","client entry must be object")
  clientId=self~required(row,"client_id"); if clientId==.nil then return self~missing("client_id")
  peerNodeId=self~required(row,"peer_node_id"); if peerNodeId==.nil then return self~missing("peer_node_id")
  replyQueue=self~required(row,"client_reply_queue"); if replyQueue==.nil then return self~missing("client_reply_queue")
  operations=row["operations"]
  if operations==.nil | \operations~isA(.Array) | operations~items=0 then return .QueueOperationResult~failure("AUTHORITY_PEER_CLIENT_CONFIG_INVALID",clientId||":operations")
  do op over operations
    if \.QueueRexxJobNodeNetworkOperation~valid(op) then return .QueueOperationResult~failure("AUTHORITY_PEER_CLIENT_CONFIG_INVALID",clientId||":operation:"||op)
  end
  owner=row["owner_node_id"]; if owner==.nil then owner=""
  return .QueueOperationResult~success(.QueueRexxAuthorityPeerClientSpec~new(clientId,peerNodeId,replyQueue,operations,owner))
::method required private
  use strict arg row,key
  v=row[key]; if v==.nil then return .nil; if v~string~strip="" then return .nil; return v~string
::method missing private
  use strict arg field
  return .QueueOperationResult~failure("AUTHORITY_PEER_CLIENT_CONFIG_INVALID","missing "||field)

/* Long-running QueueRexx authority host.  Durable authority is restored by
 * QueueRexxAuthorityStack before this object can expose its listener.  When
 * peerConfig is supplied it is always applied before semantic service ACLs. */
::class QueueRexxAuthorityServer public
::attribute running get
::attribute stack get
::method init
  expose stack running clientConfig configApplied peerConfig peerConfigApplied localNodeId
  use strict arg stackArg, clientConfigArg=.nil, peerConfigArg=.nil, localNodeIdArg=""
  if stackArg==.nil then raise syntax 88.900 array("QueueRexxAuthorityStack required")
  stack=stackArg; running=.false; clientConfig=clientConfigArg; configApplied=.false
  peerConfig=peerConfigArg; peerConfigApplied=.false; localNodeId=localNodeIdArg~string
::method start
  expose stack running clientConfig configApplied peerConfig peerConfigApplied localNodeId
  if running then return .QueueOperationResult~success(.true,"already running")
  if peerConfig<>.nil & \peerConfigApplied then do
    if localNodeId~strip="" then return .QueueOperationResult~failure("PEER_MESH_LOCAL_NODE_REQUIRED","local node id required when peer config is supplied")
    mesh=stack~enablePeerMesh(localNodeId)
    configuredPeers=peerConfig~apply(mesh); if \configuredPeers~ok then return configuredPeers
    peerConfigApplied=.true
  end
  if clientConfig<>.nil & \configApplied then do
    configured=clientConfig~apply(stack); if \configured~ok then return configured; configApplied=.true
  end
  /* Restore/drain durable request queues before accepting new transport. */
  drained=self~drainPending; if \drained~ok then return drained
  if \stack~startListener then return .QueueOperationResult~failure("LISTENER_START_FAILED",stack~listener~lastError)
  running=.true
  return .QueueOperationResult~success(.true,"authority server ready")
::method stop
  expose stack running
  if running then ignore=stack~listener~stop
  running=.false
  return .QueueOperationResult~success(.true,"authority server stopped")
::method drainPending
  expose stack
  n=stack~drainNetwork(0); if \n~ok then return n
  /* Retry staged replies even when no new request was processed.  The pump is
   * best-effort because an unavailable peer is represented by durable backlog,
   * not by rollback of already-committed authority work. */
  delivery=stack~pumpClientReplies
  p=stack~drainPeerControl; if \p~ok then return p
  return .QueueOperationResult~success((n~value+0)+(p~value+0),"network="||n~value||" peer="||p~value||" "||delivery~detail)
::method serveOne
  expose stack running
  if \running then do; r=self~start; if \r~ok then return r; end
  pre=self~drainPending; if \pre~ok then return pre
  transportResult=stack~serveTransportOne
  if \transportResult~ok then return .QueueOperationResult~failure("TRANSPORT_RECEIVE_FAILED",transportResult~code||":"||transportResult~detail)
  return self~drainPending
::method run
  expose running
  use strict arg maxCycles=0
  r=self~start; if \r~ok then return r
  cycles=0
  do while running & (maxCycles=0 | cycles<maxCycles)
    r=self~serveOne; if \r~ok then do; ignore=self~stop; return r; end; cycles+=1
  end
  return .QueueOperationResult~success(cycles,"cycles="||cycles)

::requires "QueueRexxSerialization.cls"
::requires "QueueRexxJobNodeDurable.cls"
::requires "QueueRexxWLU.cls"
::requires "JobNodeNetworkService.cls"
::requires "JobNodeLiveness.cls"
::requires "ObjectQueueSocketTransport.cls"
::requires "QueueRexxPeerMeshAdapters.cls"
