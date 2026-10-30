/* StorageRepairPeerSource.cls
 * Verified peer materialisation adapter for Storage repair.
 * API: storage.fabric.repair.peer-source/0.1
 *
 * This adapter consumes the existing StoragePeerClient/StoragePeerMaterialiser
 * contract. It chooses only from explicit/canonical Storage location evidence,
 * materialises to a temporary staged path, and returns verified bytes to the
 * repair destination planner. It never admits the staged copy as durable.
 */

::class StorageRepairPeerSourceBuild public
::constant VERSION "0.1-dev9"
::constant API "storage.fabric.repair.peer-source/0.1"

/* The selector is deliberately bounded by an explicit allowlist. A caller may
 * name metadata["source_peer"], but that peer must be allowed and must still be
 * represented by an AVAILABLE+VERIFIED location for the object. Without an
 * explicit requested peer, the first allowed nodeId from a verified available
 * object location is selected. No topology/telemetry inference occurs here. */
::class StorageRepairPeerSelector public
::method init
  expose allowed
  use strict arg allowedPeersArg
  allowed=.directory~new
  if allowedPeersArg==.nil then raise syntax 88.900 array("STORAGE_REPAIR_ALLOWED_PEERS_REQUIRED")
  do peer over allowedPeersArg
    p=peer~string~strip
    if p<>"" then allowed[p]=.true
  end
  if allowed~items=0 then raise syntax 88.900 array("STORAGE_REPAIR_ALLOWED_PEERS_EMPTY")

::method allowed private
  expose allowed
  use strict arg peerArg
  return allowed[peerArg~string~strip]<>.nil

::method select
  use strict arg object,payload=.nil
  if object==.nil then return ""

  requested=""
  if payload<>.nil then do
    if payload~isA(.Directory) then do
      metadata=payload["metadata"]
      if metadata<>.nil then do
        if metadata~isA(.Directory) then do
          if metadata["source_peer"]<>.nil then requested=metadata["source_peer"]~string~strip
        end
      end
    end
  end

  if requested<>"" then do
    if \self~allowed(requested) then return ""
    do loc over object~locations
      if loc~nodeId=requested then do
        if loc~state=.StorageLocationState~AVAILABLE then do
          if loc~verified then return requested
        end
      end
    end
    return ""
  end

  do loc over object~locations
    peer=loc~nodeId~string~strip
    if peer="" then iterate
    if \self~allowed(peer) then iterate
    if loc~state<>.StorageLocationState~AVAILABLE then iterate
    if \loc~verified then iterate
    return peer
  end
  return ""

/* Produces an unused target pathname beneath a pre-created staging directory.
 * The directory itself is deployment/admin authority and is not created here. */
::class StorageRepairStagingPathAllocator public
::method init
  expose root
  use strict arg rootArg
  root=rootArg~string~strip
  if root="" then raise syntax 88.900 array("STORAGE_REPAIR_STAGING_ROOT_REQUIRED")
  if stream(root,"c","query exists")="" then raise syntax 88.900 array("STORAGE_REPAIR_STAGING_ROOT_NOT_FOUND",root)

::method allocate
  expose root
  use strict arg object,payload=.nil
  if object==.nil then return ""
  pattern=root
  if right(pattern,1)<>"/" then pattern=pattern||"/"
  pattern=pattern||"storage-repair-source-??????"
  path=SysTempFileName(pattern)
  if path="" then return ""
  /* StoragePeerMaterialiser requires an unused target. Some Rexx runtimes may
   * reserve the returned path; remove it before passing the lease onward. */
  if stream(path,"c","query exists")<>"" then do
    rcDelete=SysFileDelete(path)
    if rcDelete<>0 then return ""
  end
  return path

::class StoragePeerRepairSourceResolver public
::attribute client get
::attribute materialiser get
::attribute selector get
::attribute allocator get

::method init
  expose client materialiser selector allocator
  use strict arg clientArg,materialiserArg,selectorArg,allocatorArg
  if clientArg==.nil | materialiserArg==.nil | selectorArg==.nil | allocatorArg==.nil then -
    raise syntax 88.900 array("STORAGE_REPAIR_PEER_SOURCE_DEPENDENCIES_REQUIRED")
  client=clientArg
  materialiser=materialiserArg
  selector=selectorArg
  allocator=allocatorArg

::method resolve
  expose client materialiser selector allocator
  use strict arg object,payload=.nil
  if object==.nil then return .StorageRepairSourceResult~failure("OBJECT_REQUIRED")
  peer=selector~select(object,payload)
  if peer="" then return .StorageRepairSourceResult~failure("NO_ELIGIBLE_SOURCE_PEER")
  target=allocator~allocate(object,payload)
  if target="" then return .StorageRepairSourceResult~failure("SOURCE_STAGE_ALLOCATION_FAILED")

  result=materialiser~materialise(client,peer,object~ref,target)
  if result==.nil then do
    self~deleteIfPresent(target)
    return .StorageRepairSourceResult~failure("PEER_MATERIALISE_FAILED","nil materialise result")
  end
  if \result~ok then do
    self~deleteIfPresent(target)
    return .StorageRepairSourceResult~failure(result~code)
  end
  if result~code<>"VERIFIED" then do
    self~deleteIfPresent(target)
    return .StorageRepairSourceResult~failure("PEER_MATERIALISE_NOT_VERIFIED",result~code)
  end

  expected=.StoragePeerCodec~normaliseSha256(object~ref~digest)
  actual=.StoragePeerCodec~normaliseSha256(result~digest)
  if expected="" | actual="" | expected<>actual then do
    self~deleteIfPresent(target)
    return .StorageRepairSourceResult~failure("PEER_MATERIALISE_DIGEST_MISMATCH")
  end
  if result~path<>target then do
    self~deleteIfPresent(target)
    return .StorageRepairSourceResult~failure("PEER_MATERIALISE_PATH_MISMATCH")
  end
  return .StorageRepairSourceResult~success(target,"sha256:"||actual,.true)

::method deleteIfPresent private
  use strict arg pathArg
  path=pathArg~string
  if path="" then return .true
  if stream(path,"c","query exists")="" then return .true
  return SysFileDelete(path)=0

::requires "StorageRepairPlanner.cls"
::requires "StoragePeer.cls"
