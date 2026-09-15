/* IBM4361Journal.cls
 *
 * OPTIONAL live in-process journal/rewind integration for IBM4361Machine.
 *
 * This is deliberately NOT an IBM4361 freeze-file codec.  Durable/exported
 * machine evidence remains IBM4361State.cls.  Journal points exist only inside
 * the running ooRexx process and may be used to rewind/fork/retry execution.
 */
::options digits 30

::class IBM370StorageRangeDelta public
::method init
  expose address oldHex newHex
  use strict arg address,oldHex,newHex
::method applyForward
  expose address newHex
  use strict arg storage
  storage~storeHex(address,newHex)
  return storage
::method applyReverse
  expose address oldHex
  use strict arg storage
  storage~storeHex(address,oldHex)
  return storage
::method address; expose address; return address
::method oldHex; expose oldHex; return oldHex
::method newHex; expose newHex; return newHex

::class IBM370StorageKeyDelta public
::method init
  expose block oldValue newValue
  use strict arg block,oldValue,newValue
::method applyForward
  expose block newValue
  use strict arg storage
  storage~setStorageKeyRaw(block,newValue)
  return storage
::method applyReverse
  expose block oldValue
  use strict arg storage
  storage~setStorageKeyRaw(block,oldValue)
  return storage
::method block; expose block; return block
::method oldValue; expose oldValue; return oldValue
::method newValue; expose newValue; return newValue

::class IBM370StorageJournalEvent public
::method init
  expose operations tag metadata
  use strict arg sourceOperations,tag="",metadata=.nil
  operations=.array~new
  do op over sourceOperations
    operations~append(op)
  end
::method operations; expose operations; return operations
::method tag; expose tag; return tag
::method metadata; expose metadata; return metadata
::method applyForward
  expose operations
  use strict arg storage
  do op over operations
    op~applyForward(storage)
  end
  return storage
::method applyReverse
  expose operations
  use strict arg storage
  do i=operations~items to 1 by -1
    operations[i]~applyReverse(storage)
  end
  return storage

/* Sparse/range-delta RAM participant.  The underlying IBM370Storage remains
 * the authoritative live RAM object.  The JournalPointedState stores one
 * immutable event object per committed event, not RAM snapshots. */
::class IBM370JournaledStorage subclass IBM370Storage public
::method init
  expose journal recording operations eventTag eventMetadata replaying
  use strict arg sizeBytes=16777216,keyBlockSize=2048,requestedJournalId=""
  self~init:super(sizeBytes,keyBlockSize)
  if requestedJournalId="" then requestedJournalId="IBM370-RAM"
  journal=.JournalPointedState~new(.nil,requestedJournalId)
  recording=.false
  replaying=.false
  operations=.array~new
  eventTag=""
  eventMetadata=.nil

::method beginJournalEvent
  expose recording operations eventTag eventMetadata
  use strict arg tag="EVENT",metadata=.nil
  if recording then raise syntax 88.900 array("IBM370 storage journal event already active")
  recording=.true
  operations=.array~new
  eventTag=tag
  eventMetadata=metadata
  return self~journalPoint

::method journalEventActive
  expose recording
  return recording

::method commitJournalEvent
  expose journal recording operations eventTag eventMetadata
  if \recording then raise syntax 88.900 array("IBM370 storage journal event is not active")
  recording=.false
  if operations~items=0 then return journal~journalPoint
  ev=.IBM370StorageJournalEvent~new(operations,eventTag,eventMetadata)
  operations=.array~new
  return journal~put("EVENT",ev,eventTag,eventMetadata)

::method abortJournalEvent
  expose recording operations replaying
  if \recording then return self~journalPoint
  replaying=.true
  do i=operations~items to 1 by -1
    operations[i]~applyReverse(self)
  end
  replaying=.false
  recording=.false
  operations=.array~new
  return self~journalPoint

