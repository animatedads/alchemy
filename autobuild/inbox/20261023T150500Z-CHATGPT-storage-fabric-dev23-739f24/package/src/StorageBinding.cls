/* ooRexx Storage Fabric application binding seam.
 *
 * Durable job/application definitions carry StorageRefs / pinned generations.
 * Machine-local pathnames are transient execution bindings contained inside
 * leases and must never become durable application identity.
 */

::class StorageBindingBuild public
::constant VERSION "0.1-dev12"
::constant API "storage.fabric.binding/0.1"

::class StorageBindingAccess public
::constant READ_ONLY "READ_ONLY"
::constant READ_WRITE "READ_WRITE"

::class StorageBindingState public
::constant ACTIVE "ACTIVE"
::constant RELEASED "RELEASED"

::class StorageOutputState public
::constant RESERVED "RESERVED"
::constant WRITING "WRITING"
::constant COMMITTED "COMMITTED"
::constant RELEASED "RELEASED"

/* A durable input pin.  sourcePath is discovery/provenance only and is
 * intentionally omitted from identityKey(). */
::class StoragePinnedRef public
::attribute ref get
::attribute generation get
::attribute digest get
::attribute sourcePath get
::method init
  expose ref generation digest sourcePath
  use arg refArg, generationArg, digestArg="", sourcePathArg=""
  if refArg==.nil then raise syntax 88.900 array("StoragePinnedRef StorageRef is mandatory")
  ref=refArg
  generation=generationArg~string~strip
  if generation="" then raise syntax 88.900 array("StoragePinnedRef generation must not be empty")
  digest=digestArg~string~strip
  if digest="" then digest=ref~digest
  sourcePath=sourcePathArg~string
::method identityKey
  expose ref generation digest
  return ref~objectId||"|g="||generation||"|digest="||digest
::method sameIdentity
  use arg other
  if other==.nil then return .false
  if \other~hasMethod("IDENTITYKEY") then return .false
  return self~identityKey==other~identityKey

/* Frozen membership set for multi-file jobs.  Roles are durable semantic
 * names (cameraVideo, calibration, etc.), not pathnames. */
::class StorageRefSet public
::attribute setId get
::attribute generation get
::attribute sealed get
::method init
  expose setId generation members order sealed
  use arg setIdArg, generationArg
  setId=setIdArg~string~strip
  generation=generationArg~string~strip
  if setId="" | generation="" then raise syntax 88.900 array("StorageRefSet id and generation are mandatory")
  members=.directory~new
  order=.array~new
  sealed=.false
::method add
  expose members order sealed
  use arg roleArg, pinnedRefArg
  if sealed then raise syntax 88.900 array("StorageRefSet is sealed")
  role=roleArg~string~strip
  if role="" | pinnedRefArg==.nil then raise syntax 88.900 array("StorageRefSet role and pinned ref are mandatory")
  if members[role]<>.nil then raise syntax 88.900 array("duplicate StorageRefSet role:" role)
  members[role]=pinnedRefArg
  order~append(role)
  return self
::method seal
  expose sealed
  sealed=.true
  return self
::method member
  expose members
  use arg roleArg
  return members[roleArg~string]
::method roles
  expose order
  a=.array~new
  do r over order; a~append(r); end
  return a
::method count
  expose order
  return order~items
::method identityManifest
  expose setId generation members order
  s="set="||setId||";generation="||generation
  do r over order
    s=s||";"||r||"="||members[r]~identityKey
  end
  return s


/* Resolve human-friendly namespace paths exactly once at job submission and
 * turn them into durable pins.  Later namespace retargeting cannot alter the
 * already-created pin. */
::class StorageRolePath public
::attribute role get
::attribute path get
::method init
  expose role path
  use arg roleArg, pathArg
  role=roleArg~string~strip
  path=.StoragePath~normalize(pathArg)
  if role="" then raise syntax 88.900 array("StorageRolePath role is mandatory")

::class StorageNamespacePinResolver public
::method pin
  use arg namespaceArg, pathArg
  if namespaceArg==.nil then raise syntax 88.900 array("namespace is mandatory")
  p=.StoragePath~normalize(pathArg)
  r=namespaceArg~resolve(p)
  if r==.nil | \r~found then raise syntax 88.900 array("Storage namespace path does not resolve:" p)
  ref=r~entry~ref
  if ref==.nil then raise syntax 88.900 array("Storage namespace path resolved without StorageRef:" p)
  digest=ref~digest
  if digest="" then do
    obj=namespaceArg~catalogue~get(ref~objectId)
    if obj<>.nil then digest=obj~ref~digest
  end
  return .StoragePinnedRef~new(ref,namespaceArg~environment~generation,digest,p)
