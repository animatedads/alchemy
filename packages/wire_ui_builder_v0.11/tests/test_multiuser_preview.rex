call test
say "PASS test_multiuser_preview"
exit 0

test:
  b=.WireUIBuilderNeutralFixture~build
  c=.WireUICompiler~new
  cr=c~compile(b["workspace"],b["release"]); call assert cr~ok,"compile"
  guest=.WireUIPreviewScenario~new("guest","1","guest-1",.false,"HUMAN_VISUAL","QUERY",b["release"]~ref)
  member=.WireUIPreviewScenario~new("member","1","user-42",.true,"HUMAN_VISUAL","QUERY",b["release"]~ref)
  gm=c~previewManifest(b["workspace"],cr~value,guest); mm=c~previewManifest(b["workspace"],cr~value,member)
  call assert gm~ok & mm~ok,"preview manifests"
  call assert gm~value["ACTIVEDefinitions"]~items=1,"guest active view excludes authenticated account"
  call assert mm~value["ACTIVEDefinitions"]~items=2,"member active view includes authenticated account"
  call assert gm~value["PREFETCHDefinitions"]~items=1,"prefetch is represented separately from active view"
  call assert gm~value["subjectId"] \= mm~value["subjectId"],"multi-user isolation explicit"
  call assert gm~value["previewContract"]["requiresRenderedCapture"],"AI preview requires rendered capture"
  return
assert: use arg ok,msg; if \ok then raise syntax 88.900 array("ASSERT",msg); return
::requires "WireUIBuilderNeutralFixture.cls"
