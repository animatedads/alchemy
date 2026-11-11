/* Actual Wire UI Server v0.17 definitions/view patches -> Swing, including ordered collection operations. */
bridge=.WireUISwingBridge~new

rootDef=.WireUIElementDefinition~new("SERVER_ROOT","1","PANEL")
collectionDef=.WireUIElementDefinition~new("POSITION_TABLE","1","SEMANTIC_COLLECTION")
rowDef=.WireUIElementDefinition~new("POSITION_ROW","1","PANEL")
defs=.array~of(rootDef,collectionDef,rowDef)
manifest=.WireUIDefinitionManifest~new("server-v017-contract","swing-large-fine",defs)

fields=manifest~asWire
bridge~accept(.WireUIProtocol~message(.WireUIProtocol~UI_RENDER_PROFILE,fields))
required=bridge~drainOutbound
if required~items<>1 then call fail "server profile cold request count" required~items
if required[1]["type"]<>.WireUIProtocol~UI_DEFINITION_REQUIRED then call fail "server profile cold request type" required[1]["type"]
if required[1]["definitions"]~items<>defs~items then call fail "server profile cold request definitions" required[1]["definitions"]~items

do definition over defs
  wire=definition~asWire
  wire["profileId"]="swing-large-fine"
  bridge~accept(.WireUIProtocol~message(.WireUIProtocol~UI_DEFINITION,wire))
end

view=.WireUIView~new("server-v017-view","root")
call must view~createInstance("root",rootDef~definitionKey,.table~new,"")
call must view~createInstance("positions",collectionDef~definitionKey,.table~new,"root")
bridge~accept(view~snapshot)
if bridge~revision<>0 then call fail "server snapshot revision" bridge~revision

rowA=.table~new; rowA["symbol"]="AAA"; rowA["severity"]="INFO"
r=view~listAppend("positions","P-100",rowDef~definitionKey,rowA,0); call must r
if r~value["operations"][1]["op"]<>"LIST_APPEND" then call fail "server append op" r~value["operations"][1]["op"]
bridge~accept(r~value)
if bridge~revision<>1 then call fail "server append revision" bridge~revision

rowB=.table~new; rowB["symbol"]="BBB"; rowB["severity"]="WARNING"
r=view~listAppend("positions","P-200",rowDef~definitionKey,rowB,1); call must r
bridge~accept(r~value)
if bridge~revision<>2 then call fail "server second append revision" bridge~revision

r=view~listMove("positions","P-200",0); call must r
if r~value["operations"][1]["op"]<>"LIST_MOVE" then call fail "server move op" r~value["operations"][1]["op"]
bridge~accept(r~value)
if bridge~revision<>3 then call fail "server move revision" bridge~revision

r=view~listRemove("positions","P-200"); call must r
if r~value["operations"][1]["op"]<>"LIST_REMOVE" then call fail "server remove op" r~value["operations"][1]["op"]
bridge~accept(r~value)
if bridge~revision<>4 then call fail "server remove revision" bridge~revision

/* v0.15+ bounded collection-window reconciliation can mix row updates,
   structural membership changes and authoritative window metadata in one patch. */
w1a=.table~new; w1a["instanceId"]="P-100"; w1a["definitionKey"]=rowDef~definitionKey
w1as=.table~new; w1as["symbol"]="AAA"; w1as["severity"]="CRITICAL"; w1a["slots"]=w1as
w1b=.table~new; w1b["instanceId"]="P-300"; w1b["definitionKey"]=rowDef~definitionKey
w1bs=.table~new; w1bs["symbol"]="CCC"; w1bs["severity"]="INFO"; w1b["slots"]=w1bs
window=.WireUICollectionWindow~new("positions",0,2,50000,"risk-desc","open-only",1,"P-100")
r=view~reconcileCollectionWindow("positions",.array~of(w1a,w1b),window); call must r
if \hasOp(r~value["operations"],"LIST_APPEND") then call fail "window append op missing"
if \hasOp(r~value["operations"],"SET_SLOT") then call fail "window slot op missing"
bridge~accept(r~value)
if bridge~revision<>5 then call fail "first window revision" bridge~revision

w2a=.table~new; w2a["instanceId"]="P-300"; w2a["definitionKey"]=rowDef~definitionKey
w2as=.table~new; w2as["symbol"]="CCC"; w2as["severity"]="WARNING"; w2a["slots"]=w2as
w2b=.table~new; w2b["instanceId"]="P-400"; w2b["definitionKey"]=rowDef~definitionKey
w2bs=.table~new; w2bs["symbol"]="DDD"; w2bs["severity"]="INFO"; w2b["slots"]=w2bs
window2=.WireUICollectionWindow~new("positions",2,2,50000,"risk-desc","open-only",2,"P-300")
r=view~reconcileCollectionWindow("positions",.array~of(w2a,w2b),window2); call must r
if \hasOp(r~value["operations"],"LIST_REMOVE") then call fail "window remove op missing"
if \hasOp(r~value["operations"],"LIST_APPEND") then call fail "window replacement append op missing"
if \hasOp(r~value["operations"],"SET_SLOT") then call fail "window replacement slot op missing"
bridge~accept(r~value)
if bridge~revision<>6 then call fail "second window revision" bridge~revision

out=bridge~drainOutbound
if out~items<>0 then call fail "unexpected renderer outbound" out~items
say "PASS Wire UI Server v0.17 ordered/windowed collection patches -> ooRexx/BSF -> Swing revision="bridge~revision
exit 0

::routine hasOp
  use arg operations,kind
  do op over operations
    if op["op"]=kind then return .true
  end
  return .false

::routine must
  use arg r
  if \r~ok then call fail "server operation" r~code
  return r

::routine fail
  use arg what,detail=""
  say "FAIL" what detail
  exit 30

::requires "WireUISwingBridge.cls"
::requires "WireUIElementDefinition.cls"
::requires "WireUIDefinitionManifest.cls"
::requires "WireUICollectionWindow.cls"
::requires "WireUIView.cls"