::method storeByte
  expose recording operations replaying
  use strict arg address,value
  if \recording | replaying then return self~storeByte:super(address,value)
  oldValue=self~byteAt(address)
  self~storeByte:super(address,value)
  newValue=self~byteAt(address)
  if oldValue \= newValue then operations~append(.IBM370StorageRangeDelta~new(address,d2x(oldValue,2),d2x(newValue,2)))
  return self

/* Keep bulk transfers as one delta.  This matters for MVC clear loops and
 * channel reads: journal cost follows changed ranges, not byte count. */
::method storeHex
  expose recording operations replaying
  use strict arg address,hexData
  if \recording | replaying then return self~storeHex:super(address,hexData)
  h=hexData~string~space(0)~translate
  if h~length//2 \=0 | verify(h,"0123456789ABCDEF") \=0 then raise syntax 93.900 array("storeHex requires even hexadecimal text",hexData)
  count=h~length%2
  if count=0 then return self
  oldHex=self~fetchHex(address,count)
  if verify(h,"0")=0 then self~zeroRange:super(address,count)
  else do i=1 to h~length by 2
    self~storeByte:super(address+((i-1)%2),x2d(h~substr(i,2)))
  end
  newHex=self~fetchHex(address,count)
  if oldHex \= newHex then operations~append(.IBM370StorageRangeDelta~new(address,oldHex,newHex))
  return self

::method zeroRange
  expose recording operations replaying
  use strict arg address,count
  if \recording | replaying then return self~zeroRange:super(address,count)
  if count=0 then return self
  oldHex=self~fetchHex(address,count)
  self~zeroRange:super(address,count)
  newHex=self~fetchHex(address,count)
  if oldHex \= newHex then operations~append(.IBM370StorageRangeDelta~new(address,oldHex,newHex))
  return self

::method setStorageKeyRaw
  expose recording operations replaying
  use strict arg blockNumber,value
  if \recording | replaying then return self~setStorageKeyRaw:super(blockNumber,value)
  oldValue=self~storageKeyRaw(blockNumber)
  self~setStorageKeyRaw:super(blockNumber,value)
  newValue=self~storageKeyRaw(blockNumber)
  if oldValue \= newValue then operations~append(.IBM370StorageKeyDelta~new(blockNumber,oldValue,newValue))
  return self

::method journalPoint
  expose journal
  return journal~journalPoint
::method journalCanMoveTo
  expose journal
  use strict arg point
  return journal~journalCanMoveTo(point)
::method journalAttachController
  expose journal
  use strict arg controller,componentId
  journal~journalAttachController(controller,componentId)
  return self
::method journalDetachController
  expose journal
  journal~journalDetachController
  return self
::method retainedJournalNodeCount
  expose journal
  return journal~retainedNodeCount

::method journalMoveTo
  expose journal recording replaying
  use strict arg point,notify=.true
  if recording then raise syntax 88.900 array("cannot move IBM370 RAM journal during active event")
  d=journal~diff(journal~journalPoint,point)
  replaying=.true
  undo=d["undo"]
  do node over undo
    self~eventFromNode(node)~applyReverse(self)
  end
  redo=d["redo"]
  do node over redo
    self~eventFromNode(node)~applyForward(self)
  end
  replaying=.false
  journal~journalMoveTo(point,notify)
  return journal~journalPoint

::method eventFromNode private
  use strict arg node
  ds=node~deltas
  do delta over ds
    if delta~key="EVENT" & delta~newExists then return delta~newValue
  end
  raise syntax 88.900 array("IBM370 RAM journal node lacks EVENT delta",node~nodeId)

/* Generic small-state participant.  Subclasses snapshot only compact machine
 * control structures; RAM uses IBM370JournaledStorage above. */
::class IBMJournalSnapshotParticipant public
::method init
  expose target journal signature
  use strict arg targetObject,requestedJournalId
  target=targetObject
  snap=self~snapshotTarget
  initial=.directory~new
  initial["STATE"]=snap
  journal=.JournalPointedState~new(initial,requestedJournalId)
  signature=.IBMJournalCanonical~encode(snap)

