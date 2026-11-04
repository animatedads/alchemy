/* StorageRepairPlanner.cls
 * Storage Fabric durable replica destination planning.
 * API: storage.fabric.repair.planner/0.1
 *
 * Storage policy owns whether protection is deficient and whether a returned
 * location improves protection. Provider adapters own byte movement and
 * provider-specific verification. Job-to-Node is deliberately not involved.
 */

::class StorageRepairPlannerBuild public
::constant VERSION "0.1-dev8"
::constant API "storage.fabric.repair.planner/0.1"

::class StorageRepairSourceResult public
::attribute ok get
::attribute code get
::attribute detail get
::attribute path get
::attribute verificationRef get
::attribute verified get

::method init
  expose ok code detail path verificationRef verified
  use strict arg okArg,codeArg="",detailArg="",pathArg="",verificationArg="",verifiedArg=.false
  ok=(okArg==.true)
  code=codeArg~string
  detail=detailArg~string
  path=pathArg~string
  verificationRef=verificationArg~string
  verified=(verifiedArg==.true)

::method success class
  use strict arg pathArg,verificationArg
  if pathArg~string="" then return self~failure("SOURCE_PATH_REQUIRED")
  if verificationArg~string="" then return self~failure("SOURCE_VERIFICATION_REQUIRED")
  return self~new(.true,"OK","",pathArg,verificationArg,.true)

::method failure class
  use strict arg codeArg,detailArg=""
  return self~new(.false,codeArg,detailArg,"","",.false)

::class StorageRepairStoreResult public
::attribute ok get
::attribute code get
::attribute detail get
::attribute location get
::attribute kind get
::attribute chunksWritten get
::attribute chunksReused get

::method init
  expose ok code detail location kind chunksWritten chunksReused
  use strict arg okArg,codeArg="",detailArg="",locationArg=.nil,kindArg="",writtenArg=0,reusedArg=0
  ok=(okArg==.true)
  code=codeArg~string
  detail=detailArg~string
  location=locationArg
  kind=kindArg~string~upper
  chunksWritten=writtenArg
  chunksReused=reusedArg

::method success class
  use strict arg locationArg,kindArg="",writtenArg=0,reusedArg=0
  return self~new(.true,"OK","",locationArg,kindArg,writtenArg,reusedArg)

::method failure class
  use strict arg codeArg,detailArg="",kindArg=""
  return self~new(.false,codeArg,detailArg,.nil,kindArg,0,0)

::class StorageRepairPlannerResult public
::attribute ok get
::attribute code get
::attribute detail get
::attribute value get

::method init
  expose ok code detail value
  use strict arg okArg,codeArg="",detailArg="",valueArg=.nil
  ok=(okArg==.true)
  code=codeArg~string
  detail=detailArg~string
  value=valueArg

::method success class
  use strict arg codeArg="OK",valueArg=.nil
  return self~new(.true,codeArg,"",valueArg)

::method failure class
  use strict arg codeArg,detailArg=""
  return self~new(.false,codeArg,detailArg,.nil)

/* Adapter for the existing storage.fabric.git/0.1 provider.
 * The provider already performs source SHA verification, bounded chunking,
 * push, remote-ref confirmation, fetch and post-push object verification.
 */
::class StorageGitRepairDestination public
::attribute provider get
::attribute preferenceScore get

::method init
  expose provider preferenceScore
  use strict arg providerArg,preferenceArg=0
  if providerArg==.nil then raise syntax 88.900 array("STORAGE_REPAIR_GIT_PROVIDER_REQUIRED")
  provider=providerArg
  preferenceScore=preferenceArg

::method kind
  return "GIT"

::method providerId
  expose provider
  return provider~providerId

::method eligible
  expose provider
  use strict arg object
  if object==.nil then return .false
  if \provider~canDurable then return .false
  if \provider~countsAsDurable then return .false
  do loc over object~locations
    if loc~providerId=provider~providerId then return .false
  end
  return .true

::method previewLocation
  expose provider
  locator="repair-candidate:"||provider~providerId
  return .StorageLocation~new(provider~providerId,locator,"git:"||provider~providerId, -
    .StorageLocationState~AVAILABLE,"",.true,"candidate", -
    .StorageSafetyClass~SAFE,provider~lifecycle~state,"", -
    provider~vendorId,provider~siteId,provider~failureDomainId)

::method store
  expose provider
  use strict arg object,sourcePath,observedAt=""
  putResult=provider~store(object~ref,sourcePath,observedAt)
  if putResult==.nil then return .StorageRepairStoreResult~failure("GIT_STORE_NIL","","GIT")
  if \putResult~ok then return .StorageRepairStoreResult~failure(putResult~code,"","GIT")
  if putResult~location==.nil then return .StorageRepairStoreResult~failure("GIT_LOCATION_MISSING","","GIT")
  return .StorageRepairStoreResult~success(putResult~location,"GIT",putResult~chunksWritten,putResult~chunksReused)

/* Destination planning is policy-improvement first, preference second.
 * Preference may encode observed throughput/cost/locality but cannot make a
 * destination eligible if it does not improve the current replica requirement.
 */
