/* StorageInstrumentationMesh.cls
 * Storage Fabric -> Instrumentation Mesh integration.
 * API: storage.fabric.instrumentation/0.1
 *
 * Storage Fabric remains authoritative for object identity, locations,
 * durability policy, repair, placement and mutation.  This package only
 * projects bounded operational observations through instrumentation.mesh/0.1.
 */

::class StorageInstrumentationBuild public
::constant VERSION "0.1-dev7"
::constant API "storage.fabric.instrumentation/0.1"
::constant MESH_API "instrumentation.mesh/0.1"

::class StorageInstrumentationMetric public
::constant REPLICA_OBJECTS_TOTAL "storage.replica.objects.total"
::constant REPLICA_OBJECTS_PROTECTED "storage.replica.objects.protected"
::constant REPLICA_OBJECTS_DEGRADED "storage.replica.objects.degraded"
::constant REPLICA_OBJECTS_POLICY_MISSING "storage.replica.objects.policy_missing"
::constant REPLICA_DEGRADED_REASON "storage.replica.degraded.reason"
::constant DURABLE_LOCATIONS "storage.replica.locations.durable"
::constant AVAILABLE_LOCATIONS "storage.location.available"
::constant OFFLINE_LOCATIONS "storage.location.offline"
::constant SAFE_LOCATIONS "storage.location.safe"
::constant DISPOSABLE_LOCATIONS "storage.location.disposable"
::constant DISTINCT_VENDORS "storage.replica.distinct_vendors"
::constant DISTINCT_SITES "storage.replica.distinct_sites"
::constant DISTINCT_FAILURE_DOMAINS "storage.replica.distinct_failure_domains"
::constant REPAIR_REQUIRED_TOTAL "storage.replica.repair.required.total"
::constant REPAIR_SATISFIED_TOTAL "storage.replica.repair.satisfied.total"
::constant TRANSFER_STARTED_TOTAL "storage.transfer.started.total"
::constant TRANSFER_COMPLETED_TOTAL "storage.transfer.completed.total"
::constant TRANSFER_FAILED_TOTAL "storage.transfer.failed.total"
::constant TRANSFER_BYTES_TOTAL "storage.transfer.bytes.total"
::constant PROVIDER_TRANSITIONS_TOTAL "storage.provider.transitions.total"
::constant AUTHORITY_CHECKPOINT_TOTAL "storage.authority.checkpoint.total"
::constant AUTHORITY_RECOVERY_TOTAL "storage.authority.recovery.total"
::constant GIT_STORE_TOTAL "storage.git.store.total"
::constant GIT_STORE_FAILED_TOTAL "storage.git.store.failed.total"
::constant GIT_CHUNKS_WRITTEN_TOTAL "storage.git.chunks.written.total"
::constant GIT_CHUNKS_REUSED_TOTAL "storage.git.chunks.reused.total"
::constant GIT_MATERIALISE_TOTAL "storage.git.materialise.total"
::constant GIT_MATERIALISE_FAILED_TOTAL "storage.git.materialise.failed.total"
::constant REASON_INSUFFICIENT_REPLICAS "INSUFFICIENT_REPLICAS"
::constant REASON_INSUFFICIENT_VENDOR_DIVERSITY "INSUFFICIENT_VENDOR_DIVERSITY"
::constant REASON_INSUFFICIENT_SITE_DIVERSITY "INSUFFICIENT_SITE_DIVERSITY"
::constant REASON_INSUFFICIENT_FAILURE_DOMAIN_DIVERSITY "INSUFFICIENT_FAILURE_DOMAIN_DIVERSITY"

/* Event/progress facade.  It intentionally accepts only bounded operational
 * identifiers and low-cardinality dimensions.  StorageRef ids, paths, tokens,
 * credentials and arbitrary provider locators must not be used as dimensions. */
::class StorageFabricMeshEvents public
::attribute emitter get
::method init
  expose emitter
  use strict arg identityArg
  if identityArg==.nil then raise syntax 88.900 array("STORAGE_INSTRUMENTATION_IDENTITY_REQUIRED")
  emitter=.InstrumentationEmitter~new(identityArg)
  emitter~setHealth(.InstrumentationHealth~STARTING)

::method healthy
  expose emitter
  emitter~setHealth(.InstrumentationHealth~HEALTHY); return self
