call addLocalPackage
p=.WireUIBuilderProject~new("COND_RESOURCE","Conditional resource journey")

call put p,"DESIGN.COMPONENT.DRAFT","CARD",component("1","SEMANTIC_RECORD")
call put p,"DESIGN.ELEMENT.DRAFT","BAG_ASSISTANCE",element("1","SERVICE_ASSISTANCE",.array~of("bagStatus"),.array~of("BAG.RECOVERY.OPEN"))

c=.table~new; c["publishVersion"]="1"; c["sourceKind"]="FACT"; c["sourceRef"]="BAG_IRREGULARITY.STATUS"; c["operator"]="EQ"; c["expectedValue"]="LOST"; c["authorityRef"]="FLYLO.BAGGAGE"
call put p,"DESIGN.CONDITION.DRAFT","LOST_BAG",c

pol=.table~new; pol["publishVersion"]="1"; pol["precedence"]=.array~of("URGENT_SERVICE","REQUIRED_ACTION","COMMERCIAL_OPPORTUNITY")
caps=.table~new; caps["attention"]=1; pol["capacities"]=caps
call put p,"DESIGN.PRESENTATION_POLICY.DRAFT","CUSTOMER_ATTENTION",pol

pr=.table~new; pr["publishVersion"]="1"; pr["profile"]="HUMAN_VISUAL"; pr["elementId"]="BAG_ASSISTANCE"; pr["componentId"]="CARD"; pr["definitionId"]="BAG_ASSISTANCE_VIEW"; pr["action"]="BAG.RECOVERY.OPEN"; pr["styleRole"]="service.alert"; pr["materialRole"]="service.alert"; pr["bindings"]=.table~new
rr=.table~new; rr["resourceId"]="FLYLO.BAG.RECOVERY.ALERT"; rr["version"]="4"; rr["contentAddress"]="sha512-fixed-resource-4"; rr["resourceClass"]="GRAPHIC"; rr["locale"]="en-GB"
rb=.table~new; rb["role"]="PRIMARY_CONTENT"; rb["resourceRef"]=rr; rb["required"]=.true
pr["resourceBindings"]=.array~of(rb)
call put p,"DESIGN.PROJECTION.DRAFT","BAG_ASSISTANCE_PROJECTION",pr

j=.table~new; j["publishVersion"]="1"; j["initialState"]="LAST_FLIGHT"; j["initialFlowId"]="MAIN"
flows=.array~new
f=.table~new; f["flowId"]="MAIN"; f["initialState"]="LAST_FLIGHT"; flows~append(f)
f=.table~new; f["flowId"]="BAG_RECOVERY"; f["initialState"]="BAG_STATUS"; flows~append(f)
j["flows"]=flows
states=.array~new
s=.table~new; s["stateId"]="LAST_FLIGHT"; s["flowId"]="MAIN"; s["ACTIVE"]=.array~of("BAG_ASSISTANCE"); s["PREFETCH"]=.array~new; s["ON_DEMAND"]=.array~new; states~append(s)
s=.table~new; s["stateId"]="BAG_STATUS"; s["flowId"]="BAG_RECOVERY"; s["ACTIVE"]=.array~of("BAG_ASSISTANCE"); s["PREFETCH"]=.array~new; s["ON_DEMAND"]=.array~new; states~append(s)
j["states"]=states
trs=.array~new; t=.table~new; t["fromState"]="LAST_FLIGHT"; t["toState"]="BAG_STATUS"; t["trigger"]="BAG.RECOVERY.OPEN"; t["purpose"]="enter baggage recovery flow"; trs~append(t); j["transitions"]=trs
call put p,"DESIGN.JOURNEY.DRAFT","CUSTOMER_JOURNEY",j

co=.table~new; co["publishVersion"]="1"; co["journeyId"]="CUSTOMER_JOURNEY"; co["profile"]="HUMAN_VISUAL"; co["stateId"]="LAST_FLIGHT"; co["layoutModel"]="GRID12"; co["presentationPolicyId"]="CUSTOMER_ATTENTION"
pl=.table~new; pl["elementId"]="BAG_ASSISTANCE"; pl["projectionId"]="BAG_ASSISTANCE_PROJECTION"; pl["region"]="attention"; pl["order"]=10; pl["span"]=12; pl["rowSpan"]=1; pl["align"]="STRETCH"; pl["viewportClass"]="DEFAULT"; pl["whenMode"]="ALL"; pl["whenConditionIds"]=.array~of("LOST_BAG"); pl["suppressConditionIds"]=.array~new; pl["presentationClass"]="URGENT_SERVICE"
co["placements"]=.array~of(pl)
call put p,"DESIGN.COMPOSITION.DRAFT","LAST_FLIGHT_LAYOUT",co

pub=p~publish("COND_RESOURCE_RELEASE","1")
call assert pub~ok,"publish conditional/resource journey"
pkg=pub~value["package"]
call assert pkg~conditions~items=1,"condition compiled"
call assert pkg~presentationPolicies~items=1,"presentation policy compiled"
call assert pkg~journeyPlans[1]["flows"]~items=2,"flows remain part of journey plan"
call assert pkg~journeyPlans[1]["initialFlowId"]="MAIN","initial flow compiled"
call assert pkg~compositions[1]["placements"][1]["whenConditionIds"][1]="LOST_BAG","conditional placement compiled"
call assert pkg~compositions[1]["placements"][1]["whenConditionRefs"][1]["id"]="LOST_BAG","conditional placement exact condition ref compiled"
call assert pkg~compositions[1]["placements"][1]["admissionMode"]="AUTHORITATIVE","conditional placement requires authoritative admission"
call assert pkg~compositions[1]["placements"][1]["unknownConditionPolicy"]="OMIT","unknown condition fails closed"
call assert pkg~compositions[1]["presentationPolicyRef"]["id"]="CUSTOMER_ATTENTION","policy pinned exactly"
plan=pkg~journeyPlans[1]
last=.nil; bag=.nil
do row over plan["states"]
  if row["stateId"]="LAST_FLIGHT" then last=row
  if row["stateId"]="BAG_STATUS" then bag=row
