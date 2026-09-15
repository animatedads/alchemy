/* FD Door Micro Motion v0.2-dev5 managed initial placement bridge.
 *
 * Normal NEW placement uses the Migratable Job v0.2.4 standard managed API:
 *   migratable.job.placement/1
 *
 * Job-to-Node v0.6 remains the authority.  This file only adapts the existing
 * FD node-probe evidence to a JobNode registry and places JobNode's durable
 * journal under the standard managed-placement tool.  There is deliberately
 * no FD-specific placement receipt or invented ownership epoch.
 */

::class FDDoorMicroMotionManagedPlacementBuild public
::constant PROBE_SCHEMA 'fd.job_to_node.node.probe/1'
::constant POLICY_GENERATION 'FD-MANAGED-PLACEMENT-1'
::constant PLACEMENT_API 'migratable.job.placement/1'
::constant PLACEMENT_RECEIPT_API 'migratable.job.placement.receipt/1'

::class FDDoorMicroMotionNodeProbe public
::attribute state get
::attribute jobId get
::attribute nodeId get
::attribute ownerNodeId get
::attribute sourceEvidenceRef get
::attribute leaseDurationMs get
::attribute observedEpochMs get
::attribute expiresEpochMs get
::attribute capabilityGeneration get
::attribute observationGeneration get

::method init
  expose state jobId nodeId ownerNodeId sourceEvidenceRef leaseDurationMs observedEpochMs expiresEpochMs capabilityGeneration observationGeneration
  use strict arg stateArg
  state=stateArg
  if state==.nil then raise syntax 88.900 array('FD managed placement probe missing')
  if state~get('schema','')<>.FDDoorMicroMotionManagedPlacementBuild~PROBE_SCHEMA then raise syntax 88.900 array('FD managed placement probe schema mismatch',state~get('schema',''))
  jobId=state~require('job_id'); nodeId=state~require('source_node_id'); ownerNodeId=state~get('owner_node_id',nodeId); sourceEvidenceRef=state~require('source_evidence_ref')
  leaseDurationMs=state~require('lease_duration_ms')+0; observedEpochMs=state~require('observed_epoch_ms')+0; expiresEpochMs=state~require('expires_epoch_ms')+0
  capabilityGeneration=state~get('capability_generation','1')+0; observationGeneration=state~get('observation_generation','1')+0
  if leaseDurationMs<1 | observedEpochMs<1 | expiresEpochMs<=observedEpochMs then raise syntax 88.900 array('FD managed placement probe has invalid time window')
  if observedEpochMs+leaseDurationMs>expiresEpochMs then raise syntax 88.900 array('FD managed placement lease exceeds probe evidence window')

::method load class
  use strict arg pathArg
  path=pathArg~string
  s=.FDControlFile~read(path)
  if s==.nil then raise syntax 88.900 array('FD managed placement probe not readable',path)
  return self~new(s)

::method sourceTag
  expose sourceEvidenceRef
  return 'FD.SOURCE.'||sourceEvidenceRef~upper~changestr(':','_')

::method assignmentTag
  expose jobId
  return 'FD.ASSIGNED.'||jobId~upper

::method abilities
  return .array~of('FD.DOOR.MICRO.MOTION')

::method runtimes
  return .array~of('OOREXX/5.3')

::method tags
  return .array~of('FD.NIGHT.F11',self~assignmentTag,self~sourceTag)

::method placementRequirement
  /* Keep the requirement stable between central allocation and worker-side
   * START verification.  Source identity and assigned node are carried by
   * capability tags; capacity thresholds are intentionally conservative. */
  return .JobNodeRequirement~new(.nil,.nil,.nil,.nil,self~abilities,self~runtimes,self~tags,'',256,128,1,64,64,1,0)

::method placementRequest
  expose jobId ownerNodeId
  return .JobPlacementRequest~new(jobId,self~placementRequirement,ownerNodeId,0,0,0,.array~of('FD.NIGHT.F11'))

::method addToRegistry
  expose state nodeId capabilityGeneration observationGeneration observedEpochMs expiresEpochMs
  use strict arg registry
  arch=state~require('architecture')~upper
  memoryMiB=state~require('memory_mib')+0; diskMiB=state~require('disk_mib')+0; cpuUnits=state~require('cpu_units')+0
  freeMemoryMiB=state~require('free_memory_mib')+0; freeDiskMiB=state~require('free_disk_mib')+0; availableCpuUnits=state~require('available_cpu_units')+0
  runtimeGeneration=state~get('runtime_generation','5.3-r13196'); proofRef=state~get('proof_ref','')
  if arch='' | memoryMiB<1 | diskMiB<1 | cpuUnits<1 | freeMemoryMiB<1 | freeDiskMiB<1 | availableCpuUnits<=0 then raise syntax 88.900 array('FD managed placement probe capability/capacity invalid',nodeId)
  cap=.NodeCapabilityStatement~new(nodeId,capabilityGeneration,proofRef,.nil,.nil,.nil,.nil,self~abilities,self~runtimes,self~tags,arch,memoryMiB,diskMiB,cpuUnits,runtimeGeneration)
  obs=.NodeCapacityObservation~new(nodeId,capabilityGeneration,observationGeneration,observedEpochMs,expiresEpochMs,freeMemoryMiB,freeDiskMiB,availableCpuUnits,0,0,0,proofRef)
  if \registry~advertiseCapability(cap) then raise syntax 88.900 array('FD managed placement capability advertisement rejected',nodeId)
  if \registry~observeCapacity(obs) then raise syntax 88.900 array('FD managed placement capacity observation rejected',nodeId)
  return .true

