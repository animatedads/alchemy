/*
  Real Wire UI Server v0.17 large-collection round trip through ooRexx/BSF/Swing.
  Renderer demand is semantic only; the server/application remains the only source authority.
*/
bridge=.WireUISwingBridge~new

rootDef=.WireUIElementDefinition~new("MAIL_ROOT","1","PANEL")
collectionDef=.WireUIElementDefinition~new("MESSAGE_LIST","1","SEMANTIC_COLLECTION")
rowDef=.WireUIElementDefinition~new("MESSAGE_ROW","1","PANEL")
defs=.array~of(rootDef,collectionDef,rowDef)
manifest=.WireUIDefinitionManifest~new("server-v017-range-roundtrip","swing-large-fine",defs)

fields=manifest~asWire
bridge~accept(.WireUIProtocol~message(.WireUIProtocol~UI_RENDER_PROFILE,fields))
required=bridge~drainOutbound
if required~items<>1 then call fail "cold definition request count" required~items

do definition over defs
  wire=definition~asWire
  wire["profileId"]="swing-large-fine"
  bridge~accept(.WireUIProtocol~message(.WireUIProtocol~UI_DEFINITION,wire))
end

view=.WireUIView~new("mail-200k-view","root")
call must view~createInstance("root",rootDef~definitionKey,.table~new,"")
call must view~createInstance("messages",collectionDef~definitionKey,.table~new,"root")
bridge~accept(view~snapshot)
if bridge~revision<>0 then call fail "initial snapshot revision" bridge~revision

rows=makeRows(0,100,rowDef~definitionKey)
window=.WireUICollectionWindow~new("messages",0,100,200000,"date-desc","inbox",1,"M0")
r=view~reconcileCollectionWindow("messages",rows,window); call must r
if \hasWindowSlot(r~value["operations"],"windowOffset",0) then call fail "missing initial windowOffset"
if \hasWindowSlot(r~value["operations"],"windowLimit",100) then call fail "missing initial windowLimit"
if \hasWindowSlot(r~value["operations"],"windowTotalCount",200000) then call fail "missing initial windowTotalCount"
bridge~accept(r~value)
if bridge~revision<>1 then call fail "initial window revision" bridge~revision

/* This calls the same semantic runtime seam used by native viewport movement.
   Java tests separately prove that the actual Swing scrollbar reaches this seam. */
bridge~runtime~requestRange("messages",1000,100)
action=bridge~pollAction
if action==.nil then call fail "missing RangeRequested action"
if action["type"]<>.WireUIProtocol~UI_ACTION then call fail "range action type" action["type"]
if action["action"]<>"RangeRequested" then call fail "range action name" action["action"]
if action["elementInstance"]<>"messages" then call fail "range element identity" action["elementInstance"]
if action["renderedRevision"]<>1 then call fail "range event revision" action["renderedRevision"]
if action["detail"]["start"]<>1000 then call fail "range start" action["detail"]["start"]
if action["detail"]["count"]<>100 then call fail "range count" action["detail"]["count"]

/* Application/server authority satisfies the demand. */
start=action["detail"]["start"]
count=action["detail"]["count"]
rows2=makeRows(start,count,rowDef~definitionKey)
window2=.WireUICollectionWindow~new("messages",start,count,200000,"date-desc","inbox",2,"M"start)
r=view~reconcileCollectionWindow("messages",rows2,window2); call must r
bridge~accept(r~value)
if bridge~revision<>2 then call fail "replacement window revision" bridge~revision
if bridge~pollAction<>.nil then call fail "authoritative patch echoed renderer demand"

/* A final partial window remains valid in the server contract: limit is request size,
   while only the remaining 50 authoritative rows are projected. */
bridge~runtime~requestRange("messages",199950,100)
action=bridge~pollAction
if action==.nil then call fail "missing final RangeRequested action"
if action["renderedRevision"]<>2 then call fail "final range event revision" action["renderedRevision"]
rows3=makeRows(199950,50,rowDef~definitionKey)
window3=.WireUICollectionWindow~new("messages",199950,100,200000,"date-desc","inbox",3,"M199950")
r=view~reconcileCollectionWindow("messages",rows3,window3); call must r
bridge~accept(r~value)
if bridge~revision<>3 then call fail "final partial window revision" bridge~revision
if bridge~pollAction<>.nil then call fail "final authoritative patch echoed renderer demand"

say "PASS Wire UI Server v0.17 200000-row RangeRequested round trip -> Swing revision="bridge~revision
exit 0

::routine makeRows
  use arg start,count,definitionKey
  rows=.array~new
  do i=0 to count-1
    n=start+i
    row=.table~new
    row["instanceId"]="M"n
    row["definitionKey"]=definitionKey
    slots=.table~new
    slots["messageId"]="M"n
    slots["subject"]="Message "n
    row["slots"]=slots
    rows~append(row)
  end
  return rows

::routine hasWindowSlot
  use arg operations,slot,wanted
  do op over operations
    if op["op"]<>"SET_SLOT" then iterate
    if op["instanceId"]<>"messages" then iterate
    if op["slot"]<>slot then iterate
    return op["value"]=wanted
  end
  return .false

::routine must
  use arg r
  if \r~ok then call fail "server operation" r~code
  return r

::routine fail
  use arg what,detail=""
  say "FAIL" what detail
  exit 31

::requires "WireUISwingBridge.cls"
::requires "WireUIElementDefinition.cls"
::requires "WireUIDefinitionManifest.cls"
::requires "WireUICollectionWindow.cls"
::requires "WireUIView.cls"
