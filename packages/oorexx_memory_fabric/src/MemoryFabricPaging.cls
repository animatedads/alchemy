/* MemoryFabricPaging.cls
 * ooRexx Memory Fabric v0.1-dev6
 * memory.fabric.paging/0.1
 *
 * RexxOS/MI paging control over an MU-resident MemoryBlockBag.
 *
 * The control plane tracks page-group ownership, dirty/clean state, pinning,
 * block backing and MI/bag epochs.  It does NOT require page payloads to pass
 * through Rexx.  Production transfer plans are intended for the native
 * QEMU/shared-memory/DMA path below memory.fabric.block/0.1.
 *
 * swapOutBytes()/swapInBytes() are qualification/debug conveniences only.
 */

::class MemoryFabricPageResidency public
::constant RESIDENT "RESIDENT"
::constant SWAPPED "SWAPPED"
::constant RELEASED "RELEASED"

::class MemoryFabricPageTransferKind public
::constant SWAP_OUT "SWAP_OUT"
::constant SWAP_IN "SWAP_IN"
::constant EVICT_CLEAN "EVICT_CLEAN"

::class MemoryFabricPageGroup public
::method init
  expose groupId ownerMiId ownerMiEpoch logicalBytes pageBytes residency dirty pinCount backingHandle recoveryClass recoveryRef generation
  use strict arg groupId, ownerMiId, ownerMiEpoch, logicalBytes, pageBytes, recoveryClass="VOLATILE", recoveryRef=""
  numeric digits 20
  groupId=groupId~string~strip
  ownerMiId=ownerMiId~string~strip
  ownerMiEpoch=ownerMiEpoch+0
  logicalBytes=logicalBytes+0
  pageBytes=pageBytes+0
  recoveryClass=recoveryClass~string~upper
  recoveryRef=recoveryRef~string
  if groupId="" | ownerMiId="" then raise syntax 88.900 array("page group requires groupId and owner MI")
  if ownerMiEpoch<1 | logicalBytes<1 | pageBytes<1 then raise syntax 88.900 array("invalid page-group size/epoch")
  residency=.MemoryFabricPageResidency~RESIDENT
  dirty=.true
  pinCount=0
  backingHandle=.nil
  generation=1

::attribute groupId get
::attribute ownerMiId get
::attribute ownerMiEpoch get
::attribute logicalBytes get
::attribute pageBytes get
::attribute residency get
::attribute dirty get
::attribute pinCount get
::attribute backingHandle get
::attribute recoveryClass get
::attribute recoveryRef get
::attribute generation get

::method pageCount
  expose logicalBytes pageBytes
  numeric digits 20
  return (logicalBytes+pageBytes-1)%pageBytes

::method isPinned
  expose pinCount
  return pinCount>0

::method pin
  expose pinCount generation
  numeric digits 20
  pinCount+=1
  generation+=1
  return pinCount

::method unpin
  expose pinCount generation
  numeric digits 20
  if pinCount<1 then return .false
  pinCount-=1
  generation+=1
  return .true

::method markDirty
  expose residency dirty generation
  if residency<>.MemoryFabricPageResidency~RESIDENT then return .false
  dirty=.true
  generation+=1
  return .true

::method installBacking
  expose backingHandle generation
  use strict arg h
  backingHandle=h
  generation+=1
  return .true

::method markSwappedClean
  expose residency dirty generation
  residency=.MemoryFabricPageResidency~SWAPPED
  dirty=.false
  generation+=1
  return .true

::method markResidentClean
  expose residency dirty generation
  residency=.MemoryFabricPageResidency~RESIDENT
  dirty=.false
  generation+=1
  return .true

::method markReleased
  expose residency generation
  residency=.MemoryFabricPageResidency~RELEASED
  generation+=1
  return .true

::method rebindOwnerEpoch
  expose ownerMiEpoch generation
  use strict arg newMiEpoch
  numeric digits 20
  if newMiEpoch<1 then return .false
  ownerMiEpoch=newMiEpoch+0
  generation+=1
  return .true


::class MemoryFabricPageTransferPlan public
::method init
  expose planId kind spaceId spaceEpoch groupId groupGeneration miId miEpoch attachmentId bagId bagEpoch blockHandle byteCount transferRequired
  use strict arg planId, kind, spaceId, spaceEpoch, groupId, groupGeneration, miId, miEpoch, attachmentId, bagId, bagEpoch, blockHandle, byteCount, transferRequired=.true
  numeric digits 20
  planId=planId~string
  kind=kind~string~upper
  spaceId=spaceId~string
  spaceEpoch=spaceEpoch+0
  groupId=groupId~string
  groupGeneration=groupGeneration+0
  miId=miId~string
  miEpoch=miEpoch+0
  attachmentId=attachmentId~string
  bagId=bagId~string
  bagEpoch=bagEpoch+0
  byteCount=byteCount+0
  transferRequired=transferRequired