end
call assert last<>.nil,"last-flight state compiled"
call assert last["ACTIVE_ELEMENTS"]~items=0,"conditional-only element removed from ordinary ACTIVE participation"
call assert last["ACTIVE"]~items=0,"conditional-only definition not subscribed by legacy runtime"
call assert last["CONDITIONAL_PARTICIPANTS"]~items=1,"conditional participant compiled separately"
cp=last["CONDITIONAL_PARTICIPANTS"][1]
call assert cp["elementId"]="BAG_ASSISTANCE","conditional participant identity"
call assert cp["sourceTier"]="ACTIVE","candidate source tier preserved"
call assert cp["definitionAdmissionRequired"],"conditional-only definition admission required"
call assert cp["definitionKeys"][1]="BAG_ASSISTANCE_VIEW@1","conditional exact definition key preserved"
call assert cp["whenConditionRefs"][1]["id"]="LOST_BAG","conditional exact ref pinned"
call assert cp["presentationPolicyRef"]["id"]="CUSTOMER_ATTENTION","conditional policy pinned"
call assert cp["unknownConditionPolicy"]="OMIT","legacy/unknown runtime omits participant"
call assert bag<>.nil,"bag-recovery state compiled"
call assert bag["ACTIVE_ELEMENTS"]~items=1,"same element may participate normally in recovery flow"
call assert bag["ACTIVE_ELEMENTS"][1]="BAG_ASSISTANCE","recovery flow ordinary participation retained"
found=.false
do d over pkg~definitions
  if d["definitionId"]="BAG_ASSISTANCE_VIEW" then do
    found=.true
    call assert d["resourceBindings"]~items=1,"resource binding compiled"
    call assert d["resourceBindings"][1]["resourceRef"]["resourceId"]="FLYLO.BAG.RECOVERY.ALERT","resource identity preserved"
    call assert d["resourceBindings"][1]["resourceRef"]["contentAddress"]="sha512-fixed-resource-4","resource content address preserved"
  end
end
call assert found,"resource-bound definition found"

/* There is deliberately no Builder display-copy escape hatch. */
q=.WireUIBuilderProject~new("NO_INLINE","No inline display copy")
bad=element("1","NOTICE",.array~new,.array~new); bad["label"]="Please read these terms and conditions"
payload=.table~new; payload["artifactId"]="BAD"; payload["spec"]=bad
op=.WireUIDesignOperation~new("bad-inline","DESIGN.ELEMENT.DRAFT",0,.nil,payload,"TEST","literal display copy must be rejected")
r=q~applyOperation(op)
call assert \r~ok,"inline display content rejected"
call assert r~code="INLINE_DISPLAY_CONTENT_FORBIDDEN","inline display failure exact"

/* Nor is there an Insert Image/file URL escape hatch. Graphics arrive only as ResourceRef. */
q2=.WireUIBuilderProject~new("NO_INSERT_IMAGE","No insert image")
call put q2,"DESIGN.COMPONENT.DRAFT","CARD",component("1","SEMANTIC_RECORD")
call put q2,"DESIGN.ELEMENT.DRAFT","NOTICE",element("1","NOTICE",.array~new,.array~new)
badProjection=.table~new; badProjection["publishVersion"]="1"; badProjection["profile"]="HUMAN_VISUAL"; badProjection["elementId"]="NOTICE"; badProjection["componentId"]="CARD"; badProjection["definitionId"]="NOTICE_VIEW"; badProjection["bindings"]=.table~new; badProjection["imageUrl"]="/tmp/card.png"
payload=.table~new; payload["artifactId"]="BAD_IMAGE"; payload["spec"]=badProjection
op=.WireUIDesignOperation~new("bad-image","DESIGN.PROJECTION.DRAFT",q2~revision,.nil,payload,"TEST","insert image must be rejected")
r=q2~applyOperation(op)
call assert \r~ok,"insert image field rejected"
call assert r~code="INLINE_DISPLAY_CONTENT_FORBIDDEN","insert image failure exact"

say "PASS test_conditional_resources_flows"
exit 0

component: procedure
  use arg v,primitive; s=.table~new; s["publishVersion"]=v; s["primitive"]=primitive; return s
element: procedure
  use arg v,typ,fields,actions; s=.table~new; s["publishVersion"]=v; s["semanticType"]=typ; s["fields"]=fields; s["actions"]=actions; s["audiencePolicyRef"]="PUBLIC"; return s
put: procedure
  use arg p,verb,id,spec
  payload=.table~new; payload["artifactId"]=id; payload["spec"]=spec
  op=.WireUIDesignOperation~new("op-"p~revision"-"id,verb,p~revision,.nil,payload,"TEST","conditional resource test")
  r=p~applyOperation(op); call assert r~ok,verb" "id" "r~code" "r~detail
  return
assert: procedure
  use arg cond,msg
  if \cond then do; say "FAIL" msg; exit 1; end
  return
addLocalPackage: procedure
  return
::requires "WireUIBuilderAll.cls"
