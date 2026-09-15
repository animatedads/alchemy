::requires "WireUIProtocol.cls"
/* Stable semantic selection independent of visible window or renderer rows. */
::class WireUIWorkspaceSelection subclass AlchemyObject public
::attribute workspaceRef get
::attribute selectionRevision get
::attribute scopeRevision get

::method init
  expose workspaceRef selectionRevision scopeRevision selected
  use arg workspaceRef, initialScopeRevision=0
  self~init:super(.WireUIAlchemy~metadata("Authoritative Wire UI workspace semantic selection"))
  workspaceRef=workspaceRef~string~strip
  if workspaceRef="" then raise syntax 93.906 array("workspace selection",workspaceRef)
  selectionRevision=0
  scopeRevision=initialScopeRevision
  selected=.array~new
  self~registerStateVariable("workspaceRef","PUBLIC","semantic workspace identity")
  self~registerStateVariable("selectionRevision","PUBLIC","monotonic semantic selection revision")
  self~registerStateVariable("scopeRevision","PUBLIC","query scope selection is valid against")

::method replace
  expose selectionRevision scopeRevision selected
  use arg expectedScopeRevision, ids
  if expectedScopeRevision<>scopeRevision then return .WireUIResult~failure("WORKSPACE_SELECTION_SCOPE_STALE",expectedScopeRevision,scopeRevision)
  if ids==.nil | \ids~isA(.Array) then return .WireUIResult~failure("WORKSPACE_SELECTION_INVALID")
  canonical=self~canonicalIds(ids)
  if self~arraysEqual(selected,canonical) then return .WireUIResult~success(self,"NO_CHANGE")
  selected=canonical
  selectionRevision+=1
  return .WireUIResult~success(self,"WORKSPACE_SELECTION_REPLACED")

::method clear
  expose selectionRevision selected
  if selected~items=0 then return .WireUIResult~success(self,"NO_CHANGE")
  selected=.array~new
  selectionRevision+=1
  return .WireUIResult~success(self,"WORKSPACE_SELECTION_CLEARED")

::method invalidateForScope
  expose selectionRevision scopeRevision selected
  use arg newScopeRevision
  if newScopeRevision=scopeRevision then return .WireUIResult~success(self,"NO_CHANGE")
  scopeRevision=newScopeRevision
  selected=.array~new
  selectionRevision+=1
  return .WireUIResult~success(self,"WORKSPACE_SELECTION_INVALIDATED")

::method selectedIds
  expose selected
  a=.array~new; do id over selected; a~append(id); end; return a

::method contains
  expose selected
  use arg semanticId
  do id over selected; if id=semanticId then return .true; end
  return .false

::method asWire
  expose workspaceRef selectionRevision scopeRevision selected
  d=.table~new
  d["workspaceRef"]=workspaceRef
  d["selectionRevision"]=selectionRevision
  d["scopeRevision"]=scopeRevision
  d["selectedIds"]=self~selectedIds
  return d

::method canonicalIds private
  use arg ids
  seen=.set~new; out=.array~new
  do id over ids
    value=id~string~strip
    if value="" then iterate
    if \seen~hasIndex(value) then do; seen~put(value); out~append(value); end
  end
  out~sort
  return out

::method arraysEqual private
  use arg a,b
  if a~items<>b~items then return .false
  do i=1 to a~items
    if a[i]<>b[i] then return .false
  end
  return .true

::requires "WireUIAlchemy.cls"
