/* ooRexx Job-to-Node Allocator v0.6
 * Authority-constrained placement over authenticated node capability and
 * transient capacity observations.
 *
 * HARD RULE: optimisation is applied only after every mandatory eligibility
 * constraint has passed.  A score can never override an eligibility failure.
 */

::class JobNodeAllocatorBuild public
::constant VERSION "0.6"
::constant API "job.node.allocator/0.6"

/* ---------- small set/value helpers ---------- */
::class JNASet public
::method from class
  use arg values=.nil
  s=.directory~new
  if values==.nil then return s
  do v over values
    s[v~string~upper]=.true
  end
  return s
::method containsAll class
  use arg offered,required
  if required==.nil then return .true
  do k over required
    if offered~at(k)==.nil then return .false
  end
  return .true
::method canonical class
  use arg setArg
  if setArg==.nil | setArg~items=0 then return ""
  a=.array~new
  do k over setArg; a~append(k~string); end
  a~sort
  out=""
  do i=1 to a~items
    if i>1 then out=out || ","
    out=out || a[i]
  end
  return out
::method canonicalValues class
  use arg values
  if values==.nil then return ""
  s=self~from(values)
  return self~canonical(s)

/* ---------- job requirements ---------- */
::class JobNodeRequirement public
::attribute jurisdictions get
::attribute legalDomains get
::attribute trustDomains get
::attribute authorities get
::attribute abilities get
::attribute runtimes get
::attribute tags get
::attribute architecture get
::attribute minimumMemoryMiB get
::attribute minimumDiskMiB get
::attribute minimumCpuUnits get
::attribute minimumFreeMemoryMiB get
::attribute minimumFreeDiskMiB get
::attribute minimumAvailableCpuUnits get
::attribute minimumAvailableMicroWluPerSecond get
::attribute apiRouteRequirement get
::attribute exactRuntimeGeneration get
::method init
  expose jurisdictions legalDomains trustDomains authorities abilities runtimes tags architecture minimumMemoryMiB minimumDiskMiB minimumCpuUnits minimumFreeMemoryMiB minimumFreeDiskMiB minimumAvailableCpuUnits minimumAvailableMicroWluPerSecond apiRouteRequirement exactRuntimeGeneration
  use arg jurisdictionsArg=.nil, legalArg=.nil, trustArg=.nil, authoritiesArg=.nil, abilitiesArg=.nil, runtimesArg=.nil, tagsArg=.nil, architectureArg="", minMemArg=0, minDiskArg=0, minCpuArg=0, minFreeMemArg=0, minFreeDiskArg=0, minAvailCpuArg=0, minWluRateArg=0, apiRouteArg=.nil, runtimeGenerationArg=""
  jurisdictions=.JNASet~from(jurisdictionsArg)
  legalDomains=.JNASet~from(legalArg)
  trustDomains=.JNASet~from(trustArg)
  authorities=.JNASet~from(authoritiesArg)
  abilities=.JNASet~from(abilitiesArg)
  runtimes=.JNASet~from(runtimesArg)
  tags=.JNASet~from(tagsArg)
  architecture=architectureArg~string~upper
  minimumMemoryMiB=minMemArg+0; minimumDiskMiB=minDiskArg+0; minimumCpuUnits=minCpuArg+0
  minimumFreeMemoryMiB=minFreeMemArg+0; minimumFreeDiskMiB=minFreeDiskArg+0; minimumAvailableCpuUnits=minAvailCpuArg+0
  minimumAvailableMicroWluPerSecond=minWluRateArg+0
  apiRouteRequirement=apiRouteArg
  exactRuntimeGeneration=runtimeGenerationArg~string
::method canonical
  expose jurisdictions legalDomains trustDomains authorities abilities runtimes tags architecture minimumMemoryMiB minimumDiskMiB minimumCpuUnits minimumFreeMemoryMiB minimumFreeDiskMiB minimumAvailableCpuUnits minimumAvailableMicroWluPerSecond apiRouteRequirement exactRuntimeGeneration
  apiRoute=""
  if apiRouteRequirement<>.nil then apiRoute="country=" || apiRouteRequirement~country~string~upper || ",vpn=" || apiRouteRequirement~vpn~string~upper || ",network=" || apiRouteRequirement~network~string~upper || ",egress=" || apiRouteRequirement~egressClass~string~upper || ",tags=" || .JNASet~canonicalValues(apiRouteRequirement~requiredTags)
  return "jur=" || .JNASet~canonical(jurisdictions) || ";legal=" || .JNASet~canonical(legalDomains) || ";trust=" || .JNASet~canonical(trustDomains) || ";auth=" || .JNASet~canonical(authorities) || ";ability=" || .JNASet~canonical(abilities) || ";runtime=" || .JNASet~canonical(runtimes) || ";tags=" || .JNASet~canonical(tags) || ";arch=" || architecture || ";mem=" || minimumMemoryMiB || ";disk=" || minimumDiskMiB || ";cpu=" || minimumCpuUnits || ";freeMem=" || minimumFreeMemoryMiB || ";freeDisk=" || minimumFreeDiskMiB || ";availCpu=" || minimumAvailableCpuUnits || ";wluRate=" || minimumAvailableMicroWluPerSecond || ";apiRoute={" || apiRoute || "};runtimeGen=" || exactRuntimeGeneration