::method targetObject
  expose target
  return target

::method capture
  expose journal signature
  use strict arg tag="EVENT",metadata=.nil
  snap=self~snapshotTarget
  sig=.IBMJournalCanonical~encode(snap)
  if sig=signature then return journal~journalPoint
  signature=sig
  return journal~put("STATE",snap,tag,metadata)

::method journalPoint; expose journal; return journal~journalPoint
::method journalCanMoveTo
  expose journal
  use strict arg point
  return journal~journalCanMoveTo(point)
::method journalAttachController
  expose journal
  use strict arg controller,componentId
  journal~journalAttachController(controller,componentId)
  return self
::method journalDetachController
  expose journal
  journal~journalDetachController
  return self
::method journalMoveTo
  expose journal signature
  use strict arg point,notify=.true
  journal~journalMoveTo(point,notify)
  snap=journal~at("STATE")
  self~restoreTarget(snap)
  signature=.IBMJournalCanonical~encode(snap)
  return journal~journalPoint

::method snapshotTarget
  raise syntax 88.900 array("IBMJournalSnapshotParticipant subclass must implement snapshotTarget")
::method restoreTarget
  use strict arg snapshot
  raise syntax 88.900 array("IBMJournalSnapshotParticipant subclass must implement restoreTarget")

::class IBM4361MachineJournalParticipant subclass IBMJournalSnapshotParticipant public
::method init
  use strict arg machine
  self~init:super(machine,"IBM4361-MACHINE")
::method snapshotTarget
  target=self~targetObject
  return target~state
::method restoreTarget
  use strict arg snapshot
  target=self~targetObject
  target~restoreMachineState(snapshot)
  return target

::class IBM370CPUJournalParticipant subclass IBMJournalSnapshotParticipant public
::method init
  use strict arg cpu
  self~init:super(cpu,"IBM370-CPU")
::method snapshotTarget
  target=self~targetObject
  return target~state
::method restoreTarget
  use strict arg snapshot
  target=self~targetObject
  target~restoreState(snapshot)
  return target

::class IBM370ClockJournalParticipant subclass IBMJournalSnapshotParticipant public
::method init
  use strict arg clock
  self~init:super(clock,"IBM370-CLOCK")
::method snapshotTarget
  target=self~targetObject
  return target~state
::method restoreTarget
  use strict arg snapshot
  target=self~targetObject
  target~restoreState(snapshot)
  return target

::class IBM370ChannelJournalParticipant subclass IBMJournalSnapshotParticipant public
::method init
  use strict arg channels
  self~init:super(channels,"IBM370-CHANNELS")

::method snapshotTarget
  target=self~targetObject
  d=.directory~new
  d["subsystem"]=target~state
  ps=.directory~new
  do n over target~activeProgramNumbers
    ps[d2x(n,4)]=target~activeProgram(n)~state
  end
  d["programs"]=ps
  ds=.directory~new
  do n over target~deviceNumbers
    ds[d2x(n,4)]=target~device(n)~state
  end
  d["devices"]=ds
  return d

::method restoreTarget
  use strict arg snapshot
  target=self~targetObject
  ss=snapshot["subsystem"]
  if ss["pendingInterruptCount"] \=0 then raise syntax 40.900 array("current IBM channel journal adapter has no pending-interrupt reconstruction codec")
  target~restoreState(ss)
  ds=snapshot["devices"]
  do key over ds~allIndexes
    target~device(x2d(key))~restoreState(ds[key])
  end
  ps=snapshot["programs"]
  do key over ps~allIndexes
    pstate=ps[key]
    p=.IBM370ChannelProgram~new(x2d(key),pstate["currentCCWAddress"],pstate["kind"])
    p~restoreState(pstate)
    target~restoreActiveProgram(p)
  end
  return target

