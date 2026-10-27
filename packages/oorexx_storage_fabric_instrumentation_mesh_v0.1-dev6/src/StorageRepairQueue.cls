/* StorageRepairQueue.cls
 * Durable replica-repair submission seam for Storage Fabric.
 * API: storage.fabric.repair.queue/0.1
 *
 * Queue Fabric owns durable delivery/recovery. Storage Fabric owns whether
 * repair is required, target eligibility, transfer verification and replica
 * admission. Instrumentation Mesh only observes those semantic transitions.
 */

::class StorageRepairQueueBuild public
::constant VERSION "0.1-dev6"
::constant API "storage.fabric.repair.queue/0.1"
::constant WORK_SCHEMA "storage.fabric.repair.work/1"
::constant QUEUE_DEFAULT "STORAGE.REPAIR"
::constant SECURITY_DOMAIN "STORAGE.REPAIR"

::class StorageRepairWork public
::attribute repairId get
::attribute objectId get
::attribute reason get
::attribute requirement get
::attribute policyRevision get
::attribute createdAt get
::attribute preferredProviderKind get
::attribute metadata get

::method init
  expose repairId objectId reason requirement policyRevision createdAt preferredProviderKind metadata
  use strict arg repairIdArg,objectIdArg,reasonArg,requirementArg=.nil,policyRevisionArg="",preferredProviderKindArg="",metadataArg=.nil
  repairId=repairIdArg~string~strip
  objectId=objectIdArg~string~strip
  reason=reasonArg~string~upper~strip
  if repairId="" | objectId="" | reason="" then raise syntax 88.900 array("STORAGE_REPAIR_ID_OBJECT_REASON_REQUIRED")
  requirement=requirementArg
  policyRevision=policyRevisionArg~string
  preferredProviderKind=preferredProviderKindArg~string~upper
  if metadataArg==.nil then metadata=.directory~new
  else metadata=metadataArg
  createdAt=.DateTime~new~string

::method payload
  expose repairId objectId reason requirement policyRevision createdAt preferredProviderKind metadata
  d=.directory~new
  d["schema"]=.StorageRepairQueueBuild~WORK_SCHEMA
  d["kind"]="STORAGE_REPLICA_REPAIR"
  d["repair_id"]=repairId
  d["object_id"]=objectId
  d["reason"]=reason
  d["created_at"]=createdAt
  d["policy_revision"]=policyRevision
  d["preferred_provider_kind"]=preferredProviderKind
  d["metadata"]=metadata
  if requirement<>.nil then do
    r=.directory~new
    r["safe_replicas"]=requirement~requiredReplicas
    r["distinct_vendors"]=requirement~distinctVendors
    r["distinct_sites"]=requirement~distinctSites
    r["distinct_failure_domains"]=requirement~distinctFailureDomains
    d["requirement"]=r
  end
  return d

/* Owns only the durable queue binding. It deliberately receives an existing
 * ObjectQueueManager so it cannot create a second Queue Fabric authority over
 * a live store. */
::class StorageRepairQueueBinding public
::attribute manager get
::attribute queueName get
::attribute adminPrincipal get
::attribute submitPrincipal get
::attribute workerPrincipal get
::attribute instrumentation get

::method init
  expose manager queueName adminPrincipal submitPrincipal workerPrincipal instrumentation
  use strict arg managerArg,queueNameArg=.StorageRepairQueueBuild~QUEUE_DEFAULT,adminPrincipalArg="storage-admin",submitPrincipalArg="storage-repair-submit",workerPrincipalArg="storage-repair-worker",instrumentationArg=.nil
  if managerArg==.nil then raise syntax 88.900 array("STORAGE_REPAIR_QUEUE_MANAGER_REQUIRED")
  manager=managerArg
  queueName=queueNameArg~string
  adminPrincipal=adminPrincipalArg~string
  submitPrincipal=submitPrincipalArg~string
  workerPrincipal=workerPrincipalArg~string
  instrumentation=instrumentationArg

::method ensureQueue
  expose manager queueName adminPrincipal submitPrincipal workerPrincipal
  if manager~queue(queueName)==.nil then do
    r=manager~createQueue(queueName,"PERMANENT",.StorageRepairQueueBuild~SECURITY_DOMAIN,1024,adminPrincipal)
    if r==.nil | \r~ok then return r
  end
  r=manager~grant(queueName,submitPrincipal,.QueueAccess~PUT,adminPrincipal)
  if r==.nil | \r~ok then return r
  /* Worker capability is kept deliberately minimal here. Current Queue Fabric
   * worker adapters may additionally grant CLAIM/ACK/NACK according to their
   * exact package contract. */
  return manager~grant(queueName,workerPrincipal,.QueueAccess~GET,adminPrincipal)

