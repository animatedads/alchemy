/* KL10Journal.cls
 *
 * Hot reversible state for long-lived KL10 development runs.  Durable
 * KL10_STATE/1 freeze/load remains a separate cold checkpoint path.
 */
::options digits 30

::class KL10CPUJournalParticipant public
::method init
  expose cpu state controller componentId
  use strict arg cpuObject,journalId="KL10-CPU"
  cpu=cpuObject
  initial=self~captureDirectory
  state=.JournalPointedState~new(initial,journalId)
  controller=.nil
  componentId=""

::method journalPoint
  expose state
  return state~journalPoint
::method journalCanMoveTo
  expose state
  use strict arg point
  return state~journalCanMoveTo(point)
::method journalAttachController
  expose controller componentId
  use strict arg c,id
  controller=c; componentId=id
  return self
::method journalDetachController
  expose controller componentId
  controller=.nil; componentId=""
  return self
::method journalMoveTo
  expose state controller componentId
  use strict arg point,notify=.true
  p=state~journalMoveTo(point,.false)
  self~applyDirectory(state~snapshot)
  if notify & controller \== .nil then controller~participantChanged(componentId,p,"MOVE","MOVE",.nil)
  return p
::method capture
  expose state controller componentId
  use strict arg tag="CPU",metadata=.nil
  before=state~journalPoint~nodeId
  current=self~captureDirectory
  edit=state~beginEdit(tag,metadata)
  old=state~snapshot
  do key over current~allIndexes; edit~put(key,current[key]); end
  do key over old~allIndexes
    if \current~hasIndex(key) then edit~remove(key)
  end
  p=edit~commit
  if p~nodeId \= before & controller \== .nil then controller~participantChanged(componentId,p,"CHANGE",tag,metadata)
  return p
::method stateAt
  expose state
  use strict arg point
  return state~reconstruct(point)
::method retainedNodeCount
  expose state
  return state~retainedNodeCount
::method captureDirectory private
  expose cpu
  d=.directory~new
  d["pc"]=cpu~pc
  d["flags"]=cpu~flags
  d["halted"]=cpu~halted
  d["instructionCount"]=cpu~instructionCount
  d["processorMode"]=cpu~processorMode
  do block=0 to 7
    do ac=0 to 15
      d["AC:"||block||":"||ac]=cpu~accumulatorInBlock(block,ac)
    end
  end
  return d
::method applyDirectory private
  expose cpu
  use strict arg d
  cpu~restoreCoreState(d["pc"],d["flags"],d["halted"],d["instructionCount"],d["processorMode"])
  do block=0 to 7
    do ac=0 to 15
      cpu~setAccumulatorInBlock(block,ac,d["AC:"||block||":"||ac])
    end
  end
  cpu~clearPendingPageFault
  return self


::class KL10DeviceJournalParticipant public
::method init
  expose target state controller componentId
  use strict arg targetObject,journalId
  target=targetObject
  if \target~hasMethod("STATE") | \target~hasMethod("RESTORESTATE") then
    raise syntax 88.900 array("KL10 journal target lacks state/restoreState",journalId)
  initial=self~copyDirectory(target~state)
  state=.JournalPointedState~new(initial,journalId)
  controller=.nil
  componentId=""
::method journalPoint
  expose state
  return state~journalPoint
::method journalCanMoveTo
  expose state
  use strict arg point
  return state~journalCanMoveTo(point)
::method journalAttachController
  expose controller componentId
  use strict arg c,id
  controller=c; componentId=id
  return self
::method journalDetachController
  expose controller componentId
  controller=.nil; componentId=""
  return self
::method journalMoveTo
  expose target state controller componentId
  use strict arg point,notify=.true
  p=state~journalMoveTo(point,.false)
  target~restoreState(state~snapshot)
  if notify & controller \== .nil then controller~participantChanged(componentId,p,"MOVE","MOVE",.nil)
  return p
::method capture
  expose target state controller componentId
  use strict arg tag="DEVICE",metadata=.nil
  before=state~journalPoint~nodeId
  current=self~copyDirectory(target~state)
  old=state~snapshot
  edit=state~beginEdit(tag,metadata)
  do key over current~allIndexes; edit~put(key,current[key]); end
  do key over old~allIndexes
    if \current~hasIndex(key) then edit~remove(key)
  end
  p=edit~commit
  if p~nodeId \= before & controller \== .nil then controller~participantChanged(componentId,p,"CHANGE",tag,metadata)
  return p
::method stateAt
  expose state
  use strict arg point
  return state~reconstruct(point)
::method retainedNodeCount
  expose state
  return state~retainedNodeCount