::attribute planId get
::attribute kind get
::attribute spaceId get
::attribute spaceEpoch get
::attribute groupId get
::attribute groupGeneration get
::attribute miId get
::attribute miEpoch get
::attribute attachmentId get
::attribute bagId get
::attribute bagEpoch get
::attribute blockHandle get
::attribute byteCount get
::attribute transferRequired get


::class MemoryFabricPageSwapReceipt public
::method init
  expose receiptId operation spaceId groupId miId miEpoch bagId bagEpoch blockId blockGeneration byteCount beforeResidency afterResidency dirtyBefore dirtyAfter
  use strict arg receiptId, operation, spaceId, groupId, miId, miEpoch, bagId, bagEpoch, blockId, blockGeneration, byteCount, beforeResidency, afterResidency, dirtyBefore, dirtyAfter
  numeric digits 20
  receiptId=receiptId~string
  operation=operation~string~upper
  spaceId=spaceId~string
  groupId=groupId~string
  miId=miId~string
  miEpoch=miEpoch+0
  bagId=bagId~string
  bagEpoch=bagEpoch+0
  blockId=blockId~string
  blockGeneration=blockGeneration+0
  byteCount=byteCount+0
  beforeResidency=beforeResidency~string~upper
  afterResidency=afterResidency~string~upper
  dirtyBefore=dirtyBefore
  dirtyAfter=dirtyAfter
::attribute receiptId get
::attribute operation get
::attribute spaceId get
::attribute groupId get
::attribute miId get
::attribute miEpoch get
::attribute bagId get
::attribute bagEpoch get
::attribute blockId get
::attribute blockGeneration get
::attribute byteCount get
::attribute beforeResidency get
::attribute afterResidency get
::attribute dirtyBefore get
::attribute dirtyAfter get


::class MemoryFabricPagingSpace public
::method init
  expose spaceId miId miEpoch bag attachment groups receipts nextPlan nextReceipt spaceEpoch
  use strict arg spaceId, miId, miEpoch, bag, attachment
  numeric digits 20
  spaceId=spaceId~string~strip
  miId=miId~string~strip
  miEpoch=miEpoch+0
  if spaceId="" | miId="" | miEpoch<1 then raise syntax 88.900 array("invalid paging-space identity")
  if bag=.nil | attachment=.nil then raise syntax 88.900 array("paging space requires bag and MI attachment")
  if attachment~miId<>miId | attachment~miEpoch<>miEpoch then raise syntax 88.900 array("attachment MI identity/epoch mismatch")
  if \bag~validateAttachment(attachment) then raise syntax 88.900 array("paging-space attachment is not valid for current bag incarnation")
  groups=.directory~new
  receipts=.array~new
  nextPlan=1
  nextReceipt=1
  spaceEpoch=1

::attribute spaceId get
::attribute miId get
::attribute miEpoch get
::attribute spaceEpoch get
::attribute bag get
::attribute attachment get

::method registerGroup
  expose groups miId miEpoch bag
  use strict arg groupId, logicalBytes, recoveryClass="VOLATILE", recoveryRef=""
  numeric digits 20
  groupId=groupId~string~strip
  if groupId="" | groups[groupId]<>.nil then return .nil
  g=.MemoryFabricPageGroup~new(groupId,miId,miEpoch,logicalBytes,bag~largePageBytes,recoveryClass,recoveryRef)
  groups[groupId]=g
  return g

::method group
  expose groups
  use strict arg groupId
  return groups[groupId~string]

::method allGroups
  expose groups
  return groups~allItems

::method allReceipts
  expose receipts
  return receipts~copy

::method pin
  use strict arg groupId
  g=self~group(groupId)
  if g=.nil | g~residency=.MemoryFabricPageResidency~RELEASED then return 0
  return g~pin

::method unpin
  use strict arg groupId
  g=self~group(groupId)
  if g=.nil then return .false
  return g~unpin

::method markDirty
  use strict arg groupId
  g=self~group(groupId)
  if g=.nil then return .false
  return g~markDirty