::method submit
  expose manager queueName submitPrincipal instrumentation
  use strict arg work
  if work==.nil | \work~isA(.StorageRepairWork) then raise syntax 88.900 array("STORAGE_REPAIR_WORK_REQUIRED")
  options=.table~new
  options["persistent"]=.true
  options["securityDomain"]=.StorageRepairQueueBuild~SECURITY_DOMAIN
  options["correlationId"]=work~repairId
  headers=.table~new
  headers["storage-repair-schema"]=.StorageRepairQueueBuild~WORK_SCHEMA
  headers["storage-repair-reason"]=work~reason
  options["headers"]=headers
  queueResult=manager~put(queueName,work~payload,options,submitPrincipal)
  if queueResult<>.nil then do
    if queueResult~ok then do
      if instrumentation<>.nil then instrumentation~repairRequired(work~repairId,work~reason)
    end
  end
  return queueResult

/* Semantic execution boundary for an already-claimed queue package. The Queue
 * Fabric worker owns CLAIM/ACK/NACK. This object owns only Storage semantics:
 * re-resolve object, re-assess current policy, repair if still needed, verify,
 * admit, then re-assess. A stale repair request therefore cannot force an
 * unnecessary copy merely because it survived longer than the topology event.
 */
::class StorageRepairExecutionBoundary public
::attribute manager get
::attribute planner get
::attribute instrumentation get
::method init
  expose manager planner instrumentation policy
  use strict arg storageManagerArg,plannerArg,instrumentationArg=.nil
  if storageManagerArg==.nil | plannerArg==.nil then raise syntax 88.900 array("STORAGE_REPAIR_MANAGER_PLANNER_REQUIRED")
  manager=storageManagerArg; planner=plannerArg; instrumentation=instrumentationArg
  policy=.StorageReplicaPolicy~new

::method requirementFromPayload private
  use strict arg payload
  /* Missing policy is not authority to reduce protection to one replica.
   * Repair work must carry the requirement that justified the repair. */
  if payload["requirement"]==.nil then return .nil
  r=payload["requirement"]
  safe=1; vendors=0; sites=0; domains=0
  if r["safe_replicas"]<>.nil then safe=r["safe_replicas"]
  if r["distinct_vendors"]<>.nil then vendors=r["distinct_vendors"]
  if r["distinct_sites"]<>.nil then sites=r["distinct_sites"]
  if r["distinct_failure_domains"]<>.nil then domains=r["distinct_failure_domains"]
  return .StorageReplicaRequirement~new(safe,vendors,sites,domains)

::method execute
  expose manager planner instrumentation policy
  use strict arg payload
  if payload==.nil | \payload~isA(.Directory) then return .StorageRepairResult~failure("INVALID_REPAIR_PAYLOAD","repair payload must be Directory")
  if payload["schema"]<>.StorageRepairQueueBuild~WORK_SCHEMA | payload["kind"]<>"STORAGE_REPLICA_REPAIR" then return .StorageRepairResult~failure("INVALID_REPAIR_SCHEMA","unsupported repair payload")
  repairId=payload["repair_id"]~string
  objectId=payload["object_id"]~string
  object=manager~catalogue~get(objectId)
  if object==.nil then return .StorageRepairResult~failure("OBJECT_NOT_FOUND",objectId)
  requirement=self~requirementFromPayload(payload)
  if requirement==.nil then return .StorageRepairResult~failure("REPLICA_REQUIREMENT_MISSING","repair work carries no authoritative replica requirement")
  before=policy~assess(object,requirement)
  if before~satisfied then do
    if instrumentation<>.nil then instrumentation~repairSatisfied(repairId)
    return .StorageRepairResult~success("ALREADY_SATISFIED",object)
  end

  /* Planner is injected because placement authority and provider choice remain
   * outside this adapter. It must return a result object with ok/value/code/detail.
   * The value is expected to be an admitted/verified Storage location or other
   * planner-owned success evidence after Storage commit. */
  repaired=planner~repair(object,requirement,payload)
  if repaired==.nil | \repaired~ok then do
    if instrumentation<>.nil then instrumentation~degraded
    if repaired==.nil then return .StorageRepairResult~failure("REPAIR_FAILED","nil planner result")
    return .StorageRepairResult~failure(repaired~code,repaired~detail)
  end

  after=policy~assess(object,requirement)
  if \after~satisfied then return .StorageRepairResult~failure("REPAIR_NOT_SATISFIED",after~reason)
  if instrumentation<>.nil then instrumentation~repairSatisfied(repairId)
  return .StorageRepairResult~success("SATISFIED",repaired~value)


