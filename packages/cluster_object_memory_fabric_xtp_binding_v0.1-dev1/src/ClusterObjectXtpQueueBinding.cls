/* ClusterObjectXtpQueueBinding.cls
 * Cluster-owned composition of cluster.object.peer/0.2 with the protected
 * Queue Fabric XTP session transport.
 *
 * API: cluster.object.xtp-binding/0.1
 *
 * This package DOES NOT own XTP, Queue Fabric, Memory Fabric or placement.
 * It binds the already-defined authorities together for cluster object MOVE:
 *   - Memory Fabric owns block/provider identity and residency fencing.
 *   - Job-to-Node owns execution placement/admission.
 *   - Queue Fabric owns durable store-and-forward and receiver UOW receipts.
 *   - XTP owns the protected named-service carrier.
 *   - cluster.object.peer/0.2 owns object generation and source release rules.
 *
 * The route is fail-closed until an injected readiness authority says the
 * selected peer/service route is acceptable. A successful XTP session alone
 * is not readiness and is not Queue Fabric durable acceptance.
 */

::options numeric inherit

::class ClusterObjectXtpBindingBuild public
::constant VERSION "0.1-dev1"
::constant API "cluster.object.xtp-binding/0.1"
::constant CLUSTER_API "cluster.object.peer/0.2"
::constant REQUIRED_PROTECTION "encrypt"

::class ClusterObjectXtpRoute public
::method init
  expose peerNode xtpPeer xtpService localManager remoteManager requestAlias requestChannel replyQueue localPrincipal providerSet clientTransport channels wire receiptGate
  use strict arg peerNodeArg, xtpPeerArg, xtpServiceArg, localManagerArg, remoteManagerArg, requestAliasArg, requestChannelArg, replyQueueArg, localPrincipalArg, providerIdsArg, clientArg, channelsArg, wireArg, receiptGateArg
  peerNode=peerNodeArg~string~strip
  xtpPeer=xtpPeerArg~string~strip
  xtpService=xtpServiceArg~string~strip
  localManager=localManagerArg~string~strip
  remoteManager=remoteManagerArg~string~strip
  requestAlias=requestAliasArg~string~strip
  requestChannel=requestChannelArg~string~strip
  replyQueue=replyQueueArg~string~strip
  localPrincipal=localPrincipalArg~string~strip
  if peerNode='' then raise syntax 88.900 array('cluster peer node is required')
  if xtpPeer='' then raise syntax 88.900 array('XTP peer is required')
  if xtpService='' then raise syntax 88.900 array('XTP named service is required')
  if localManager='' then raise syntax 88.900 array('local Queue Fabric manager is required')
  if remoteManager='' then raise syntax 88.900 array('remote Queue Fabric manager is required')
  if requestAlias='' then raise syntax 88.900 array('Queue Fabric request alias is required')
  if requestChannel='' then raise syntax 88.900 array('Queue Fabric sender channel is required')
  if replyQueue='' then raise syntax 88.900 array('Queue Fabric reply queue is required')
  if localPrincipal='' then raise syntax 88.900 array('Queue Fabric local principal is required')
  if clientArg==.nil then raise syntax 88.900 array('cluster Queue Fabric client transport is required')
  if channelsArg==.nil then raise syntax 88.900 array('QueueChannelFabric is required')
  if wireArg==.nil then raise syntax 88.900 array('Queue XTP session wire is required')
  if receiptGateArg==.nil then raise syntax 88.900 array('Queue XTP durable receipt gate is required')
  providerSet=.directory~new
  do providerId over providerIdsArg
    id=providerId~string~strip
    if id<>'' then providerSet[id]=.true
  end
  if providerSet~items=0 then raise syntax 88.900 array('at least one Memory Fabric provider id is required')
  clientTransport=clientArg
  channels=channelsArg
  wire=wireArg
  receiptGate=receiptGateArg

::attribute peerNode get
::attribute xtpPeer get
::attribute xtpService get
::attribute localManager get
::attribute remoteManager get
::attribute requestAlias get
::attribute requestChannel get
::attribute replyQueue get
::attribute localPrincipal get
::attribute clientTransport get
::attribute channels get
::attribute wire get
::attribute receiptGate get

::method allowsProvider
  expose providerSet
  use strict arg providerId
  return providerSet[providerId~string~strip]<>.nil

::method providerIds
  expose providerSet
  ids=.array~new
  supplier=providerSet~supplier
  do while supplier~available
    ids~append(supplier~index)
    supplier~next
  end
  return ids

