/* JournalPointedState.cls
 *
 * Compact branching journal state and State-of-the-Nation checkpoint control.
 *
 * Checkpoints contain journal pointers, not full state images.  Each journal
 * node carries only the values changed by that edit.  Moving between two
 * retained points walks back to the common ancestor and then rolls forward,
 * so failed speculative execution may remain inspectable while a repaired run
 * forks from the same pre-fault point.
 */

::class JournalPoint public

::method init
  expose journalId nodeId
  use strict arg journalId,nodeId

::method journalId
  expose journalId
  return journalId

::method nodeId
  expose nodeId
  return nodeId

::method string
  expose journalId nodeId
  return journalId || "@" || nodeId

::method asDirectory
  expose journalId nodeId
  d=.directory~new
  d["journalId"]=journalId
  d["nodeId"]=nodeId
  return d


::class JournalDelta public

::method init
  expose key oldExists oldValue newExists newValue
  use strict arg key,oldExists,oldValue,newExists,newValue

::method key
  expose key
  return key

::method oldExists
  expose oldExists
  return oldExists

::method oldValue
  expose oldValue
  return oldValue

::method newExists
  expose newExists
  return newExists

::method newValue
  expose newValue
  return newValue

::method reverseDirectory
  expose key oldExists oldValue
  d=.directory~new
  d["key"]=key
  d["exists"]=oldExists
  d["value"]=oldValue
  return d

::method forwardDirectory
  expose key newExists newValue
  d=.directory~new
  d["key"]=key
  d["exists"]=newExists
  d["value"]=newValue
  return d


::class JournalChangeNode public

::method init
  expose journalId nodeId parentId deltas tag metadata timestamp
  use strict arg journalId,nodeId,parentId,deltas,tag="",metadata=.nil
  timestamp=date("S") || "T" || time("L")

::method journalId
  expose journalId
  return journalId

::method nodeId
  expose nodeId
  return nodeId

::method parentId
  expose parentId
  return parentId

::method deltas
  expose deltas
  return deltas

::method tag
  expose tag
  return tag

::method metadata
  expose metadata
  return metadata

::method timestamp
  expose timestamp
  return timestamp

::method point
  expose journalId nodeId
  return .JournalPoint~new(journalId,nodeId)

::method asDirectory
  expose journalId nodeId parentId deltas tag metadata timestamp
  d=.directory~new
  d["journalId"]=journalId
  d["nodeId"]=nodeId
  d["parentId"]=parentId
  d["deltas"]=deltas
  d["tag"]=tag
  d["metadata"]=metadata
  d["timestamp"]=timestamp
  return d


::class JournalEditOperation private

::method init
  expose kind value
  use strict arg kind,value=.nil

::method kind
  expose kind
  return kind

::method value
  expose value
  return value


::class JournalEdit public

::method init
  expose owner operations tag metadata committed
  use strict arg owner,tag="",metadata=.nil
  operations=.directory~new
  committed=.false

::method put
  expose operations committed
  use strict arg key,value
  if committed then raise syntax 88.900 array("journal edit already committed")
  operations[key]=.JournalEditOperation~new("PUT",value)
  return self

::method remove
  expose operations committed
  use strict arg key
  if committed then raise syntax 88.900 array("journal edit already committed")
  operations[key]=.JournalEditOperation~new("REMOVE")
  return self

::method operationKeys
  expose operations
  return operations~allIndexes

::method operation
  expose operations
  use strict arg key
  return operations[key]

::method tag
  expose tag
  return tag

::method metadata
  expose metadata
  return metadata

::method owner
  expose owner
  return owner

::method committed
  expose committed
  return committed

::method markCommitted private
  expose committed
  committed=.true
  return self

::method commit
  expose owner committed
  if committed then raise syntax 88.900 array("journal edit already committed")
  p=owner~commitJournalEdit(self)
  self~markCommitted
  return p


::class JournalPointedState public

::method init
  expose journalId data nodes currentHead nextNodeId controller componentId
  use strict arg initial=.nil,requestedId=""
  if requestedId="" then requestedId="JPS-" || date("S") || "-" || time("L")~translate("",":.") || "-" || random(100000,999999)
  journalId=requestedId
  data=.directory~new
  if initial \== .nil then do
    if \initial~isA(.Directory) then raise syntax 88.900 array("JournalPointedState initial value must be a Directory")
    do k over initial~allIndexes
      data[k]=initial[k]
    end
  end
  nodes=.directory~new
  currentHead="ROOT"
  nextNodeId=1
  controller=.nil
  componentId=""

::method journalId
  expose journalId
  return journalId