::method copyDirectory private
  use strict arg source
  d=.directory~new
  do key over source~allIndexes; d[key]=source[key]; end
  return d


::class KL10JournalSession public
::method init
  expose cpu controller memory participants armed lastRecovery progress
  use strict arg cpuObject,controllerObject=.nil
  cpu=cpuObject
  if cpu~memory=.nil then raise syntax 88.900 array("KL10 journal session requires loaded CPU memory")
  if controllerObject=.nil then controller=.StateOfNationController~new
  else controller=controllerObject
  participants=.directory~new
  backing=cpu~memory~backingMemory
  if \backing~hasMethod("ENABLEJOURNAL") then raise syntax 88.900 array("KL10 backing memory lacks hot journal support")
  memory=backing
  memState=memory~enableJournal("KL10-MEMORY")
  controller~register("memory",memState)
  cpuPart=.KL10CPUJournalParticipant~new(cpu,"KL10-CPU")
  participants["cpu"]=cpuPart
  controller~register("cpu",cpuPart)
  self~registerDevice("apr",cpu~apr)
  self~registerDevice("pi",cpu~pi)
  self~registerDevice("pag",cpu~pag)
  dteCode=self~oct("0200")
  if cpu~ioBus~hasDevice(dteCode) then self~registerDevice("dte",cpu~ioBus~device(dteCode))
  do rhCode=352 to 380 by 4
    if cpu~ioBus~hasDevice(rhCode) then do
      rh=cpu~ioBus~device(rhCode)
      self~registerDevice("rh20:"||rhCode,rh)
      do unitNumber over rh~unitNumbers
        unit=rh~unit(unitNumber)
        if unit~hasMethod("STATE") & unit~hasMethod("RESTORESTATE") then
          self~registerDevice("rh20:"||rhCode||":unit:"||unitNumber,unit)
      end
    end
  end
  armed=.nil
  lastRecovery=.nil
  progress=0

::method controller
  expose controller
  return controller
::method cpuParticipant
  expose participants
  return participants["cpu"]
::method participant
  expose participants
  use strict arg id
  return participants[id]
::method participantIds
  expose participants
  return participants~allIndexes
::method beginInstruction
  expose controller memory armed cpu
  use strict arg context=.nil
  if armed \= .nil then raise syntax 88.900 array("KL10 journal instruction already armed")
  meta=.directory~new
  meta["pc"]=cpu~pc
  meta["instructionCount"]=cpu~instructionCount
  if context \== .nil then meta["context"]=context
  memory~beginJournalEvent("INSTRUCTION",meta)
  armed=controller~checkpoint("before-instruction","INSTRUCTION",meta)
  return armed
::method commitInstruction
  expose controller memory participants armed progress cpu
  use strict arg context=.nil
  if armed=.nil then raise syntax 88.900 array("KL10 journal instruction is not armed")
  memory~commitJournalEvent
  do id over participants~allIndexes
    participants[id]~capture("INSTRUCTION",context)
  end
  meta=.directory~new
  meta["pc"]=cpu~pc
  meta["instructionCount"]=cpu~instructionCount
  after=controller~checkpoint("after-instruction","INSTRUCTION",meta)
  progress=progress+1
  controller~noteProgress("kl10",progress,meta)
  armed=.nil
  return after
::method abortInstruction
  expose controller memory armed lastRecovery
  use strict arg reason="ABORT"
  if armed=.nil then return .nil
  memory~abortJournalEvent
  cp=armed
  controller~restore(cp)
  lastRecovery=cp
  armed=.nil
  return cp
::method step
  expose cpu lastRecovery
  signal on syntax name StepFailed
  before=self~beginInstruction
  trace=cpu~step
  after=self~commitInstruction(trace)
  trace["journalBefore"]=before~checkpointId
  trace["journalAfter"]=after~checkpointId
  return trace
StepFailed:
  cp=self~abortInstruction("SYNTAX")
  lastRecovery=cp
  raise propagate
::method restore
  expose controller
  use strict arg checkpoint
  return controller~restore(checkpoint)
::method checkpoint
  expose controller
  use strict arg label="manual",eventName="MANUAL",metadata=.nil
  return controller~checkpoint(label,eventName,metadata)
::method lastRecoveryPoint
  expose lastRecovery
  return lastRecovery
::method registerDevice private
  expose controller participants
  use strict arg id,target
  p=.KL10DeviceJournalParticipant~new(target,"KL10-"||id)
  participants[id]=p
  controller~register(id,p)
  return p
::method oct private
  use strict arg text
  n=0
  do i=1 to text~length; n=n*8+text~substr(i,1); end
  return n

::requires "lib/JournalPointedState.cls"
::requires "KL10IPL.cls"