::method pinSet
  use arg namespaceArg, setIdArg, rolePathsArg
  if rolePathsArg==.nil then raise syntax 88.900 array("role/path list is mandatory")
  generation=namespaceArg~environment~generation
  set=.StorageRefSet~new(setIdArg,generation)
  do rp over rolePathsArg
    if rp==.nil | \rp~hasMethod("ROLE") | \rp~hasMethod("PATH") then
      raise syntax 88.900 array("pinSet requires StorageRolePath-like entries")
    set~add(rp~role,self~pin(namespaceArg,rp~path))
  end
  return set~seal

/* The only place where a transient machine-local pathname belongs. */
::class StorageMaterialisationLease public
::attribute leaseId get
::attribute pinnedRef get
::attribute nodeId get
::attribute localPath get
::attribute verifiedDigest get
::attribute accessMode get
::attribute state get
::attribute evidenceRef get
::method init
  expose leaseId pinnedRef nodeId localPath verifiedDigest accessMode state evidenceRef
  use arg leaseIdArg, pinnedRefArg, nodeArg, localPathArg, verifiedDigestArg="", accessModeArg="READ_ONLY", evidenceArg=""
  leaseId=leaseIdArg~string~strip
  pinnedRef=pinnedRefArg
  nodeId=nodeArg~string~strip
  localPath=localPathArg~string
  verifiedDigest=verifiedDigestArg~string~strip
  accessMode=accessModeArg~string~strip~upper
  evidenceRef=evidenceArg~string
  state=.StorageBindingState~ACTIVE
  if leaseId="" | pinnedRef==.nil | nodeId="" | localPath="" then
    raise syntax 88.900 array("materialisation lease id/ref/node/path are mandatory")
  if accessMode<>.StorageBindingAccess~READ_ONLY & accessMode<>.StorageBindingAccess~READ_WRITE then
    raise syntax 88.900 array("invalid materialisation access mode")
  expected=pinnedRef~digest
  if expected<>"" & verifiedDigest<>"" & expected<>verifiedDigest then
    raise syntax 88.900 array("materialisation digest does not match pinned StorageRef")
::method active
  expose state
  return state=.StorageBindingState~ACTIVE
::method release
  expose state
  if state=.StorageBindingState~RELEASED then return .false
  state=.StorageBindingState~RELEASED
  return .true
::method identityKey
  expose pinnedRef
  return pinnedRef~identityKey

/* A provider-neutral materialisation authority.  Subclasses implement
 * materialisePinned(); the base class enforces the returned lease contract. */
::class StorageMaterialisationAuthority public
::method materialise
  use arg pinnedRefArg, nodeArg, accessArg="READ_ONLY", leaseIdArg=""
  if pinnedRefArg==.nil then raise syntax 88.900 array("pinned StorageRef is mandatory")
  node=nodeArg~string~strip
  if node="" then raise syntax 88.900 array("target node is mandatory")
  lease=self~materialisePinned(pinnedRefArg,node,accessArg,leaseIdArg)
  if lease==.nil | \lease~hasMethod("IDENTITYKEY") | \lease~hasMethod("LOCALPATH") then
    raise syntax 88.900 array("materialisation authority returned an invalid lease")
  if lease~identityKey<>pinnedRefArg~identityKey then
    raise syntax 88.900 array("materialisation authority changed durable object identity")
  return lease
::method materialisePinned abstract

/* Binds an entire immutable input set on one execution node. */
::class StorageJobBinding public
::attribute jobId get
::attribute nodeId get
::attribute inputSet get
::method init
  expose jobId nodeId inputSet leases roleOrder released
  use arg jobArg, nodeArg, inputSetArg
  jobId=jobArg~string~strip
  nodeId=nodeArg~string~strip
  inputSet=inputSetArg
  leases=.directory~new
  roleOrder=.array~new
  released=.false
  if jobId="" | nodeId="" | inputSet==.nil then raise syntax 88.900 array("job/node/input set are mandatory")
  if \inputSet~sealed then raise syntax 88.900 array("job input StorageRefSet must be sealed")