::class JobPlacementRequest public
::attribute jobId get
::attribute ownerNodeId get
::attribute requirement get
::attribute expectedMicroWlu get
::attribute requestedRateMicroWluPerSecond get
::attribute deadlineEpochMs get
::attribute policyTags get
::method init
  expose jobId ownerNodeId requirement expectedMicroWlu requestedRateMicroWluPerSecond deadlineEpochMs policyTags
  use arg jobIdArg, requirementArg, ownerArg="", expectedArg=0, rateArg=0, deadlineArg=0, policyTagsArg=.nil
  jobId=jobIdArg~string; requirement=requirementArg; ownerNodeId=ownerArg~string
  expectedMicroWlu=expectedArg+0; requestedRateMicroWluPerSecond=rateArg+0; deadlineEpochMs=deadlineArg+0
  policyTags=.JNASet~from(policyTagsArg)
::method canonical
  expose jobId ownerNodeId requirement expectedMicroWlu requestedRateMicroWluPerSecond deadlineEpochMs policyTags
  return "job=" || jobId || ";owner=" || ownerNodeId || ";expected=" || expectedMicroWlu || ";rate=" || requestedRateMicroWluPerSecond || ";deadline=" || deadlineEpochMs || ";policy=" || .JNASet~canonical(policyTags) || ";req={" || requirement~canonical || "}"

/* ---------- durable capability ---------- */
::class NodeApiEgressCapability public
::attribute countries get
::attribute vpns get
::attribute networks get
::attribute egressClasses get
::attribute tags get
::method init
  expose countries vpns networks egressClasses tags
  use arg countriesArg=.nil, vpnsArg=.nil, networksArg=.nil, classesArg=.nil, tagsArg=.nil
  countries=.JNASet~from(countriesArg); vpns=.JNASet~from(vpnsArg); networks=.JNASet~from(networksArg); egressClasses=.JNASet~from(classesArg); tags=.JNASet~from(tagsArg)
::method fromApiEgressNode class
  use arg n
  if n==.nil then return .nil
  /* ApiEgressNode already normalises these dictionaries.  Copy keys so this
   * general allocator never owns or mutates API Client session state. */
  c=self~keys(n~countries); v=self~keys(n~vpns); nw=self~keys(n~networks); ec=self~keys(n~egressClasses); t=self~keys(n~tags)
  return self~new(c,v,nw,ec,t)
::method keys class private
  use arg d
  a=.array~new
  if d==.nil then return a
  do k over d; a~append(k); end
  return a
::method supportsApiRoute
  expose countries vpns networks egressClasses tags
  use arg route
  if route==.nil then return .true
  if route~country<>"" & countries~at(route~country)==.nil then return .false
  if route~vpn<>"" & vpns~at(route~vpn)==.nil then return .false
  if route~network<>"" & networks~at(route~network)==.nil then return .false
  if route~egressClass<>"" & egressClasses~at(route~egressClass)==.nil then return .false
  do tag over route~requiredTags
    if tags~at(tag~string~upper)==.nil then return .false
  end
  return .true
::method canonical
  expose countries vpns networks egressClasses tags
  return "countries=" || .JNASet~canonical(countries) || ";vpns=" || .JNASet~canonical(vpns) || ";networks=" || .JNASet~canonical(networks) || ";egress=" || .JNASet~canonical(egressClasses) || ";tags=" || .JNASet~canonical(tags)

