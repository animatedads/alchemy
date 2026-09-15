call test
say "PASS test_preview_matrix"
exit 0

test:
  b=.WireUIBuilderNeutralFixture~build; w=b["workspace"]
  c=.WireUICompiler~new; cr=c~compile(w,b["release"]); call assert cr~ok,"compile"
  guest=.WireUIPreviewScenario~new("GUEST_DESKTOP","1","guest-1",.false,"HUMAN_VISUAL","QUERY",b["release"]~ref)
  member=.WireUIPreviewScenario~new("MEMBER_DESKTOP","1","member-1",.true,"HUMAN_VISUAL","QUERY",b["release"]~ref)
  matrix=.WireUIPreviewMatrix~new("BUILDER_PREVIEW_MATRIX","1",b["release"]~ref)
  call must matrix~addScenario(guest); call must matrix~addScenario(member); call must matrix~seal
  rr=matrix~execute(c,w,cr~value); call assert rr~ok,"matrix executes"
  gm=rr~value["GUEST_DESKTOP"]; mm=rr~value["MEMBER_DESKTOP"]
  call assert gm["ACTIVEDefinitions"]~items=1,"guest sees public active UI only"
  call assert mm["ACTIVEDefinitions"]~items=2,"authenticated scenario sees account section"
  call assert gm["releaseRef"]["contentAddress"]=mm["releaseRef"]["contentAddress"],"same exact release under both users"
  call assert matrix~ref~contentAddress<>"","matrix sealed/addressed"
  return
must: use arg r; if \r~ok then raise syntax 88.900 array(r~code,r~detail); return
assert: use arg ok,msg; if \ok then raise syntax 88.900 array("ASSERT",msg); return
::requires "WireUIBuilderNeutralFixture.cls"