::method rootPoint
  expose journalId
  return .JournalPoint~new(journalId,"ROOT")

::method journalPoint
  expose journalId currentHead
  return .JournalPoint~new(journalId,currentHead)

::method currentPoint
  forward message("JOURNALPOINT")

::method headNodeId
  expose currentHead
  return currentHead

::method at
  expose data
  use strict arg key
  return data[key]

::method hasIndex
  expose data
  use strict arg key
  return data~hasIndex(key)

::method items
  expose data
  return data~items

::method allIndexes
  expose data
  return data~allIndexes

::method snapshot
  expose data
  return self~copyDirectory(data)

::method beginEdit
  use strict arg tag="",metadata=.nil
  return .JournalEdit~new(self,tag,metadata)

::method put
  use strict arg key,value,tag="",metadata=.nil
  edit=self~beginEdit(tag,metadata)
  edit~put(key,value)
  return edit~commit

::method remove
  use strict arg key,tag="",metadata=.nil
  edit=self~beginEdit(tag,metadata)
  edit~remove(key)
  return edit~commit

::method clear
  expose data
  use strict arg tag="CLEAR",metadata=.nil
  edit=self~beginEdit(tag,metadata)
  do k over data~allIndexes
    edit~remove(k)
  end
  return edit~commit

::method commitJournalEdit
  expose journalId data nodes currentHead nextNodeId
  use strict arg edit
  if \edit~isA(.JournalEdit) | edit~owner \== self then raise syntax 88.900 array("journal edit belongs to another state object")
  if edit~committed then raise syntax 88.900 array("journal edit already committed")

  deltas=.array~new
  keys=edit~operationKeys
  do key over keys
    op=edit~operation(key)
    oldExists=data~hasIndex(key)
    if oldExists then oldValue=data[key]
    else oldValue=.nil

    if op~kind="PUT" then do
      newExists=.true
      newValue=op~value
    end
    else do
      newExists=.false
      newValue=.nil
    end

    changed=.true
    if oldExists=newExists then do
      if \oldExists then changed=.false
      else if oldValue == newValue then changed=.false
    end
    if changed then deltas~append(.JournalDelta~new(key,oldExists,oldValue,newExists,newValue))
  end

  if deltas~items=0 then return self~journalPoint

  nodeId="N" || nextNodeId
  nextNodeId=nextNodeId+1
  node=.JournalChangeNode~new(journalId,nodeId,currentHead,deltas,edit~tag,edit~metadata)
  nodes[nodeId]=node
  self~applyForward(node,data)
  currentHead=nodeId
  point=node~point
  self~notifyController("CHANGE",point,edit~tag,edit~metadata)
  return point

::method journalCanMoveTo
  expose journalId nodes
  use strict arg point
  target=self~normalisePoint(point)
  if target="ROOT" then return .true
  return nodes~hasIndex(target)

::method canMoveTo
  forward message("JOURNALCANMOVETO")

::method journalMoveTo
  expose currentHead data
  use strict arg point,notify=.true
  target=self~normalisePoint(point)
  if target=currentHead then return self~journalPoint
  plan=self~pathPlan(currentHead,target)
  undo=plan["undo"]
  redo=plan["redo"]
  do i=1 to undo~items
    self~applyReverse(undo[i],data)
  end
  do i=redo~items to 1 by -1
    self~applyForward(redo[i],data)
  end
  currentHead=target
  p=self~journalPoint
  if notify then self~notifyController("MOVE",p,"MOVE",.nil)
  return p

::method moveTo
  forward message("JOURNALMOVETO")

::method reconstruct
  expose currentHead data
  use strict arg point
  target=self~normalisePoint(point)
  scratch=self~copyDirectory(data)
  if target=currentHead then return scratch
  plan=self~pathPlan(currentHead,target)
  undo=plan["undo"]
  redo=plan["redo"]
  do i=1 to undo~items
    self~applyReverse(undo[i],scratch)
  end
  do i=redo~items to 1 by -1
    self~applyForward(redo[i],scratch)
  end
  return scratch

::method stateAt
  forward message("RECONSTRUCT")

::method diff
  expose currentHead
  use strict arg fromPoint,toPoint
  fromId=self~normalisePoint(fromPoint)
  toId=self~normalisePoint(toPoint)
  plan=self~pathPlan(fromId,toId)
  d=.directory~new
  d["from"]=.JournalPoint~new(self~journalId,fromId)
  d["to"]=.JournalPoint~new(self~journalId,toId)
  d["undo"]=plan["undo"]
  d["redo"]=self~reverseArray(plan["redo"])
  return d

