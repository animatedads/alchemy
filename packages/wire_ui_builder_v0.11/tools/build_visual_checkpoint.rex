parse arg outPath root
if outPath="" then outPath="visual_snapshot.json"
if root="" then do; parse source . . script; root=filespec("P",script)".."; end
p=.WireUIBuilderProject~new("VISUAL_WORKSPACE","Neutral multi-screen workspace")
call put p,"DESIGN.COMPONENT.DRAFT","CARD",component("PANEL")
call put p,"DESIGN.COMPONENT.DRAFT","FORM",component("FORM")
call put p,"DESIGN.COMPONENT.DRAFT","LIST",component("OFFER_LIST")
do id over .array~of("APP_HEADER","NAVIGATION","SEARCH_PANEL","DETAIL_PANEL","ACTION_PANEL","HISTORY_PANEL","NOTICES")
  call put p,"DESIGN.ELEMENT.DRAFT",id,element(id)
end
call put p,"DESIGN.PROJECTION.DRAFT","APP_HEADER_VIEW",projection("APP_HEADER","CARD","PREVIEW_HEADER")
call put p,"DESIGN.PROJECTION.DRAFT","NAVIGATION_VIEW",projection("NAVIGATION","LIST","PREVIEW_NAV")
call put p,"DESIGN.PROJECTION.DRAFT","SEARCH_PANEL_VIEW",projection("SEARCH_PANEL","FORM","PREVIEW_SEARCH")
call put p,"DESIGN.PROJECTION.DRAFT","DETAIL_PANEL_VIEW",projection("DETAIL_PANEL","CARD","PREVIEW_DETAIL")
call put p,"DESIGN.PROJECTION.DRAFT","ACTION_PANEL_VIEW",projection("ACTION_PANEL","FORM","PREVIEW_ACTION")
call put p,"DESIGN.PROJECTION.DRAFT","HISTORY_PANEL_VIEW",projection("HISTORY_PANEL","LIST","PREVIEW_HISTORY")
call put p,"DESIGN.PROJECTION.DRAFT","NOTICES_VIEW",projection("NOTICES","CARD","PREVIEW_NOTICES")
call put p,"DESIGN.JOURNEY.DRAFT","MAIN_FLOW",journey()
do sid over .array~of("SEARCH","SUMMARY","TRANSACTION","OPEN","CONFIRM","AUDIT")
  call put p,"DESIGN.COMPOSITION.DRAFT",sid"_LAYOUT",composition(sid)
end

catalog=.WireUISourceCatalogue~new("builder")
ignore=catalog~addTree(root,"*.cls",.true)
ignore=catalog~seal
br=.WireUIBuilderRuntimeFactory~build(p,catalog,"WIRE-UI-BUILDER","VISUAL-CHECKPOINT","BUILDER-WEB",root"/studio/wire_ui_builder_studio_v0.11.json")
if \br~ok then do; say br~code br~detail; exit 6; end
app=br~value
.json~toJsonFile(outPath,app~snapshot,.true)
say "VISUAL_SNAPSHOT" outPath "revision" p~revision "drafts" p~drafts~items
exit 0

component: use arg primitive; s=.table~new; s["publishVersion"]="1"; s["primitive"]=primitive; return s
element:
  use arg id
  s=.table~new; s["publishVersion"]="1"; s["semanticType"]="WORKSPACE_"id; s["fields"]=.array~of("title","summary"); s["actions"]=.array~new; s["audiencePolicyRef"]="PUBLIC"; return s
projection:
  use arg elementId,componentId,definitionId
  s=.table~new; s["publishVersion"]="1"; s["profile"]="HUMAN_VISUAL"; s["elementId"]=elementId; s["componentId"]=componentId; s["definitionId"]=definitionId; s["action"]=""; s["styleRole"]="workspace.card"; s["materialRole"]="workspace.card"; s["bindings"]=.table~new; return s
journey:
  s=.table~new; s["publishVersion"]="1"; s["initialState"]="SEARCH"; states=.array~new
  do sid over .array~of("SEARCH","SUMMARY","TRANSACTION","OPEN","CONFIRM","AUDIT")
    row=.table~new; row["stateId"]=sid; row["ACTIVE"]=.array~of("APP_HEADER","NAVIGATION","SEARCH_PANEL","DETAIL_PANEL","ACTION_PANEL","HISTORY_PANEL","NOTICES"); row["PREFETCH"]=.array~new; row["ON_DEMAND"]=.array~new; states~append(row)
  end
  s["states"]=states; ts=.array~new; prior="SEARCH"
  do next over .array~of("SUMMARY","TRANSACTION","OPEN","CONFIRM","AUDIT")
    t=.table~new; t["fromState"]=prior; t["toState"]=next; t["trigger"]="NEXT"; t["purpose"]="visual checkpoint"; ts~append(t); prior=next
  end
  s["transitions"]=ts; return s
composition:
  use arg stateId
  s=.table~new; s["publishVersion"]="1"; s["journeyId"]="MAIN_FLOW"; s["profile"]="HUMAN_VISUAL"; s["stateId"]=stateId; s["layoutModel"]="GRID12"; rows=.array~new
  call add rows,"APP_HEADER","header",0,12
  select
    when stateId="SEARCH" then do
      call add rows,"NAVIGATION","sidebar",10,3; call add rows,"SEARCH_PANEL","main",20,5; call add rows,"DETAIL_PANEL","main",30,4
    end
    when stateId="SUMMARY" then do
      call add rows,"NAVIGATION","sidebar",10,3; call add rows,"DETAIL_PANEL","main",20,6; call add rows,"NOTICES","secondary",30,3
    end
    when stateId="TRANSACTION" then do
      call add rows,"NAVIGATION","sidebar",10,3; call add rows,"ACTION_PANEL","main",20,6; call add rows,"HISTORY_PANEL","secondary",30,3
    end
    when stateId="OPEN" then do
      call add rows,"NAVIGATION","sidebar",10,3; call add rows,"SEARCH_PANEL","main",20,4; call add rows,"ACTION_PANEL","main",30,5
    end
    when stateId="CONFIRM" then do
      call add rows,"DETAIL_PANEL","main",10,8; call add rows,"NOTICES","secondary",20,4
    end
    otherwise do
      call add rows,"NAVIGATION","sidebar",10,3; call add rows,"HISTORY_PANEL","main",20,9
    end
  end
  call add rows,"NOTICES","footer",90,12
  s["placements"]=rows; return s
add:
  use arg rows,id,region,order,span
  r=.table~new; r["elementId"]=id; r["projectionId"]=""; r["region"]=region; r["order"]=order; r["span"]=span; r["rowSpan"]=1; r["align"]="STRETCH"; r["viewportClass"]="DEFAULT"; rows~append(r); return
put:
  use arg p,verb,id,spec
  payload=.table~new; payload["artifactId"]=id; payload["spec"]=spec
  op=.WireUIDesignOperation~new("visual-"p~revision"-"id,verb,p~revision,.nil,payload,"BUILDER:SELF","visual checkpoint")
  r=p~applyOperation(op); if \r~ok then raise syntax 88.900 array(r~code,r~detail); return
::requires "json.cls"
::requires "WireUIBuilderApplication.cls"
