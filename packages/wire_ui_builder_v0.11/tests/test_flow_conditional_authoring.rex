call test
say "PASS test_flow_conditional_authoring"
exit 0

test:
  parse source . . script
  root=filespec("P",script); if root~right(6)="tests/" then root=root~left(root~length-6)
  target=.WireUIBuilderProject~new("FLOW_CONDITIONAL_TARGET","Conditional flow authoring target")
  call put target,"DESIGN.CONDITION.DRAFT","BAG_LOST",conditionSpec()
  call put target,"DESIGN.JOURNEY.DRAFT","TRIP",journeySpec()
  call put target,"DESIGN.COMPOSITION.DRAFT","LAST_FLIGHT_LAYOUT",compositionSpec()

  br=.WireUIBuilderRuntimeFactory~build(target,.nil,"BUILDER-APP","FLOW-COND","BUILDER-WEB",root"/studio/wire_ui_builder_studio_v0.11.json")
  call assert br~ok,"Builder application factory"
  app=br~value

  flow=app~view~instance("flow-map")["slots"]["items"]
  row=findState(flow,"LAST_FLIGHT")
  call assert row<>.nil,"LAST_FLIGHT flow row exists"
  call assert row["branchCount"]=1 & row["conditionalBranchCount"]=1,"conditional branch counts projected"
  call assert pos("BAG.RECOVERY.OPEN ? BAG_LOST",row["branches"])>0,"conditional branch summary projected"
  call assert row["conditionalPlacementCount"]=1,"conditional placement count projected"
  call assert pos("BAG_ASSISTANCE ? BAG_LOST",row["conditionalPlacements"])>0,"conditional placement summary projected"

  call navigate app,"FLOW"
  d=.directory~new; d["id"]="JOURNEY:TRIP"
  r=send(app,"artifact-library","ARTIFACT.SELECT",d); call assert r~ok,"journey selected"
  editor=app~view~instance("journey-editor")["slots"]
  call assert editor["fromState"]="LAST_FLIGHT" & editor["toState"]="BAG_STATUS","conditional edge selected into editor"
  call assert editor["trigger"]="BAG.RECOVERY.OPEN" & editor["transitionWhenConditionIds"]="BAG_LOST","edge condition facts visible"

  d=.directory~new
  do key over .array~of("artifactId","publishVersion","initialState","initialFlowId","flowId","flowInitialState","stateId","active","prefetch","onDemand","fromState","toState","trigger","purpose","transitionWhenMode","transitionWhenConditionIds","transitionSuppressConditionIds")
    d[key]=editor[key]
  end
  d["purpose"]="open baggage recovery facts"
  d["transitionSuppressConditionIds"]="SERVICE_RECOVERY_BLOCKED"
  r=send(app,"journey-editor","DESIGN.JOURNEY.DRAFT",d); call assert r~ok,"conditional edge edited through real UI_ACTION"

  tr=target~draft("JOURNEY","TRIP")~spec["transitions"][1]
  call assert tr["purpose"]="open baggage recovery facts","edge purpose persisted as journey fact"
  call assert tr["whenConditionIds"]~items=1 & tr["whenConditionIds"][1]="BAG_LOST","admission condition preserved"
  call assert tr["suppressConditionIds"]~items=1 & tr["suppressConditionIds"][1]="SERVICE_RECOVERY_BLOCKED","suppression condition persisted"

  flow=app~view~instance("flow-map")["slots"]["items"]
  row=findState(flow,"LAST_FLIGHT")
  call assert pos("suppress:SERVICE_RECOVERY_BLOCKED",row["branches"])>0,"flow map immediately reflects edited suppression fact"
  call assert target~workspace~allArtifacts~items=0,"FLOW editing remains draft-only"
  return

navigate:
  use arg app,state
  d=.directory~new; d["value"]=state
  r=send(app,"tool-nav","STUDIO.NAVIGATE",d); call assert r~ok,"navigate "state
  return

findState:
  use arg items,stateId
  do item over items; if item["stateId"]=stateId then return item; end
  return .nil

conditionSpec:
  s=.table~new; s["publishVersion"]="1"; s["sourceKind"]="FACT"; s["sourceRef"]="BAG.IRREGULARITY.STATUS"; s["operator"]="EQ"; s["expectedValue"]="LOST"; s["authorityRef"]="FLYLO.BAGGAGE"; return s

journeySpec:
  j=.table~new; j["publishVersion"]="1"; j["initialState"]="LAST_FLIGHT"; j["initialFlowId"]="TRIP"
  f1=.table~new; f1["flowId"]="TRIP"; f1["initialState"]="LAST_FLIGHT"
  f2=.table~new; f2["flowId"]="BAG_RECOVERY"; f2["initialState"]="BAG_STATUS"; j["flows"]=.array~of(f1,f2)
  a=.table~new; a["stateId"]="LAST_FLIGHT"; a["flowId"]="TRIP"; a["ACTIVE"]=.array~of("FLIGHT_SUMMARY"); a["PREFETCH"]=.array~new; a["ON_DEMAND"]=.array~new
  b=.table~new; b["stateId"]="BAG_STATUS"; b["flowId"]="BAG_RECOVERY"; b["ACTIVE"]=.array~of("BAG_ASSISTANCE"); b["PREFETCH"]=.array~new; b["ON_DEMAND"]=.array~new; j["states"]=.array~of(a,b)
  t=.table~new; t["fromState"]="LAST_FLIGHT"; t["toState"]="BAG_STATUS"; t["trigger"]="BAG.RECOVERY.OPEN"; t["purpose"]="open baggage recovery"; t["whenMode"]="ALL"; t["whenConditionIds"]=.array~of("BAG_LOST"); t["suppressConditionIds"]=.array~new; j["transitions"]=.array~of(t); return j

compositionSpec:
  s=.table~new; s["publishVersion"]="1"; s["journeyId"]="TRIP"; s["profile"]="HUMAN_VISUAL"; s["stateId"]="LAST_FLIGHT"; s["layoutModel"]="GRID12"
  p=.table~new; p["elementId"]="BAG_ASSISTANCE"; p["projectionId"]=""; p["region"]="service"; p["order"]=10; p["span"]=12; p["rowSpan"]=1; p["align"]="STRETCH"; p["viewportClass"]="DEFAULT"; p["whenMode"]="ALL"; p["whenConditionIds"]=.array~of("BAG_LOST"); p["suppressConditionIds"]=.array~new; p["presentationClass"]="URGENT_SERVICE"
  s["placements"]=.array~of(p); return s

put:
  use arg p,verb,id,spec
  payload=.table~new; payload["artifactId"]=id; payload["spec"]=spec
  op=.WireUIDesignOperation~new("seed-"p~revision"-"id,verb,p~revision,.nil,payload,"TEST")
  r=p~applyOperation(op); if \r~ok then raise syntax 88.900 array(r~code,r~detail); return

send:
  use arg app,instanceId,action,detail
  f=.directory~new; f["applicationId"]=app~applicationId; f["sessionId"]=app~sessionId; f["accessPointId"]=app~accessPointId; f["viewRef"]=app~view~viewRef; f["elementInstance"]=instanceId; f["action"]=action; f["renderedRevision"]=app~view~revision; f["detail"]=detail
  return app~receive(.WireUIProtocol~message(.WireUIProtocol~UI_ACTION,f))

assert: use arg ok,msg; if \ok then raise syntax 88.900 array("ASSERT",msg); return
::requires "WireUIBuilderApplication.cls"
