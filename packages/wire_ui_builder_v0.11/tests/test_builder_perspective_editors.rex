call test
say "PASS test_builder_perspective_editors"
exit 0

test:
  parse source . . script
  root=filespec("P",script); if root~right(6)="tests/" then root=root~left(root~length-6)
  target=.WireUIBuilderProject~new("PERSPECTIVE_TARGET","Perspective target")
  call put target,"DESIGN.COMPONENT.DRAFT","CARD",componentSpec()
  call put target,"DESIGN.ELEMENT.DRAFT","OFFER",elementSpec()
  call put target,"DESIGN.PROJECTION.DRAFT","OFFER_VIEW",projectionSpec()
  call put target,"DESIGN.MATERIAL.DRAFT","BASE_MATERIAL",materialSpec()
  call put target,"DESIGN.CONDITION.DRAFT","ELIGIBLE",conditionSpec()
  call put target,"DESIGN.JOURNEY.DRAFT","MAIN",journeySpec()

  br=.WireUIBuilderRuntimeFactory~build(target,.nil,"BUILDER-APP","PERSPECTIVES","BUILDER-WEB",root"/studio/wire_ui_builder_studio_v0.11.json")
  call assert br~ok,"Builder application factory"
  app=br~value

  call navigate app,"COMPONENTS"
  items=app~view~instance("artifact-library")["slots"]["items"]
  call assert items~items=3,"COMPONENTS catalogue contains only component/element/projection facts"
  call assert hasKind(items,"COMPONENT") & hasKind(items,"ELEMENT") & hasKind(items,"PROJECTION"),"COMPONENTS catalogue kinds exact"
  d=.directory~new; d["id"]="COMPONENT:CARD"
  r=send(app,"artifact-library","ARTIFACT.SELECT",d); call assert r~ok,"component selected"
  ed=app~view~instance("component-editor")["slots"]
  call assert ed["artifactId"]="CARD" & ed["primitive"]="SEMANTIC_RECORD","component editor populated from selected fact"

  d=.directory~new; d["id"]="PROJECTION:OFFER_VIEW"
  r=send(app,"artifact-library","ARTIFACT.SELECT",d); call assert r~ok,"projection selected"
  ed=app~view~instance("projection-editor")["slots"]
  call assert ed["artifactId"]="OFFER_VIEW" & ed["elementId"]="OFFER" & ed["componentId"]="CARD","projection editor populated from selected fact"
  call assert ed["resourceId"]="BANK.CARD.PREAPPROVED.GOLD" & ed["resourceVersion"]="7","projection exposes resource reference, not resource content"

  call navigate app,"MATERIALS"
  items=app~view~instance("artifact-library")["slots"]["items"]
  call assert items~items=1 & items[1]["kind"]="MATERIAL","MATERIALS catalogue is material-only"
  d=.directory~new; d["id"]="MATERIAL:BASE_MATERIAL"; r=send(app,"artifact-library","ARTIFACT.SELECT",d); call assert r~ok,"material selected"
  ed=app~view~instance("material-editor")["slots"]
  call assert ed["artifactId"]="BASE_MATERIAL" & ed["tokenName"]="space.unit" & ed["tokenValue"]="8","material editor populated"

  call navigate app,"FLOW"
  items=app~view~instance("artifact-library")["slots"]["items"]
  call assert items~items=2 & hasKind(items,"CONDITION") & hasKind(items,"JOURNEY"),"FLOW catalogue contains journey and conditional facts"
  d=.directory~new; d["id"]="CONDITION:ELIGIBLE"; r=send(app,"artifact-library","ARTIFACT.SELECT",d); call assert r~ok,"condition selected"
  ed=app~view~instance("condition-editor")["slots"]
  call assert ed["artifactId"]="ELIGIBLE" & ed["sourceRef"]="BANK.CARD.ELIGIBILITY" & ed["expectedValue"]="ELIGIBLE","condition editor populated from selected fact"

  d=.directory~new; d["id"]="JOURNEY:MAIN"; r=send(app,"artifact-library","ARTIFACT.SELECT",d); call assert r~ok,"journey selected"
  ed=app~view~instance("journey-editor")["slots"]
  call assert ed["fromState"]="HOME" & ed["toState"]="CARD" & ed["trigger"]="CARD.OFFER.OPEN","journey editor exposes semantic transition"
  call assert ed["transitionWhenConditionIds"]="ELIGIBLE" & ed["transitionWhenMode"]="ALL","journey editor exposes conditional edge facts"

  call navigate app,"PUBLISH"
  items=app~view~instance("artifact-library")["slots"]["items"]
  call assert items~items=6,"PUBLISH catalogue sees complete draft set for release review"
  call assert target~workspace~allArtifacts~items=0,"perspective navigation and selection do not publish drafts"
  return

