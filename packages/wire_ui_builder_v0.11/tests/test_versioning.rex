call test
say "PASS test_versioning"
exit 0

test:
  w=.WireUIDesignWorkspace~new("vtest")
  e1=.WireUISemanticElement~new("SEARCH","1","SEARCH")
  e2=.WireUISemanticElement~new("SEARCH","2","SEARCH",.array~of("origin"))
  call must w~register(e1)
  call must w~register(e2)
  call assert e1~ref~key="ELEMENT:SEARCH@1","v1 exact key"
  call assert e2~ref~key="ELEMENT:SEARCH@2","v2 exact key"
  call assert e1~contentAddress \= e2~contentAddress,"version content differs"
  call assert w~artifact("ELEMENT","SEARCH","1") == e1,"v1 coexists"
  call assert w~artifact("ELEMENT","SEARCH","2") == e2,"v2 coexists"
  return
must: use arg r; if \r~ok then raise syntax 88.900 array(r~code,r~detail); return
assert: use arg ok,msg; if \ok then raise syntax 88.900 array("ASSERT",msg); return
::requires "WireUIBuilderAll.cls"
