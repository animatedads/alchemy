/* InstrumentationFabricAdapters.cls
 * Read-only instrumentation projections for current Queue, Memory and Storage
 * Fabric objects.  Each adapter uses public object methods only; it does not
 * acquire the underlying fabric's authority or mutate service state.
 *
 * API: instrumentation.mesh/0.1
 */

::class InstrumentationAdapterSupport public
::method dims class
  use strict arg pairs=.nil
  d=.directory~new
  if pairs==.nil then return d
  do i=1 to pairs~items by 2
    d[pairs[i]~string]=pairs[i+1]
  end
  return d

::method sample class
  use strict arg name,kind,unit,value,observedAt,dims=.nil
  return .InstrumentationCodec~sample(name,kind,unit,value,observedAt,dims)

/* ---------------------------------------------------------------------- */
/* Queue Fabric projection.  Queue identity remains Queue Fabric authority;
 * this class merely observes public queue/channel counters and states. */
::class QueueFabricInstrumentationSource public
::method init
  expose identity manager channels sequence
  use strict arg identityArg,managerArg,channelsArg=.nil
  if identityArg==.nil | managerArg==.nil then raise syntax 88.900 array("Queue instrumentation requires identity and manager")
  identity=identityArg; manager=managerArg; channels=channelsArg; sequence=0

::method snapshot
  expose identity manager channels sequence
  use strict arg observedAt=""
  sequence+=1
  samples=.array~new
  queues=manager~queues
  totalReady=0; totalInflight=0; totalDepth=0
  do q over queues
    ready=q~readyDepth; inflight=q~inflightDepth; depth=q~totalDepth
    totalReady+=ready; totalInflight+=inflight; totalDepth+=depth
    dims=.InstrumentationAdapterSupport~dims(.array~of("queue",q~name,"security_domain",q~securityDomain,"state",q~state))
    samples~append(.InstrumentationAdapterSupport~sample(.InstrumentationVocabulary~QUEUE_READY_DEPTH,.InstrumentationMetricKind~GAUGE,"messages",ready,observedAt,dims))
    samples~append(.InstrumentationAdapterSupport~sample(.InstrumentationVocabulary~QUEUE_INFLIGHT_DEPTH,.InstrumentationMetricKind~GAUGE,"messages",inflight,observedAt,dims))
    samples~append(.InstrumentationAdapterSupport~sample(.InstrumentationVocabulary~QUEUE_DEPTH,.InstrumentationMetricKind~GAUGE,"messages",depth,observedAt,dims))
  end
  samples~append(.InstrumentationAdapterSupport~sample(.InstrumentationVocabulary~QUEUE_COUNT,.InstrumentationMetricKind~GAUGE,"queues",queues~items,observedAt))
  samples~append(.InstrumentationAdapterSupport~sample(.InstrumentationVocabulary~QUEUE_READY_DEPTH,.InstrumentationMetricKind~GAUGE,"messages",totalReady,observedAt))
  samples~append(.InstrumentationAdapterSupport~sample(.InstrumentationVocabulary~QUEUE_INFLIGHT_DEPTH,.InstrumentationMetricKind~GAUGE,"messages",totalInflight,observedAt))
  samples~append(.InstrumentationAdapterSupport~sample(.InstrumentationVocabulary~QUEUE_DEPTH,.InstrumentationMetricKind~GAUGE,"messages",totalDepth,observedAt))
  samples~append(.InstrumentationAdapterSupport~sample(.InstrumentationVocabulary~QUEUE_TRAFFIC_EVENTS_TOTAL,.InstrumentationMetricKind~COUNTER,"events",manager~traffic~items,observedAt))
  samples~append(.InstrumentationAdapterSupport~sample(.InstrumentationVocabulary~QUEUE_UOW_ACTIVE,.InstrumentationMetricKind~GAUGE,"units",manager~activeUnitOfWorkCount,observedAt))
  samples~append(.InstrumentationAdapterSupport~sample(.InstrumentationVocabulary~QUEUE_TRANSFER_RECEIPTS_TOTAL,.InstrumentationMetricKind~COUNTER,"receipts",manager~transferReceiptCount,observedAt))
  if channels<>.nil then self~appendChannelSamples(samples,observedAt)
  return .InstrumentationCodec~snapshot(.InstrumentationCodec~copyDirectory(identity),.InstrumentationHealth~HEALTHY,samples,observedAt,.array~new,sequence)