::class NodeCapabilityStatement public
::attribute nodeId get
::attribute generation get
::attribute proofRef get
::attribute jurisdictions get
::attribute legalDomains get
::attribute trustDomains get
::attribute authorities get
::attribute abilities get
::attribute runtimes get
::attribute tags get
::attribute architecture get
::attribute memoryMiB get
::attribute diskMiB get
::attribute cpuUnits get
::attribute runtimeGeneration get
::attribute apiEgressCapability get
::attribute online get
::method init
  expose nodeId generation proofRef jurisdictions legalDomains trustDomains authorities abilities runtimes tags architecture memoryMiB diskMiB cpuUnits runtimeGeneration apiEgressCapability online
  use arg nodeIdArg, generationArg=1, proofArg="", jurisdictionsArg=.nil, legalArg=.nil, trustArg=.nil, authoritiesArg=.nil, abilitiesArg=.nil, runtimesArg=.nil, tagsArg=.nil, architectureArg="", memoryArg=0, diskArg=0, cpuArg=0, runtimeGenerationArg="", apiEgressArg=.nil
  nodeId=nodeIdArg~string; generation=generationArg+0; proofRef=proofArg~string
  jurisdictions=.JNASet~from(jurisdictionsArg); legalDomains=.JNASet~from(legalArg); trustDomains=.JNASet~from(trustArg)
  authorities=.JNASet~from(authoritiesArg); abilities=.JNASet~from(abilitiesArg); runtimes=.JNASet~from(runtimesArg); tags=.JNASet~from(tagsArg)
  architecture=architectureArg~string~upper; memoryMiB=memoryArg+0; diskMiB=diskArg+0; cpuUnits=cpuArg+0
  runtimeGeneration=runtimeGenerationArg~string; apiEgressCapability=apiEgressArg; online=.true
::method setOnline guarded
  expose online
  use arg v
  online=v
::method canonical
  expose nodeId generation proofRef jurisdictions legalDomains trustDomains authorities abilities runtimes tags architecture memoryMiB diskMiB cpuUnits runtimeGeneration apiEgressCapability online
  apiEgress=""
  if apiEgressCapability<>.nil then apiEgress=apiEgressCapability~canonical
  return "node=" || nodeId || ";gen=" || generation || ";proofRef=" || proofRef || ";jur=" || .JNASet~canonical(jurisdictions) || ";legal=" || .JNASet~canonical(legalDomains) || ";trust=" || .JNASet~canonical(trustDomains) || ";auth=" || .JNASet~canonical(authorities) || ";ability=" || .JNASet~canonical(abilities) || ";runtime=" || .JNASet~canonical(runtimes) || ";tags=" || .JNASet~canonical(tags) || ";arch=" || architecture || ";mem=" || memoryMiB || ";disk=" || diskMiB || ";cpu=" || cpuUnits || ";runtimeGen=" || runtimeGeneration || ";apiEgress={" || apiEgress || "};online=" || online

/* ---------- transient capacity ---------- */
::class NodeCapacityObservation public
::attribute nodeId get
::attribute capabilityGeneration get
::attribute observationGeneration get
::attribute observedEpochMs get
::attribute expiresEpochMs get
::attribute freeMemoryMiB get
::attribute freeDiskMiB get
::attribute availableCpuUnits get
::attribute availableMicroWluPerSecond get
::attribute queueDepth get
::attribute activeJobs get
::attribute proofRef get
::method init
  expose nodeId capabilityGeneration observationGeneration observedEpochMs expiresEpochMs freeMemoryMiB freeDiskMiB availableCpuUnits availableMicroWluPerSecond queueDepth activeJobs proofRef
  use arg nodeArg, capGenArg, obsGenArg=1, observedArg=0, expiresArg=0, freeMemArg=0, freeDiskArg=0, availCpuArg=0, availWluArg=0, queueDepthArg=0, activeJobsArg=0, proofArg=""
  nodeId=nodeArg~string; capabilityGeneration=capGenArg+0; observationGeneration=obsGenArg+0
  observedEpochMs=observedArg+0; expiresEpochMs=expiresArg+0
  freeMemoryMiB=freeMemArg+0; freeDiskMiB=freeDiskArg+0; availableCpuUnits=availCpuArg+0; availableMicroWluPerSecond=availWluArg+0
  queueDepth=queueDepthArg+0; activeJobs=activeJobsArg+0; proofRef=proofArg~string
::method isExpired
  expose expiresEpochMs
  use arg nowEpochMs=0
  if expiresEpochMs=0 then return .false
  return nowEpochMs+0 >= expiresEpochMs
::method canonical
  expose nodeId capabilityGeneration observationGeneration observedEpochMs expiresEpochMs freeMemoryMiB freeDiskMiB availableCpuUnits availableMicroWluPerSecond queueDepth activeJobs proofRef
  return "node=" || nodeId || ";capGen=" || capabilityGeneration || ";obsGen=" || observationGeneration || ";observed=" || observedEpochMs || ";expires=" || expiresEpochMs || ";freeMem=" || freeMemoryMiB || ";freeDisk=" || freeDiskMiB || ";availCpu=" || availableCpuUnits || ";availWlu=" || availableMicroWluPerSecond || ";queue=" || queueDepth || ";active=" || activeJobs || ";proofRef=" || proofRef

/* ---------- registry ---------- */
::class NodeCapabilityRegistry public
::method init
  expose capabilities capacities
  capabilities=.directory~new; capacities=.directory~new
::method advertiseCapability guarded
  expose capabilities
  use arg c
  old=capabilities~at(c~nodeId)
  if old<>.nil then do
    if old~generation>c~generation then return .false
    if old~generation=c~generation then do
      if old~canonical<>c~canonical then return .false
      return .true
    end
  end
  capabilities[c~nodeId]=c
  return .true
