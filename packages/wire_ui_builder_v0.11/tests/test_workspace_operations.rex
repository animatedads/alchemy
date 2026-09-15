call test
say "PASS test_workspace_operations"
exit 0

test:
  b=.WireUIBuilderNeutralFixture~build
  w=b["workspace"]
  call assert w~revision=0,"imports do not manufacture authoring revisions"

  offerList=w~artifact("COMPONENT","COLLECTION","1")
  p=.table~new; p["newVersion"]="2"; p["componentRef"]=offerList~ref
  op=.WireUIDesignOperation~new("op-projection-component","DESIGN.PROJECTION.SET_COMPONENT",0,b["humanSearch"]~ref,p,"AI:builder","try card/list presentation")
  r=w~applyOperation(op); call assert r~ok,"projection operation accepted"
  p2=r~value
  call assert w~revision=1,"revision advances once"
  call assert p2~version="2","new projection version derived"
  call assert p2~componentRef~key=offerList~ref~key,"component changed exactly"
  call assert w~artifact("PROJECTION","SOURCE_QUERY_FORM","1")==b["humanSearch"],"predecessor remains immutable/addressable"
  call assert w~artifact("PROJECTION","SOURCE_QUERY_FORM","2")==p2,"derived version registered"
  lin=w~lineageFor(p2~ref); call assert lin<>.nil,"lineage recorded"
  call assert lin~predecessorRef~key=b["humanSearch"]~ref~key,"lineage predecessor exact"
  call assert lin~operationRef~contentAddress=op~ref~contentAddress,"lineage operation exact"

  dup=w~applyOperation(op); call assert dup~ok & dup~code="OPERATION_ALREADY_APPLIED","identical operation idempotent"
  call assert w~revision=1,"duplicate does not advance revision"

  stalePayload=.table~new; stalePayload["newVersion"]="2"; stalePayload["tokenName"]="space.unit"; stalePayload["tokenValue"]="10"
  stale=.WireUIDesignOperation~new("op-stale","DESIGN.MATERIAL.SET_TOKEN",0,b["material"]~ref,stalePayload,"HUMAN:designer")
  sr=w~applyOperation(stale); call assert \sr~ok & sr~code="DESIGN_REVISION_CONFLICT","stale CAS rejected"
  call assert w~revision=1,"stale operation leaves revision unchanged"

  good=.WireUIDesignOperation~new("op-material-token","DESIGN.MATERIAL.SET_TOKEN",1,b["material"]~ref,stalePayload,"HUMAN:designer","increase spacing")
  gr=w~applyOperation(good); call assert gr~ok,"material operation accepted"
  call assert w~revision=2,"second accepted operation advances once"
  mw=gr~value~asWire; call assert mw["tokens"]["space.unit"]="10","material token changed"
  call assert b["material"]~asWire["tokens"]["space.unit"]="8","old material unchanged"

  jpayload=.table~new; jpayload["newVersion"]="2"; jpayload["stateId"]="QUERY"; jpayload["elements"]=.array~of("SOURCE_RESULTS","PRIVATE_PANEL")
  jop=.WireUIDesignOperation~new("op-prefetch","DESIGN.JOURNEY.SET_PREFETCH",2,b["journey"]~ref,jpayload,"AI:builder","prefetch account for authenticated path")
  jr=w~applyOperation(jop); call assert jr~ok,"journey prefetch operation accepted"
  call assert jr~value~state("QUERY")["PREFETCH"]~items=2,"new prefetch list exact"
  call assert b["journey"]~state("QUERY")["PREFETCH"]~items=1,"old journey unchanged"

  account=w~artifact("ELEMENT","PRIVATE_PANEL","1")
  ep=.table~new; ep["newVersion"]="2"; ep["audiencePolicyRef"]="PUBLIC"
  eop=.WireUIDesignOperation~new("op-audience","DESIGN.ELEMENT.SET_AUDIENCE",3,account~ref,ep,"HUMAN:designer","preview policy variant")
  er=w~applyOperation(eop); call assert er~ok,"audience operation accepted"
  call assert er~value~audiencePolicyRef="PUBLIC","new audience exact"
  call assert account~audiencePolicyRef="AUTHENTICATED","old audience unchanged"
  call assert w~revision=4,"four accepted semantic edits"
  return

assert: use arg ok,msg; if \ok then raise syntax 88.900 array("ASSERT",msg); return
::requires "WireUIBuilderNeutralFixture.cls"