::method degraded
  expose emitter
  emitter~setHealth(.InstrumentationHealth~DEGRADED); return self
::method stopping
  expose emitter
  emitter~setHealth(.InstrumentationHealth~STOPPING); return self

::method repairRequired
  expose emitter
  use strict arg operationId="", reason=""
  dims=.directory~new
  if reason<>"" then dims["reason"]=reason~string~upper
  emitter~counterAdd(.StorageInstrumentationMetric~REPAIR_REQUIRED_TOTAL,1,"repairs",dims)
  if operationId<>"" then emitter~progress(operationId,"REPAIR_REQUIRED",0,1,"repairs","",reason)
  emitter~setHealth(.InstrumentationHealth~DEGRADED)
  return self

::method repairSatisfied
  expose emitter
  use strict arg operationId=""
  emitter~counterAdd(.StorageInstrumentationMetric~REPAIR_SATISFIED_TOTAL,1,"repairs")
  if operationId<>"" then emitter~clearProgress(operationId)
  return self

::method transferStarted
  expose emitter
  use strict arg transferId,totalBytes=0
  emitter~counterAdd(.StorageInstrumentationMetric~TRANSFER_STARTED_TOTAL,1,"transfers")
  emitter~progress(transferId,"COPYING",0,totalBytes,"bytes")
  return self

::method transferProgress
  expose emitter
  use strict arg transferId,currentBytes,totalBytes
  emitter~progress(transferId,"COPYING",currentBytes,totalBytes,"bytes")
  return self

::method transferCompleted
  expose emitter
  use strict arg transferId,bytes=0
  emitter~counterAdd(.StorageInstrumentationMetric~TRANSFER_COMPLETED_TOTAL,1,"transfers")
  if datatype(bytes,"W") then if bytes>=0 then emitter~counterAdd(.StorageInstrumentationMetric~TRANSFER_BYTES_TOTAL,bytes,"bytes")
  emitter~clearProgress(transferId)
  return self

::method transferFailed
  expose emitter
  use strict arg transferId,code=""
  emitter~counterAdd(.StorageInstrumentationMetric~TRANSFER_FAILED_TOTAL,1,"transfers")
  emitter~progress(transferId,"FAILED",0,0,"bytes","",code)
  emitter~setHealth(.InstrumentationHealth~DEGRADED)
  return self

::method providerTransition
  expose emitter
  use strict arg providerKind="",state=""
  dims=.directory~new
  if providerKind<>"" then dims["provider_kind"]=providerKind~string~upper
  if state<>"" then dims["state"]=state~string~upper
  emitter~counterAdd(.StorageInstrumentationMetric~PROVIDER_TRANSITIONS_TOTAL,1,"transitions",dims)
  return self

::method authorityCheckpoint
  expose emitter
  use strict arg operationId=""
  emitter~counterAdd(.StorageInstrumentationMetric~AUTHORITY_CHECKPOINT_TOTAL,1,"checkpoints")
  if operationId<>"" then emitter~progress(operationId,"CHECKPOINT_COMMITTED",1,1,"checkpoints")
  return self

::method authorityRecovered
  expose emitter
  use strict arg operationId=""
  emitter~counterAdd(.StorageInstrumentationMetric~AUTHORITY_RECOVERY_TOTAL,1,"recoveries")
  if operationId<>"" then emitter~progress(operationId,"RECOVERED",1,1,"recoveries")
  return self

::method gitStoreCompleted
  expose emitter
  use strict arg chunksWritten=0,chunksReused=0
  emitter~counterAdd(.StorageInstrumentationMetric~GIT_STORE_TOTAL,1,"operations")
  emitter~counterAdd(.StorageInstrumentationMetric~GIT_CHUNKS_WRITTEN_TOTAL,chunksWritten,"chunks")
  emitter~counterAdd(.StorageInstrumentationMetric~GIT_CHUNKS_REUSED_TOTAL,chunksReused,"chunks")
  return self

::method gitStoreFailed
  expose emitter
  emitter~counterAdd(.StorageInstrumentationMetric~GIT_STORE_FAILED_TOTAL,1,"operations")
  emitter~setHealth(.InstrumentationHealth~DEGRADED)
  return self

