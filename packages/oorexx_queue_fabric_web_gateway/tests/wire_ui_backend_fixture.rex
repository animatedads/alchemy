parse arg portFile stopFile resultFile
if portFile="" | stopFile="" | resultFile="" then do; say "fixture paths required"; exit 2; end
manager=.ObjectQueueManager~new("GWWIREUI")
call must manager~createQueue("WIREUI.TEST.IN","TEMPORARY","WIREUI",0,"admin")
call must manager~createQueue("WIREUI.TEST.OUT","TEMPORARY","WIREUI",0,"admin")
call must manager~grant("WIREUI.TEST.IN","browser-gateway",.QueueAccess~PUT,"admin")
call must manager~grant("WIREUI.TEST.OUT","browser-gateway",.QueueAccess~GET,"admin")
call must manager~grant("WIREUI.TEST.OUT","browser-gateway",.QueueAccess~BROWSE,"admin")
backend=.QueueFabricWebGatewayBackend~new(manager,"WIREUI.TEST.IN","WIREUI.TEST.OUT","browser-gateway","bridge-secret")
listener=.QueueFabricWebGatewayBridgeListener~new(backend,"127.0.0.1",0)
if listener~serveAsync == .false then do; say "listener start failed"; exit 3; end
call lineout portFile,listener~port; call lineout portFile

materialTokens=.directory~new; materialTokens["brand.pink"]="#ff2d88"; materialTokens["brand.yellow"]="#ffd61f"; materialTokens["brand.blue"]="#183b8f"; materialTokens["brand.ink"]="#10204f"; materialTokens["surface"]="#ffffff"; materialTokens["space.unit"]="8"; materialTokens["radius.control"]="14"
materialRecipes=.directory~new; materialRecipes["hero.search"]="brand.hero/search.card"; materialRecipes["assistant.panel"]="surface.white/chat"
material=.directory~new; material["type"]="UI_MATERIAL_SET"; material["materialId"]="FLYLO_MATERIAL"; material["version"]="1"; material["contentAddress"]="fixture-flylo-material-1"; material["tokens"]=materialTokens; material["recipes"]=materialRecipes
call send manager, material

profile=.directory~new; profile["type"]="UI_RENDER_PROFILE"; profile["profileId"]="HUMAN_VISUAL"; profile["siteId"]="FLYLO"
call send manager, profile

bindings=.directory~new; bindings["origin"]="origin"; bindings["destination"]="destination"; bindings["date"]="date"; bindings["passengers"]="passengers"
meta=.directory~new; meta["styleRole"]="hero-search"; meta["materialRole"]="PRIMARY"; meta["bindings"]=bindings
searchDef=.directory~new; searchDef["type"]="UI_DEFINITION"; searchDef["definitionId"]="FLYLO_SEARCH_FORM"; searchDef["definitionVersion"]=1; searchDef["definitionKey"]="FLYLO_SEARCH_FORM@1"; searchDef["primitive"]="FORM"; searchDef["profile"]="HUMAN_VISUAL"; searchDef["semanticAction"]="FLIGHT.SEARCH"; searchDef["metadata"]=meta
call send manager, searchDef

slots=.directory~new; slots["origin"]="PIK"; slots["destination"]="EWR"; slots["date"]="2026-09-01"; slots["passengers"]="1"
inst=.directory~new; inst["instanceId"]="search"; inst["definitionKey"]="FLYLO_SEARCH_FORM@1"; inst["slots"]=slots
snapshot=.directory~new; snapshot["type"]="UI_VIEW_SNAPSHOT"; snapshot["viewRef"]="FlyLo.Search"; snapshot["revision"]=7; snapshot["rootInstanceId"]="search"; snapshot["elementInstances"]=.array~of(inst)
call send manager, snapshot