::method ensureBacking
  expose bag
  use strict arg g
  h=g~backingHandle
  if h<>.nil then do
    if bag~validate(h) then return h
    return .nil
  end
  h=bag~allocate(g~logicalBytes,g~recoveryClass,g~recoveryRef)
  if h=.nil then return .nil
  unused=g~installBacking(h)
  return h

::method prepareSwapOut
  expose spaceId miId miEpoch bag attachment nextPlan spaceEpoch
  use strict arg groupId
  numeric digits 20
  g=self~group(groupId)
  if g=.nil then return .nil
  if g~residency<>.MemoryFabricPageResidency~RESIDENT | g~isPinned then return .nil
  if \bag~validateAttachment(attachment) then return .nil

  h=self~ensureBacking(g)
  if h=.nil then return .nil

  if g~dirty then do
    kind=.MemoryFabricPageTransferKind~SWAP_OUT
    xfer=.true
  end
  else do
    kind=.MemoryFabricPageTransferKind~EVICT_CLEAN
    xfer=.false
  end
  id=spaceId||"-plan-"||nextPlan
  nextPlan+=1
  return .MemoryFabricPageTransferPlan~new(id,kind,spaceId,spaceEpoch,g~groupId,g~generation,miId,miEpoch,attachment~attachmentId,bag~bagId,bag~ownerEpoch,h,g~logicalBytes,xfer)

::method validatePlan
  expose spaceId miId miEpoch bag attachment spaceEpoch
  use strict arg plan, expectedKind=""
  if plan=.nil then return .false
  if plan~spaceId<>spaceId | plan~spaceEpoch<>spaceEpoch then return .false
  if plan~miId<>miId | plan~miEpoch<>miEpoch then return .false
  if plan~attachmentId<>attachment~attachmentId then return .false
  if plan~bagId<>bag~bagId | plan~bagEpoch<>bag~ownerEpoch then return .false
  if \bag~validateAttachment(attachment) then return .false
  if expectedKind<>"" then do
    if plan~kind<>expectedKind~string~upper then return .false
  end
  g=self~group(plan~groupId)
  if g=.nil | g~generation<>plan~groupGeneration then return .false
  if g~backingHandle=.nil then return .false
  if \bag~validate(g~backingHandle) then return .false
  if g~backingHandle~blockId<>plan~blockHandle~blockId | g~backingHandle~generation<>plan~blockHandle~generation then return .false
  return .true

::method commitSwapOut
  expose receipts nextReceipt spaceId miId miEpoch bag
  use strict arg plan
  if \self~validatePlan(plan) then return .nil
  if plan~kind<>.MemoryFabricPageTransferKind~SWAP_OUT & plan~kind<>.MemoryFabricPageTransferKind~EVICT_CLEAN then return .nil
  g=self~group(plan~groupId)
  if g~residency<>.MemoryFabricPageResidency~RESIDENT | g~isPinned then return .nil
  beforeResidency=g~residency
  dirtyBefore=g~dirty
  unused=g~markSwappedClean
  h=g~backingHandle
  id=spaceId||"-receipt-"||nextReceipt
  nextReceipt+=1
  r=.MemoryFabricPageSwapReceipt~new(id,plan~kind,spaceId,g~groupId,miId,miEpoch,bag~bagId,bag~ownerEpoch,h~blockId,h~generation,g~logicalBytes,beforeResidency,g~residency,dirtyBefore,g~dirty)
  receipts~append(r)
  return r

::method prepareSwapIn
  expose spaceId miId miEpoch bag attachment nextPlan spaceEpoch
  use strict arg groupId
  numeric digits 20
  g=self~group(groupId)
  if g=.nil | g~residency<>.MemoryFabricPageResidency~SWAPPED then return .nil
  if g~isPinned | g~backingHandle=.nil then return .nil
  if \bag~validateAttachment(attachment) | \bag~validate(g~backingHandle) then return .nil
  id=spaceId||"-plan-"||nextPlan
  nextPlan+=1
  return .MemoryFabricPageTransferPlan~new(id,.MemoryFabricPageTransferKind~SWAP_IN,spaceId,spaceEpoch,g~groupId,g~generation,miId,miEpoch,attachment~attachmentId,bag~bagId,bag~ownerEpoch,g~backingHandle,g~logicalBytes,.true)

