/*
 * Consumer-neutral multi-screen project used by the first-party live Studio
 * launcher. This is target-project data, not Builder architecture.
 */
::class WireUIBuilderLiveWorkspaceFixture public
::method build class
  p=.WireUIBuilderProject~new("VISUAL_WORKSPACE","Neutral multi-screen workspace")
  ignore=self~put(p,"DESIGN.COMPONENT.DRAFT","CARD",self~component("PANEL"))
  ignore=self~put(p,"DESIGN.COMPONENT.DRAFT","FORM",self~component("FORM"))
  ignore=self~put(p,"DESIGN.COMPONENT.DRAFT","LIST",self~component("OFFER_LIST"))
  do id over .array~of("APP_HEADER","NAVIGATION","SEARCH_PANEL","DETAIL_PANEL","ACTION_PANEL","HISTORY_PANEL","NOTICES")
    ignore=self~put(p,"DESIGN.ELEMENT.DRAFT",id,self~element(id))
  end
  ignore=self~put(p,"DESIGN.PROJECTION.DRAFT","APP_HEADER_VIEW",self~projection("APP_HEADER","CARD","PREVIEW_HEADER"))
  ignore=self~put(p,"DESIGN.PROJECTION.DRAFT","NAVIGATION_VIEW",self~projection("NAVIGATION","LIST","PREVIEW_NAV"))
  ignore=self~put(p,"DESIGN.PROJECTION.DRAFT","SEARCH_PANEL_VIEW",self~projection("SEARCH_PANEL","FORM","PREVIEW_SEARCH"))
  ignore=self~put(p,"DESIGN.PROJECTION.DRAFT","DETAIL_PANEL_VIEW",self~projection("DETAIL_PANEL","CARD","PREVIEW_DETAIL"))
  ignore=self~put(p,"DESIGN.PROJECTION.DRAFT","ACTION_PANEL_VIEW",self~projection("ACTION_PANEL","FORM","PREVIEW_ACTION"))
  ignore=self~put(p,"DESIGN.PROJECTION.DRAFT","HISTORY_PANEL_VIEW",self~projection("HISTORY_PANEL","LIST","PREVIEW_HISTORY"))
  ignore=self~put(p,"DESIGN.PROJECTION.DRAFT","NOTICES_VIEW",self~projection("NOTICES","CARD","PREVIEW_NOTICES"))
  ignore=self~put(p,"DESIGN.JOURNEY.DRAFT","MAIN_FLOW",self~journey)
  do sid over .array~of("SEARCH","SUMMARY","TRANSACTION","OPEN","CONFIRM","AUDIT")
    ignore=self~put(p,"DESIGN.COMPOSITION.DRAFT",sid"_LAYOUT",self~composition(sid))
  end
  return p

::method component class
  use arg primitive
  s=.table~new; s["publishVersion"]="1"; s["primitive"]=primitive; return s

::method element class
  use arg id
  s=.table~new; s["publishVersion"]="1"; s["semanticType"]="WORKSPACE_"id; s["fields"]=.array~of("title","summary"); s["actions"]=.array~new; s["audiencePolicyRef"]="PUBLIC"; return s

::method projection class
  use arg elementId,componentId,definitionId
  s=.table~new; s["publishVersion"]="1"; s["profile"]="HUMAN_VISUAL"; s["elementId"]=elementId; s["componentId"]=componentId; s["definitionId"]=definitionId; s["action"]=""; s["styleRole"]="workspace.card"; s["materialRole"]="workspace.card"; s["bindings"]=.table~new; return s

::method journey class
  s=.table~new; s["publishVersion"]="1"; s["initialState"]="SEARCH"; states=.array~new
  do sid over .array~of("SEARCH","SUMMARY","TRANSACTION","OPEN","CONFIRM","AUDIT")
    row=.table~new; row["stateId"]=sid; row["ACTIVE"]=.array~of("APP_HEADER","NAVIGATION","SEARCH_PANEL","DETAIL_PANEL","ACTION_PANEL","HISTORY_PANEL","NOTICES"); row["PREFETCH"]=.array~new; row["ON_DEMAND"]=.array~new; states~append(row)
  end
  s["states"]=states; ts=.array~new; prior="SEARCH"
  do next over .array~of("SUMMARY","TRANSACTION","OPEN","CONFIRM","AUDIT")
    t=.table~new; t["fromState"]=prior; t["toState"]=next; t["trigger"]="NEXT"; t["purpose"]="live Builder workspace"; ts~append(t); prior=next
  end
  s["transitions"]=ts; return s

::method composition class
  use arg stateId
  s=.table~new; s["publishVersion"]="1"; s["journeyId"]="MAIN_FLOW"; s["profile"]="HUMAN_VISUAL"; s["stateId"]=stateId; s["layoutModel"]="GRID12"; rows=.array~new
  ignore=self~add(rows,"APP_HEADER","header",0,12)
  select
    when stateId="SEARCH" then do
      ignore=self~add(rows,"NAVIGATION","sidebar",10,3); ignore=self~add(rows,"SEARCH_PANEL","main",20,5); ignore=self~add(rows,"DETAIL_PANEL","main",30,4)
    end
    when stateId="SUMMARY" then do
      ignore=self~add(rows,"NAVIGATION","sidebar",10,3); ignore=self~add(rows,"DETAIL_PANEL","main",20,6); ignore=self~add(rows,"NOTICES","secondary",30,3)
    end
    when stateId="TRANSACTION" then do
      ignore=self~add(rows,"NAVIGATION","sidebar",10,3); ignore=self~add(rows,"ACTION_PANEL","main",20,6); ignore=self~add(rows,"HISTORY_PANEL","secondary",30,3)
    end
    when stateId="OPEN" then do
      ignore=self~add(rows,"NAVIGATION","sidebar",10,3); ignore=self~add(rows,"SEARCH_PANEL","main",20,4); ignore=self~add(rows,"ACTION_PANEL","main",30,5)
    end
    when stateId="CONFIRM" then do
      ignore=self~add(rows,"DETAIL_PANEL","main",10,8); ignore=self~add(rows,"NOTICES","secondary",20,4)
    end
    otherwise do
      ignore=self~add(rows,"NAVIGATION","sidebar",10,3); ignore=self~add(rows,"HISTORY_PANEL","main",20,9)
    end
  end
  ignore=self~add(rows,"NOTICES","footer",90,12)
  s["placements"]=rows; return s

::method add class
  use arg rows,id,region,order,span
  r=.table~new; r["elementId"]=id; r["projectionId"]=""; r["region"]=region; r["order"]=order; r["span"]=span; r["rowSpan"]=1; r["align"]="STRETCH"; r["viewportClass"]="DEFAULT"; rows~append(r); return .true

::method put class
  use arg p,verb,id,spec
  payload=.table~new; payload["artifactId"]=id; payload["spec"]=spec
  op=.WireUIDesignOperation~new("live-"p~revision"-"id,verb,p~revision,.nil,payload,"BUILDER:SELF","first-party live workspace")
  r=p~applyOperation(op); if \r~ok then raise syntax 88.900 array(r~code,r~detail); return r

::requires "WireUIBuilderAll.cls"
