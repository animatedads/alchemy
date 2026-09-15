call test
say "PASS test_builder_action_adapter"
exit 0

test:
  b=.WireUIBuilderNeutralFixture~build; w=b["workspace"]
  adapter=.WireUIBuilderActionAdapter~new(w)
  detail=.table~new; detail["operationId"]="wire-action-1"; detail["expectedRevision"]=0; detail["actorRef"]="USER:designer"; detail["reason"]="visual drag/drop"
  detail["targetRef"]=b["humanSearch"]~ref~asWire
  payload=.table~new; payload["newVersion"]="2"; payload["componentRef"]=w~artifact("COMPONENT","COLLECTION","1")~ref~asWire
  detail["payload"]=payload
  r=adapter~apply("DESIGN.PROJECTION.SET_COMPONENT",detail)
  call assert r~ok,"semantic action converted to operation"
  call assert w~revision=1,"same workspace revision semantics"
  call assert r~value~version="2","derived immutable projection"
  op=w~operation("wire-action-1"); call assert op<>.nil,"typed operation recorded"
  call assert op~verb="DESIGN.PROJECTION.SET_COMPONENT","browser and direct API share verb"
  ww=w~asWire; call assert ww["revision"]=1,"workspace wire view reports revision"
  call assert ww["operations"]~items=1 & ww["lineages"]~items=1,"workspace wire view exposes causal history"
  return
assert: use arg ok,msg; if \ok then raise syntax 88.900 array("ASSERT",msg); return
::requires "WireUIBuilderNeutralFixture.cls"