::method commitSwapIn
  expose receipts nextReceipt spaceId miId miEpoch bag
  use strict arg plan
  if \self~validatePlan(plan,.MemoryFabricPageTransferKind~SWAP_IN) then return .nil
  g=self~group(plan~groupId)
  if g~residency<>.MemoryFabricPageResidency~SWAPPED | g~isPinned then return .nil
  beforeResidency=g~residency
  dirtyBefore=g~dirty
  unused=g~markResidentClean
  h=g~backingHandle
  id=spaceId||"-receipt-"||nextReceipt
  nextReceipt+=1
  r=.MemoryFabricPageSwapReceipt~new(id,plan~kind,spaceId,g~groupId,miId,miEpoch,bag~bagId,bag~ownerEpoch,h~blockId,h~generation,g~logicalBytes,beforeResidency,g~residency,dirtyBefore,g~dirty)
  receipts~append(r)
  return r

/* Qualification/debug convenience only: payload is materialised as a Rexx
 * string. Production RexxOS uses prepare/commit with the native QEMU path. */
::method swapOutBytes
  expose bag attachment
  use strict arg groupId, bytes
  g=self~group(groupId)
  if g=.nil | bytes~length<>g~logicalBytes then return .nil
  plan=self~prepareSwapOut(groupId)
  if plan=.nil then return .nil
  if plan~transferRequired then do
    if bag~writeBytesFor(attachment,plan~blockHandle,bytes)<>bytes~length then return .nil
    if \bag~flush(plan~blockHandle) then return .nil
  end
  return self~commitSwapOut(plan)

::method swapInBytes
  expose bag attachment
  use strict arg groupId
  plan=self~prepareSwapIn(groupId)
  if plan=.nil then return .nil
  bytes=bag~readBytesFor(attachment,plan~blockHandle,plan~byteCount)
  if bytes=.nil then return .nil
  receipt=self~commitSwapIn(plan)
  if receipt=.nil then return .nil
  answer=.directory~new
  answer["bytes"]=bytes
  answer["receipt"]=receipt
  return answer

/* Rebind the control plane after an MI restart.  The space epoch advances,
 * fencing every in-flight transfer plan. Existing valid MU backing remains
 * associated with the logical groups, but the caller must act on the recovery
 * obligations returned by restartObligations(). */
::method rebindMI
  expose miId miEpoch bag attachment spaceEpoch groups
  use strict arg newMiEpoch, newAttachment
  numeric digits 20
  newMiEpoch=newMiEpoch+0
  if newMiEpoch<=miEpoch | newAttachment=.nil then return .false
  if newAttachment~miId<>miId | newAttachment~miEpoch<>newMiEpoch then return .false
  if \bag~validateAttachment(newAttachment) then return .false
  oldAttachment=attachment
  miEpoch=newMiEpoch
  attachment=newAttachment
  unused=bag~detachMI(oldAttachment)
  spaceEpoch+=1
  do g over groups~allItems
    unused=g~rebindOwnerEpoch(newMiEpoch)
  end
  return .true

::method restartObligations
  expose groups bag
  obligations=.array~new
  do g over groups~allItems
    d=.directory~new
    d["groupId"]=g~groupId
    d["residency"]=g~residency
    d["dirty"]=g~dirty
    d["recoveryClass"]=g~recoveryClass
    d["recoveryRef"]=g~recoveryRef
    h=g~backingHandle
    hasBacking=(h<>.nil)
    if hasBacking then hasBacking=bag~validate(h)
    d["hasValidBacking"]=hasBacking
    if g~residency=.MemoryFabricPageResidency~SWAPPED & hasBacking then
      d["action"]="RESTORE_FROM_MU_BACKING"
    else if g~residency=.MemoryFabricPageResidency~RESIDENT & \g~dirty & hasBacking then
      d["action"]="RESTORE_FROM_MU_BACKING"
    else if g~recoveryClass="RECONSTRUCTABLE" then
      d["action"]="RECONSTRUCT_FROM_REFERENCE"
    else if g~recoveryClass="REPLICATED" then
      d["action"]="VERIFY_OR_PROMOTE_REPLICA"
    else if g~recoveryClass="CHECKPOINTED" then
      d["action"]="RESTORE_CHECKPOINT"
    else
      d["action"]="DROP_VOLATILE"
    obligations~append(d)
  end
  return obligations

::method releaseGroup
  expose groups bag
  use strict arg groupId
  g=self~group(groupId)
  if g=.nil | g~isPinned then return .false
  h=g~backingHandle
  if h<>.nil then do
    if bag~validate(h) then do
      if \bag~release(h) then return .false
    end
  end
  unused=g~markReleased
  groups~remove(g~groupId)
  return .true

::requires "MemoryFabricMemoryBlock.cls"
