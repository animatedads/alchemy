/* Semantic view state; exact definition keys; no browser/DOM concepts. */
::requires "WireUIProtocol.cls"
::requires "WireUIRevision.cls"

::class WireUIView subclass AlchemyObject public
::attribute viewRef get
::attribute rootInstance get

::method init
  expose viewRef rootInstance revisionCounter instances availableActions actionRevisionHistory
  use arg viewRef, rootInstance
  self~init:super(.WireUIAlchemy~metadata("Authoritative semantic Wire UI view state"))
  revisionCounter = .WireUIRevision~new(0)
  instances = .table~new
  availableActions = .table~new
  actionRevisionHistory = .table~new

::method revision
  expose revisionCounter
  return revisionCounter~value

::method parseDefinitionKey private
  use arg definitionKey
  at=definitionKey~lastPos("@")
  d=.table~new
  if at>1 & at<definitionKey~length then do
    d["id"]=definitionKey~substr(1,at-1)
    d["version"]=definitionKey~substr(at+1)
  end
  else do
    d["id"]=definitionKey
    d["version"]=""
  end
  return d

::method createInstance
  expose instances
  use arg instanceId, definitionKey, slots = .nil, parentId = ""
  if instances~hasIndex(instanceId) then return .WireUIResult~failure("INSTANCE_EXISTS", instanceId)
  parsed=self~parseDefinitionKey(definitionKey)
  i = .table~new
  i["instanceId"] = instanceId
  i["definitionKey"] = definitionKey
  i["definitionId"] = parsed["id"]
  if parsed["version"] \= "" then i["definitionVersion"] = parsed["version"]
  i["parentId"] = parentId
  i["slots"] = self~copyTable(slots)
  i["children"] = .array~new
  instances[instanceId] = i
  if parentId \= "" & instances~hasIndex(parentId) then instances[parentId]["children"]~append(instanceId)
  return .WireUIResult~success(i)


::method createInstancePatch
  expose revisionCounter viewRef
  use arg instanceId, definitionKey, slots=.nil, parentId=""
  r=self~createInstance(instanceId,definitionKey,slots,parentId)
  if \r~ok then return r
  pair=revisionCounter~next
  op=.table~new
  op["op"]="CREATE_INSTANCE"
  op["instance"]=self~copyInstance(r~value)
  fields=.table~new
  fields["viewRef"]=viewRef
  fields["previousRevision"]=pair[1]
  fields["newRevision"]=pair[2]
  fields["operations"]=.array~of(op)
  return .WireUIResult~success(.WireUIProtocol~message(.WireUIProtocol~UI_VIEW_PATCH,fields),"INSTANCE_CREATED")

::method instance
  expose instances
  use arg instanceId
  if instances~hasIndex(instanceId) then return instances[instanceId]
  return .nil

::method setActionAvailable
  expose availableActions actionRevisionHistory revisionCounter
  use arg instanceId, action, available = .true
  key = instanceId"|"action
  availableActions[key] = available
  hist = actionRevisionHistory[key]
  if hist == .nil then do
    hist = .table~new
    actionRevisionHistory[key] = hist
  end
  hist[revisionCounter~value] = available
  return available

::method actionWasAvailableAt
  expose actionRevisionHistory
  use arg instanceId, action, revision
  key = instanceId"|"action
  hist = actionRevisionHistory[key]
  if hist == .nil then return .false
  if hist~hasIndex(revision) then return hist[revision]
  best = -1
  value = .false
  do r over hist
    if datatype(r, "W") & r <= revision & r > best then do
      best = r
      value = hist[r]
    end
  end
  return value

