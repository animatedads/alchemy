::requires "WireUIProtocol.cls"
/* Immutable server-generated context binding a workspace command to exact query/selection/result state. */
::class WireUIWorkspaceCommandContext subclass AlchemyObject public
::attribute workspaceRef get
::attribute queryRevision get
::attribute scopeRevision get
::attribute orderRevision get
::attribute selectionRevision get
::attribute resultRevision get
::attribute resultQueryRevision get
::attribute resultScopeRevision get
::attribute resultOrderRevision get
::attribute resultCurrent get

::method init
  expose workspaceRef queryRevision scopeRevision orderRevision selectionRevision selectedIds resultRevision resultQueryRevision resultScopeRevision resultOrderRevision resultCurrent
  use arg inputWorkspaceRef, inputQueryRevision, inputScopeRevision, inputOrderRevision, inputSelectionRevision, inputSelectedIds, inputResultRevision=.nil, inputResultQueryRevision=.nil, inputResultScopeRevision=.nil, inputResultOrderRevision=.nil, inputResultCurrent=.false
  self~init:super(.WireUIAlchemy~metadata("Exact Wire UI workspace command context"))
  workspaceRef=inputWorkspaceRef~string~strip
  queryRevision=inputQueryRevision
  scopeRevision=inputScopeRevision
  orderRevision=inputOrderRevision
  selectionRevision=inputSelectionRevision
  if inputSelectedIds==.nil then inputSelectedIds=.array~new
  selectedIds=self~copyArray(inputSelectedIds)
  resultRevision=inputResultRevision
  resultQueryRevision=inputResultQueryRevision
  resultScopeRevision=inputResultScopeRevision
  resultOrderRevision=inputResultOrderRevision
  resultCurrent=inputResultCurrent
  self~registerStateVariable("workspaceRef","PUBLIC","semantic workspace identity")
  self~registerStateVariable("queryRevision","PUBLIC","exact query revision for command")
  self~registerStateVariable("selectionRevision","PUBLIC","exact selection revision for command")
  self~registerStateVariable("resultRevision","PUBLIC","exact authoritative result revision for command")

::method selectedIds
  expose selectedIds
  return self~copyArray(selectedIds)

::method asWire
  expose workspaceRef queryRevision scopeRevision orderRevision selectionRevision selectedIds resultRevision resultQueryRevision resultScopeRevision resultOrderRevision resultCurrent
  d=.table~new
  d["workspaceRef"]=workspaceRef
  d["queryRevision"]=queryRevision
  d["scopeRevision"]=scopeRevision
  d["orderRevision"]=orderRevision
  d["selectionRevision"]=selectionRevision
  d["selectedIds"]=self~copyArray(selectedIds)
  if resultRevision\==.nil then do
    d["resultRevision"]=resultRevision
    d["resultQueryRevision"]=resultQueryRevision
    d["resultScopeRevision"]=resultScopeRevision
    d["resultOrderRevision"]=resultOrderRevision
    d["resultCurrent"]=resultCurrent
  end
  return d

::method copyArray private
  use arg source
  a=.array~new
  do v over source; a~append(v); end
  return a

::requires "WireUIAlchemy.cls"