::class StorageRepairDestinationPlanner public
::attribute sourceResolver get
::attribute instrumentation get

::method init
  expose sourceResolver destinations instrumentation policy
  use strict arg sourceResolverArg,destinationsArg=.nil,instrumentationArg=.nil
  if sourceResolverArg==.nil then raise syntax 88.900 array("STORAGE_REPAIR_SOURCE_RESOLVER_REQUIRED")
  sourceResolver=sourceResolverArg
  instrumentation=instrumentationArg
  policy=.StorageReplicaPolicy~new
  if destinationsArg==.nil then destinations=.array~new
  else destinations=destinationsArg

::method addDestination
  expose destinations
  use strict arg destinationArg
  if destinationArg==.nil then raise syntax 88.900 array("STORAGE_REPAIR_DESTINATION_REQUIRED")
  destinations~append(destinationArg)
  return self

::method repair
  expose sourceResolver destinations instrumentation policy
  use strict arg object,requirement,payload=.nil
  if object==.nil then return .StorageRepairPlannerResult~failure("OBJECT_REQUIRED")
  if requirement==.nil then return .StorageRepairPlannerResult~failure("REPLICA_REQUIREMENT_MISSING")

  before=policy~assess(object,requirement)
  if before~satisfied then return .StorageRepairPlannerResult~success("ALREADY_SATISFIED",object)

  selected=.nil
  bestGain=0
  bestPreference=0
  do destination over destinations
    if destination==.nil then iterate
    if \destination~eligible(object) then iterate
    preview=destination~previewLocation
    if preview==.nil then iterate
    if \preview~countsAsDurable then iterate
    shadow=self~shadowWith(object,preview)
    after=policy~assess(shadow,requirement)
    gain=self~policyGain(before,after,requirement)
    if gain<=0 then iterate
    preference=destination~preferenceScore
    if selected==.nil then do
      selected=destination
      bestGain=gain
      bestPreference=preference
      iterate
    end
    if gain>bestGain then do
      selected=destination
      bestGain=gain
      bestPreference=preference
      iterate
    end
    if gain=bestGain then do
      if preference>bestPreference then do
        selected=destination
        bestPreference=preference
      end
    end
  end

  if selected==.nil then return .StorageRepairPlannerResult~failure("NO_ELIGIBLE_REPAIR_DESTINATION",before~reason)

  source=sourceResolver~resolve(object,payload)
  if source==.nil then return .StorageRepairPlannerResult~failure("SOURCE_RESOLUTION_FAILED","nil source result")
  if \source~ok then return .StorageRepairPlannerResult~failure(source~code,source~detail)
  if \source~verified then return .StorageRepairPlannerResult~failure("SOURCE_NOT_VERIFIED")
  if source~path="" then return .StorageRepairPlannerResult~failure("SOURCE_PATH_REQUIRED")
  if source~verificationRef="" then return .StorageRepairPlannerResult~failure("SOURCE_VERIFICATION_REQUIRED")

  observedAt=.DateTime~new~string
  stored=selected~store(object,source~path,observedAt)
  if stored==.nil then return .StorageRepairPlannerResult~failure("REPAIR_STORE_FAILED","nil store result")
  if \stored~ok then return .StorageRepairPlannerResult~failure(stored~code,stored~detail)
  location=stored~location
  if location==.nil then return .StorageRepairPlannerResult~failure("REPAIR_LOCATION_MISSING")
  if location~providerId<>selected~providerId then return .StorageRepairPlannerResult~failure("REPAIR_PROVIDER_MISMATCH")
  if \location~countsAsDurable then return .StorageRepairPlannerResult~failure("REPAIR_LOCATION_NOT_DURABLE")

  /* Admit only after the provider returns independently verified durable
   * location evidence. The execution boundary performs the final policy
   * reassessment after this method returns. */
  object~addLocation(location)

  if instrumentation<>.nil then do
    if stored~kind="GIT" then instrumentation~gitStoreCompleted(stored~chunksWritten,stored~chunksReused)
  end
  return .StorageRepairPlannerResult~success("REPLICA_ADMITTED",location)

::method shadowWith private
  use strict arg object,location
  shadow=.StorageObject~new(object~ref,object~displayName,object~sizeBytes,object~mediaType)
  do loc over object~locations
    shadow~addLocation(loc)
  end
  shadow~addLocation(location)
  return shadow

::method policyGain private
  use strict arg before,after,requirement
  gain=0
  gain+=self~boundedGain(before~durableReplicas,after~durableReplicas,requirement~requiredReplicas)
  gain+=self~boundedGain(before~vendors,after~vendors,requirement~distinctVendors)
  gain+=self~boundedGain(before~sites,after~sites,requirement~distinctSites)
  gain+=self~boundedGain(before~failureDomains,after~failureDomains,requirement~distinctFailureDomains)
  return gain

::method boundedGain private
  use strict arg beforeArg,afterArg,requiredArg
  if requiredArg<=0 then return 0
  before=beforeArg
  after=afterArg
  required=requiredArg
  if before>required then before=required
  if after>required then after=required
  if after<=before then return 0
  return after-before

::requires "StorageFabric.cls"