::method setSlot
  expose instances revisionCounter viewRef
  use arg instanceId, slotName, newValue
  if \instances~hasIndex(instanceId) then return .WireUIResult~failure("INSTANCE_NOT_FOUND", instanceId)
  i = instances[instanceId]
  slots = i["slots"]
  oldValue = .nil
  if slots~hasIndex(slotName) then oldValue = slots[slotName]
  if oldValue == newValue then return .WireUIResult~success(.nil, "NO_CHANGE")
  slots[slotName] = newValue
  pair = revisionCounter~next
  op = .table~new
  op["op"] = "SET_SLOT"
  op["instanceId"] = instanceId
  op["slot"] = slotName
  op["value"] = newValue
  fields = .table~new
  fields["viewRef"] = viewRef
  fields["previousRevision"] = pair[1]
  fields["newRevision"] = pair[2]
  fields["operations"] = .array~of(op)
  return .WireUIResult~success(.WireUIProtocol~message(.WireUIProtocol~UI_VIEW_PATCH, fields))

::method setSlots
  expose instances revisionCounter viewRef
  use arg instanceId, updates
  if \instances~hasIndex(instanceId) then return .WireUIResult~failure("INSTANCE_NOT_FOUND", instanceId)
  if updates==.nil | \updates~hasMethod("HASINDEX") then return .WireUIResult~failure("SLOT_GROUP_INVALID", instanceId)
  i=instances[instanceId]
  slots=i["slots"]
  names=updates~allIndexes
  names~sort
  operations=.array~new
  do slotName over names
    newValue=updates[slotName]
    oldValue=.nil
    if slots~hasIndex(slotName) then oldValue=slots[slotName]
    if oldValue==newValue then iterate
    slots[slotName]=newValue
    op=.table~new
    op["op"]="SET_SLOT"
    op["instanceId"]=instanceId
    op["slot"]=slotName
    op["value"]=newValue
    operations~append(op)
  end
  if operations~items=0 then return .WireUIResult~success(.nil,"NO_CHANGE")
  pair=revisionCounter~next
  fields=.table~new
  fields["viewRef"]=viewRef
  fields["previousRevision"]=pair[1]
  fields["newRevision"]=pair[2]
  fields["operations"]=operations
  return .WireUIResult~success(.WireUIProtocol~message(.WireUIProtocol~UI_VIEW_PATCH,fields),"SLOT_GROUP_UPDATED")



/* Apply slot updates to several existing semantic instances under one view
   revision.  This is the workspace coherence primitive: related projections
   (position state, risk banner, margin summary, intent consequence) become
   visible atomically rather than as a sequence of transient revisions. */
::method setSlotsAcross
  expose instances revisionCounter viewRef
  use arg updatesByInstance
  if updatesByInstance==.nil | \updatesByInstance~hasMethod("HASINDEX") then return .WireUIResult~failure("SLOT_GROUP_SET_INVALID",viewRef)
  instanceIds=updatesByInstance~allIndexes
  instanceIds~sort
  operations=.array~new
  do instanceId over instanceIds
    if \instances~hasIndex(instanceId) then return .WireUIResult~failure("INSTANCE_NOT_FOUND",instanceId)
    updates=updatesByInstance[instanceId]
    if updates==.nil | \updates~hasMethod("HASINDEX") then return .WireUIResult~failure("SLOT_GROUP_INVALID",instanceId)
    slots=instances[instanceId]["slots"]
    slotNames=updates~allIndexes
    slotNames~sort
    do slotName over slotNames
      newValue=updates[slotName]
      oldValue=.nil
      if slots~hasIndex(slotName) then oldValue=slots[slotName]
      if oldValue==newValue then iterate
      slots[slotName]=newValue
      op=.table~new
      op["op"]="SET_SLOT"
      op["instanceId"]=instanceId
      op["slot"]=slotName
      op["value"]=newValue
      operations~append(op)
    end
  end
  if operations~items=0 then return .WireUIResult~success(.nil,"NO_CHANGE")
  pair=revisionCounter~next
  fields=.table~new
  fields["viewRef"]=viewRef
  fields["previousRevision"]=pair[1]
  fields["newRevision"]=pair[2]
  fields["operations"]=operations
  return .WireUIResult~success(.WireUIProtocol~message(.WireUIProtocol~UI_VIEW_PATCH,fields),"MULTI_INSTANCE_SLOT_GROUP_UPDATED")

