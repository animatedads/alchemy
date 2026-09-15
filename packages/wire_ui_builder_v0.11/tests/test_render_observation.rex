call test
say "PASS test_render_observation"
exit 0

test:
  b=.WireUIBuilderNeutralFixture~build; w=b["workspace"]
  c=.WireUICompiler~new; cr=c~compile(w,b["release"]); call assert cr~ok,"compile"
  scenario=.WireUIPreviewScenario~new("MEMBER_DESKTOP_B","1","member-b",.true,"HUMAN_VISUAL","QUERY",b["release"]~ref)
  pm=c~previewManifest(w,cr~value,scenario); call assert pm~ok,"preview manifest"
  renderer=.WireUIArtifactRef~new("RENDERER","ALCHEMY_WIRE_UI_JS","0.4-dev1","sha512-renderer-build")
  vp=.table~new; vp["width"]=1440; vp["height"]=900; vp["devicePixelRatio"]=1
  ro=.WireUIRenderObservation~new("render-member-b","1",b["release"]~ref,scenario~ref,renderer,pm~value["manifestContentAddress"],vp)
  search=w~artifact("ELEMENT","SOURCE_QUERY","1"); form=w~artifact("COMPONENT","FORM","1")
  bounds=.table~new; bounds["x"]=118; bounds["y"]=174; bounds["width"]=905; bounds["height"]=398
  eo=.WireUIRenderElementObservation~new("instance-search-1",search~ref,"source-query/current",b["humanSearch"]~ref,form~ref,b["material"]~ref,bounds,.true,.false,.true,.false,"form","Source query")
  call must ro~addElement(eo); call must ro~seal
  rw=ro~asWire
  call assert rw["rendererRef"]["version"]="0.4-dev1","renderer version bound"
  call assert rw["elements"]~items=1,"one observed render instance"
  call assert rw["elements"][1]["semanticRef"]["id"]="SOURCE_QUERY","semantic identity correlated"
  call assert rw["elements"][1]["bounds"]["width"]=905,"measured geometry retained"

  facts=.table~new; facts["primaryActionVisible"]=.true; facts["primaryActionWidth"]=206
  affected=.array~of(search~ref,b["humanSearch"]~ref)
  assessment=.WireUIDesignAssessment~new("assessment-1","1","VISUAL_HIERARCHY","MEDIUM",0.91,"Primary action may be visually weak",ro~ref,facts,affected,.array~of("DESIGN.PROJECTION.SET_MATERIAL"))
  aw=assessment~asWire
  call assert aw["facts"]["primaryActionVisible"]=.true,"measured fact separate"
  call assert aw["finding"]="Primary action may be visually weak","assessment retained separately"

  pp=.table~new; pp["newVersion"]="2"; pp["styleRole"]="search.form.primary"; pp["materialRole"]="search.form.primary"
  op=.WireUIDesignOperation~new("proposal-op","DESIGN.PROJECTION.SET_MATERIAL",0,b["humanSearch"]~ref,pp,"AI:designer","assessment recommendation",.array~of(ro~ref))
  proposal=.WireUIDesignProposal~new("proposal-1","1",assessment~ref,.array~of(op~ref))
  call assert proposal~operationRefs[1]~contentAddress=op~contentAddress,"proposal binds exact operation"
  return
must: use arg r; if \r~ok then raise syntax 88.900 array(r~code,r~detail); return
assert: use arg ok,msg; if \ok then raise syntax 88.900 array("ASSERT",msg); return
::requires "WireUIBuilderNeutralFixture.cls"
