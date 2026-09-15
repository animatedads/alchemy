call test
say "PASS test_composition_publish"
exit 0

test:
  p=.WireUIBuilderProject~new("COMPOSE.TEST","Composition Test")
  call draft p,"DESIGN.COMPONENT.DRAFT","CARD",componentSpec()
  call draft p,"DESIGN.ELEMENT.DRAFT","THING",elementSpec()
  call draft p,"DESIGN.PROJECTION.DRAFT","THING_VIEW",projectionSpec()
  call draft p,"DESIGN.JOURNEY.DRAFT","MAIN",journeySpec()
  call draft p,"DESIGN.COMPOSITION.DRAFT","HOME_LAYOUT",compositionSpec()
  call assert p~workspace~allArtifacts~items=0,"composition remains a project draft before publish"
  pr=p~publish("COMPOSE_SITE","1"); call assert pr~ok,"composition project published"
  pkg=pr~value["package"]
  call assert pkg~compositions~items=1,"composition compiled"
  c=pkg~compositions[1]
  call assert c["stateId"]="HOME","state preserved"
  call assert c["placements"][1]["span"]=6,"span preserved"
  call assert c["placements"][1]["region"]="main","region preserved"
  call assert pkg~definitions~items=1,"projection compiled"
  md=pkg~definitions[1]["metadata"]
  call assert md~hasIndex("compositionHints"),"definition carries composition hints"
  call assert md["compositionHints"]~items=1,"one composition hint"
  h=md["compositionHints"][1]
  call assert h["placement"]["elementId"]="THING","hint is element centric"
  release=pr~value["release"]
  scenario=.WireUIPreviewScenario~new("P","1","u",.false,"HUMAN_VISUAL","HOME",release~ref); scenario~seal
  preview=.WireUICompiler~new~previewManifest(p~workspace,pkg,scenario)
  call assert preview~ok,"preview compiled"
  call assert preview~value["compositions"]~items=1,"preview carries state composition"
  return

draft:
  use arg p,verb,id,spec
  payload=.table~new; payload["artifactId"]=id; payload["spec"]=spec
  op=.WireUIDesignOperation~new("op-"p~revision"-"id,verb,p~revision,.nil,payload,"TEST")
  r=p~applyOperation(op); if \r~ok then raise syntax 88.900 array(r~code,r~detail); return
componentSpec: s=.table~new; s["publishVersion"]="1"; s["primitive"]="PANEL"; return s
elementSpec: s=.table~new; s["publishVersion"]="1"; s["semanticType"]="THING"; s["fields"]=.array~of("label"); s["actions"]=.array~new; s["audiencePolicyRef"]="PUBLIC"; return s
projectionSpec:
  s=.table~new; s["publishVersion"]="1"; s["profile"]="HUMAN_VISUAL"; s["elementId"]="THING"; s["componentId"]="CARD"; s["definitionId"]="THING_DEF"; s["styleRole"]="thing.card"; return s
journeySpec:
  s=.table~new; s["publishVersion"]="1"; s["initialState"]="HOME"
  row=.table~new; row["stateId"]="HOME"; row["ACTIVE"]=.array~of("THING"); row["PREFETCH"]=.array~new; row["ON_DEMAND"]=.array~new
  s["states"]=.array~of(row); return s
compositionSpec:
  s=.table~new; s["publishVersion"]="1"; s["journeyId"]="MAIN"; s["profile"]="HUMAN_VISUAL"; s["stateId"]="HOME"; s["layoutModel"]="GRID12"
  row=.table~new; row["elementId"]="THING"; row["region"]="main"; row["order"]=10; row["span"]=6; row["rowSpan"]=1; row["align"]="STRETCH"; row["viewportClass"]="DEFAULT"
  s["placements"]=.array~of(row); return s
assert: use arg ok,msg; if \ok then raise syntax 88.900 array("ASSERT",msg); return
::requires "WireUIBuilderAll.cls"