/* Add one stable semantic child to an ordered collection. The renderer already
   understands LIST_APPEND; this method makes the ooRexx view authoritative for
   membership, identity and ordering. index is zero-based on the wire. */
::method listAppend
  expose instances revisionCounter viewRef
  use arg parentId, instanceId, definitionKey, slots=.nil, index=.nil
  if \instances~hasIndex(parentId) then return .WireUIResult~failure("PARENT_INSTANCE_NOT_FOUND",parentId)
  if instances~hasIndex(instanceId) then return .WireUIResult~failure("INSTANCE_EXISTS",instanceId)
  r=self~createInstance(instanceId,definitionKey,slots,"")
  if \r~ok then return r
  child=instances[instanceId]
  child["parentId"]=parentId
  parent=instances[parentId]
  children=parent["children"]
  count=children~items
  if index==.nil then index=count
  if \datatype(index,"W") | index<0 | index>count then do
    ignore=self~removeInstanceState(instanceId)
    return .WireUIResult~failure("LIST_INDEX_INVALID",index)
  end
  parent["children"]=self~arrayInsert(children,instanceId,index)
  pair=revisionCounter~next
  op=.table~new
  op["op"]="LIST_APPEND"
  op["parentInstanceId"]=parentId
  op["index"]=index
  op["instance"]=self~copyInstance(child)
  fields=.table~new
  fields["viewRef"]=viewRef
  fields["previousRevision"]=pair[1]
  fields["newRevision"]=pair[2]
  fields["operations"]=.array~of(op)
  return .WireUIResult~success(.WireUIProtocol~message(.WireUIProtocol~UI_VIEW_PATCH,fields),"LIST_APPENDED")

::method listMove
  expose instances revisionCounter viewRef
  use arg parentId, childId, index
  if \instances~hasIndex(parentId) then return .WireUIResult~failure("PARENT_INSTANCE_NOT_FOUND",parentId)
  if \instances~hasIndex(childId) then return .WireUIResult~failure("INSTANCE_NOT_FOUND",childId)
  if instances[childId]["parentId"]<>parentId then return .WireUIResult~failure("LIST_MEMBERSHIP_MISMATCH",childId)
  parent=instances[parentId]
  children=parent["children"]
  count=children~items
  if \datatype(index,"W") | index<0 | index>=count then return .WireUIResult~failure("LIST_INDEX_INVALID",index)
  old=self~arrayIndexOf(children,childId)
  if old=0 then return .WireUIResult~failure("LIST_MEMBERSHIP_MISMATCH",childId)
  if old-1=index then return .WireUIResult~success(.nil,"NO_CHANGE")
  remaining=self~arrayWithout(children,childId)
  parent["children"]=self~arrayInsert(remaining,childId,index)
  pair=revisionCounter~next
  op=.table~new
  op["op"]="LIST_MOVE"
  op["parentInstanceId"]=parentId
  op["childInstanceId"]=childId
  op["index"]=index
  fields=.table~new
  fields["viewRef"]=viewRef
  fields["previousRevision"]=pair[1]
  fields["newRevision"]=pair[2]
  fields["operations"]=.array~of(op)
  return .WireUIResult~success(.WireUIProtocol~message(.WireUIProtocol~UI_VIEW_PATCH,fields),"LIST_MOVED")