::method gitMaterialiseCompleted
  expose emitter
  use strict arg bytes=0
  emitter~counterAdd(.StorageInstrumentationMetric~GIT_MATERIALISE_TOTAL,1,"operations")
  if datatype(bytes,"W") then if bytes>=0 then emitter~counterAdd(.StorageInstrumentationMetric~TRANSFER_BYTES_TOTAL,bytes,"bytes")
  return self

::method gitMaterialiseFailed
  expose emitter
  emitter~counterAdd(.StorageInstrumentationMetric~GIT_MATERIALISE_FAILED_TOTAL,1,"operations")
  emitter~setHealth(.InstrumentationHealth~DEGRADED)
  return self

::method snapshot
  expose emitter
  use strict arg observedAt=""
  return emitter~snapshot(observedAt)

/* Composite source: keeps the estate's existing StorageFabricInstrumentationSource
 * intact and merges richer protection/repair observations into one normal Mesh
 * source.  authorityArg is optional and, when present, is expected to expose the
 * storage.fabric.authority/0.1 StorageAuthoritySnapshot contract. */
::class StorageFabricMeshSource public
::attribute events get
::method init
  expose base manager authority policy events sequence fallbackRequirement
  use strict arg identityArg, managerArg, nodeIdArg="", authorityArg=.nil, fallbackRequirementArg=.nil
  if identityArg==.nil | managerArg==.nil then raise syntax 88.900 array("STORAGE_INSTRUMENTATION_IDENTITY_MANAGER_REQUIRED")
  manager=managerArg; authority=authorityArg; fallbackRequirement=fallbackRequirementArg
  policy=.StorageReplicaPolicy~new
  base=.StorageFabricInstrumentationSource~new(identityArg,managerArg,nodeIdArg)
  events=.StorageFabricMeshEvents~new(identityArg)
  sequence=0

::method replicaRequirement private
  expose authority fallbackRequirement
  use strict arg object
  if authority<>.nil then do
    book=authority~replicaPolicies
    if book<>.nil then do
      req=book~get(object~ref~objectId)
      if req<>.nil then return req
    end
  end
  /* Missing protection policy is observable uncertainty, not permission to
   * pretend one replica is enough. An estate fallback must be injected. */
  return fallbackRequirement

::method appendProtectionSamples private
  expose manager policy
  use strict arg samples,observedAt
  objects=manager~catalogue~all
  objectCount=0; protected=0; degraded=0; policyMissing=0; durable=0
  available=0; offline=0; safe=0; disposable=0
  vendors=.directory~new; sites=.directory~new; domains=.directory~new
  reasons=.directory~new

  do object over objects
    objectCount+=1
    req=self~replicaRequirement(object)
    if req==.nil then policyMissing+=1
    else do
      assessment=policy~assess(object,req)
      if assessment~satisfied then protected+=1
      else do
        degraded+=1
        reason=assessment~reason~string~upper
        old=reasons[reason]; if old==.nil then old=0
        reasons[reason]=old+1
      end
    end

    do loc over object~locations
      if loc~state=.StorageLocationState~AVAILABLE then available+=1
      else if loc~state=.StorageLocationState~OFFLINE then offline+=1
      if loc~safetyClass=.StorageSafetyClass~SAFE then safe+=1
      else if loc~safetyClass=.StorageSafetyClass~DISPOSABLE then disposable+=1
      if loc~countsAsDurable then do
        durable+=1
        if loc~vendorId<>"" then vendors[loc~vendorId]=1
        if loc~siteId<>"" then sites[loc~siteId]=1
        if loc~failureDomainId<>"" then domains[loc~failureDomainId]=1
      end
    end
  end

  samples~append(.InstrumentationCodec~sample(.StorageInstrumentationMetric~REPLICA_OBJECTS_TOTAL,.InstrumentationMetricKind~GAUGE,"objects",objectCount,observedAt))
  samples~append(.InstrumentationCodec~sample(.StorageInstrumentationMetric~REPLICA_OBJECTS_PROTECTED,.InstrumentationMetricKind~GAUGE,"objects",protected,observedAt))
  samples~append(.InstrumentationCodec~sample(.StorageInstrumentationMetric~REPLICA_OBJECTS_DEGRADED,.InstrumentationMetricKind~GAUGE,"objects",degraded,observedAt))
  samples~append(.InstrumentationCodec~sample(.StorageInstrumentationMetric~REPLICA_OBJECTS_POLICY_MISSING,.InstrumentationMetricKind~GAUGE,"objects",policyMissing,observedAt))
  do reason over reasons
    dims=.directory~new; dims["reason"]=reason
    samples~append(.InstrumentationCodec~sample(.StorageInstrumentationMetric~REPLICA_DEGRADED_REASON,.InstrumentationMetricKind~GAUGE,"objects",reasons[reason],observedAt,dims))
  end
  samples~append(.InstrumentationCodec~sample(.StorageInstrumentationMetric~DURABLE_LOCATIONS,.InstrumentationMetricKind~GAUGE,"locations",durable,observedAt))
  samples~append(.InstrumentationCodec~sample(.StorageInstrumentationMetric~AVAILABLE_LOCATIONS,.InstrumentationMetricKind~GAUGE,"locations",available,observedAt))
  samples~append(.InstrumentationCodec~sample(.StorageInstrumentationMetric~OFFLINE_LOCATIONS,.InstrumentationMetricKind~GAUGE,"locations",offline,observedAt))
  samples~append(.InstrumentationCodec~sample(.StorageInstrumentationMetric~SAFE_LOCATIONS,.InstrumentationMetricKind~GAUGE,"locations",safe,observedAt))
  samples~append(.InstrumentationCodec~sample(.StorageInstrumentationMetric~DISPOSABLE_LOCATIONS,.InstrumentationMetricKind~GAUGE,"locations",disposable,observedAt))
  samples~append(.InstrumentationCodec~sample(.StorageInstrumentationMetric~DISTINCT_VENDORS,.InstrumentationMetricKind~GAUGE,"vendors",vendors~items,observedAt))
  samples~append(.InstrumentationCodec~sample(.StorageInstrumentationMetric~DISTINCT_SITES,.InstrumentationMetricKind~GAUGE,"sites",sites~items,observedAt))
  samples~append(.InstrumentationCodec~sample(.StorageInstrumentationMetric~DISTINCT_FAILURE_DOMAINS,.InstrumentationMetricKind~GAUGE,"failure_domains",domains~items,observedAt))
  return degraded+policyMissing