::method appendChannelSamples
  expose channels
  use strict arg samples,observedAt
  do c over channels~senderChannels
    dims=.InstrumentationAdapterSupport~dims(.array~of("channel",c~channelName,"direction","SEND","state",c~state,"remote_manager",c~remoteManager))
    samples~append(.InstrumentationAdapterSupport~sample(.InstrumentationVocabulary~QUEUE_CHANNEL_SENT_TOTAL,.InstrumentationMetricKind~COUNTER,"messages",c~sentCount,observedAt,dims))
  end
  do c over channels~receiverChannels
    dims=.InstrumentationAdapterSupport~dims(.array~of("channel",c~channelName,"direction","RECEIVE","state",c~state,"source_manager",c~sourceManager))
    samples~append(.InstrumentationAdapterSupport~sample(.InstrumentationVocabulary~QUEUE_CHANNEL_RECEIVED_TOTAL,.InstrumentationMetricKind~COUNTER,"messages",c~receivedCount,observedAt,dims))
    samples~append(.InstrumentationAdapterSupport~sample(.InstrumentationVocabulary~QUEUE_CHANNEL_REJECTED_TOTAL,.InstrumentationMetricKind~COUNTER,"messages",c~rejectedCount,observedAt,dims))
  end
  return samples

/* ---------------------------------------------------------------------- */
/* Memory Fabric projection.  Provider membership and capacity remain Memory
 * Fabric facts; no allocation or failover decision is made here. */
::class MemoryFabricInstrumentationSource public
::method init
  expose identity fabric sequence
  use strict arg identityArg,fabricArg
  if identityArg==.nil | fabricArg==.nil then raise syntax 88.900 array("Memory instrumentation requires identity and fabric")
  identity=identityArg; fabric=fabricArg; sequence=0

::method snapshot
  expose identity fabric sequence
  use strict arg observedAt=""
  numeric digits 20
  sequence+=1
  samples=.array~new
  providers=fabric~providers
  totalCapacity=0; totalCommitted=0; totalAvailable=0; usable=0
  do p over providers
    capacity=p~capacityBytes; committed=p~committedBytes; available=p~availableBytes
    totalCapacity+=capacity; totalCommitted+=committed; totalAvailable+=available
    if p~providerState<>"OFFLINE" then usable+=1
    dims=.InstrumentationAdapterSupport~dims(.array~of("provider_id",p~providerId,"provider_kind",p~kind,"mu_id",p~muId,"mi_id",p~miId,"site_id",p~siteId,"machine_id",p~machineId,"provider_state",p~providerState,"allocation_state",p~allocationState))
    samples~append(.InstrumentationAdapterSupport~sample(.InstrumentationVocabulary~MEMORY_CAPACITY_BYTES,.InstrumentationMetricKind~GAUGE,"bytes",capacity,observedAt,dims))
    samples~append(.InstrumentationAdapterSupport~sample(.InstrumentationVocabulary~MEMORY_COMMITTED_BYTES,.InstrumentationMetricKind~GAUGE,"bytes",committed,observedAt,dims))
    samples~append(.InstrumentationAdapterSupport~sample(.InstrumentationVocabulary~MEMORY_AVAILABLE_BYTES,.InstrumentationMetricKind~GAUGE,"bytes",available,observedAt,dims))
  end
  samples~append(.InstrumentationAdapterSupport~sample(.InstrumentationVocabulary~MEMORY_PROVIDER_COUNT,.InstrumentationMetricKind~GAUGE,"providers",providers~items,observedAt))
  samples~append(.InstrumentationAdapterSupport~sample(.InstrumentationVocabulary~MEMORY_MANAGED_BYTES,.InstrumentationMetricKind~GAUGE,"bytes",totalCapacity,observedAt))
  samples~append(.InstrumentationAdapterSupport~sample(.InstrumentationVocabulary~MEMORY_RESIDENT_BYTES,.InstrumentationMetricKind~GAUGE,"bytes",totalCommitted,observedAt))
  samples~append(.InstrumentationAdapterSupport~sample(.InstrumentationVocabulary~MEMORY_AVAILABLE_BYTES,.InstrumentationMetricKind~GAUGE,"bytes",totalAvailable,observedAt))
  health=.InstrumentationHealth~UNKNOWN
  if providers~items>0 then do
    health=.InstrumentationHealth~HEALTHY
    if usable=0 then health=.InstrumentationHealth~DEGRADED
  end
  return .InstrumentationCodec~snapshot(.InstrumentationCodec~copyDirectory(identity),health,samples,observedAt,.array~new,sequence)

/* ---------------------------------------------------------------------- */
/* Storage Fabric projection.  Pool/capacity values are observations, not
 * allocation authority.  If a node id is supplied, only pools admitted for
 * that node are projected. */
::class StorageFabricInstrumentationSource public
::method init
  expose identity manager nodeId sequence
  use strict arg identityArg,managerArg,nodeIdArg=""
  if identityArg==.nil | managerArg==.nil then raise syntax 88.900 array("Storage instrumentation requires identity and manager")
  identity=identityArg; manager=managerArg
  nodeId=nodeIdArg~string~strip
  if nodeId="" then nodeId=.InstrumentationCodec~value(identity,"node_id","")~string~strip
  sequence=0