::method listRemove
  expose instances revisionCounter viewRef
  use arg parentId, childId
  if \instances~hasIndex(parentId) then return .WireUIResult~failure("PARENT_INSTANCE_NOT_FOUND",parentId)
  if \instances~hasIndex(childId) then return .WireUIResult~failure("INSTANCE_NOT_FOUND",childId)
  if instances[childId]["parentId"]<>parentId then return .WireUIResult~failure("LIST_MEMBERSHIP_MISMATCH",childId)
  subtree=.array~new
  self~collectSubtree(childId,subtree)
  parent=instances[parentId]
  parent["children"]=self~arrayWithout(parent["children"],childId)
  operations=.array~new
  /* Descendants are destroyed explicitly so renderer instance registries do not
     retain detached grandchildren when the collection row owns a subtree. */
  if subtree~items>1 then do i=subtree~items to 2 by -1
    op=.table~new
    op["op"]="DESTROY_INSTANCE"
    op["instanceId"]=subtree[i]
    operations~append(op)
  end
  op=.table~new
  op["op"]="LIST_REMOVE"
  op["parentInstanceId"]=parentId
  op["childInstanceId"]=childId
  operations~append(op)
  do id over subtree
    ignore=self~removeInstanceState(id)
  end
  pair=revisionCounter~next
  fields=.table~new
  fields["viewRef"]=viewRef
  fields["previousRevision"]=pair[1]
  fields["newRevision"]=pair[2]
  fields["operations"]=operations
  return .WireUIResult~success(.WireUIProtocol~message(.WireUIProtocol~UI_VIEW_PATCH,fields),"LIST_REMOVED")

::method collectSubtree private
  expose instances
  use arg instanceId,out
  if \instances~hasIndex(instanceId) then return
  out~append(instanceId)
  do child over instances[instanceId]["children"]
    self~collectSubtree(child,out)
  end

::method removeInstanceState private
  expose instances availableActions actionRevisionHistory
  use arg instanceId
  if instances~hasIndex(instanceId) then instances~remove(instanceId)
  prefix=instanceId"|"
  actionKeys=availableActions~allIndexes
  do key over actionKeys
    if key~left(prefix~length)=prefix then availableActions~remove(key)
  end
  historyKeys=actionRevisionHistory~allIndexes
  do key over historyKeys
    if key~left(prefix~length)=prefix then actionRevisionHistory~remove(key)
  end
  return .true

::method arrayIndexOf private
  use arg source,value
  do i=1 to source~items
    if source[i]==value then return i
  end
  return 0

::method arrayWithout private
  use arg source,value
  out=.array~new
  do item over source
    if item\==value then out~append(item)
  end
  return out

::method arrayInsert private
  use arg source,value,index
  out=.array~new
  inserted=.false
  do i=0 to source~items
    if i=index then do
      out~append(value)
      inserted=.true
    end
    if i<source~items then out~append(source[i+1])
  end
  if \inserted then out~append(value)
  return out

/* Reconcile one visible window of a potentially large authoritative collection.
   rows is an ordered Array of tables containing instanceId, definitionKey and
   optional slots.  Membership/order/row updates and window metadata are emitted
   under one view revision; rows outside the requested window need not exist in
   the renderer at all. */
