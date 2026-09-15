/* v0.11: explicit preview condition outcomes drive conditional participation,
   presentation arbitration, and conditional journey edges without making the
   browser or preview scenario an authority for production facts. */
p=.WireUIBuilderProject~new("FLOW_PREVIEW","Conditional fact-flow preview")
call put p,"DESIGN.COMPONENT.DRAFT","CARD",component("1","SEMANTIC_RECORD")
call put p,"DESIGN.ELEMENT.DRAFT","FLIGHT_SUMMARY",element("1","FLIGHT_SUMMARY",.array~of("flightId"),.array~new)
call put p,"DESIGN.ELEMENT.DRAFT","BAG_ASSISTANCE",element("1","SERVICE_ASSISTANCE",.array~of("bagId"),.array~of("BAG.RECOVERY.OPEN"))
call condition p,"LOST_BAG","FACT","BAG_IRREGULARITY.STATUS","EQ","LOST","FLYLO.BAGGAGE"
call projection p,"SUMMARY_P","FLIGHT_SUMMARY","SUMMARY_VIEW",""
call projection p,"BAG_P","BAG_ASSISTANCE","BAG_ASSISTANCE_VIEW","BAG.RECOVERY.OPEN"

j=.table~new; j["publishVersion"]="1"; j["initialState"]="LAST_FLIGHT"; j["initialFlowId"]="MAIN"
f=.table~new; f["flowId"]="MAIN"; f["initialState"]="LAST_FLIGHT"
f2=.table~new; f2["flowId"]="BAG_RECOVERY"; f2["initialState"]="BAG_STATUS"; j["flows"]=.array~of(f,f2)
s=.table~new; s["stateId"]="LAST_FLIGHT"; s["flowId"]="MAIN"; s["ACTIVE"]=.array~of("FLIGHT_SUMMARY","BAG_ASSISTANCE"); s["PREFETCH"]=.array~new; s["ON_DEMAND"]=.array~new
s2=.table~new; s2["stateId"]="BAG_STATUS"; s2["flowId"]="BAG_RECOVERY"; s2["ACTIVE"]=.array~of("BAG_ASSISTANCE"); s2["PREFETCH"]=.array~new; s2["ON_DEMAND"]=.array~new; j["states"]=.array~of(s,s2)
t=.table~new; t["fromState"]="LAST_FLIGHT"; t["toState"]="BAG_STATUS"; t["trigger"]="BAG.RECOVERY.OPEN"; t["purpose"]="enter baggage recovery"; t["whenMode"]="ALL"; t["whenConditionIds"]=.array~of("LOST_BAG"); t["suppressConditionIds"]=.array~new; j["transitions"]=.array~of(t)
call put p,"DESIGN.JOURNEY.DRAFT","CUSTOMER_JOURNEY",j

co=.table~new; co["publishVersion"]="1"; co["journeyId"]="CUSTOMER_JOURNEY"; co["profile"]="HUMAN_VISUAL"; co["stateId"]="LAST_FLIGHT"; co["layoutModel"]="GRID12"
a=.array~new; a~append(place("FLIGHT_SUMMARY","SUMMARY_P",.array~new,"STANDARD",10)); a~append(place("BAG_ASSISTANCE","BAG_P",.array~of("LOST_BAG"),"URGENT_SERVICE",20)); co["placements"]=a
call put p,"DESIGN.COMPOSITION.DRAFT","LAST_FLIGHT_LAYOUT",co
co2=.table~new; co2["publishVersion"]="1"; co2["journeyId"]="CUSTOMER_JOURNEY"; co2["profile"]="HUMAN_VISUAL"; co2["stateId"]="BAG_STATUS"; co2["layoutModel"]="GRID12"; co2["placements"]=.array~of(place("BAG_ASSISTANCE","BAG_P",.array~new,"URGENT_SERVICE",10))
call put p,"DESIGN.COMPOSITION.DRAFT","BAG_STATUS_LAYOUT",co2

pub=p~publish("FLOW_PREVIEW_RELEASE","1"); call must pub,"publish"
pkg=pub~value["package"]
plan=pkg~journeyPlans[1]
call assert plan["conditionalTransitionContract"]="AUTHORITATIVE_ADMISSION_REQUIRED","conditional transition contract"
call assert plan["unknownConditionalTransitionPolicy"]="DENY","unknown transition fails closed"
tr=plan["transitions"][1]
call assert tr["whenConditionRefs"][1]["id"]="LOST_BAG","transition exact condition ref"
call assert tr["admissionMode"]="AUTHORITATIVE","transition authoritative admission"
call assert tr["unknownConditionPolicy"]="DENY","transition unknown denied"