/* Reconciles committed Storage provider/topology state into durable repair work.
 * This class is deliberately downstream of Storage authority mutation: callers
 * first update/commit provider or location state, then notify this reconciler.
 * It never marks locations OFFLINE/AVAILABLE and it never admits replicas. */
::class StorageReplicaRepairReconciler public
::attribute manager get
::attribute authority get
::attribute binding get
::method init
  expose manager authority binding policy submitted fallbackRequirement
  use strict arg storageManagerArg,authorityArg,bindingArg,fallbackRequirementArg=.nil
  if storageManagerArg==.nil | bindingArg==.nil then raise syntax 88.900 array("STORAGE_REPAIR_RECONCILER_MANAGER_BINDING_REQUIRED")
  manager=storageManagerArg; authority=authorityArg; binding=bindingArg
  fallbackRequirement=fallbackRequirementArg
  policy=.StorageReplicaPolicy~new
  submitted=.directory~new

::method requirementFor private
  expose authority fallbackRequirement
  use strict arg object
  if authority<>.nil then do
    book=authority~replicaPolicies
    if book<>.nil then do
      req=book~get(object~ref~objectId)
      if req<>.nil then return req
    end
  end
  /* An estate-wide fallback is allowed only when an authority owner injects it.
   * There is deliberately no implicit StorageReplicaRequirement(1). */
  return fallbackRequirement

::method repairKey private
  use strict arg object,assessment,policyRevision=""
  return object~ref~objectId || ":" || assessment~reason || ":" || policyRevision~string

::method providerTransitionCommitted
  expose manager binding policy submitted
  use strict arg providerIdArg,newStateArg,policyRevisionArg="",preferredProviderKindArg=""
  providerId=providerIdArg~string~strip
  newState=newStateArg~string~upper~strip
  if providerId="" | newState="" then raise syntax 88.900 array("STORAGE_REPAIR_PROVIDER_STATE_REQUIRED")

  affected=manager~catalogue~byProvider(providerId)
  queued=0; alreadyProtected=0; duplicateSuppressed=0; failed=0; policyMissing=0
  do object over affected
    requirement=self~requirementFor(object)
    if requirement==.nil then do
      policyMissing+=1
      iterate
    end
    assessment=policy~assess(object,requirement)
    if assessment~satisfied then do
      alreadyProtected+=1
      iterate
    end

    key=self~repairKey(object,assessment,policyRevisionArg)
    if submitted[key]<>.nil then do
      duplicateSuppressed+=1
      iterate
    end

    repairId="repair:" || key
    meta=.directory~new
    meta["trigger"]="PROVIDER_TRANSITION"
    meta["provider_id"]=providerId
    meta["provider_state"]=newState
    work=.StorageRepairWork~new(repairId,object~ref~objectId,assessment~reason,requirement,policyRevisionArg,preferredProviderKindArg,meta)
    submitResult=binding~submit(work)
    if submitResult==.nil then failed+=1
    else do
      if submitResult~ok then do
        submitted[key]=repairId
        queued+=1
      end
      else failed+=1
    end
  end
  return .StorageRepairReconcileResult~new(affected~items,queued,alreadyProtected,duplicateSuppressed,failed,policyMissing)

::method forgetRepairKey
  expose submitted
  use strict arg repairKeyArg
  submitted~remove(repairKeyArg~string)
  return self

::class StorageRepairReconcileResult public
::attribute affected get
::attribute queued get
::attribute alreadyProtected get
::attribute duplicateSuppressed get
::attribute failed get
::attribute policyMissing get
::method init
  expose affected queued alreadyProtected duplicateSuppressed failed policyMissing
  use strict arg affectedArg=0,queuedArg=0,protectedArg=0,duplicateArg=0,failedArg=0,policyMissingArg=0
  affected=affectedArg+0
  queued=queuedArg+0
  alreadyProtected=protectedArg+0
  duplicateSuppressed=duplicateArg+0
  failed=failedArg+0
  policyMissing=policyMissingArg+0

::class StorageRepairResult public
::attribute ok get
::attribute code get
::attribute detail get
::attribute value get
::method init
  expose ok code detail value
  use strict arg okArg,codeArg="",detailArg="",valueArg=.nil
  ok=okArg; code=codeArg~string; detail=detailArg~string; value=valueArg
::method success class
  use strict arg codeArg="OK",valueArg=.nil
  return self~new(.true,codeArg,"",valueArg)
::method failure class
  use strict arg codeArg,detailArg=""
  return self~new(.false,codeArg,detailArg,.nil)

::requires "StorageFabric.cls"
::requires "StorageInstrumentationMesh.cls"
::requires "ObjectQueueFabric.cls"