::method reconcileCollectionWindow
  expose instances revisionCounter viewRef
  use arg parentId, rows, window
  if \instances~hasIndex(parentId) then return .WireUIResult~failure("PARENT_INSTANCE_NOT_FOUND",parentId)
  if rows==.nil | \rows~isA(.Array) then return .WireUIResult~failure("COLLECTION_WINDOW_ROWS_INVALID",parentId)
  if window==.nil | \window~isA(.WireUICollectionWindow) then return .WireUIResult~failure("COLLECTION_WINDOW_INVALID",parentId)
  if window~collectionRef<>parentId then return .WireUIResult~failure("COLLECTION_WINDOW_REF_MISMATCH",window~collectionRef)
  if rows~items>window~limit then return .WireUIResult~failure("COLLECTION_WINDOW_LIMIT_EXCEEDED",rows~items)
  if window~totalCount=0 & rows~items>0 then return .WireUIResult~failure("COLLECTION_WINDOW_COUNT_MISMATCH",rows~items)
  if window~totalCount>0 & window~offset+rows~items>window~totalCount then return .WireUIResult~failure("COLLECTION_WINDOW_COUNT_MISMATCH",rows~items)

  parent=instances[parentId]
  desired=.array~new
  seen=.set~new
  do row over rows
    if row==.nil | \row~hasMethod("HASINDEX") then return .WireUIResult~failure("COLLECTION_WINDOW_ROW_INVALID",parentId)
    if \row~hasIndex("instanceId") | \row~hasIndex("definitionKey") then return .WireUIResult~failure("COLLECTION_WINDOW_ROW_IDENTITY_REQUIRED",parentId)
    id=row["instanceId"]~string
    defKey=row["definitionKey"]~string
    if id="" | defKey="" then return .WireUIResult~failure("COLLECTION_WINDOW_ROW_IDENTITY_REQUIRED",id)
    if seen~hasIndex(id) then return .WireUIResult~failure("COLLECTION_WINDOW_DUPLICATE_ROW",id)
    seen~put(id); desired~append(id)
    if instances~hasIndex(id) then do
      if instances[id]["parentId"]<>parentId then return .WireUIResult~failure("LIST_MEMBERSHIP_MISMATCH",id)
      if self~arrayIndexOf(parent["children"],id)=0 then return .WireUIResult~failure("LIST_MEMBERSHIP_MISMATCH",id)
      if instances[id]["definitionKey"]<>defKey then return .WireUIResult~failure("WINDOW_DEFINITION_MISMATCH",id)
    end
  end

  working=.array~new
  do id over parent["children"]; working~append(id); end
  operations=.array~new

  /* Drop rows that are no longer in the visible authoritative window. */
  current=.array~new; do id over working; current~append(id); end
  do id over current
    if seen~hasIndex(id) then iterate
    subtree=.array~new; self~collectSubtree(id,subtree)
    if subtree~items>1 then do i=subtree~items to 2 by -1
      op=.table~new; op["op"]="DESTROY_INSTANCE"; op["instanceId"]=subtree[i]; operations~append(op)
    end
    op=.table~new; op["op"]="LIST_REMOVE"; op["parentInstanceId"]=parentId; op["childInstanceId"]=id; operations~append(op)
    working=self~arrayWithout(working,id)
    do gone over subtree; ignore=self~removeInstanceState(gone); end
  end

  /* Materialise/update rows and establish exact requested order. */
  do pos=1 to rows~items
    row=rows[pos]
    id=row["instanceId"]~string
    defKey=row["definitionKey"]~string
    slots=.table~new
    if row~hasIndex("slots") & row["slots"]\==.nil then slots=row["slots"]
    if \instances~hasIndex(id) then do
      cr=self~createInstance(id,defKey,slots,"")
      if \cr~ok then return cr
      instances[id]["parentId"]=parentId
      op=.table~new
      op["op"]="LIST_APPEND"
      op["parentInstanceId"]=parentId
      op["index"]=pos-1
      op["instance"]=self~copyInstance(instances[id])
      operations~append(op)
      working=self~arrayInsert(working,id,pos-1)
    end
    else do
      target=instances[id]["slots"]
      names=slots~allIndexes; names~sort
      do name over names
        newValue=slots[name]
        oldValue=.nil; if target~hasIndex(name) then oldValue=target[name]
        if oldValue==newValue then iterate
        target[name]=newValue
        op=.table~new; op["op"]="SET_SLOT"; op["instanceId"]=id; op["slot"]=name; op["value"]=newValue; operations~append(op)
      end
    end
    actual=self~arrayIndexOf(working,id)
    if actual=0 then return .WireUIResult~failure("LIST_MEMBERSHIP_MISMATCH",id)
    if actual<>pos then do
      op=.table~new; op["op"]="LIST_MOVE"; op["parentInstanceId"]=parentId; op["childInstanceId"]=id; op["index"]=pos-1; operations~append(op)
      working=self~arrayWithout(working,id)
      working=self~arrayInsert(working,id,pos-1)
    end
  end
  parent["children"]=working

  /* Window metadata is semantic collection state and changes in the same patch. */
  wslots=window~asSlots
  parentSlots=parent["slots"]
  names=wslots~allIndexes; names~sort
  do name over names
    newValue=wslots[name]
    oldValue=.nil; if parentSlots~hasIndex(name) then oldValue=parentSlots[name]
    if oldValue==newValue then iterate
    parentSlots[name]=newValue
    op=.table~new; op["op"]="SET_SLOT"; op["instanceId"]=parentId; op["slot"]=name; op["value"]=newValue; operations~append(op)
  end

  if operations~items=0 then return .WireUIResult~success(.nil,"NO_CHANGE")
  pair=revisionCounter~next
  fields=.table~new
  fields["viewRef"]=viewRef
  fields["previousRevision"]=pair[1]
  fields["newRevision"]=pair[2]
  fields["operations"]=operations
  return .WireUIResult~success(.WireUIProtocol~message(.WireUIProtocol~UI_VIEW_PATCH,fields),"COLLECTION_WINDOW_RECONCILED")

