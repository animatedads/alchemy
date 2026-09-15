/* ooRexx Managed Node Host Profile v0.1-dev1
 *
 * Provider-neutral host identity/capability/bootstrap seam for Managed Node.
 * No SSH, shell transport or remote execution is implemented here.
 */

::class ManagedNodeHostProfileBuild public
::constant VERSION "0.1-dev1"
::constant API "managed.node.host.profile/0.1"

::class ManagedNodeBootstrapState public
::constant DISCOVERED "DISCOVERED"
::constant PREPARING "PREPARING"
::constant QUEUE_READY "QUEUE_READY"
::constant DEGRADED "DEGRADED"

::class ManagedNodeHostIdentity public
::attribute nodeId get
::attribute provider get
::attribute providerResourceId get
::attribute displayName get
::attribute costClass get
::attribute region get
::attribute availabilityDomain get
::attribute faultDomain get
::attribute networkEgressCapable get
::method init
  expose nodeId provider providerResourceId displayName costClass region availabilityDomain faultDomain networkEgressCapable
  use arg nodeArg, providerArg="", providerIdArg="", displayArg="", costArg="", regionArg="", adArg="", fdArg="", egressArg=.false
  nodeId=nodeArg~string~strip
  provider=providerArg~string~strip~upper
  providerResourceId=providerIdArg~string~strip
  displayName=displayArg~string~strip
  costClass=costArg~string~strip~upper
  region=regionArg~string~strip~upper
  availabilityDomain=adArg~string~strip~upper
  faultDomain=fdArg~string~strip~upper
  networkEgressCapable=(egressArg==.true)
  if nodeId="" then raise syntax 88.900 array("nodeId must not be empty")
::method canonical
  expose nodeId provider providerResourceId displayName costClass region availabilityDomain faultDomain networkEgressCapable
  return "nodeId="||nodeId||";provider="||provider||";providerId="||providerResourceId||";display="||displayName||";cost="||costClass||";region="||region||";ad="||availabilityDomain||";fd="||faultDomain||";egress="||networkEgressCapable

/* Capability profile changes require a new allocator capability generation. */
::class ManagedNodeCapabilityProfile public
::attribute nodeId get
::attribute online get
::attribute queueReady get
::attribute runtimeGeneration get
::attribute architecture get
::attribute memoryMiB get
::attribute diskMiB get
::attribute cpuUnits get
::attribute runtimes get
::attribute taskKinds get
::attribute proofRef get
::method init
  expose nodeId online queueReady runtimeGeneration architecture memoryMiB diskMiB cpuUnits runtimes taskKinds proofRef
  use arg nodeArg, onlineArg=.false, queueReadyArg=.false, runtimeGenerationArg="", architectureArg="", memoryArg=0, diskArg=0, cpuArg=0, runtimesArg=.nil, taskKindsArg=.nil, proofArg=""
  nodeId=nodeArg~string~strip
  online=(onlineArg==.true)
  queueReady=(queueReadyArg==.true)
  runtimeGeneration=runtimeGenerationArg~string~strip
  architecture=architectureArg~string~strip~upper
  memoryMiB=memoryArg+0; diskMiB=diskArg+0; cpuUnits=cpuArg+0
  if runtimesArg==.nil then runtimes=.array~new; else runtimes=runtimesArg
  if taskKindsArg==.nil then taskKinds=.array~new; else taskKinds=taskKindsArg
  proofRef=proofArg~string
  if nodeId="" then raise syntax 88.900 array("nodeId must not be empty")
  if memoryMiB<0 | diskMiB<0 | cpuUnits<0 then raise syntax 88.900 array("installed resources must not be negative")
::method canonical
  expose nodeId online queueReady runtimeGeneration architecture memoryMiB diskMiB cpuUnits runtimes taskKinds proofRef
  rt=""; do r over runtimes; if rt<>"" then rt=rt||","; rt=rt||r~string~upper; end
  tk=""; do k over taskKinds; if tk<>"" then tk=tk||","; tk=tk||k~string~upper; end
  return "node="||nodeId||";online="||online||";queueReady="||queueReady||";runtimeGen="||runtimeGeneration||";arch="||architecture||";mem="||memoryMiB||";disk="||diskMiB||";cpu="||cpuUnits||";runtimes="||rt||";taskKinds="||tk||";proof="||proofRef

