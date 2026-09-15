call test
say "PASS test_ab_preview"
exit 0

test:
  w=.WireUIDesignWorkspace~new("ab-preview")
  form=.WireUIVisualComponent~new("FORM","1","FORM")
  e=.WireUISemanticElement~new("SEARCH","1","SEARCH")
  p1=.WireUIProjectionDesign~new("SEARCH_FORM","1","HUMAN_VISUAL",e~ref,form~ref,"SEARCH_FORM")
  p2=.WireUIProjectionDesign~new("SEARCH_FORM","2","HUMAN_VISUAL",e~ref,form~ref,"SEARCH_FORM")
  do x over .array~of(form,e,p1,p2); call must w~register(x); end
  j=.WireUIJourneyDesign~new("J","1","S"); call must j~defineState("S",.array~of("SEARCH")); call must j~seal; call must w~register(j)
  exp=.WireUIExperiment~new("SEARCH_LAYOUT","1","SEARCH"); call must exp~addVariant("A",50,p1~ref); call must exp~addVariant("B",50,p2~ref); call must exp~seal; call must w~register(exp)
  rel=.WireUISiteRelease~new("SITE","1")
  do x over .array~of(form,e,p1,p2,j,exp); call must rel~pin(x~ref); end
  call must rel~seal; call must w~register(rel)
  c=.WireUICompiler~new; cr=c~compile(w,rel); call assert cr~ok,"compile"
  a=.WireUIPreviewScenario~new("A","1","uA",.false,"HUMAN_VISUAL","S",rel~ref); a~assignExperiment("SEARCH_LAYOUT","A")
  b=.WireUIPreviewScenario~new("B","1","uB",.false,"HUMAN_VISUAL","S",rel~ref); b~assignExperiment("SEARCH_LAYOUT","B")
  am=c~previewManifest(w,cr~value,a); bm=c~previewManifest(w,cr~value,b)
  call assert am~ok & bm~ok,"both previews"
  call assert am~value["ACTIVEDefinitions"]~items=1 & bm~value["ACTIVEDefinitions"]~items=1,"one projection per user"
  call assert am~value["ACTIVEDefinitions"][1]["definitionVersion"]="1","A gets v1"
  call assert bm~value["ACTIVEDefinitions"][1]["definitionVersion"]="2","B gets v2"
  call assert am~value["resolvedExperiments"]["SEARCH_LAYOUT"]="A","A recorded"
  call assert bm~value["resolvedExperiments"]["SEARCH_LAYOUT"]="B","B recorded"
  return
must: use arg r; if \r~ok then raise syntax 88.900 array(r~code,r~detail); return
assert: use arg ok,msg; if \ok then raise syntax 88.900 array("ASSERT",msg); return
::requires "WireUIBuilderAll.cls"
