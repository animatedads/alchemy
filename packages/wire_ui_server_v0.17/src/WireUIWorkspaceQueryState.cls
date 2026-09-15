::requires "WireUIProtocol.cls"
/* Authoritative semantic filter/sort state for a dense workspace. */
::class WireUIWorkspaceQueryState subclass AlchemyObject public
::attribute workspaceRef get
::attribute queryRevision get
::attribute scopeRevision get
::attribute orderRevision get

::method init
  expose workspaceRef queryRevision scopeRevision orderRevision filters sortRef sortDirection
  use arg workspaceRef
  self~init:super(.WireUIAlchemy~metadata("Authoritative Wire UI workspace query state"))
  workspaceRef=workspaceRef~string~strip
  if workspaceRef="" then raise syntax 93.906 array("workspace query",workspaceRef)
  queryRevision=0; scopeRevision=0; orderRevision=0
  filters=.table~new
  sortRef=""; sortDirection="ASC"
  self~registerStateVariable("workspaceRef","PUBLIC","semantic workspace identity")
  self~registerStateVariable("queryRevision","PUBLIC","monotonic workspace query revision")
  self~registerStateVariable("scopeRevision","PUBLIC","filter/membership scope revision")
  self~registerStateVariable("orderRevision","PUBLIC","sort/order revision")

::method setFilter
  expose queryRevision scopeRevision filters
  use arg filterRef, value
  filterRef=filterRef~string~strip
  if filterRef="" then return .WireUIResult~failure("WORKSPACE_FILTER_REF_REQUIRED")
  if filters~hasIndex(filterRef) & filters[filterRef]==value then return .WireUIResult~success(self,"NO_CHANGE")
  filters[filterRef]=value
  queryRevision+=1; scopeRevision+=1
  return .WireUIResult~success(self,"WORKSPACE_FILTER_UPDATED")

::method removeFilter
  expose queryRevision scopeRevision filters
  use arg filterRef
  filterRef=filterRef~string~strip
  if \filters~hasIndex(filterRef) then return .WireUIResult~success(self,"NO_CHANGE")
  filters~remove(filterRef)
  queryRevision+=1; scopeRevision+=1
  return .WireUIResult~success(self,"WORKSPACE_FILTER_REMOVED")

::method clearFilters
  expose queryRevision scopeRevision filters
  if filters~items=0 then return .WireUIResult~success(self,"NO_CHANGE")
  filters=.table~new
  queryRevision+=1; scopeRevision+=1
  return .WireUIResult~success(self,"WORKSPACE_FILTERS_CLEARED")

::method setSort
  expose queryRevision orderRevision sortRef sortDirection
  use arg newSortRef, newDirection="ASC"
  newSortRef=newSortRef~string~strip
  newDirection=newDirection~string~strip~translate
  if newSortRef="" then return .WireUIResult~failure("WORKSPACE_SORT_REF_REQUIRED")
  if newDirection<>"ASC" & newDirection<>"DESC" then return .WireUIResult~failure("WORKSPACE_SORT_DIRECTION_INVALID",newDirection)
  if sortRef=newSortRef & sortDirection=newDirection then return .WireUIResult~success(self,"NO_CHANGE")
  sortRef=newSortRef; sortDirection=newDirection
  queryRevision+=1; orderRevision+=1
  return .WireUIResult~success(self,"WORKSPACE_SORT_UPDATED")

::method filters
  expose filters
  return self~copyTable(filters)

::method asWire
  expose workspaceRef queryRevision scopeRevision orderRevision filters sortRef sortDirection
  d=.table~new
  d["workspaceRef"]=workspaceRef
  d["queryRevision"]=queryRevision
  d["scopeRevision"]=scopeRevision
  d["orderRevision"]=orderRevision
  d["filters"]=self~copyTable(filters)
  if sortRef<>"" then do
    s=.table~new; s["sortRef"]=sortRef; s["direction"]=sortDirection; d["sort"]=s
  end
  return d

::method copyTable private
  use arg source
  d=.table~new
  do k over source~allIndexes; d[k]=source[k]; end
  return d

::requires "WireUIAlchemy.cls"