::method snapshot
  expose base events sequence
  use strict arg observedAt=""
  sequence+=1
  static=base~snapshot(observedAt)
  samples=static["samples"]; if samples==.nil then samples=.array~new
  degraded=self~appendProtectionSamples(samples,observedAt)

  dynamic=events~snapshot(observedAt)
  ds=dynamic["samples"]
  if ds<>.nil then do sample over ds; samples~append(sample); end
  progress=dynamic["progress"]; if progress==.nil then progress=.array~new

  health=static["health"]
  if dynamic["health"]=.InstrumentationHealth~STOPPING then health=.InstrumentationHealth~STOPPING
  else if degraded>0 | dynamic["health"]=.InstrumentationHealth~DEGRADED then health=.InstrumentationHealth~DEGRADED
  else if dynamic["health"]=.InstrumentationHealth~STARTING then health=.InstrumentationHealth~STARTING
  else health=.InstrumentationHealth~HEALTHY

  return .InstrumentationCodec~snapshot(static["identity"],health,samples,observedAt,progress,sequence)


/* -------------------------------------------------------------------------
 * dev3 boundary hooks
 *
 * These classes make instrumentation an ordinary dependency passed to the
 * semantic operation boundary.  They deliberately do not monkey-patch Storage
 * Fabric classes and do not acquire Storage authority.  Storage dev23 can use
 * them at construction/commit points; older Storage lines can opt in through
 * the same factories without changing their public APIs.
 * ---------------------------------------------------------------------- */

::class StorageInstrumentationHooks public
::attribute events get
::method init
  expose events
  use strict arg eventsArg
  if eventsArg==.nil then raise syntax 88.900 array("STORAGE_INSTRUMENTATION_EVENTS_REQUIRED")
  events=eventsArg

::method newTransfer
  expose events
  use strict arg idArg,refArg,sourceArg,targetProviderArg,targetLocatorArg="",sizeArg=0
  return .StorageInstrumentedTransfer~new(idArg,refArg,sourceArg,targetProviderArg,targetLocatorArg,sizeArg,events)

::method repairRequired
  expose events
  use strict arg operationId="",reason=""
  events~repairRequired(operationId,reason); return self

::method repairSatisfied
  expose events
  use strict arg operationId=""
  events~repairSatisfied(operationId); return self

