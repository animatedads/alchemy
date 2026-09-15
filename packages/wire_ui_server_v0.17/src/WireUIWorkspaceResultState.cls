::requires "WireUIProtocol.cls"
/* Authoritative result snapshot for a dense workspace query. */
::class WireUIWorkspaceResultState subclass AlchemyObject public
::attribute workspaceRef get
::attribute resultRevision get
::attribute queryRevision get
::attribute scopeRevision get
::attribute orderRevision get
::attribute totalCount get
::attribute provenanceRef get
::attribute asOfRef get
::attribute published get

::method init
  expose workspaceRef resultRevision queryRevision scopeRevision orderRevision totalCount aggregates provenanceRef asOfRef published
  use arg workspaceRef
  self~init:super(.WireUIAlchemy~metadata("Authoritative Wire UI workspace result state"))
  workspaceRef=workspaceRef~string~strip
  if workspaceRef="" then raise syntax 93.906 array("workspace result",workspaceRef)
  resultRevision=0
  queryRevision=-1
  scopeRevision=-1
  orderRevision=-1
  totalCount=0
  aggregates=.table~new
  provenanceRef=""
  asOfRef=""
  published=.false
  self~registerStateVariable("workspaceRef","PUBLIC","semantic workspace identity")
  self~registerStateVariable("resultRevision","PUBLIC","monotonic authoritative workspace result revision")
  self~registerStateVariable("queryRevision","PUBLIC","query revision this result was produced from")
  self~registerStateVariable("scopeRevision","PUBLIC","membership scope revision this result was produced from")
  self~registerStateVariable("orderRevision","PUBLIC","ordering revision this result was produced from")
  self~registerStateVariable("totalCount","PUBLIC","authoritative result membership count")
  self~registerStateVariable("provenanceRef","PUBLIC","result provenance reference")
  self~registerStateVariable("asOfRef","PUBLIC","business/source as-of reference")

::method publish
  expose resultRevision queryRevision scopeRevision orderRevision totalCount aggregates provenanceRef asOfRef published
  use arg query, inputTotalCount, inputAggregates=.nil, inputProvenanceRef="", inputAsOfRef=""
  if query==.nil | \query~hasMethod("QUERYREVISION") | \query~hasMethod("SCOPEREVISION") | \query~hasMethod("ORDERREVISION") then return .WireUIResult~failure("WORKSPACE_RESULT_QUERY_INVALID")
  if \datatype(inputTotalCount,"W") | inputTotalCount<0 then return .WireUIResult~failure("WORKSPACE_RESULT_TOTAL_INVALID",inputTotalCount)
  if inputAggregates==.nil then inputAggregates=.table~new
  if \inputAggregates~hasMethod("HASINDEX") then return .WireUIResult~failure("WORKSPACE_RESULT_AGGREGATES_INVALID")
  queryRevision=query~queryRevision
  scopeRevision=query~scopeRevision
  orderRevision=query~orderRevision
  totalCount=inputTotalCount
  aggregates=self~copyTable(inputAggregates)
  provenanceRef=inputProvenanceRef~string~strip
  asOfRef=inputAsOfRef~string~strip
  resultRevision+=1
  published=.true
  return .WireUIResult~success(self,"WORKSPACE_RESULT_PUBLISHED")

::method currentFor
  expose published queryRevision scopeRevision orderRevision
  use arg query
  if \published then return .false
  return queryRevision=query~queryRevision & scopeRevision=query~scopeRevision & orderRevision=query~orderRevision

::method aggregates
  expose aggregates
  return self~copyTable(aggregates)

::method asWire
  expose workspaceRef resultRevision queryRevision scopeRevision orderRevision totalCount aggregates provenanceRef asOfRef published
  d=.table~new
  d["workspaceRef"]=workspaceRef
  d["resultRevision"]=resultRevision
  d["queryRevision"]=queryRevision
  d["scopeRevision"]=scopeRevision
  d["orderRevision"]=orderRevision
  d["totalCount"]=totalCount
  d["aggregates"]=self~copyTable(aggregates)
  d["published"]=published
  if provenanceRef<>"" then d["provenanceRef"]=provenanceRef
  if asOfRef<>"" then d["asOfRef"]=asOfRef
  return d

::method copyTable private
  use arg source
  d=.table~new
  do k over source~allIndexes; d[k]=source[k]; end
  return d

::requires "WireUIAlchemy.cls"
