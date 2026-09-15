call test
say "PASS test_composition_experiment_preview"
exit 0

test:
  p=.WireUIBuilderProject~new("VISUAL.AB","Independent visual A/B composition")
  call draft p,"DESIGN.COMPONENT.DRAFT","CARD",componentSpec()
  call draft p,"DESIGN.ELEMENT.DRAFT","THING",elementSpec()
  call draft p,"DESIGN.PROJECTION.DRAFT","THING_CONTROL",projectionSpec("THING_CONTROL_DEF","control")
  call draft p,"DESIGN.PROJECTION.DRAFT","THING_COMPACT",projectionSpec("THING_COMPACT_DEF","compact")
  call draft p,"DESIGN.JOURNEY.DRAFT","MAIN",journeySpec()
  call draft p,"DESIGN.COMPOSITION.DRAFT","HOME_LAYOUT",compositionSpec()
  call draft p,"DESIGN.EXPERIMENT.DRAFT","THING_LAYOUT",experimentSpec()
  pr=p~publish("VISUAL_AB_SITE","1"); call assert pr~ok,"visual A/B publish"
  pkg=pr~value["package"]; release=pr~value["release"]
  call assert pkg~compositions~items=1,"one semantic composition shared by variants"
  call assert pkg~definitions~items=2,"both variant definitions compiled"
  do d over pkg~definitions
    hints=d["metadata"]["compositionHints"]
    call assert hints~items=1,"each variant inherits semantic element placement"
    call assert hints[1]["placement"]["span"]=8,"composition placement retained"
  end
  sA=.WireUIPreviewScenario~new("A","1","user-a",.false,"HUMAN_VISUAL","HOME",release~ref); sA~assignExperiment("THING_LAYOUT","A"); sA~seal
  sB=.WireUIPreviewScenario~new("B","1","user-b",.false,"HUMAN_VISUAL","HOME",release~ref); sB~assignExperiment("THING_LAYOUT","B"); sB~seal
  c=.WireUICompiler~new
  a=c~previewManifest(p~workspace,pkg,sA); call assert a~ok,"variant A composition preview"
  b=c~previewManifest(p~workspace,pkg,sB); call assert b~ok,"variant B composition preview"
  call assert a~value["compositions"]~items=1 & b~value["compositions"]~items=1,"same composition resolves for both variants"
  da=a~value["ACTIVEDefinitions"][1]; db=b~value["ACTIVEDefinitions"][1]
  call assert da["projectionRef"]["id"]="THING_CONTROL","A keeps control projection"
  call assert db["projectionRef"]["id"]="THING_COMPACT","B keeps compact projection"
  call assert da["metadata"]["compositionHints"][1]["placement"]["region"]="main","A placement remains semantic"
  call assert db["metadata"]["compositionHints"][1]["placement"]["region"]="main","B placement remains semantic"
  return

draft:
  use arg p,verb,id,spec
  payload=.table~new; payload["artifactId"]=id; payload["spec"]=spec
  op=.WireUIDesignOperation~new("op-"p~revision"-"id,verb,p~revision,.nil,payload,"TEST")
  r=p~applyOperation(op); if \r~ok then raise syntax 88.900 array(r~code,r~detail); return
componentSpec: s=.table~new; s["publishVersion"]="1"; s["primitive"]="PANEL"; return s
elementSpec: s=.table~new; s["publishVersion"]="1"; s["semanticType"]="THING"; s["fields"]=.array~of("label"); s["actions"]=.array~new; s["audiencePolicyRef"]="PUBLIC"; return s
projectionSpec:
  use arg def,role
  s=.table~new; s["publishVersion"]="1"; s["profile"]="HUMAN_VISUAL"; s["elementId"]="THING"; s["componentId"]="CARD"; s["definitionId"]=def; s["styleRole"]=role; s["materialRole"]=role; return s
journeySpec:
  s=.table~new; s["publishVersion"]="1"; s["initialState"]="HOME"
  row=.table~new; row["stateId"]="HOME"; row["ACTIVE"]=.array~of("THING"); row["PREFETCH"]=.array~new; row["ON_DEMAND"]=.array~new
  s["states"]=.array~of(row); return s
compositionSpec:
  s=.table~new; s["publishVersion"]="1"; s["journeyId"]="MAIN"; s["profile"]="HUMAN_VISUAL"; s["stateId"]="HOME"; s["layoutModel"]="GRID12"
  p=.table~new; p["elementId"]="THING"; p["projectionId"]=""; p["viewportClass"]="DEFAULT"; p["region"]="main"; p["order"]=10; p["span"]=8; p["rowSpan"]=1; p["align"]="STRETCH"
  s["placements"]=.array~of(p); return s
experimentSpec:
  s=.table~new; s["publishVersion"]="1"; s["targetElementId"]="THING"; s["assignmentUnit"]="USER"
  a=.table~new; a["variantId"]="A"; a["weight"]=50; a["projectionId"]="THING_CONTROL"
  b=.table~new; b["variantId"]="B"; b["weight"]=50; b["projectionId"]="THING_COMPACT"
  s["variants"]=.array~of(a,b); return s
assert: use arg ok,msg; if \ok then raise syntax 88.900 array("ASSERT",msg); return
::requires "WireUIBuilderAll.cls"