::method node
  expose nodes
  use strict arg nodeId
  if nodeId="ROOT" then return .nil
  if \nodes~hasIndex(nodeId) then raise syntax 88.900 array("unknown journal node",nodeId)
  return nodes[nodeId]

::method retainedNodeCount
  expose nodes
  return nodes~items

::method journalAttachController
  expose controller componentId
  use strict arg newController,newComponentId
  controller=newController
  componentId=newComponentId
  return self

::method attachController
  forward message("JOURNALATTACHCONTROLLER")

::method journalDetachController
  expose controller componentId
  controller=.nil
  componentId=""
  return self

::method normalisePoint private
  expose journalId nodes
  use strict arg point
  if point~isA(.JournalPoint) then do
    if point~journalId \= journalId then raise syntax 88.900 array("journal point belongs to a different journal",point~journalId,journalId)
    nodeId=point~nodeId
  end
  else nodeId=point~string
  if nodeId="ROOT" then return nodeId
  if \nodes~hasIndex(nodeId) then raise syntax 88.900 array("unknown journal point",nodeId)
  return nodeId

::method pathPlan private
  expose nodes
  use strict arg fromId,toId
  ancestors=.directory~new
  cursor=fromId
  do forever
    ancestors[cursor]=1
    if cursor="ROOT" then leave
    cursor=nodes[cursor]~parentId
  end

  redo=.array~new
  cursor=toId
  do while \ancestors~hasIndex(cursor)
    redo~append(nodes[cursor])
    cursor=nodes[cursor]~parentId
  end
  common=cursor

  undo=.array~new
  cursor=fromId
  do while cursor \= common
    undo~append(nodes[cursor])
    cursor=nodes[cursor]~parentId
  end

  d=.directory~new
  d["common"]=common
  d["undo"]=undo
  d["redo"]=redo
  return d

::method applyForward private
  use strict arg node,target
  deltas=node~deltas
  do i=1 to deltas~items
    delta=deltas[i]
    if delta~newExists then target[delta~key]=delta~newValue
    else target~remove(delta~key)
  end
  return target

::method applyReverse private
  use strict arg node,target
  deltas=node~deltas
  do i=deltas~items to 1 by -1
    delta=deltas[i]
    if delta~oldExists then target[delta~key]=delta~oldValue
    else target~remove(delta~key)
  end
  return target

::method copyDirectory private
  use strict arg source
  copy=.directory~new
  do k over source~allIndexes
    copy[k]=source[k]
  end
  return copy

::method reverseArray private
  use strict arg source
  out=.array~new
  do i=source~items to 1 by -1
    out~append(source[i])
  end
  return out

::method notifyController private
  expose controller componentId
  use strict arg kind,point,tag,metadata
  if controller == .nil then return 0
  controller~participantChanged(componentId,point,kind,tag,metadata)
  return 1


::class StateOfNationCheckpoint public

::method init
  expose checkpointId label eventName positions metadata timestamp
  use strict arg checkpointId,label,eventName,positions,metadata=.nil
  timestamp=date("S") || "T" || time("L")

::method checkpointId
  expose checkpointId
  return checkpointId

::method label
  expose label
  return label

::method eventName
  expose eventName
  return eventName

::method positions
  expose positions
  return positions

::method pointFor
  expose positions
  use strict arg componentId
  return positions[componentId]

::method metadata
  expose metadata
  return metadata

::method timestamp
  expose timestamp
  return timestamp

::method asDirectory
  expose checkpointId label eventName positions metadata timestamp
  d=.directory~new
  d["checkpointId"]=checkpointId
  d["label"]=label
  d["eventName"]=eventName
  d["positions"]=positions
  d["metadata"]=metadata
  d["timestamp"]=timestamp
  return d


::class StateOfNationController public

::method init
  expose participants latestPositions checkpoints checkpointOrder nextCheckpointId policy policyEvent progressRecords
  participants=.directory~new
  latestPositions=.directory~new
  checkpoints=.directory~new
  checkpointOrder=.array~new
  nextCheckpointId=1
  policy="MANUAL"
  policyEvent=""
  progressRecords=.directory~new

::method register
  expose participants latestPositions
  use strict arg componentId,participant
  if componentId="" then raise syntax 88.900 array("State-of-the-Nation component id must not be empty")
  if participants~hasIndex(componentId) then raise syntax 88.900 array("State-of-the-Nation component already registered",componentId)
  do required over .array~of("JOURNALPOINT","JOURNALCANMOVETO","JOURNALMOVETO","JOURNALATTACHCONTROLLER")
    if \participant~hasMethod(required) then raise syntax 88.900 array("participant lacks journal contract method",componentId,required)
  end
  participants[componentId]=participant
  latestPositions[componentId]=participant~journalPoint
  participant~journalAttachController(self,componentId)
  return participant