/* Capacity is intentionally transient and expiry-bounded. */
::class ManagedNodeCapacitySample public
::attribute nodeId get
::attribute freeMemoryMiB get
::attribute freeDiskMiB get
::attribute availableCpuUnits get
::attribute availableMicroWluPerSecond get
::attribute queueDepth get
::attribute activeJobs get
::attribute proofRef get
::method init
  expose nodeId freeMemoryMiB freeDiskMiB availableCpuUnits availableMicroWluPerSecond queueDepth activeJobs proofRef
  use arg nodeArg, freeMemArg=0, freeDiskArg=0, availCpuArg=0, availWluArg=0, queueDepthArg=0, activeJobsArg=0, proofArg=""
  nodeId=nodeArg~string~strip
  freeMemoryMiB=freeMemArg+0; freeDiskMiB=freeDiskArg+0; availableCpuUnits=availCpuArg+0
  availableMicroWluPerSecond=availWluArg+0; queueDepth=queueDepthArg+0; activeJobs=activeJobsArg+0
  proofRef=proofArg~string
  if nodeId="" then raise syntax 88.900 array("nodeId must not be empty")
  if freeMemoryMiB<0 | freeDiskMiB<0 | availableCpuUnits<0 | availableMicroWluPerSecond<0 | queueDepth<0 | activeJobs<0 then raise syntax 88.900 array("capacity values must not be negative")

/* Terminal owns the concrete implementation (SSH, PTY, host-key trust,
 * credentials, file transfer and bootstrap automation). */
::class ManagedNodeBootstrapPort public
::method inspect abstract
::method prepareRuntime abstract
::method prepareQueueEndpoint abstract
::method recoverQueueEndpoint abstract

::class ManagedNodeBootstrapReceipt public
::attribute nodeId get
::attribute state get
::attribute runtimeGeneration get
::attribute runtimes get
::attribute queueReady get
::attribute evidenceRef get
::method init
  expose nodeId state runtimeGeneration runtimes queueReady evidenceRef
  use arg nodeArg, stateArg, generationArg="", runtimesArg=.nil, queueReadyArg=.false, evidenceArg=""
  nodeId=nodeArg~string~strip; state=stateArg~string~upper; runtimeGeneration=generationArg~string
  if runtimesArg==.nil then runtimes=.array~new; else runtimes=runtimesArg
  queueReady=(queueReadyArg==.true); evidenceRef=evidenceArg~string
  if nodeId="" then raise syntax 88.900 array("nodeId must not be empty")

::class ManagedNodeHostProfilePublisher public
::method capability
  use arg identity, profile, capabilityGeneration=1
  if identity==.nil | profile==.nil then raise syntax 88.900 array("identity and profile are mandatory")
  if identity~nodeId<>profile~nodeId then raise syntax 88.900 array("identity/profile node mismatch")
  abilities=.array~new
  /* Queue readiness is a hard admission gate for ordinary managed work. */
  if profile~online & profile~queueReady then do
    abilities~append("MANAGED_NODE_EXECUTION")
    do kind over profile~taskKinds
      a=.ManagedTaskKind~requiredAbility(kind)
      if a<>"" then abilities~append(a)
    end
  end
  tags=.array~of("MANAGED_NODE","NO_ACCELERATOR")
  if identity~provider<>"" then tags~append("PROVIDER_"||identity~provider)
  if identity~costClass<>"" then tags~append("COST_"||identity~costClass)
  if identity~region<>"" then tags~append("REGION_"||identity~region)
  if identity~availabilityDomain<>"" then tags~append("AVAILABILITY_DOMAIN_"||identity~availabilityDomain)
  if identity~faultDomain<>"" then tags~append("FAULT_DOMAIN_"||identity~faultDomain)
  if identity~networkEgressCapable then tags~append("NETWORK_EGRESS")
  c=.NodeCapabilityStatement~new(identity~nodeId,capabilityGeneration,profile~proofRef,.nil,.nil,.nil,.nil,abilities,profile~runtimes,tags,profile~architecture,profile~memoryMiB,profile~diskMiB,profile~cpuUnits,profile~runtimeGeneration,.nil)
  if \profile~online then c~setOnline(.false)
  return c
::method capacity
  use arg sample, capabilityGeneration=1, observationGeneration=1, observedEpochMs=0, expiresEpochMs=0
  if sample==.nil then raise syntax 88.900 array("capacity sample is mandatory")
  return .NodeCapacityObservation~new(sample~nodeId,capabilityGeneration,observationGeneration,observedEpochMs,expiresEpochMs,sample~freeMemoryMiB,sample~freeDiskMiB,sample~availableCpuUnits,sample~availableMicroWluPerSecond,sample~queueDepth,sample~activeJobs,sample~proofRef)

::requires "ManagedNode.cls"
::requires "JobNodeAllocator.cls"
