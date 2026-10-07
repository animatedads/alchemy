/* MemoryFabricMemoryBlock.cls
 * ooRexx Memory Fabric v0.1-dev6
 * memory.fabric.block/0.1
 *
 * Native MU-resident large-block bag.  Fabric semantics live here; the native
 * connector only maps/copies bytes.  QEMU/DMA is deliberately below this ABI.
 */

::class MemoryBlockNative public
::method open external "LIBRARY memory_block_connector MBOpen"
::method close external "LIBRARY memory_block_connector MBClose"
::method write external "LIBRARY memory_block_connector MBWrite"
::method read external "LIBRARY memory_block_connector MBRead"
::method copy external "LIBRARY memory_block_connector MBCopy"
::method zero external "LIBRARY memory_block_connector MBZero"
::method flush external "LIBRARY memory_block_connector MBFlush"
::method capacity external "LIBRARY memory_block_connector MBCapacity"
::method pageSize external "LIBRARY memory_block_connector MBPageSize"

::class MemoryBlockExtent public
::method init
  expose offset length
  use strict arg offset, length
::attribute offset get
::attribute length get

::class MemoryBlockHandle public
::method init
  expose bagId blockId generation offset length ownerEpoch recoveryClass recoveryRef state
  use strict arg bagId, blockId, generation, offset, length, ownerEpoch=1, recoveryClass="VOLATILE", recoveryRef="", state="LIVE"
  numeric digits 20
  bagId=bagId~string
  blockId=blockId~string
  generation=generation+0
  offset=offset+0
  length=length+0
  ownerEpoch=ownerEpoch+0
  providerState=providerState~string~upper
  allocationState=allocationState~string~upper
  recoveryClass=recoveryClass~string~upper
  recoveryRef=recoveryRef~string
  state=state~string~upper
::attribute bagId get
::attribute blockId get
::attribute generation get
::attribute offset get
::attribute length get
::attribute ownerEpoch get
::attribute providerState get
::attribute allocationState get
::attribute recoveryClass get
::attribute recoveryRef get
::attribute state get
::method asReleased
  expose bagId blockId generation offset length ownerEpoch recoveryClass recoveryRef
  return .MemoryBlockHandle~new(bagId,blockId,generation,offset,length,ownerEpoch,recoveryClass,recoveryRef,"RELEASED")
::method canonical
  expose bagId blockId generation offset length ownerEpoch recoveryClass recoveryRef state
  return "bag="||bagId||";block="||blockId||";generation="||generation||";offset="||offset||";length="||length||";ownerEpoch="||ownerEpoch||";recovery="||recoveryClass||";recoveryRef="||recoveryRef||";state="||state

::class MemoryBlockAttachment public
::method init
  expose attachmentId bagId muId miId bagEpoch miEpoch state
  use strict arg attachmentId, bagId, muId, miId, bagEpoch, miEpoch=1, state="ACTIVE"
  numeric digits 20
  attachmentId=attachmentId~string
  bagId=bagId~string
  muId=muId~string
  miId=miId~string
  bagEpoch=bagEpoch+0
  miEpoch=miEpoch+0
  state=state~string~upper
::attribute attachmentId get
::attribute bagId get
::attribute muId get
::attribute miId get
::attribute bagEpoch get
::attribute miEpoch get
::attribute state get

::class MemoryBlockBag public
::method init
  expose bagId muId containerPath capacityBytes largePageBytes ownerEpoch native nativeHandle highWater freeExtents liveById nextBlock nextGeneration closed providerState allocationState attachments nextAttachment
  use strict arg bagId, muId, containerPath, capacityBytes, largePageBytes=2097152, ownerEpoch=1, createFile=.true, providerState="ACTIVE", allocationState="ACCEPTING"
  numeric digits 20
  bagId=bagId~string~strip
  muId=muId~string~strip
  containerPath=containerPath~string
  capacityBytes=capacityBytes+0
  largePageBytes=largePageBytes+0
  ownerEpoch=ownerEpoch+0
  if bagId="" | muId="" | containerPath="" then raise syntax 88.900 array("bagId/muId/containerPath are mandatory")
  if capacityBytes<1 | largePageBytes<1 | ownerEpoch<1 then raise syntax 88.900 array("invalid memory-block bag sizing/epoch")
  native=.MemoryBlockNative~new
  nativeHandle=native~open(containerPath,capacityBytes,createFile,.true)
  if nativeHandle=0 then raise syntax 88.900 array("native memory-block container open failed: "||containerPath)
  highWater=0
  freeExtents=.array~new
  liveById=.directory~new
  nextBlock=1
  nextGeneration=1
  closed=.false
  attachments=.directory~new
  nextAttachment=1