::class ClusterObjectXtpRouteFactory public
::method create class
  use strict arg peerNode, providerIds, localManagerName, queueManager, adminPrincipal, requestAlias, requestChannel, replyQueue, localPrincipal, remoteManager, xtpPeer, xtpService, sessionFactory, deliveryCodec, receiptVerifier, timeoutMs=10000, openTimeoutMs=3000, ioTimeoutMs=5000, maxReplyBytes=8388608
  if queueManager==.nil then raise syntax 88.900 array('Queue Fabric manager is required')
  if sessionFactory==.nil then raise syntax 88.900 array('XTP session factory is required')
  if deliveryCodec==.nil then raise syntax 88.900 array('queue.transport/2 delivery codec is required')
  if receiptVerifier==.nil then raise syntax 88.900 array('authenticated durable receipt verifier is required')
  if xtpService~string~strip='' then raise syntax 88.900 array('XTP named service is required')
  wire=.QueueXtpSessionWire~new(sessionFactory,deliveryCodec,.QueueOperationResult,xtpPeer,xtpService,openTimeoutMs,ioTimeoutMs,maxReplyBytes)
  gate=.QueueXtpReceiptGate~new(wire,receiptVerifier,.QueueOperationResult)
  channels=.QueueChannelFabric~new(localManagerName,queueManager,gate,adminPrincipal)
  client=.ClusterObjectQueueFabricClientTransport~new(channels,requestAlias,requestChannel,replyQueue,localPrincipal,timeoutMs)
  return .ClusterObjectXtpRoute~new(peerNode,xtpPeer,xtpService,localManagerName,remoteManager,requestAlias,requestChannel,replyQueue,localPrincipal,providerIds,client,channels,wire,gate)

::class ClusterObjectXtpDenyReadiness public
::method allow
  use strict arg route,request
  return .false

::class ClusterObjectXtpStaticReadiness public
::method init
  expose allowed
  use strict arg allowedArg=.false
  allowed=(allowedArg==.true)
::method allow
  expose allowed
  use strict arg route,request
  return allowed

::class ClusterObjectXtpRouterTransport public
::method init
  expose routes readiness lastFailure
  use strict arg readinessAuthority=.nil
  routes=.directory~new
  if readinessAuthority==.nil then readiness=.ClusterObjectXtpDenyReadiness~new
  else readiness=readinessAuthority
  if \readiness~hasMethod('ALLOW') then raise syntax 88.900 array('XTP readiness authority must implement ALLOW')
  lastFailure=''

::attribute lastFailure get

::method registerRoute
  expose routes
  use strict arg route
  if route==.nil then return .false
  if \route~isA(.ClusterObjectXtpRoute) then return .false
  key=route~peerNode~string~strip
  if key='' then return .false
  if routes[key]<>.nil then return .false
  routes[key]=route
  return .true

::method route
  expose routes
  use strict arg peerNodeId
  return routes[peerNodeId~string~strip]

::method request
  expose routes readiness lastFailure
  use strict arg peerNodeId,request
  lastFailure=''
  peer=peerNodeId~string~strip
  route=routes[peer]
  if route==.nil then do
    lastFailure='ROUTE_NOT_FOUND'
    return .nil
  end
  if request==.nil then do
    lastFailure='REQUEST_REQUIRED'
    return .nil
  end
  if \request~isA(.Directory) then do
    lastFailure='REQUEST_INVALID'
    return .nil
  end
  toNode=.ClusterObjectCodec~value(request,'to_node','')~string~strip
  if toNode<>peer then do
    lastFailure='DESTINATION_ROUTE_MISMATCH'
    return .nil
  end
  operation=.ClusterObjectCodec~value(request,'operation','')~string~upper
  if operation=.ClusterObjectOperation~MOVE then do
    memoryTarget=request['memory_target']
    if memoryTarget==.nil then do
      lastFailure='MEMORY_TARGET_REQUIRED'
      return .nil
    end
    if \memoryTarget~isA(.Directory) then do
      lastFailure='MEMORY_TARGET_INVALID'
      return .nil
    end
    providerId=.ClusterObjectCodec~value(memoryTarget,'provider_id','')~string~strip
    if providerId='' then do
      lastFailure='MEMORY_PROVIDER_REQUIRED'
      return .nil
    end
    if \route~allowsProvider(providerId) then do
      lastFailure='MEMORY_PROVIDER_ROUTE_MISMATCH'
      return .nil
    end
  end
  permitted=readiness~allow(route,request)
  if permitted<>.true then do
    lastFailure='XTP_ROUTE_NOT_READY'
    return .nil
  end
  response=route~clientTransport~request(peer,request)
  if response==.nil then lastFailure='QUEUE_XTP_REQUEST_UNCERTAIN'
  return response

::requires 'ClusterObjectMemoryFabricTransport.cls'
::requires 'ObjectQueueChannels.cls'
::requires 'QueueXtpSessionWire.cls'
::requires 'QueueXtpReceiptGate.cls'