::method observeCapacity guarded
  expose capabilities capacities
  use arg o
  c=capabilities~at(o~nodeId)
  if c==.nil then return .false
  if c~generation<>o~capabilityGeneration then return .false
  old=capacities~at(o~nodeId)
  if old<>.nil then do
    if old~observationGeneration>o~observationGeneration then return .false
    if old~observationGeneration=o~observationGeneration then do
      if old~canonical<>o~canonical then return .false
      return .true
    end
  end
  capacities[o~nodeId]=o
  return .true
::method revoke guarded
  expose capabilities
  use arg nodeId
  c=capabilities~at(nodeId~string)
  if c<>.nil then c~setOnline(.false)
::method capability guarded
  expose capabilities
  use arg nodeId
  return capabilities~at(nodeId~string)
::method capacity guarded
  expose capacities
  use arg nodeId
  return capacities~at(nodeId~string)
::method nodeIds guarded
  expose capabilities
  a=.array~new
  do k over capabilities; a~append(k); end
  return a

/* ---------- eligibility ---------- */
::class NodeEligibilityAssessment public
::attribute eligible get
::attribute nodeId get
::attribute reasons get
::attribute capability get
::attribute capacity get
::method init
  expose eligible nodeId reasons capability capacity
  use arg nodeIdArg, eligibleArg, reasonsArg, capabilityArg=.nil, capacityArg=.nil
  nodeId=nodeIdArg~string; eligible=eligibleArg; reasons=reasonsArg; capability=capabilityArg; capacity=capacityArg
::method firstReason
  expose reasons
  if reasons~items=0 then return ""
  return reasons[1]

::class JobNodeEligibilityPolicy public
::method init
  expose externalAssessors
  use arg externalAssessorsArg=.nil
  if externalAssessorsArg==.nil then externalAssessors=.array~new; else externalAssessors=externalAssessorsArg
::method assess
  expose externalAssessors
  use arg placementRequest, capability, capacity, nowEpochMs=0
  reasons=.array~new
  if capability==.nil then do; reasons~append("CAPABILITY_MISSING"); return .NodeEligibilityAssessment~new("",.false,reasons,capability,capacity); end
  nodeId=capability~nodeId
  if \capability~online then reasons~append("NODE_OFFLINE")
  r=placementRequest~requirement
  if \.JNASet~containsAll(capability~jurisdictions,r~jurisdictions) then reasons~append("JURISDICTION_NOT_PERMITTED")
  if \.JNASet~containsAll(capability~legalDomains,r~legalDomains) then reasons~append("LEGAL_DOMAIN_NOT_PERMITTED")
  if \.JNASet~containsAll(capability~trustDomains,r~trustDomains) then reasons~append("TRUST_DOMAIN_NOT_SATISFIED")
  if \.JNASet~containsAll(capability~authorities,r~authorities) then reasons~append("REQUIRED_AUTHORITY_UNAVAILABLE")
  if \.JNASet~containsAll(capability~abilities,r~abilities) then reasons~append("REQUIRED_ABILITY_UNAVAILABLE")
  if \.JNASet~containsAll(capability~runtimes,r~runtimes) then reasons~append("RUNTIME_UNAVAILABLE")
  if \.JNASet~containsAll(capability~tags,r~tags) then reasons~append("REQUIRED_TAG_UNAVAILABLE")
  if r~architecture<>"" & capability~architecture<>r~architecture then reasons~append("ARCHITECTURE_MISMATCH")
  if capability~memoryMiB<r~minimumMemoryMiB then reasons~append("INSUFFICIENT_INSTALLED_MEMORY")
  if capability~diskMiB<r~minimumDiskMiB then reasons~append("INSUFFICIENT_INSTALLED_DISK")
  if capability~cpuUnits<r~minimumCpuUnits then reasons~append("INSUFFICIENT_INSTALLED_CPU")
  if r~exactRuntimeGeneration<>"" & capability~runtimeGeneration<>r~exactRuntimeGeneration then reasons~append("RUNTIME_GENERATION_MISMATCH")
  if r~apiRouteRequirement<>.nil then do
    if capability~apiEgressCapability==.nil then reasons~append("API_EGRESS_CAPABILITY_UNAVAILABLE")
    else if \capability~apiEgressCapability~supportsApiRoute(r~apiRouteRequirement) then reasons~append("API_ROUTE_REQUIREMENT_UNSATISFIED")
  end
  /* Capacity is deliberately assessed only as mandatory availability here;
   * its magnitude is not allowed to compensate for any capability failure. */
  if capacity==.nil then reasons~append("CAPACITY_OBSERVATION_MISSING")
  else do
    if capacity~capabilityGeneration<>capability~generation then reasons~append("CAPACITY_CAPABILITY_GENERATION_MISMATCH")
    if capacity~isExpired(nowEpochMs) then reasons~append("CAPACITY_OBSERVATION_EXPIRED")
    if capacity~freeMemoryMiB<r~minimumFreeMemoryMiB then reasons~append("INSUFFICIENT_FREE_MEMORY")
    if capacity~freeDiskMiB<r~minimumFreeDiskMiB then reasons~append("INSUFFICIENT_FREE_DISK")
    if capacity~availableCpuUnits<r~minimumAvailableCpuUnits then reasons~append("INSUFFICIENT_AVAILABLE_CPU")
    neededRate=r~minimumAvailableMicroWluPerSecond
    if placementRequest~requestedRateMicroWluPerSecond>neededRate then neededRate=placementRequest~requestedRateMicroWluPerSecond
    if capacity~availableMicroWluPerSecond<neededRate then reasons~append("INSUFFICIENT_WLU_RATE")
  end
  /* External security/legal/access authorities are also hard eligibility.
   * They return zero or more stable reason codes and are never consulted by
   * the scoring policy. */
  do assessor over externalAssessors
    extra=assessor~assess(placementRequest,capability,capacity,nowEpochMs)
    if extra<>.nil then do reason over extra; reasons~append(reason~string); end
  end
  return .NodeEligibilityAssessment~new(nodeId,reasons~items=0,reasons,capability,capacity)