compiler=.WireUICompiler~new
unknown=.WireUIPreviewScenario~new("UNKNOWN","1","PAX",.false,"HUMAN_VISUAL","LAST_FLIGHT",pub~value["release"]~ref); unknown~seal
r=compiler~previewManifest(p~workspace,pkg,unknown); call must r,"unknown preview"; m=r~value
call assert hasDef(m["ACTIVEDefinitions"],"SUMMARY_VIEW"),"unconditional summary remains"
call assert \hasDef(m["ACTIVEDefinitions"],"BAG_ASSISTANCE_VIEW"),"unknown lost-bag fact does not admit assistance"
call assert placementCount(m,"BAG_ASSISTANCE")=0,"unknown condition removes conditional placement"
call assert m["admissibleTransitions"]~items=0,"unknown condition denies recovery edge"
call assert m["transitionDecisions"][1]["previewAdmissionDecision"]="REJECTED_UNKNOWN","unknown edge evidence"

notLost=.WireUIPreviewScenario~new("NOT_LOST","1","PAX",.false,"HUMAN_VISUAL","LAST_FLIGHT",pub~value["release"]~ref); notLost~setConditionOutcome("LOST_BAG","FALSE")~seal
r=compiler~previewManifest(p~workspace,pkg,notLost); call must r,"not lost preview"; m=r~value
call assert \hasDef(m["ACTIVEDefinitions"],"BAG_ASSISTANCE_VIEW"),"false condition does not deliver assistance definition"
call assert m["admissibleTransitions"]~items=0,"false condition denies recovery edge"
call assert m["transitionDecisions"][1]["previewAdmissionDecision"]="REJECTED_CONDITION","false edge evidence"

lost=.WireUIPreviewScenario~new("LOST","1","PAX",.false,"HUMAN_VISUAL","LAST_FLIGHT",pub~value["release"]~ref); lost~setConditionOutcome("LOST_BAG",.true)~seal
r=compiler~previewManifest(p~workspace,pkg,lost); call must r,"lost preview"; m=r~value
call assert hasDef(m["ACTIVEDefinitions"],"BAG_ASSISTANCE_VIEW"),"true condition admits exact assistance definition"
call assert placementCount(m,"BAG_ASSISTANCE")=1,"true condition admits assistance placement"
call assert m["admissibleTransitions"]~items=1,"true condition admits recovery edge"
call assert m["admissibleTransitions"][1]["toState"]="BAG_STATUS","recovery edge target"
call assert m["conditionalAdmissionEvidence"][1]["decision"]="ADMITTED","placement admission evidence"

say "PASS test_conditional_preview_flow"
exit 0

component: procedure
  use arg v,primitive; x=.table~new; x["publishVersion"]=v; x["primitive"]=primitive; return x
element: procedure
  use arg v,typ,fields,actions; x=.table~new; x["publishVersion"]=v; x["semanticType"]=typ; x["fields"]=fields; x["actions"]=actions; x["audiencePolicyRef"]="PUBLIC"; return x
condition: procedure
  use arg p,id,sk,sr,op,expected,auth; x=.table~new; x["publishVersion"]="1"; x["sourceKind"]=sk; x["sourceRef"]=sr; x["operator"]=op; x["expectedValue"]=expected; x["authorityRef"]=auth; call put p,"DESIGN.CONDITION.DRAFT",id,x; return
projection: procedure
  use arg p,id,eid,did,action; x=.table~new; x["publishVersion"]="1"; x["profile"]="HUMAN_VISUAL"; x["elementId"]=eid; x["componentId"]="CARD"; x["definitionId"]=did; x["action"]=action; x["styleRole"]="test"; x["materialRole"]="test"; x["bindings"]=.table~new; call put p,"DESIGN.PROJECTION.DRAFT",id,x; return
place: procedure
  use arg eid,pid,conditions,pclass,order; x=.table~new; x["elementId"]=eid; x["projectionId"]=pid; x["region"]="main"; x["order"]=order; x["span"]=12; x["rowSpan"]=1; x["align"]="STRETCH"; x["viewportClass"]="DEFAULT"; x["whenMode"]="ALL"; x["whenConditionIds"]=conditions; x["suppressConditionIds"]=.array~new; x["presentationClass"]=pclass; return x
placementCount: procedure
  use arg manifest,eid; n=0; do c over manifest["compositions"]; do p over c["placements"]; if p["elementId"]=eid then n+=1; end; end; return n
hasDef: procedure
  use arg defs,did; do d over defs; if d["definitionId"]=did then return .true; end; return .false
put: procedure
  use arg p,verb,id,spec; payload=.table~new; payload["artifactId"]=id; payload["spec"]=spec; op=.WireUIDesignOperation~new("op-"p~revision"-"id,verb,p~revision,.nil,payload,"TEST","conditional preview"); r=p~applyOperation(op); call must r,verb" "id; return
must: procedure
  use arg r,msg; if \r~ok then do; say "FAIL" msg r~code r~detail; exit 1; end; return
assert: procedure
  use arg cond,msg; if \cond then do; say "FAIL" msg; exit 1; end; return
::requires "WireUIBuilderAll.cls"