::method providerTransition
  expose events
  use strict arg providerKind="",state=""
  events~providerTransition(providerKind,state); return self

::method authorityCheckpoint
  expose events
  use strict arg operationId=""
  events~authorityCheckpoint(operationId); return self

::method authorityRecovered
  expose events
  use strict arg operationId=""
  events~authorityRecovered(operationId); return self

::method gitStoreCompleted
  expose events
  use strict arg chunksWritten=0,chunksReused=0
  events~gitStoreCompleted(chunksWritten,chunksReused); return self

::method gitStoreFailed
  expose events
  events~gitStoreFailed; return self

::method gitMaterialiseCompleted
  expose events
  use strict arg bytes=0
  events~gitMaterialiseCompleted(bytes); return self

::method gitMaterialiseFailed
  expose events
  events~gitMaterialiseFailed; return self

/* Transfer state itself is still owned by StorageTransfer.  This subclass only
 * observes successful state transitions and emits Mesh progress/counters after
 * the Storage state change has succeeded.  Failed attempts do not fabricate
 * progress. */
::class StorageInstrumentedTransfer subclass StorageTransfer public
::method init
  expose instrumentationEvents instrumentationStarted
  use strict arg idArg,refArg,sourceArg,targetProviderArg,targetLocatorArg="",sizeArg=0,eventsArg=.nil
  self~init:super(idArg,refArg,sourceArg,targetProviderArg,targetLocatorArg,sizeArg)
  instrumentationEvents=eventsArg
  instrumentationStarted=.false

::method begin
  expose instrumentationEvents instrumentationStarted
  result=self~begin:super
  if result then do
    if instrumentationEvents<>.nil then do
      instrumentationEvents~transferStarted(self~transferId,self~sizeBytes)
      instrumentationStarted=.true
    end
  end
  return result

::method progress
  expose instrumentationEvents instrumentationStarted
  use strict arg bytesArg
  result=self~progress:super(bytesArg)
  if result then do
    if instrumentationEvents<>.nil then do
      if instrumentationStarted then -
        instrumentationEvents~transferProgress(self~transferId,self~bytesTransferred,self~sizeBytes)
    end
  end
  return result

::method copied
  return self~copied:super

::method verify
  use strict arg verificationArg
  return self~verify:super(verificationArg)

::method commit
  expose instrumentationEvents instrumentationStarted
  result=self~commit:super
  if result then do
    if instrumentationEvents<>.nil then do
      if instrumentationStarted then do
        instrumentationEvents~transferCompleted(self~transferId,self~bytesTransferred)
        instrumentationStarted=.false
      end
    end
  end
  return result

::method fail
  expose instrumentationEvents instrumentationStarted
  use strict arg reasonArg
  result=self~fail:super(reasonArg)
  if instrumentationEvents<>.nil then do
    if instrumentationStarted then do
      instrumentationEvents~transferFailed(self~transferId,reasonArg)
      instrumentationStarted=.false
    end
  end
  return result

/* Some current streaming paths finish at VERIFIED and intentionally leave
 * COMMIT to the catalogue/provider admission boundary.  This observer bridges
 * that explicit boundary rather than declaring a transfer complete early. */
::class StorageTransferCommitObserver public
::attribute events get
::method init
  expose events
  use strict arg eventsArg
  events=eventsArg
::method committed
  expose events
  use strict arg transfer
  if transfer==.nil then return .false
  if transfer~state<>.StorageTransferState~COMMITTED then return .false
  events~transferCompleted(transfer~transferId,transfer~bytesTransferred)
  return .true

/* Low-cardinality provider state watcher.  The provider identity remains in
 * Storage; Mesh receives provider kind and state only. */
::class StorageProviderStateObserver public
::attribute events get
::attribute lastStates get
::method init
  expose events lastStates
  use strict arg eventsArg
  events=eventsArg; lastStates=.directory~new
::method observe
  expose events lastStates
  use strict arg providerIdArg,providerKindArg,stateArg
  providerId=providerIdArg~string; state=stateArg~string~upper
  previous=lastStates[providerId]
  if previous==.nil | previous<>state then do
    lastStates[providerId]=state
    events~providerTransition(providerKindArg,state)
    return .true
  end
  return .false


::requires "StorageFabric.cls"
::requires "InstrumentationMesh.cls"
::requires "InstrumentationFabricAdapters.cls"