/* ---------- external hard-authority / admission seams ---------- */
::class JobNodeHardConstraintAssessor public
::method assess abstract

::class JobNodeAdmissionResult public
::attribute admitted get
::attribute code get
::attribute detail get
::attribute reservation get
::attribute reservationRef get
::method init
  expose admitted code detail reservation reservationRef
  use arg admittedArg, codeArg, detailArg="", reservationArg=.nil, refArg=""
  admitted=admittedArg; code=codeArg~string; detail=detailArg~string
  reservation=reservationArg; reservationRef=refArg~string
::method allow class
  use arg reservationArg=.nil, refArg=""
  return self~new(.true,"ADMITTED","",reservationArg,refArg)
::method deny class
  use arg codeArg, detailArg=""
  return self~new(.false,codeArg,detailArg,.nil,"")

::class JobNodeAdmissionAuthority public
::method reserve abstract
::method release abstract

/* ---------- optimisation after eligibility ---------- */
::class JobNodePlacementPolicy public
::method score
  use arg placementRequest, assessment
  if \assessment~eligible then raise syntax 88.900 array("ineligible node must never be scored")
  c=assessment~capacity
  /* Simple v0.1 deterministic fitness: available WLU dominates, then CPU and
   * memory; existing queue/activity subtracts. Policy is replaceable. */
  return c~availableMicroWluPerSecond + (c~availableCpuUnits*1000000) + (c~freeMemoryMiB*1000) - (c~queueDepth*10000) - (c~activeJobs*1000)

/* ---------- proof/digest seam ---------- */
::class JobNodeDigestProvider public
::method digest
  use arg canonicalText
  /* Stable Crypto public surface. */
  return .SHA256~new(canonicalText)~digest

::class JobNodeProofAuthority public
::method sign abstract
::method verify abstract

::class JobNodePlacementLease public
::attribute placementId get
::attribute jobId get
::attribute nodeId get
::attribute ownerNodeId get
::attribute capabilityGeneration get
::attribute capacityObservationGeneration get
::attribute issuedEpochMs get
::attribute expiresEpochMs get
::attribute requirementDigest get
::attribute capabilityDigest get
::attribute capacityDigest get
::attribute allocationPolicyGeneration get
::attribute proofRef get
::attribute reservationRef get
::attribute signature
::attribute ownershipEpoch get
::attribute renewalSequence get
::attribute supersedesPlacementId get
::method init
  expose placementId jobId nodeId ownerNodeId capabilityGeneration capacityObservationGeneration issuedEpochMs expiresEpochMs requirementDigest capabilityDigest capacityDigest allocationPolicyGeneration proofRef reservationRef signature ownershipEpoch renewalSequence supersedesPlacementId
  use arg placementIdArg, jobArg, nodeArg, ownerArg, capGenArg, obsGenArg, issuedArg, expiresArg, reqDigestArg, capDigestArg, capacityDigestArg, policyGenArg="1", proofRefArg="", reservationRefArg="", signatureArg="", ownershipEpochArg=0, renewalSequenceArg=0, supersedesArg=""
  placementId=placementIdArg~string; jobId=jobArg~string; nodeId=nodeArg~string; ownerNodeId=ownerArg~string
  capabilityGeneration=capGenArg+0; capacityObservationGeneration=obsGenArg+0; issuedEpochMs=issuedArg+0; expiresEpochMs=expiresArg+0
  requirementDigest=reqDigestArg~string; capabilityDigest=capDigestArg~string; capacityDigest=capacityDigestArg~string
  allocationPolicyGeneration=policyGenArg~string; proofRef=proofRefArg~string; reservationRef=reservationRefArg~string; signature=signatureArg~string
  ownershipEpoch=ownershipEpochArg+0; renewalSequence=renewalSequenceArg+0; supersedesPlacementId=supersedesArg~string
