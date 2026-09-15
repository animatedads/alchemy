call test
say "PASS test_builder_visual_workspace"
exit 0

test:
  parse source . . script
  root=filespec("P",script); if root~right(6)="tests/" then root=root~left(root~length-6)
  target=.WireUIBuilderProject~new("VISUAL_TARGET","Consumer-neutral visual target")
  call draft target,"DESIGN.JOURNEY.DRAFT","MAIN_FLOW",journeySpec()
  call draft target,"DESIGN.COMPOSITION.DRAFT","HOME_LAYOUT",compositionSpec("HOME",2)
  call draft target,"DESIGN.COMPOSITION.DRAFT","DETAIL_LAYOUT",compositionSpec("DETAIL",1)
  br=.WireUIBuilderRuntimeFactory~build(target,.nil,"BUILDER-APP","VISUAL-08","BUILDER-WEB",root"/studio/wire_ui_builder_studio_v0.11.json")
  call assert br~ok,"Builder app"
  app=br~value

  library=app~view~instance("artifact-library")["slots"]["items"]
  call assert library~items=3,"library derives target drafts"
  flow=app~view~instance("flow-map")["slots"]["items"]
  call assert flow~items=3,"flow derives journey states"
  call assert flow[1]["stateId"]="HOME" & flow[1]["nextStates"]="DETAIL","flow carries transition target"
  call assert flow[1]["layoutSignature"]<>"","flow carries derived composition thumbnail signature"
  call assert flow[3]["stateId"]="CONFIRM" & flow[3]["nextStates"]="END","terminal flow state explicit"

  d=.directory~new; d["id"]="JOURNEY:MAIN_FLOW"; r=send(app,"artifact-library","ARTIFACT.SELECT",d); call assert r~ok,"library selection via Server UI_ACTION"
  call assert app~view~instance("selection-inspector")["slots"]["kind"]="JOURNEY","inspector follows library selection"

  canvas=app~view~instance("composition-canvas")["slots"]["items"]
  call assert canvas~items=2 & canvas[1]["stateId"]="HOME","initial canvas scoped to initial journey state"
  itemId=canvas[1]["id"]
  d=.directory~new; d["id"]=itemId; d["deltaSpan"]=2; r=send(app,"composition-canvas","DESIGN.COMPOSITION.RESIZE",d); call assert r~ok,"direct resize accepted"
  row=target~draft("COMPOSITION","HOME_LAYOUT")~spec["placements"][1]
  call assert row["span"]=8,"resize changed semantic span"

  d=.directory~new; d["id"]=itemId; d["region"]="sidebar"; r=send(app,"composition-canvas","DESIGN.COMPOSITION.RELOCATE",d); call assert r~ok,"direct relocate accepted"
  row=target~draft("COMPOSITION","HOME_LAYOUT")~spec["placements"][1]
  call assert row["region"]="sidebar","relocate changed semantic region"

  d=.directory~new; d["id"]=itemId; d["align"]="CENTER"; r=send(app,"composition-canvas","DESIGN.COMPOSITION.ALIGN",d); call assert r~ok,"direct align accepted"
  row=target~draft("COMPOSITION","HOME_LAYOUT")~spec["placements"][1]
  call assert row["align"]="CENTER","align changed semantic alignment"

  d=.directory~new; d["id"]="MAIN_FLOW|DETAIL"; r=send(app,"flow-map","FLOW.SELECT",d); call assert r~ok,"flow selection via Server UI_ACTION"
  call assert app~view~instance("selection-inspector")["slots"]["kind"]="JOURNEY_STATE","inspector follows flow state"
  canvas=app~view~instance("composition-canvas")["slots"]["items"]
  call assert canvas~items=1 & canvas[1]["stateId"]="DETAIL","flow selection switches canvas to selected state"

  call assert target~workspace~allArtifacts~items=0,"all visual interaction remains draft until Publish"
  return

draft:
  use arg p,verb,id,spec
  payload=.table~new; payload["artifactId"]=id; payload["spec"]=spec
  op=.WireUIDesignOperation~new("seed-"p~revision"-"id,verb,p~revision,.nil,payload,"TEST")
  r=p~applyOperation(op); if \r~ok then raise syntax 88.900 array(r~code,r~detail); return
journeySpec:
  s=.table~new; s["publishVersion"]="1"; s["initialState"]="HOME"; states=.array~new
  do sid over .array~of("HOME","DETAIL","CONFIRM")
    row=.table~new; row["stateId"]=sid; row["ACTIVE"]=.array~of("A","B"); row["PREFETCH"]=.array~new; row["ON_DEMAND"]=.array~new; states~append(row)
  end
  s["states"]=states; ts=.array~new
  t=.table~new; t["fromState"]="HOME"; t["toState"]="DETAIL"; t["trigger"]="NEXT"; t["purpose"]="detail"; ts~append(t)
  t=.table~new; t["fromState"]="DETAIL"; t["toState"]="CONFIRM"; t["trigger"]="NEXT"; t["purpose"]="confirm"; ts~append(t)
  s["transitions"]=ts; return s
compositionSpec:
  use arg stateId="HOME", elementCount=2
  s=.table~new; s["publishVersion"]="1"; s["journeyId"]="MAIN_FLOW"; s["profile"]="HUMAN_VISUAL"; s["stateId"]=stateId; s["layoutModel"]="GRID12"; rows=.array~new
  names=.array~of("A","B")
  do i=1 to elementCount
    name=names[i]; row=.table~new; row["elementId"]=name; row["projectionId"]=""; row["region"]="main"; row["order"]=rows~items*10+10; row["span"]=6; row["rowSpan"]=1; row["align"]="STRETCH"; row["viewportClass"]="DEFAULT"; rows~append(row)
  end
  s["placements"]=rows; return s
send:
  use arg app,instanceId,action,detail
  f=.directory~new; f["applicationId"]=app~applicationId; f["sessionId"]=app~sessionId; f["accessPointId"]=app~accessPointId; f["viewRef"]=app~view~viewRef; f["elementInstance"]=instanceId; f["action"]=action; f["renderedRevision"]=app~view~revision; f["detail"]=detail
  return app~receive(.WireUIProtocol~message(.WireUIProtocol~UI_ACTION,f))
assert: use arg ok,msg; if \ok then raise syntax 88.900 array("ASSERT",msg); return
::requires "WireUIBuilderApplication.cls"