searchAction=.nil; selectionAction=.nil; assistantAction=.nil; offered=.false; assistantOffered=.false
do while stream(stopFile,"C","QUERY EXISTS") = ""
  r=manager~claim("WIREUI.TEST.IN","admin")
  if \r~ok then do
    if r~code="QUEUE_EMPTY" then do; call syssleep 0.01; iterate; end
    say "claim failed" r~code r~detail; leave
  end
  p=r~value; payload=p~payload
  ignore=manager~ack("WIREUI.TEST.IN",p~packageId,p~claimToken,"admin")
  if payload~hasIndex("type") & payload["type"]="UI_ACTION" then do
    action=payload["action"]
    if action="FLIGHT.SEARCH" & searchAction==.nil then do
      searchAction=payload
      if \offered then do
        offerMeta=.directory~new; offerMeta["styleRole"]="utility-card"
        offerDef=.directory~new; offerDef["type"]="UI_DEFINITION"; offerDef["definitionId"]="FLYLO_OFFER_CARDS"; offerDef["definitionVersion"]=1; offerDef["definitionKey"]="FLYLO_OFFER_CARDS@1"; offerDef["primitive"]="OFFER_LIST"; offerDef["profile"]="HUMAN_VISUAL"; offerDef["semanticAction"]="FLIGHT.SELECT"; offerDef["metadata"]=offerMeta
        call send manager, offerDef
        o1=.directory~new; o1["offerId"]="OFF-7"; o1["origin"]="PIK"; o1["destination"]="EWR"; o1["fare"]="199.00"; o1["currency"]="GBP"
        o2=.directory~new; o2["offerId"]="OFF-8"; o2["origin"]="PIK"; o2["destination"]="EWR"; o2["fare"]="249.00"; o2["currency"]="GBP"
        offerSlots=.directory~new; offerSlots["offers"]=.array~of(o1,o2)
        offerInst=.directory~new; offerInst["instanceId"]="offers"; offerInst["definitionKey"]="FLYLO_OFFER_CARDS@1"; offerInst["slots"]=offerSlots
        offerSnap=.directory~new; offerSnap["type"]="UI_VIEW_SNAPSHOT"; offerSnap["viewRef"]="FlyLo.Offers"; offerSnap["revision"]=8; offerSnap["rootInstanceId"]="offers"; offerSnap["elementInstances"]=.array~of(offerInst)
        call send manager, offerSnap
        offered=.true
      end
    end
    else if action="FLIGHT.SELECT" then do
      selectionAction=payload
      if \assistantOffered then do
        assistantBindings=.directory~new; assistantBindings["message"]="message"; assistantBindings["answer"]="answer"
        assistantMeta=.directory~new; assistantMeta["styleRole"]="assistant-panel"; assistantMeta["materialRole"]="assistant.panel"; assistantMeta["bindings"]=assistantBindings
        assistantDef=.directory~new; assistantDef["type"]="UI_DEFINITION"; assistantDef["definitionId"]="FLYLO_ASSISTANT"; assistantDef["definitionVersion"]=1; assistantDef["definitionKey"]="FLYLO_ASSISTANT@1"; assistantDef["primitive"]="SEMANTIC_RECORD"; assistantDef["profile"]="HUMAN_VISUAL"; assistantDef["semanticAction"]="ASSISTANT.ASK"; assistantDef["metadata"]=assistantMeta
        call send manager, assistantDef
        assistantSlots=.directory~new; assistantSlots["message"]=""; assistantSlots["answer"]="Ask FlyLo about this trip."
        assistantInst=.directory~new; assistantInst["instanceId"]="assistant"; assistantInst["definitionKey"]="FLYLO_ASSISTANT@1"; assistantInst["slots"]=assistantSlots
        assistantSnap=.directory~new; assistantSnap["type"]="UI_VIEW_SNAPSHOT"; assistantSnap["viewRef"]="FlyLo.Assistant"; assistantSnap["revision"]=9; assistantSnap["rootInstanceId"]="assistant"; assistantSnap["elementInstances"]=.array~of(assistantInst)
        call send manager, assistantSnap
        assistantOffered=.true
      end
    end
    else if action="ASSISTANT.ASK" then do
      assistantAction=payload
      captured=.directory~new; captured["search"]=searchAction; captured["selection"]=selectionAction; captured["assistant"]=assistantAction
      call lineout resultFile,.JSON~toJSON(captured); call lineout resultFile
    end
  end
end
ignore=listener~stop
exit 0

::routine send
  use arg manager,payload
  r=manager~put("WIREUI.TEST.OUT",payload,.table~new,"admin")
  if \r~ok then do; say "outbound put failed" r~code r~detail; exit 4; end
  return r
::routine must
  use arg r
  if \r~ok then do; say "queue operation failed" r~code r~detail; exit 5; end
  return r
::requires "QueueFabricWebGatewayBridge.cls"