::method unregister
  expose participants latestPositions
  use strict arg componentId
  if \participants~hasIndex(componentId) then return .false
  p=participants[componentId]
  if p~hasMethod("JOURNALDETACHCONTROLLER") then p~journalDetachController
  participants~remove(componentId)
  latestPositions~remove(componentId)
  return .true

::method participantIds
  expose participants
  return participants~allIndexes

::method currentPoint
  expose latestPositions
  use strict arg componentId
  if \latestPositions~hasIndex(componentId) then raise syntax 88.900 array("unknown State-of-the-Nation component",componentId)
  return latestPositions[componentId]

::method setCheckpointPolicy
  expose policy policyEvent
  use strict arg newPolicy,eventName=""
  p=newPolicy~string~translate
  if p="ANY" then p="ANY_CHANGE"
  if p="FIXED_EVENT" then p="EVENT"
  if p<>"MANUAL" & p<>"ANY_CHANGE" & p<>"EVENT" then raise syntax 88.900 array("unsupported checkpoint policy",newPolicy)
  if p="EVENT" & eventName="" then raise syntax 88.900 array("EVENT checkpoint policy requires an event name")
  policy=p
  policyEvent=eventName
  return self

::method checkpointPolicy
  expose policy
  return policy

::method checkpointPolicyEvent
  expose policyEvent
  return policyEvent

::method participantChanged
  expose latestPositions policy
  use strict arg componentId,point,kind="CHANGE",tag="",metadata=.nil
  if \latestPositions~hasIndex(componentId) then raise syntax 88.900 array("change from unregistered State-of-the-Nation component",componentId)
  latestPositions[componentId]=point
  if policy="ANY_CHANGE" & kind="CHANGE" then return self~checkpointFromLatest("change:" || componentId,tag,metadata)
  return .nil

::method checkpoint
  use strict arg label="",eventName="MANUAL",metadata=.nil
  return self~checkpointFromLatest(label,eventName,metadata)

::method noteEvent
  expose policy policyEvent
  use strict arg eventName,metadata=.nil
  if policy="EVENT" & (policyEvent="*" | eventName~caselessCompare(policyEvent)=0) then
    return self~checkpointFromLatest("event:" || eventName,eventName,metadata)
  return .nil

::method checkpointCount
  expose checkpointOrder
  return checkpointOrder~items

::method latestCheckpoint
  expose checkpointOrder checkpoints
  if checkpointOrder~items=0 then return .nil
  return checkpoints[checkpointOrder[checkpointOrder~items]]

::method checkpointById
  expose checkpoints
  use strict arg checkpointId
  if checkpointId~isA(.StateOfNationCheckpoint) then return checkpointId
  if \checkpoints~hasIndex(checkpointId) then raise syntax 88.900 array("unknown State-of-the-Nation checkpoint",checkpointId)
  return checkpoints[checkpointId]

::method restore
  expose participants latestPositions
  use strict arg checkpoint
  cp=self~checkpointById(checkpoint)
  positions=cp~positions

  -- Preflight every participant before changing any participant head.
  do componentId over participants~allIndexes
    if \positions~hasIndex(componentId) then raise syntax 88.900 array("checkpoint lacks registered component",componentId)
    participant=participants[componentId]
    if \participant~journalCanMoveTo(positions[componentId]) then raise syntax 88.900 array("participant cannot restore checkpoint",componentId,cp~checkpointId)
  end

  do componentId over participants~allIndexes
    participant=participants[componentId]
    p=participant~journalMoveTo(positions[componentId],.false)
    latestPositions[componentId]=p
  end
  return cp

::method noteProgress
  expose progressRecords
  use strict arg source,marker,context=.nil
  rec=.directory~new
  rec["source"]=source
  rec["marker"]=marker
  rec["context"]=context
  rec["timestamp"]=date("S") || "T" || time("L")
  if progressRecords~hasIndex(source) then rec["generation"]=progressRecords[source]["generation"]+1
  else rec["generation"]=1
  progressRecords[source]=rec
  return rec

::method progress
  expose progressRecords
  use strict arg source
  if \progressRecords~hasIndex(source) then return .nil
  return progressRecords[source]

::method checkpointFromLatest private
  expose latestPositions checkpoints checkpointOrder nextCheckpointId
  use strict arg label,eventName,metadata
  positions=.directory~new
  do componentId over latestPositions~allIndexes
    positions[componentId]=latestPositions[componentId]
  end
  checkpointId="SOTN-" || nextCheckpointId
  nextCheckpointId=nextCheckpointId+1
  cp=.StateOfNationCheckpoint~new(checkpointId,label,eventName,positions,metadata)
  checkpoints[checkpointId]=cp
  checkpointOrder~append(checkpointId)
  return cp


