call test
say "PASS test_element_experiment"
exit 0

test:
  w=.WireUIDesignWorkspace~new("ab")
  slots=.table~new; slots["q"]="TEXT"
  form=.WireUIVisualComponent~new("FORM","1","FORM",slots)
  e=.WireUISemanticElement~new("SEARCH","1","SEARCH",.array~of("q"))
  p1=.WireUIProjectionDesign~new("SEARCH_FORM","1","HUMAN_VISUAL",e~ref,form~ref,"SEARCH_FORM")
  p2=.WireUIProjectionDesign~new("SEARCH_FORM","2","HUMAN_VISUAL",e~ref,form~ref,"SEARCH_FORM")
  do x over .array~of(form,e,p1,p2); call must w~register(x); end
  exp=.WireUIExperiment~new("SEARCH_LAYOUT","1","SEARCH","USER")
  call must exp~addVariant("A",50,p1~ref)
  call must exp~addVariant("B",50,p2~ref)
  call must exp~seal
  call must w~register(exp)
  call assert exp~assign("user-17")~value["variantId"] = exp~assign("user-17")~value["variantId"],"deterministic assignment"
  call assert p1~definitionId=p2~definitionId,"stable definition identity"
  call assert p1~version \= p2~version,"variant changes exact version"
  return
must: use arg r; if \r~ok then raise syntax 88.900 array(r~code,r~detail); return
assert: use arg ok,msg; if \ok then raise syntax 88.900 array("ASSERT",msg); return
::requires "WireUIBuilderAll.cls"