::method snapshot
  expose identity manager nodeId sequence
  use strict arg observedAt=""
  numeric digits 20
  sequence+=1
  samples=.array~new
  workspace=manager~workspace
  pools=workspace~poolsForNode(nodeId)
  domainFloors=.directory~new

  /* Pool availability is a pool view.  Physical capacity and reservations are
   * capacity-domain facts and must not be summed once per pool. */
  do p over pools
    domain=p~capacityDomainId
    floor=domainFloors[domain]
    if floor==.nil | p~safetyFloorBytes>floor then domainFloors[domain]=p~safetyFloorBytes
    poolAvailable=workspace~availableForPool(p~poolId)
    dims=.InstrumentationAdapterSupport~dims(.array~of("pool_id",p~poolId,"provider_id",p~providerId,"capacity_domain",domain,"node_id",p~nodeId,"region",p~region,"mode",p~mode,"safety_class",p~lifecycle~safetyClass,"lifecycle_state",p~lifecycle~state))
    samples~append(.InstrumentationAdapterSupport~sample(.InstrumentationVocabulary~STORAGE_WORKSPACE_AVAILABLE_BYTES,.InstrumentationMetricKind~GAUGE,"bytes",poolAvailable,observedAt,dims))
  end

  capacity=0; free=0; available=0; reserved=0
  do domain over domainFloors
    observation=workspace~observation(domain)
    domainReserved=workspace~reservedForDomain(domain)
    total=0; domainFree=0
    if observation<>.nil then do; total=observation~totalBytes; domainFree=observation~freeBytes; end
    domainAvailable=domainFree-domainReserved-domainFloors[domain]
    if domainAvailable<0 then domainAvailable=0
    capacity+=total; free+=domainFree; reserved+=domainReserved; available+=domainAvailable
    dims=.InstrumentationAdapterSupport~dims(.array~of("capacity_domain",domain,"node_id",nodeId))
    samples~append(.InstrumentationAdapterSupport~sample(.InstrumentationVocabulary~STORAGE_CAPACITY_BYTES,.InstrumentationMetricKind~GAUGE,"bytes",total,observedAt,dims))
    samples~append(.InstrumentationAdapterSupport~sample(.InstrumentationVocabulary~STORAGE_FREE_BYTES,.InstrumentationMetricKind~GAUGE,"bytes",domainFree,observedAt,dims))
    samples~append(.InstrumentationAdapterSupport~sample(.InstrumentationVocabulary~STORAGE_WORKSPACE_RESERVED_BYTES,.InstrumentationMetricKind~GAUGE,"bytes",domainReserved,observedAt,dims))
    samples~append(.InstrumentationAdapterSupport~sample(.InstrumentationVocabulary~STORAGE_WORKSPACE_AVAILABLE_BYTES,.InstrumentationMetricKind~GAUGE,"bytes",domainAvailable,observedAt,dims))
  end

  allocations=workspace~allocations
  activeAllocations=0
  do a over allocations
    if a~state="ACTIVE" then activeAllocations+=1
  end
  samples~append(.InstrumentationAdapterSupport~sample(.InstrumentationVocabulary~STORAGE_CATALOGUE_OBJECTS,.InstrumentationMetricKind~GAUGE,"objects",manager~catalogue~count,observedAt))
  samples~append(.InstrumentationAdapterSupport~sample(.InstrumentationVocabulary~STORAGE_POOL_COUNT,.InstrumentationMetricKind~GAUGE,"pools",pools~items,observedAt))
  samples~append(.InstrumentationAdapterSupport~sample(.InstrumentationVocabulary~STORAGE_CAPACITY_BYTES,.InstrumentationMetricKind~GAUGE,"bytes",capacity,observedAt))
  samples~append(.InstrumentationAdapterSupport~sample(.InstrumentationVocabulary~STORAGE_FREE_BYTES,.InstrumentationMetricKind~GAUGE,"bytes",free,observedAt))
  samples~append(.InstrumentationAdapterSupport~sample(.InstrumentationVocabulary~STORAGE_WORKSPACE_AVAILABLE_BYTES,.InstrumentationMetricKind~GAUGE,"bytes",available,observedAt))
  samples~append(.InstrumentationAdapterSupport~sample(.InstrumentationVocabulary~STORAGE_WORKSPACE_RESERVED_BYTES,.InstrumentationMetricKind~GAUGE,"bytes",reserved,observedAt))
  samples~append(.InstrumentationAdapterSupport~sample(.InstrumentationVocabulary~STORAGE_ALLOCATION_COUNT,.InstrumentationMetricKind~GAUGE,"allocations",activeAllocations,observedAt))
  return .InstrumentationCodec~snapshot(.InstrumentationCodec~copyDirectory(identity),.InstrumentationHealth~HEALTHY,samples,observedAt,.array~new,sequence)

::requires "InstrumentationMesh.cls"
