call test
say "PASS test_project_experiment_publish"
exit 0

test:
  p=.WireUIBuilderProject~new("AB.TEST","Independent A/B Test")
  call draft p,"DESIGN.COMPONENT.DRAFT","CARD",componentSpec()
  call draft p,"DESIGN.ELEMENT.DRAFT","THING",elementSpec()
  call draft p,"DESIGN.PROJECTION.DRAFT","THING_CONTROL",projectionSpec("THING_CONTROL_DEF","control")
  call draft p,"DESIGN.PROJECTION.DRAFT","THING_COMPACT",projectionSpec("THING_COMPACT_DEF","compact")
  call draft p,"DESIGN.JOURNEY.DRAFT","MAIN",journeySpec()
  call draft p,"DESIGN.EXPERIMENT.DRAFT","THING_LAYOUT",experimentSpec()
  call assert p~workspace~allArtifacts~items=0,"A/B project remains draft before publish"
  pr=p~publish("AB_SITE","1"); call assert pr~ok,"A/B project published"
  out=pr~value; pkg=out["package"]; release=out["release"]
  call assert pkg~experiments~items=1,"experiment compiled"
  call assert pkg~definitions~items=2,"both exact variant projections compiled"
  sA=.WireUIPreviewScenario~new("A","1","user-a",.false,"HUMAN_VISUAL","HOME",release~ref); sA~assignExperiment("THING_LAYOUT","A"); sA~seal
  sB=.WireUIPreviewScenario~new("B","1","user-b",.false,"HUMAN_VISUAL","HOME",release~ref); sB~assignExperiment("THING_LAYOUT","B"); sB~seal
  c=.WireUICompiler~new
  a=c~previewManifest(p~workspace,pkg,sA); call assert a~ok,"variant A preview resolves"
  b=c~previewManifest(p~workspace,pkg,sB); call assert b~ok,"variant B preview resolves"
  da=a~value["ACTIVEDefinitions"][1]; db=b~value["ACTIVEDefinitions"][1]
  call assert da["projectionRef"]["id"]="THING_CONTROL","A picks control projection"
  call assert db["projectionRef"]["id"]="THING_COMPACT","B picks compact projection"
  call assert da["contentAddress"]<>db["contentAddress"],"variants remain exact distinct compiled definitions"
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
experimentSpec:
  s=.table~new; s["publishVersion"]="1"; s["targetElementId"]="THING"; s["assignmentUnit"]="USER"
  a=.table~new; a["variantId"]="A"; a["weight"]=50; a["projectionId"]="THING_CONTROL"
  b=.table~new; b["variantId"]="B"; b["weight"]=50; b["projectionId"]="THING_COMPACT"
  s["variants"]=.array~of(a,b); return s
assert: use arg ok,msg; if \ok then raise syntax 88.900 array("ASSERT",msg); return
::requires "WireUIBuilderAll.cls"