/* Adapter which preserves JobNodeDurablePlacementManager underneath the
 * standard MigratableJobManagedPlacementTool allocator seam. */
::class FDDoorMicroMotionDurableAllocator public
::method init
  expose allocator manager
  use strict arg allocatorArg, managerArg
  allocator=allocatorArg; manager=managerArg
::method allocate
  expose manager
  forward to (manager)
::method verifyLease
  expose allocator
  forward to (allocator)
::method releasePlacement
  expose manager
  forward to (manager)
::method renewPlacement
  expose manager
  forward to (manager)

::class FDDoorMicroMotionManagedEnvironment public
::attribute probe get
::attribute registry get
::attribute ownership get
::attribute rawAllocator get
::attribute allocator get
::attribute manager get
::attribute eligibility get
::attribute journal get
::attribute recovery get

::method init
  expose probe registry ownership rawAllocator allocator manager eligibility journal recovery
  use strict arg probePathArg, journalPathArg, nowEpochMsArg=0
  nowEpochMs=nowEpochMsArg+0; if nowEpochMs<1 then nowEpochMs=time('T')*1000
  probe=.FDDoorMicroMotionNodeProbe~load(probePathArg)
  registry=.NodeCapabilityRegistry~new
  ignore=probe~addToRegistry(registry)
  ownership=.JobNodeOwnershipRegistry~new
  eligibility=.JobNodeEligibilityPolicy~new
  rawAllocator=.JobNodeAllocator~new(registry,eligibility,.nil,.nil,.nil,.FDDoorMicroMotionManagedPlacementBuild~POLICY_GENERATION,.nil,ownership)
  journal=.JobNodeDurableJournal~new(journalPathArg)
  manager=.JobNodeDurablePlacementManager~new(rawAllocator,ownership,journal)
  recovery=manager~restore(nowEpochMs)
  if \recovery~ok then raise syntax 88.900 array('FD managed Job-to-Node durable recovery failed',recovery~code)
  allocator=.FDDoorMicroMotionDurableAllocator~new(rawAllocator,manager)

::method validateApplication
  expose probe
  use strict arg application
  if application==.nil then raise syntax 88.900 array('FD managed placement application missing')
  d=application~definition(.nil)
  if d==.nil then raise syntax 88.900 array('FD managed placement definition missing')
  if d~jobId<>probe~jobId then raise syntax 88.900 array('FD managed placement job/probe mismatch',d~jobId,probe~jobId)
  if application~sourceNodeId<>probe~nodeId then raise syntax 88.900 array('FD managed placement node/probe mismatch',application~sourceNodeId,probe~nodeId)
  if application~sourceEvidenceRef<>probe~sourceEvidenceRef then raise syntax 88.900 array('FD managed placement source-evidence/probe mismatch')
  if d~placementRequest~canonical<>probe~placementRequest~canonical then raise syntax 88.900 array('FD managed placement request does not match probe-derived request')
  return .true

/* Standard placed-start seam extended only to inject the already verified
 * Job-to-Node lease into the workload application before the standard starter
 * calls startNew().  It makes no placement decision. */
::class FDDoorMicroMotionPlacedStartExecutor subclass MigratableJobPlacedStartExecutor public
::method init
  expose localNodeId starter application
  use strict arg localNodeArg, starterArg, applicationArg
  localNodeId=localNodeArg~string; starter=starterArg; application=applicationArg
  if localNodeId='' | starter==.nil | application==.nil then raise syntax 88.900 array('FD placed start executor requires local node, starter and application')
::method start
  expose localNodeId starter application
  use strict arg lease, startRequest, nowEpochMs=0
  if lease==.nil then return .MigratableJobStartResult~failure(startRequest,'PLACEMENT_LEASE_REQUIRED')
  if lease~nodeId<>localNodeId then return .MigratableJobStartResult~failure(startRequest,'PLACEMENT_NOT_LOCAL','lease node='||lease~nodeId||' local='||localNodeId)
  if \application~bindInitialLease(lease) then return .MigratableJobStartResult~failure(startRequest,'FD_LEASE_BINDING_FAILED')
  return starter~start(startRequest)

::requires 'FDDoorMicroMotion.cls'
::requires 'JobNodeDurableState.cls'
::requires 'MigratableJobManagedPlacement.cls'