/* Convenience seam for append-only factual operational evidence streams. */
::method appendEvidence
  use arg parentId, entry, instanceId="", definitionKey="EVIDENCE_EVENT@1"
  if entry==.nil | \entry~isA(.WireUIEvidenceEntry) then return .WireUIResult~failure("EVIDENCE_ENTRY_INVALID",parentId)
  if instanceId="" then instanceId=entry~eventRef
  return self~listAppend(parentId,instanceId,definitionKey,entry~asSlots)

::method setEnabled
  use arg instanceId, enabled
  return self~setSlot(instanceId, "enabled", enabled)

::method setVisible
  use arg instanceId, visible
  return self~setSlot(instanceId, "visible", visible)

::method snapshot
  expose viewRef rootInstance revisionCounter instances
  fields = .table~new
  fields["viewRef"] = viewRef
  fields["revision"] = revisionCounter~value
  fields["rootInstanceId"] = rootInstance
  fields["rootInstance"] = rootInstance
  copies = .array~new
  visited=.set~new
  /* Snapshot order is part of the renderer contract: a parent must exist before
     any child is instantiated. Table iteration order is intentionally ignored. */
  if rootInstance<>"" & instances~hasIndex(rootInstance) then self~appendSnapshotSubtree(rootInstance,copies,visited)
  remaining=instances~allIndexes; remaining~sort
  do instance over remaining
    if \visited~hasIndex(instance) then self~appendSnapshotSubtree(instance,copies,visited)
  end
  fields["instances"] = copies
  fields["elementInstances"] = copies
  return .WireUIProtocol~message(.WireUIProtocol~UI_VIEW_SNAPSHOT, fields)

::method appendSnapshotSubtree private
  expose instances
  use arg instanceId,copies,visited
  if visited~hasIndex(instanceId) then return
  if \instances~hasIndex(instanceId) then return
  visited~put(instanceId)
  source=instances[instanceId]
  copies~append(self~copyInstance(source))
  do child over source["children"]
    self~appendSnapshotSubtree(child,copies,visited)
  end
  return

::method copyInstance private
  use arg source
  i = .table~new
  i["instanceId"] = source["instanceId"]
  i["definitionId"] = source["definitionId"]
  if source~hasIndex("definitionVersion") then i["definitionVersion"] = source["definitionVersion"]
  i["definitionKey"] = source["definitionKey"]
  i["parentInstanceId"] = source["parentId"]
  i["parentId"] = source["parentId"]
  i["slots"] = self~copyTable(source["slots"])
  children = .array~new
  do child over source["children"]
    children~append(child)
  end
  i["children"] = children
  return i

::method copyTable private
  use arg source
  target = .table~new
  if source == .nil then return target
  do key over source
    target[key] = source[key]
  end
  return target

::requires "WireUICollectionWindow.cls"
::requires "WireUIEvidenceEntry.cls"
::requires "WireUIAlchemy.cls"