::method canonical
  expose placementId jobId nodeId ownerNodeId capabilityGeneration capacityObservationGeneration issuedEpochMs expiresEpochMs requirementDigest capabilityDigest capacityDigest allocationPolicyGeneration proofRef reservationRef ownershipEpoch renewalSequence supersedesPlacementId
  return "placement=" || placementId || ";job=" || jobId || ";node=" || nodeId || ";owner=" || ownerNodeId || ";capGen=" || capabilityGeneration || ";obsGen=" || capacityObservationGeneration || ";issued=" || issuedEpochMs || ";expires=" || expiresEpochMs || ";req=" || requirementDigest || ";cap=" || capabilityDigest || ";capacity=" || capacityDigest || ";policy=" || allocationPolicyGeneration || ";proofRef=" || proofRef || ";reservationRef=" || reservationRef || ";ownerEpoch=" || ownershipEpoch || ";renewal=" || renewalSequence || ";supersedes=" || supersedesPlacementId
::method isExpired
  expose expiresEpochMs
  use arg nowEpochMs
  return nowEpochMs+0 >= expiresEpochMs

::class JobNodePlacementDecision public
::attribute placed get
::attribute code get
::attribute lease get
::attribute assessments get
::attribute selectedScore get
::method init
  expose placed code lease assessments selectedScore
  use arg placedArg, codeArg, leaseArg=.nil, assessmentsArg=.nil, scoreArg=0
  placed=placedArg; code=codeArg~string; lease=leaseArg
  if assessmentsArg==.nil then assessments=.array~new; else assessments=assessmentsArg
  selectedScore=scoreArg+0
::method exclusionCount
  expose assessments
  use arg codeArg
  n=0
  do a over assessments
    do r over a~reasons
      if r=codeArg then n+=1
    end
  end
  return n

::class JobNodeAllocator public
::method init
  expose registry eligibilityPolicy placementPolicy digestProvider proofAuthority policyGeneration sequence admissionAuthority activeAdmissions ownershipRegistry
  use arg registryArg, eligibilityArg=.nil, placementArg=.nil, digestArg=.nil, proofArg=.nil, policyGenerationArg="1", admissionArg=.nil, ownershipArg=.nil
  registry=registryArg
  if eligibilityArg==.nil then eligibilityPolicy=.JobNodeEligibilityPolicy~new; else eligibilityPolicy=eligibilityArg
  if placementArg==.nil then placementPolicy=.JobNodePlacementPolicy~new; else placementPolicy=placementArg
  if digestArg==.nil then digestProvider=.JobNodeDigestProvider~new; else digestProvider=digestArg
  proofAuthority=proofArg; policyGeneration=policyGenerationArg~string; sequence=0
  admissionAuthority=admissionArg; activeAdmissions=.directory~new; ownershipRegistry=ownershipArg
::method sequenceValue guarded
  expose sequence
  return sequence
::method restoreSequence guarded
  expose sequence
  use strict arg restoredSequence
  if restoredSequence+0>sequence then sequence=restoredSequence+0
  return sequence
::method admissionReservation guarded
  expose activeAdmissions
  use strict arg lease
  if lease==.nil then return .nil
  return activeAdmissions[lease~placementId]
::method restoreAdmission guarded
  expose activeAdmissions
  use strict arg lease, reservation
  if lease==.nil | reservation==.nil then return .false
  activeAdmissions[lease~placementId]=reservation
  return .true
::method hasAdmission guarded
  expose activeAdmissions
  use strict arg lease
  if lease==.nil then return .false
  if lease~reservationRef="" then return .true
  return activeAdmissions[lease~placementId]<>.nil