::attribute bagId get
::attribute muId get
::attribute containerPath get
::attribute capacityBytes get
::attribute largePageBytes get
::attribute ownerEpoch get

::method nativePageSize
  expose native
  return native~pageSize

::method alignLength
  expose largePageBytes
  use strict arg bytes
  numeric digits 20
  bytes=bytes+0
  if bytes<1 then return 0
  return ((bytes+largePageBytes-1)%largePageBytes)*largePageBytes

::method allocatedBytes
  expose liveById
  numeric digits 20
  n=0
  do h over liveById~allItems
    n+=h~length
  end
  return n

::method availableBytes
  expose capacityBytes
  numeric digits 20
  return capacityBytes-self~allocatedBytes

::method allocate
  expose bagId ownerEpoch highWater freeExtents liveById nextBlock nextGeneration capacityBytes closed providerState allocationState
  use strict arg requestedBytes, recoveryClass="VOLATILE", recoveryRef=""
  numeric digits 20
  if closed then return .nil
  if providerState<>"ACTIVE" | allocationState<>"ACCEPTING" then return .nil
  bytes=self~alignLength(requestedBytes)
  if bytes=0 then return .nil
  chosenOffset=-1
  chosenIndex=0
  chosenLength=0
  do i=1 to freeExtents~items
    e=freeExtents[i]
    if e~length>=bytes then do
      chosenOffset=e~offset; chosenIndex=i; chosenLength=e~length; leave
    end
  end
  if chosenIndex>0 then do
    freeExtents~delete(chosenIndex)
    if chosenLength>bytes then freeExtents~append(.MemoryBlockExtent~new(chosenOffset+bytes,chosenLength-bytes))
  end
  else do
    if highWater+bytes>capacityBytes then return .nil
    chosenOffset=highWater
    highWater+=bytes
  end
  blockId=bagId||"-"||nextBlock
  nextBlock+=1
  generation=nextGeneration
  nextGeneration+=1
  h=.MemoryBlockHandle~new(bagId,blockId,generation,chosenOffset,bytes,ownerEpoch,recoveryClass,recoveryRef)
  liveById[blockId]=h
  return h

::method validate
  expose bagId ownerEpoch liveById closed
  use strict arg h
  if closed | h=.nil then return .false
  if h~bagId<>bagId | h~ownerEpoch<>ownerEpoch | h~state<>"LIVE" then return .false
  live=liveById[h~blockId]
  if live=.nil then return .false
  return live~generation=h~generation & live~offset=h~offset & live~length=h~length

::method release
  expose liveById freeExtents native nativeHandle
  use strict arg h
  if \self~validate(h) then return .false
  if native~zero(nativeHandle,h~offset,h~length)<>h~length then return .false
  liveById~remove(h~blockId)
  freeExtents~append(.MemoryBlockExtent~new(h~offset,h~length))
  return .true

/* Qualification/debug ingress.  Production MI page movement should use the
 * native/QEMU block path below this object, not Rexx string materialisation. */
::method writeBytes
  expose native nativeHandle
  use strict arg h, bytes, relativeOffset=0
  numeric digits 20
  if \self~validate(h) then return 0
  relativeOffset=relativeOffset+0
  if relativeOffset<0 | relativeOffset+bytes~length>h~length then return 0
  return native~write(nativeHandle,h~offset+relativeOffset,bytes)