::class StateRecoveryRequest public

::method init
  expose checkpoint reason target methodName context timestamp
  use strict arg checkpoint,reason,target,methodName,context=.nil
  timestamp=date("S") || "T" || time("L")

::method checkpoint
  expose checkpoint
  return checkpoint

::method reason
  expose reason
  return reason

::method target
  expose target
  return target

::method methodName
  expose methodName
  return methodName

::method context
  expose context
  return context

::method timestamp
  expose timestamp
  return timestamp

::method asDirectory
  expose checkpoint reason target methodName context timestamp
  d=.directory~new
  d["checkpointId"]=checkpoint~checkpointId
  d["reason"]=reason
  d["target"]=target
  d["methodName"]=methodName
  d["context"]=context
  d["timestamp"]=timestamp
  return d


::class StateRecoveryResult public

::method init
  expose installed checkpoint request patchTarget methodName
  use strict arg installed,checkpoint,request,patchTarget=.nil,methodName=""

::method installed
  expose installed
  return installed

::method checkpoint
  expose checkpoint
  return checkpoint

::method request
  expose request
  return request

::method patchTarget
  expose patchTarget
  return patchTarget

::method methodName
  expose methodName
  return methodName


::class LiveMethodPatchable mixinclass Object public

::method installLiveMethod
  use strict arg methodName,source
  self~setMethod(methodName,source,"OBJECT")
  return .true


::class LiveStateRecoveryCoordinator public

::method init
  expose controller frontEnd armedCheckpoint
  use strict arg controller,frontEnd
  if \frontEnd~hasMethod("STATERECOVERYREQUEST") then raise syntax 88.900 array("front-end object must implement stateRecoveryRequest")
  armedCheckpoint=.nil

::method arm
  expose controller armedCheckpoint
  use strict arg label="instruction-boundary",context=.nil
  armedCheckpoint=controller~checkpoint(label,"RECOVERY_ARM",context)
  return armedCheckpoint

::method armedCheckpoint
  expose armedCheckpoint
  return armedCheckpoint

::method recover
  expose controller frontEnd armedCheckpoint
  use strict arg reason,target,methodName,context=.nil
  if armedCheckpoint == .nil then raise syntax 88.900 array("live recovery has no armed checkpoint")
  request=.StateRecoveryRequest~new(armedCheckpoint,reason,target,methodName,context)
  response=frontEnd~stateRecoveryRequest(request)
  if response == .nil then return .StateRecoveryResult~new(.false,armedCheckpoint,request)

  patchTarget=target
  patchName=methodName
  source=response
  scope="OBJECT"
  if response~isA(.Directory) then do
    if response~hasIndex("target") then patchTarget=response["target"]
    if response~hasIndex("methodName") then patchName=response["methodName"]
    if \response~hasIndex("source") then raise syntax 88.900 array("recovery response Directory lacks source")
    source=response["source"]
    if response~hasIndex("scope") then scope=response["scope"]~string~translate
  end

  if scope<>"OBJECT" then raise syntax 88.900 array("v0.1 live recovery only installs object-scope methods",scope)
  if \patchTarget~hasMethod("INSTALLLIVEMETHOD") then raise syntax 88.900 array("recovery target does not expose the LiveMethodPatchable contract",patchName)
  patchTarget~installLiveMethod(patchName,source)

  -- State rolls back; code deliberately does not.  Retrying the same message
  -- therefore sees the new method against the exact pre-fault machine state.
  controller~restore(armedCheckpoint)
  return .StateRecoveryResult~new(.true,armedCheckpoint,request,patchTarget,patchName)


::class StateProgressWatcher public

::method init
  expose controller source lastGeneration unchangedPolls threshold
  use strict arg controller,source,threshold=2
  if \datatype(threshold,"W") | threshold<1 then raise syntax 88.900 array("watcher threshold must be a positive integer")
  lastGeneration=0
  unchangedPolls=0

::method poll
  expose controller source lastGeneration unchangedPolls threshold
  rec=controller~progress(source)
  if rec == .nil then do
    unchangedPolls=unchangedPolls+1
    return unchangedPolls>=threshold
  end
  generation=rec["generation"]
  if generation=lastGeneration then unchangedPolls=unchangedPolls+1
  else do
    lastGeneration=generation
    unchangedPolls=0
  end
  return unchangedPolls>=threshold

::method unchangedPolls
  expose unchangedPolls
  return unchangedPolls