::method allocate guarded
  expose registry eligibilityPolicy placementPolicy digestProvider proofAuthority policyGeneration sequence admissionAuthority activeAdmissions ownershipRegistry
  use arg placementRequest, nowEpochMs, leaseDurationMs=30000
  if ownershipRegistry<>.nil then do
    existing=ownershipRegistry~current(placementRequest~jobId,nowEpochMs)
    if existing<>.nil then return .JobNodePlacementDecision~new(.false,"ACTIVE_PLACEMENT_EXISTS",existing,.array~new,0)
  end
  assessments=.array~new; candidates=.array~new
  ids=registry~nodeIds; ids~sort
  do nodeId over ids
    c=registry~capability(nodeId); o=registry~capacity(nodeId)
    a=eligibilityPolicy~assess(placementRequest,c,o,nowEpochMs)
    assessments~append(a)
    if a~eligible then do
      score=placementPolicy~score(placementRequest,a)
      candidates~append(.array~of(score,nodeId,a))
    end
  end
  if candidates~items=0 then return .JobNodePlacementDecision~new(.false,"NO_ELIGIBLE_NODE",.nil,assessments,0)
  /* deterministic score-descending, node-id-ascending candidate order */
  do i=1 to candidates~items-1
    do j=i+1 to candidates~items
      left=candidates[i]; right=candidates[j]
      swap=.false
      if right[1]>left[1] then swap=.true
      else if right[1]=left[1] & right[2]<left[2] then swap=.true
      if swap then do; tmp=candidates[i]; candidates[i]=candidates[j]; candidates[j]=tmp; end
    end
  end
  chosen=.nil; chosenScore=0; admission=.nil
  do candidate over candidates
    a=candidate[3]
    if admissionAuthority==.nil then admission=.JobNodeAdmissionResult~allow
    else admission=admissionAuthority~reserve(placementRequest,a~capability,a~capacity,leaseDurationMs)
    if admission<>.nil & admission~admitted then do
      chosen=a; chosenScore=candidate[1]; leave
    end
  end
  if chosen==.nil then return .JobNodePlacementDecision~new(.false,"ADMISSION_DENIED",.nil,assessments,0)
  sequence+=1
  cap=chosen~capability; obs=chosen~capacity
  reqDigest=digestProvider~digest(placementRequest~canonical)
  capDigest=digestProvider~digest(cap~canonical)
  obsDigest=digestProvider~digest(obs~canonical)
  placementId="PLACE-" || sequence || "-" || placementRequest~jobId
  expires=nowEpochMs+leaseDurationMs
  if obs~expiresEpochMs>0 & obs~expiresEpochMs<expires then expires=obs~expiresEpochMs
  proofRef=cap~proofRef
  reservationRef=admission~reservationRef
  ownershipEpoch=0
  if ownershipRegistry<>.nil then ownershipEpoch=ownershipRegistry~nextEpoch(placementRequest~jobId)
  lease=.JobNodePlacementLease~new(placementId,placementRequest~jobId,cap~nodeId,placementRequest~ownerNodeId,cap~generation,obs~observationGeneration,nowEpochMs,expires,reqDigest,capDigest,obsDigest,policyGeneration,proofRef,reservationRef,"",ownershipEpoch,0,"")
  if proofAuthority<>.nil then lease~signature=proofAuthority~sign(lease~canonical)
  if ownershipRegistry<>.nil then do
    if \ownershipRegistry~claim(lease,nowEpochMs) then do
      if admission~reservation<>.nil & admissionAuthority<>.nil then admissionAuthority~release(admission~reservation)
      return .JobNodePlacementDecision~new(.false,"OWNERSHIP_CLAIM_FAILED",.nil,assessments,0)
    end
  end
  if admission~reservation<>.nil then activeAdmissions[placementId]=admission~reservation
  return .JobNodePlacementDecision~new(.true,"PLACED",lease,assessments,chosenScore)