navigate:
  use arg app,state
  d=.directory~new; d["value"]=state
  r=send(app,"tool-nav","STUDIO.NAVIGATE",d); call assert r~ok,"navigate "state
  return

hasKind:
  use arg items,kind
  do item over items; if item["kind"]=kind then return .true; end
  return .false

componentSpec:
  s=.table~new; s["publishVersion"]="1"; s["primitive"]="SEMANTIC_RECORD"; return s
elementSpec:
  s=.table~new; s["publishVersion"]="1"; s["semanticType"]="OFFER"; s["fields"]=.array~of("offerId"); s["actions"]=.array~of("OFFER.OPEN"); s["audiencePolicyRef"]="PUBLIC"; return s
projectionSpec:
  s=.table~new; s["publishVersion"]="1"; s["profile"]="HUMAN_VISUAL"; s["elementId"]="OFFER"; s["componentId"]="CARD"; s["definitionId"]="OFFER_VIEW"; s["action"]="OFFER.OPEN"; s["styleRole"]="offer"; s["materialRole"]="offer"; s["bindings"]=.table~new
  rr=.table~new; rr["resourceId"]="BANK.CARD.PREAPPROVED.GOLD"; rr["version"]="7"; rr["contentAddress"]="sha512-resource-gold-7"; rr["resourceClass"]="GRAPHIC"; rr["locale"]="en-GB"
  rb=.table~new; rb["role"]="PRIMARY_CONTENT"; rb["resourceRef"]=rr; rb["required"]=.true; s["resourceBindings"]=.array~of(rb); return s
materialSpec:
  s=.table~new; s["publishVersion"]="1"; tokens=.table~new; tokens["space.unit"]="8"; s["tokens"]=tokens; s["recipes"]=.table~new; return s
conditionSpec:
  s=.table~new; s["publishVersion"]="1"; s["sourceKind"]="DECISION"; s["sourceRef"]="BANK.CARD.ELIGIBILITY"; s["operator"]="EQ"; s["expectedValue"]="ELIGIBLE"; s["authorityRef"]="BANK.INTERNAL.SCORING"; return s
journeySpec:
  j=.table~new; j["publishVersion"]="1"; j["initialState"]="HOME"; j["initialFlowId"]="BANKING"
  f=.table~new; f["flowId"]="BANKING"; f["initialState"]="HOME"; j["flows"]=.array~of(f)
  a=.table~new; a["stateId"]="HOME"; a["flowId"]="BANKING"; a["ACTIVE"]=.array~new; a["PREFETCH"]=.array~new; a["ON_DEMAND"]=.array~new
  b=.table~new; b["stateId"]="CARD"; b["flowId"]="BANKING"; b["ACTIVE"]=.array~new; b["PREFETCH"]=.array~new; b["ON_DEMAND"]=.array~new; j["states"]=.array~of(a,b)
  t=.table~new; t["fromState"]="HOME"; t["toState"]="CARD"; t["trigger"]="CARD.OFFER.OPEN"; t["purpose"]="open eligible card path"; t["whenMode"]="ALL"; t["whenConditionIds"]=.array~of("ELIGIBLE"); t["suppressConditionIds"]=.array~new; j["transitions"]=.array~of(t); return j

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
