/* Authoritative window descriptor for a large semantic collection. */
::class WireUICollectionWindow subclass AlchemyObject public
::attribute collectionRef get
::attribute offset get
::attribute limit get
::attribute totalCount get
::attribute sortRef get
::attribute filterRef get
::attribute windowRevision get
::attribute anchorRef get

::method init
  expose collectionRef offset limit totalCount sortRef filterRef windowRevision anchorRef
  use arg collectionRef, offset=0, limit=50, totalCount=0, sortRef="", filterRef="", windowRevision=1, anchorRef=""
  self~init:super(.WireUIAlchemy~metadata("Authoritative window over a large semantic collection"))
  collectionRef=collectionRef~string~strip
  if collectionRef="" then raise syntax 93.906 array("collectionRef",collectionRef)
  if \datatype(offset,"W") | offset<0 then raise syntax 93.906 array("offset",offset)
  if \datatype(limit,"W") | limit<1 then raise syntax 93.906 array("limit",limit)
  if \datatype(totalCount,"W") | totalCount<0 then raise syntax 93.906 array("totalCount",totalCount)
  if offset>totalCount & totalCount<>0 then raise syntax 93.906 array("offset beyond totalCount",offset)
  if \datatype(windowRevision,"W") | windowRevision<0 then raise syntax 93.906 array("windowRevision",windowRevision)
  sortRef=sortRef~string
  filterRef=filterRef~string
  anchorRef=anchorRef~string
  self~registerStateVariable("collectionRef","PUBLIC","semantic collection identity")
  self~registerStateVariable("offset","PUBLIC","zero-based authoritative window offset")
  self~registerStateVariable("limit","PUBLIC","maximum requested window size")
  self~registerStateVariable("totalCount","PUBLIC","authoritative total matching rows")
  self~registerStateVariable("windowRevision","PUBLIC","authoritative collection-window revision")

::method asSlots
  expose collectionRef offset limit totalCount sortRef filterRef windowRevision anchorRef
  d=.table~new
  d["collectionRef"]=collectionRef
  d["windowOffset"]=offset
  d["windowLimit"]=limit
  d["windowTotalCount"]=totalCount
  d["windowRevision"]=windowRevision
  d["sortRef"]=sortRef
  d["filterRef"]=filterRef
  d["anchorRef"]=anchorRef
  return d

::method asWire
  return self~asSlots

::requires "WireUIAlchemy.cls"