::class IBMJournalCanonical public
::method encode class
  use strict arg value
  if value==.nil then return "N"
  if value~isA(.Directory) then do
    keys=value~allIndexes
    if keys~items>1 then keys~sort
    out="D" || keys~items || "{"
    do key over keys
      ks=key~string
      ev=self~encode(value[key])
      out=out || ks~length || ":" || ks || ev~length || ":" || ev
    end
    return out || "}"
  end
  if value~isA(.Array) then do
    out="A" || value~items || "["
    do i=1 to value~items
      ev=self~encode(value[i])
      out=out || ev~length || ":" || ev
    end
    return out || "]"
  end
  s=value~string
  return "S" || s~length || ":" || s

/* Instruction/event transaction coordinator.  It owns journal points only.
 * It intentionally has no freeze/save method: durable freezes remain a
 * separate IBM4361State operation performed by the emulator/caller. */
::class IBM4361JournalSession public
::method init
  expose machine controller storage machineP cpuP clockP channelP recovery active preCheckpoint
  use strict arg machineObject,frontEnd=.nil
  if \machineObject~isA(.IBM4361Machine) then raise syntax 88.900 array("IBM4361JournalSession requires IBM4361Machine")
  if \machineObject~storage~isA(.IBM370JournaledStorage) then raise syntax 88.900 array("IBM4361JournalSession requires IBM370JournaledStorage")
  machine=machineObject
  storage=machine~storage
  controller=.StateOfNationController~new
  machineP=.IBM4361MachineJournalParticipant~new(machine)
  cpuP=.IBM370CPUJournalParticipant~new(machine~cpu)
  clockP=.IBM370ClockJournalParticipant~new(machine~clock)
  channelP=.IBM370ChannelJournalParticipant~new(machine~channels)
  controller~register("machine",machineP)
  controller~register("cpu",cpuP)
  controller~register("clock",clockP)
  controller~register("channels",channelP)
  controller~register("storage",storage)
  if frontEnd==.nil then recovery=.nil
  else recovery=.LiveStateRecoveryCoordinator~new(controller,frontEnd)
  active=.false
  preCheckpoint=.nil

::method controller; expose controller; return controller
::method machine; expose machine; return machine
::method active; expose active; return active
::method preInstructionCheckpoint; expose preCheckpoint; return preCheckpoint

::method beginInstruction
  expose machine storage recovery controller active preCheckpoint
  use strict arg context=.nil
  if active then raise syntax 88.900 array("IBM4361 journal instruction already active")
  if recovery==.nil then preCheckpoint=controller~checkpoint("before-instruction","INSTRUCTION",context)
  else preCheckpoint=recovery~arm("before-instruction",context)
  storage~beginJournalEvent("INSTRUCTION",context)
  active=.true
  return preCheckpoint

::method commitInstruction
  expose machine controller storage machineP cpuP clockP channelP active
  use strict arg context=.nil
  if \active then raise syntax 88.900 array("IBM4361 journal instruction is not active")
  storage~commitJournalEvent
  machineP~capture("INSTRUCTION",context)
  cpuP~capture("INSTRUCTION",context)
  clockP~capture("INSTRUCTION",context)
  channelP~capture("INSTRUCTION",context)
  controller~noteProgress("IBM4361",machine~cpu~instructionCount,context)
  active=.false
  return controller~latestCheckpoint

::method abortInstruction
  expose controller storage active preCheckpoint
  if \active then return .nil
  storage~abortJournalEvent
  controller~restore(preCheckpoint)
  active=.false
  return preCheckpoint

::method recoverInstruction
  expose recovery storage active
  use strict arg reason,target,methodName,context=.nil
  if recovery==.nil then raise syntax 88.900 array("IBM4361 journal session has no recovery front end")
  if \active then raise syntax 88.900 array("IBM4361 recovery requires an active instruction")
  storage~abortJournalEvent
  result=recovery~recover(reason,target,methodName,context)
  active=.false
  return result

::method restore
  expose controller active
  use strict arg checkpoint
  if active then raise syntax 88.900 array("cannot restore IBM4361 journal during active instruction")
  return controller~restore(checkpoint)

::requires "IBM4361.cls"
::requires "JournalPointedState.cls"
