/* Storage Fabric adapter for Migratable Job v0.2. */
::class MigratableJobStorageTransferPlan public
::attribute transfer get
::attribute source get
::attribute sink get
::attribute checkpointRoot get
::attribute verifier get
::attribute destinationCheckpointRef get
::method init
  expose transfer source sink checkpointRoot verifier destinationCheckpointRef
  use strict arg transferArg, sourceArg, sinkArg, checkpointRootArg="", verifierArg=.nil, destinationRefArg=""
  transfer=transferArg; source=sourceArg; sink=sinkArg; checkpointRoot=checkpointRootArg~string; verifier=verifierArg; destinationCheckpointRef=destinationRefArg~string
  if transfer==.nil | source==.nil | sink==.nil | destinationCheckpointRef="" then raise syntax 88.900 array("invalid migration storage transfer plan")

::class MigratableJobStorageTransferResolver public
::method resolve abstract

::class MigratableJobStorageTransferAdapter subclass MigratableJobTransferAdapter public
::method init
  expose engine resolver
  use strict arg engineArg, resolverArg
  engine=engineArg; resolver=resolverArg
::method transfer
  expose engine resolver
  use strict arg migration, maxChunksArg=0
  p=resolver~resolve(migration)
  if p==.nil then return .MigratableJobTransferResult~new(.MigratableJobTransferStatus~FAILED,"","",0,"TRANSFER_PLAN_UNAVAILABLE")
  r=engine~copy(p~transfer,p~source,p~sink,p~checkpointRoot,maxChunksArg,p~verifier)
  if r==.nil then return .MigratableJobTransferResult~new(.MigratableJobTransferStatus~FAILED,"","",0,"STORAGE_RESULT_MISSING")
  if r~status=.StorageTransferRunStatus~PAUSED then return .MigratableJobTransferResult~new(.MigratableJobTransferStatus~PAUSED,r~verificationRef,p~destinationCheckpointRef,r~bytesTransferred,r~failure)
  if r~status<>.StorageTransferRunStatus~COMPLETED then return .MigratableJobTransferResult~new(.MigratableJobTransferStatus~FAILED,r~verificationRef,p~destinationCheckpointRef,r~bytesTransferred,r~failure)
  verification=r~verificationRef
  if verification="" then return .MigratableJobTransferResult~new(.MigratableJobTransferStatus~FAILED,"",p~destinationCheckpointRef,r~bytesTransferred,"STORAGE_VERIFICATION_REQUIRED")
  return .MigratableJobTransferResult~new(.MigratableJobTransferStatus~COMPLETED,verification,p~destinationCheckpointRef,r~bytesTransferred,"")

/* Qualification/local-filesystem resolver. Production providers should map the
 * checkpoint StorageRef/provider locator to their own byte source/sink. */
::class MigratableJobLocalFileTransferResolver subclass MigratableJobStorageTransferResolver public
::method init
  expose destinationRoot chunkVerifier
  use strict arg destinationRootArg, verifierArg=.nil
  destinationRoot=destinationRootArg~string
  if destinationRoot="" then raise syntax 88.900 array("destination root required")
  if verifierArg==.nil then chunkVerifier=.StoragePosixSha256Verifier~new; else chunkVerifier=verifierArg
::method resolve
  expose destinationRoot chunkVerifier
  use strict arg migration
  sourcePath=migration~checkpointTransferRef
  if sourcePath="" then return .nil
  source=.StorageLocalFileByteSource~new(sourcePath)
  node=migration~destinationLease~nodeId
  dir=destinationRoot||"/"||node
  call SysMkDir destinationRoot
  call SysMkDir dir
  destination=dir||"/"||migration~migrationId||".checkpoint"
  sink=.StorageLocalFileByteSink~new(destination)
  ref=.StorageRef~new(migration~checkpointManifest~checkpointId,migration~checkpointManifest~stateDigest)
  loc=.StorageLocation~new("migration-source",sourcePath,"migration",.StorageLocationState~AVAILABLE,"",.true,migration~checkpointManifest~stateDigest,.StorageSafetyClass~SAFE,.StorageLifecycleState~STABLE,migration~sourceLease~nodeId)
  xfer=.StorageTransfer~new("MJ-"||migration~migrationId,ref,loc,"migration-local",destination,source~sizeBytes)
  ckroot=destination||".xfer"
  return .MigratableJobStorageTransferPlan~new(xfer,source,sink,ckroot,chunkVerifier,destination)

::requires "MigratableJob.cls"
::requires "src/StorageStreaming.cls"
