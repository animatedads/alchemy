/* Cloud Economics dev6: native lease / lifecycle / memory execution-context
 * authority gate.  Economic advice only. NEVER reserves, dispatches, migrates,
 * checkpoints, sends RPC, or purchases. Only issuer-side JobNodeAllocator's
 * verifyLease may validate leases: do not manufacture a new allocator to check.
 */
::class CloudMigrationEstateHandoff public
::method init
  expose status reason decision lease lifecycle context destinationEvidence
  use strict arg status, reason, decision=.nil, lease=.nil, lifecycle=.nil, context=.nil, destinationEvidence=.nil
::attribute status get
::attribute reason get
::attribute decision get
::attribute lease get
::attribute lifecycle get
::attribute context get
::attribute destinationEvidence get
::method dispatchable
  return .false
::method purchaseAllowed
  return .false
::method migrationAllowed
  return .false

::class CloudMigrationEstateBridge public
/* Inputs are LIVE ooRexx authority objects, not TSV claims. Route prices
 * remain unverified advisory input, even after eligibility checks pass.
 * contextPlans is a directory keyed by destination offer ID containing real
 * RegisteredJobExecutionContextPlan objects projected from the estate.
 * destProofs contains fresh node binding/request/capability/capacity objects.
 */
::method evaluate
  use strict arg running, routes, offers, now, tariffs, sourceLease, sourceRequest, allocator, lifecycleRegistry, sourceBinding, destProofs, destPolicy, contextPlans
  numeric digits 30
  hold=.CloudMigrationEstateHandoff~new('EVIDENCE_HOLD','SOURCE_AUTHORITY_REQUIRED')
  if sourceLease==.nil | sourceRequest==.nil | allocator==.nil | lifecycleRegistry==.nil | sourceBinding==.nil then return hold
  if \sourceLease~isA(.JobNodePlacementLease) | ,
     \allocator~isA(.JobNodeAllocator) | ,
     \lifecycleRegistry~isA(.JobNodeExecutionLifecycleRegistry) then return hold
  if \allocator~hasMethod('verifyLease') | \lifecycleRegistry~hasMethod('stateFor') then return hold
  if \sourceBinding~hasIndex('offer_id') | \sourceBinding~hasIndex('node_id') then return hold
  if sourceBinding['offer_id']<>running['source_id'] | sourceLease~nodeId<>sourceBinding['node_id'] then
    return .CloudMigrationEstateHandoff~new('EVIDENCE_HOLD','SOURCE_OFFER_NODE_BINDING_MISMATCH')
  if sourceLease~jobId<>running['id'] | sourceRequest~jobId<>running['id'] then
    return .CloudMigrationEstateHandoff~new('EVIDENCE_HOLD','SOURCE_JOB_ID_MISMATCH')
  /* A valid lease for a weaker request is not enough to run this job. */
  requirements=sourceRequest~requirement
  if requirements~minimumMemoryMiB<(running['memory_gib']+0)*1024 | ,
     requirements~minimumFreeMemoryMiB<(running['memory_gib']+0)*1024 | ,
     requirements~minimumCpuUnits<running['cpu']+0 | ,
     requirements~minimumAvailableCpuUnits<running['cpu']+0 then
    return .CloudMigrationEstateHandoff~new('EVIDENCE_HOLD','SOURCE_REQUEST_UNDERSTATES_JOB')
  if running['jurisdiction']<>'' then do
    if requirements~jurisdictions~at(running['jurisdiction']~upper)==.nil then
      return .CloudMigrationEstateHandoff~new('EVIDENCE_HOLD','SOURCE_RESIDENCY_UNDERSTATED')
  end
  nowMs=(now+0)*1000
  /* Native lease verifier checks policy generation, current ownership (if
   * configured), requirement and node digests, freshness, and proof signature
   * if that allocator was configured with a proof authority. */
  if \allocator~verifyLease(sourceLease,sourceRequest,nowMs) then
    return .CloudMigrationEstateHandoff~new('EVIDENCE_HOLD','SOURCE_LEASE_NOT_CURRENT')
  live=lifecycleRegistry~stateFor(sourceLease~jobId,sourceLease~placementId,sourceLease~ownershipEpoch)
  if live==.nil then return .CloudMigrationEstateHandoff~new('EVIDENCE_HOLD','RUNNING_EXECUTION_NOT_OBSERVED')
  if \live~isA(.JobNodeExecutionLifecycleState) then
    return .CloudMigrationEstateHandoff~new('EVIDENCE_HOLD','INVALID_LIFECYCLE_RECORD')
  if live~state<>'RUNNING' | live~uncertain | live~executionRef='' | live~lastEvidenceId='' then
    return .CloudMigrationEstateHandoff~new('EVIDENCE_HOLD','EXECUTION_NOT_CERTAINLY_RUNNING')
  if live~lastObservedEpochMs<=0 | live~lastObservedEpochMs>nowMs | ,
     nowMs-live~lastObservedEpochMs>300000 then
    return .CloudMigrationEstateHandoff~new('EVIDENCE_HOLD','EXECUTION_EVIDENCE_STALE')
  if destProofs==.nil | destPolicy==.nil | contextPlans==.nil then
    return .CloudMigrationEstateHandoff~new('EVIDENCE_HOLD','DESTINATION_AUTHORITY_REQUIRED',.nil,sourceLease,live)
  /* A route may enter the economic comparison only after the actual JNA
   * requirements and capacity policy approve it AND a real execution-context
   * plan declares sufficient memory/storage. No buying/commissioning here. */
  job=.directory~new
  job['id']=running['id']; job['mem']=running['memory_gib']; job['cpu']=running['cpu']
  job['gpu']=0; job['jurisdiction']=running['jurisdiction']; job['runtime']='ANY'
  do sourceOffer over offers
    if sourceOffer['id']=running['source_id'] then job['runtime']=sourceOffer['runtime']
  end
  if job['runtime']='ANY' then
    return .CloudMigrationEstateHandoff~new('EVIDENCE_HOLD','SOURCE_OFFER_NOT_FOUND',.nil,sourceLease,live)
  if requirements~runtimes~at(job['runtime']~upper)==.nil then
    return .CloudMigrationEstateHandoff~new('EVIDENCE_HOLD','SOURCE_RUNTIME_NOT_ATTESTED',.nil,sourceLease,live)
  legal=.directory~new; validRoutes=.array~new
  gate=.CloudEconomicNodeEvidenceGate~new
  do route over routes
    if route['job_id']<>running['id'] | route['source_id']<>running['source_id'] then iterate
    id=route['dest_id']
    if legal~hasIndex(id) then iterate
    if \destProofs~hasIndex(id) | \contextPlans~hasIndex(id) then iterate
    proof=destProofs[id]; ctx=contextPlans[id]
    if proof==.nil | ctx==.nil then iterate
    if \ctx~isA(.RegisteredJobExecutionContextPlan) then iterate
    if \proof~hasIndex('binding') | \proof~hasIndex('request') | ,
       \proof~hasIndex('capability') | \proof~hasIndex('capacity') then iterate
    if \proof['request']~isA(.JobPlacementRequest) | ,
       \proof['capability']~isA(.NodeCapabilityStatement) | ,
       \proof['capacity']~isA(.NodeCapacityObservation) then iterate
    if \ctx~hasMethod('memoryPlan') | \ctx~hasMethod('candidate') | \ctx~hasMethod('action') then iterate
    if ctx~memoryPlan==.nil | ctx~candidate==.nil then iterate
    if \ctx~memoryPlan~complete | \ctx~candidate~hardEligible then iterate
    if ctx~action<>'RUN_EXISTING' & ctx~action<>'COMMISSION' then iterate
    if ctx~candidate~nodeId<>proof['binding']['node_id'] then iterate
    if ctx~candidate~storageEvidence<>.nil then do
      if ctx~candidate~storageEvidence~nodeId<>ctx~candidate~nodeId then iterate
    end
    if ctx~memoryPlan~totalBytes<(running['memory_gib']+0)*1073741824 then iterate
    se=ctx~candidate~storageEvidence
    if se<>.nil then do
      if \se~workspaceFits | \se~durableOutputAdmissible then iterate
    end
    /* Do not use the source placement request for destination: explicit
     * destination request is essential for cross-node policy checks. */
    offer=.nil
    do o over offers
      if o['id']=id then offer=o
    end
    if offer==.nil then iterate
    if ctx~candidate~siteId<>offer['site'] then iterate
    if ctx~profile==.nil then iterate
    if ctx~memoryPlan~providerCount>ctx~profile~maximumMemoryProviders then iterate
    if ctx~memoryPlan~worstLocality>ctx~profile~maximumMemoryLocality then iterate
    verdict=gate~assess(offer,job,proof['binding'],proof['request'], ,
        proof['capability'],proof['capacity'],nowMs,destPolicy)
    if \verdict['allowed'] then iterate
    legal[id]=.array~of(proof,ctx)
  end
  do route over routes
    if legal~hasIndex(route['dest_id']) & route['job_id']=running['id'] & ,
       route['source_id']=running['source_id'] then validRoutes~append(route)
  end
  economic=.CloudMigrationEconomics~new~compare(running,validRoutes,offers,now,tariffs)
  if economic['status']='PAPER_MOVE_FAVORED' then do
    pair=legal[economic['selected']]
    state='NATIVE_ELIGIBLE_ADVISORY'
    why='PLACEMENT_AND_EXECUTION_CONTEXT_CHECKED_ROUTE_MOBILITY_NOT_AUTHORIZED'
    if pair[2]~action='COMMISSION' then do
      state='NATIVE_COMMISSION_SCENARIO_ADVISORY'
      why='DESTINATION_COMMISSIONING_STILL_REQUIRED_NO_CAPACITY_ACQUISITION'
    end
    return .CloudMigrationEstateHandoff~new(state,why, ,
      economic,sourceLease,live,pair[2],pair[1])
  end
  return .CloudMigrationEstateHandoff~new('NATIVE_STAY_OR_HOLD',economic['reason'], ,
    economic,sourceLease,live)

::requires 'CloudEconomicsAuthority.cls'
::requires 'CloudMigrationEconomics.cls'
::requires 'JobNodeExecutionLifecycle.cls'
::requires 'RegisteredJobExecutionContext.cls'
