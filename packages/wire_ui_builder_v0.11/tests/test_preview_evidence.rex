call test
say "PASS test_preview_evidence"
exit 0

test:
  b=.WireUIBuilderNeutralFixture~build
  c=.WireUICompiler~new; cr=c~compile(b["workspace"],b["release"]); call assert cr~ok,"compile"
  s=.WireUIPreviewScenario~new("member","1","u7",.true,"HUMAN_VISUAL","QUERY",b["release"]~ref)
  pm=c~previewManifest(b["workspace"],cr~value,s); call assert pm~ok,"preview"
  viewport=.table~new; viewport["width"]=1440; viewport["height"]=900
  geometry=.table~new; geometry["search"]="120,80,800,360"
  materials=.table~new; materials["search.form"]="observed"
  ev=.WireUIPreviewEvidence~new("capture-1","1",b["release"]~ref,s~ref,pm~value["manifestContentAddress"],"sha256-screenshot-example","sha256-accessibility-example",viewport,geometry,materials)
  vr=ev~verifyBinding(cr~value,s,pm~value)
  call assert vr~ok,"evidence binds exact release/scenario/manifest"
  s2=.WireUIPreviewScenario~new("guest","1","u8",.false,"HUMAN_VISUAL","QUERY",b["release"]~ref)
  call assert \ev~verifyBinding(cr~value,s2,pm~value)~ok,"evidence cannot be reused for another user scenario"
  return
assert: use arg ok,msg; if \ok then raise syntax 88.900 array("ASSERT",msg); return
::requires "WireUIBuilderNeutralFixture.cls"