::method bind
  expose jobId nodeId inputSet leases roleOrder
  use arg authority, accessArg="READ_ONLY"
  if authority==.nil then raise syntax 88.900 array("materialisation authority is mandatory")
  do role over inputSet~roles
    pin=inputSet~member(role)
    leaseId=jobId||":"||role
    lease=authority~materialise(pin,nodeId,accessArg,leaseId)
    leases[role]=lease
    roleOrder~append(role)
  end
  return self
::method lease
  expose leases
  use arg roleArg
  return leases[roleArg~string]
::method localPath
  expose leases
  use arg roleArg
  l=leases[roleArg~string]
  if l==.nil then return ""
  return l~localPath
::method pathMap
  expose leases roleOrder
  d=.directory~new
  do r over roleOrder
    d[r]=leases[r]~localPath
  end
  return d
::method release
  expose leases roleOrder released
  if released then return .false
  do r over roleOrder
    if leases[r]<>.nil then leases[r]~release
  end
  released=.true
  return .true

/* Durable output intent: the job specifies what it needs, not where to put it. */
::class StorageOutputIntent public
::attribute role get
::attribute mediaType get
::attribute expectedBytes get
::attribute requiredSafeReplicas get
::method init
  expose role mediaType expectedBytes requiredSafeReplicas
  use arg roleArg, mediaArg="application/octet-stream", expectedArg=0, requiredSafeArg=1
  role=roleArg~string~strip
  mediaType=mediaArg~string
  expectedBytes=expectedArg+0
  requiredSafeReplicas=requiredSafeArg+0
  if role="" | expectedBytes<0 | requiredSafeReplicas<0 then raise syntax 88.900 array("invalid output intent")

::class StorageOutputLease public
::attribute intent get
::attribute allocation get
::attribute nodeId get
::attribute localPath get
::attribute state get
::attribute committedRef get
::method init
  expose intent allocation workspaceManager nodeId localPath state committedRef
  use arg intentArg, allocationArg, nodeArg, localPathArg="", workspaceManagerArg=.nil
  intent=intentArg; allocation=allocationArg; workspaceManager=workspaceManagerArg; nodeId=nodeArg~string~strip
  if intent==.nil | allocation==.nil | nodeId="" then raise syntax 88.900 array("output intent/allocation/node are mandatory")
  localPath=localPathArg~string
  if localPath="" then localPath=allocation~locator||"/"||self~safeName(intent~role)
  state=.StorageOutputState~RESERVED
  committedRef=.nil
::method safeName private
  use arg sArg
  s=sArg~string
  /* role names are semantic identifiers; flatten characters unsafe in paths */
  do c over .array~of("/","\\",":"," ")
    s=changestr(c,s,"_")
  end
  if s="" then s="output"
  return s
::method markWriting
  expose state
  if state<>.StorageOutputState~RESERVED then return .false
  state=.StorageOutputState~WRITING
  return .true
::method commit
  expose intent state committedRef
  use arg refArg, safeReplicaCountArg
  if state=.StorageOutputState~RELEASED | state=.StorageOutputState~COMMITTED then
    raise syntax 88.900 array("output lease is not commit-capable in its current state")
  if refArg==.nil then raise syntax 88.900 array("committed StorageRef is mandatory")
  if safeReplicaCountArg+0<intent~requiredSafeReplicas then
    raise syntax 88.900 array("durable output requirement not satisfied")
  committedRef=refArg
  state=.StorageOutputState~COMMITTED
  return committedRef
::method release
  expose allocation workspaceManager state
  if state=.StorageOutputState~RELEASED then return .false
  if workspaceManager<>.nil then workspaceManager~release(allocation~allocationId)
  else allocation~release
  state=.StorageOutputState~RELEASED
  return .true

::class StorageOutputAllocator public
::method reserve
  use arg workspaceManager, nodeArg, intentArg, ownerArg="", allocationIdArg=""
  if workspaceManager==.nil | intentArg==.nil then raise syntax 88.900 array("workspace manager and output intent are mandatory")
  bytes=intentArg~expectedBytes
  if bytes<1 then bytes=1
  pool=workspaceManager~bestWorkspacePoolForNode(nodeArg,bytes)
  if pool==.nil then return .nil
  a=workspaceManager~allocate(pool~poolId,bytes,ownerArg,allocationIdArg)
  if a==.nil then return .nil
  return .StorageOutputLease~new(intentArg,a,nodeArg,"",workspaceManager)

::requires "src/StorageFabric.cls"