::method renewPlacement guarded
  expose registry eligibilityPolicy digestProvider proofAuthority policyGeneration admissionAuthority activeAdmissions ownershipRegistry
  use strict arg lease, placementRequest, nowEpochMs, leaseDurationMs=30000
  if lease==.nil then return .JobNodePlacementDecision~new(.false,"PLACEMENT_LEASE_REQUIRED")
  if lease~jobId<>placementRequest~jobId then return .JobNodePlacementDecision~new(.false,"PLACEMENT_JOB_MISMATCH")
  if lease~isExpired(nowEpochMs) then return .JobNodePlacementDecision~new(.false,"PLACEMENT_LEASE_EXPIRED",lease)
  if ownershipRegistry<>.nil then if \ownershipRegistry~isCurrent(lease,nowEpochMs) then return .JobNodePlacementDecision~new(.false,"PLACEMENT_NOT_CURRENT_OWNER",lease)
  if digestProvider~digest(placementRequest~canonical)<>lease~requirementDigest then return .JobNodePlacementDecision~new(.false,"PLACEMENT_REQUIREMENT_CHANGED",lease)
  if proofAuthority<>.nil then if \proofAuthority~verify(lease~canonical,lease~signature) then return .JobNodePlacementDecision~new(.false,"PLACEMENT_PROOF_INVALID",lease)
  cap=registry~capability(lease~nodeId); obs=registry~capacity(lease~nodeId)
  if cap==.nil | obs==.nil then return .JobNodePlacementDecision~new(.false,"PLACEMENT_NODE_STATE_MISSING",lease)
  if cap~generation<>lease~capabilityGeneration then return .JobNodePlacementDecision~new(.false,"PLACEMENT_CAPABILITY_CHANGED",lease)
  a=eligibilityPolicy~assess(placementRequest,cap,obs,nowEpochMs)
  aa=.array~new; aa~append(a)
  if \a~eligible then return .JobNodePlacementDecision~new(.false,"PLACEMENT_NO_LONGER_ELIGIBLE",lease,aa)
  replacement=.JobNodeAdmissionResult~allow
  oldReservation=activeAdmissions[lease~placementId]
  if admissionAuthority<>.nil then do
    replacement=admissionAuthority~reserve(placementRequest,cap,obs,leaseDurationMs)
    if replacement==.nil | \replacement~admitted then return .JobNodePlacementDecision~new(.false,"RENEWAL_ADMISSION_DENIED",lease,aa)
  end
  if oldReservation<>.nil & admissionAuthority<>.nil then do
    if \admissionAuthority~release(oldReservation) then do
      if replacement~reservation<>.nil then admissionAuthority~release(replacement~reservation)
      return .JobNodePlacementDecision~new(.false,"RENEWAL_OLD_RESERVATION_RELEASE_FAILED",lease,aa)
    end
  end
  expires=nowEpochMs+leaseDurationMs
  if obs~expiresEpochMs>0 & obs~expiresEpochMs<expires then expires=obs~expiresEpochMs
  reservationRef=replacement~reservationRef
  if replacement~reservation==.nil & oldReservation==.nil then reservationRef=lease~reservationRef
  renewed=.JobNodePlacementLease~new(lease~placementId,lease~jobId,lease~nodeId,lease~ownerNodeId,cap~generation,obs~observationGeneration,nowEpochMs,expires,lease~requirementDigest,digestProvider~digest(cap~canonical),digestProvider~digest(obs~canonical),policyGeneration,cap~proofRef,reservationRef,"",lease~ownershipEpoch,lease~renewalSequence+1,lease~supersedesPlacementId)
  if proofAuthority<>.nil then renewed~signature=proofAuthority~sign(renewed~canonical)
  if ownershipRegistry<>.nil then if \ownershipRegistry~claim(renewed,nowEpochMs) then do
    if replacement~reservation<>.nil & admissionAuthority<>.nil then admissionAuthority~release(replacement~reservation)
    return .JobNodePlacementDecision~new(.false,"RENEWAL_OWNERSHIP_CLAIM_FAILED",lease,aa)
  end
  if replacement~reservation<>.nil then activeAdmissions[lease~placementId]=replacement~reservation
  else activeAdmissions~remove(lease~placementId)
  return .JobNodePlacementDecision~new(.true,"RENEWED",renewed,aa,0)
::method releasePlacement guarded
  expose admissionAuthority activeAdmissions ownershipRegistry
  use arg lease
  if lease==.nil then return .false
  if ownershipRegistry<>.nil then ownershipRegistry~release(lease)
  reservation=activeAdmissions[lease~placementId]
  if reservation==.nil then return .true
  if admissionAuthority==.nil then return .false
  ok=admissionAuthority~release(reservation)
  if ok then activeAdmissions~remove(lease~placementId)
  return ok
::method verifyLease
  expose registry digestProvider proofAuthority ownershipRegistry activeAdmissions policyGeneration
  use arg lease, placementRequest, nowEpochMs
  if lease==.nil | placementRequest==.nil then return .false
  if lease~jobId<>placementRequest~jobId then return .false
  if lease~ownerNodeId<>placementRequest~ownerNodeId then return .false
  if lease~allocationPolicyGeneration<>policyGeneration then return .false
  if lease~isExpired(nowEpochMs) then return .false
  if ownershipRegistry<>.nil then if \ownershipRegistry~isCurrent(lease,nowEpochMs) then return .false
  if lease~reservationRef<>"" then if activeAdmissions[lease~placementId]==.nil then return .false
  c=registry~capability(lease~nodeId); if c==.nil then return .false
  o=registry~capacity(lease~nodeId); if o==.nil then return .false
  if \c~online then return .false
  if o~isExpired(nowEpochMs) then return .false
  if c~generation<>lease~capabilityGeneration then return .false
  if o~capabilityGeneration<>c~generation then return .false
  if o~observationGeneration<>lease~capacityObservationGeneration then return .false
  if digestProvider~digest(placementRequest~canonical)<>lease~requirementDigest then return .false
  if digestProvider~digest(c~canonical)<>lease~capabilityDigest then return .false
  if digestProvider~digest(o~canonical)<>lease~capacityDigest then return .false
  if proofAuthority<>.nil then if \proofAuthority~verify(lease~canonical,lease~signature) then return .false
  return .true

::requires "crypto.cls"