::method readBytes
  expose native nativeHandle
  use strict arg h, bytes, relativeOffset=0
  numeric digits 20
  if \self~validate(h) then return .nil
  bytes=bytes+0; relativeOffset=relativeOffset+0
  if bytes<0 | relativeOffset<0 | relativeOffset+bytes>h~length then return .nil
  return native~read(nativeHandle,h~offset+relativeOffset,bytes)

::method copyBlock
  expose native nativeHandle
  use strict arg destination, source, bytes=0
  numeric digits 20
  if \self~validate(destination) | \self~validate(source) then return 0
  if bytes=0 then bytes=source~length
  if bytes>destination~length | bytes>source~length then return 0
  return native~copy(nativeHandle,destination~offset,source~offset,bytes)

/* Attachment-gated MI ingress for the Memory Fabric control boundary.
 * The payload still moves in the native connector; this only proves that the
 * MI holds a lease for the current MU bag incarnation before the operation. */
::method writeBytesFor
  use strict arg attachment, h, bytes, relativeOffset=0
  if \self~validateAttachment(attachment) then return 0
  return self~writeBytes(h,bytes,relativeOffset)

::method readBytesFor
  use strict arg attachment, h, bytes, relativeOffset=0
  if \self~validateAttachment(attachment) then return .nil
  return self~readBytes(h,bytes,relativeOffset)

::method copyBlockFor
  use strict arg attachment, destination, source, bytes=0
  if \self~validateAttachment(attachment) then return 0
  return self~copyBlock(destination,source,bytes)

::method flush
  expose native nativeHandle
  use strict arg h
  if \self~validate(h) then return .false
  return native~flush(nativeHandle,h~offset,h~length)

::method attachMI
  expose bagId muId ownerEpoch providerState attachments nextAttachment
  use strict arg miId, miEpoch=1
  if providerState="OFFLINE" then return .nil
  miId=miId~string~strip
  if miId="" then return .nil
  id=bagId||"-attach-"||nextAttachment
  nextAttachment+=1
  a=.MemoryBlockAttachment~new(id,bagId,muId,miId,ownerEpoch,miEpoch,"ACTIVE")
  attachments[id]=a
  return a

::method validateAttachment
  expose bagId muId ownerEpoch providerState attachments
  use strict arg a
  if a=.nil | providerState="OFFLINE" then return .false
  current=attachments[a~attachmentId]
  if current=.nil then return .false
  return current~state="ACTIVE" & a~bagId=bagId & a~muId=muId & a~bagEpoch=ownerEpoch & current~miEpoch=a~miEpoch

::method detachMI
  expose attachments
  use strict arg a
  if a=.nil then return .false
  current=attachments[a~attachmentId]
  if current=.nil then return .false
  attachments~remove(a~attachmentId)
  return .true

::method transitionLifecycle
  expose providerState allocationState
  use strict arg newProviderState, newAllocationState=""
  newProviderState=newProviderState~string~upper
  if newProviderState="DRAINING" then newAllocationState="DRAINING"
  if newProviderState="OFFLINE" then newAllocationState="CLOSED"
  if newProviderState="SPARE" & newAllocationState="" then newAllocationState="RESERVED"
  if newProviderState="ACTIVE" & newAllocationState="" then newAllocationState="ACCEPTING"
  if newAllocationState="" then newAllocationState=allocationState
  providerState=newProviderState
  allocationState=newAllocationState~string~upper
  return .true

::method advanceOwnerEpoch
  expose ownerEpoch providerState allocationState attachments
  use strict arg newProviderState="ACTIVE", newAllocationState="ACCEPTING"
  numeric digits 20
  ownerEpoch+=1
  providerState=newProviderState~string~upper
  allocationState=newAllocationState~string~upper
  /* Attachments belong to the old bag incarnation and are fenced. */
  attachments=.directory~new
  return ownerEpoch

::method close
  expose native nativeHandle closed providerState allocationState attachments
  if closed then return .true
  ok=native~close(nativeHandle)
  if ok then do
    closed=.true
    providerState="OFFLINE"
    allocationState="CLOSED"
    attachments=.directory~new
  end
  return ok
