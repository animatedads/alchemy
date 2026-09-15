/* Banking-style conditional alternatives: do not project an offer the bank has
   already decided is ineligible; admit a different useful path instead. */
p=.WireUIBuilderProject~new("BANK_CONDITIONAL","Conditional offer arbitration")
call put p,"DESIGN.COMPONENT.DRAFT","CARD",component("1","SEMANTIC_RECORD")
call put p,"DESIGN.ELEMENT.DRAFT","CARD_OFFER",element("1","PRODUCT_OPPORTUNITY",.array~of("offerId"),.array~of("CARD.APPLICATION.START"))
call put p,"DESIGN.ELEMENT.DRAFT","SAVINGS_PATH",element("1","FINANCIAL_IMPROVEMENT_PATH",.array~of("planId"),.array~of("SAVINGS.APPLICATION.START"))

call condition p,"CARD_ELIGIBLE","DECISION","BANK.CARD.ELIGIBILITY","EQ","ELIGIBLE","BANK.INTERNAL_SCORING"
call condition p,"CARD_NOT_ELIGIBLE","DECISION","BANK.CARD.ELIGIBILITY","EQ","NOT_ELIGIBLE","BANK.INTERNAL_SCORING"
call condition p,"SERVICE_RESTRICTION","FACT","BANK.SERVICE.RESTRICTION","TRUE",.nil,"BANK.SERVICE_CONTROL"

pol=.table~new; pol["publishVersion"]="1"; pol["precedence"]=.array~of("REQUIRED_ACTION","SERVICE_ADVISORY","COMMERCIAL_OPPORTUNITY")
caps=.table~new; caps["opportunities"]=1; pol["capacities"]=caps
call put p,"DESIGN.PRESENTATION_POLICY.DRAFT","HOME_ATTENTION",pol

call projection p,"CARD_OFFER_PROJECTION","CARD_OFFER","CARD_OFFER_VIEW","BANK.CARD.PREAPPROVED.GOLD","7","sha512-card-gold-7","GRAPHIC","CARD.APPLICATION.START"
call projection p,"SAVINGS_PATH_PROJECTION","SAVINGS_PATH","SAVINGS_PATH_VIEW","BANK.SAVINGS.CREDIT_BUILDING","3","sha512-savings-path-3","COMPOUND","SAVINGS.APPLICATION.START"

j=.table~new; j["publishVersion"]="1"; j["initialState"]="HOME"; j["initialFlowId"]="BANKING"
f=.table~new; f["flowId"]="BANKING"; f["initialState"]="HOME"; j["flows"] = .array~of(f)
s=.table~new; s["stateId"]="HOME"; s["flowId"]="BANKING"; s["ACTIVE"] = .array~of("CARD_OFFER","SAVINGS_PATH"); s["PREFETCH"] = .array~new; s["ON_DEMAND"] = .array~new; j["states"] = .array~of(s); j["transitions"] = .array~new
call put p,"DESIGN.JOURNEY.DRAFT","ONLINE_BANKING",j

co=.table~new; co["publishVersion"]="1"; co["journeyId"]="ONLINE_BANKING"; co["profile"]="HUMAN_VISUAL"; co["stateId"]="HOME"; co["layoutModel"]="GRID12"; co["presentationPolicyId"]="HOME_ATTENTION"
a=.array~new
a~append(placement("CARD_OFFER","CARD_OFFER_PROJECTION","CARD_ELIGIBLE"))
a~append(placement("SAVINGS_PATH","SAVINGS_PATH_PROJECTION","CARD_NOT_ELIGIBLE"))
co["placements"]=a
call put p,"DESIGN.COMPOSITION.DRAFT","HOME_LAYOUT",co

pub=p~publish("BANK_CONDITIONAL_RELEASE","1"); call must pub,"publish"
pkg=pub~value["package"]
row=pkg~journeyPlans[1]["states"][1]
call assert row["ACTIVE_ELEMENTS"]~items=0,"both alternatives are conditional-only, not ordinary active definitions"
call assert row["CONDITIONAL_PARTICIPANTS"]~items=2,"both alternatives compiled as conditional participants"
call assert pkg~presentationPolicies[1]["capacities"]["opportunities"]=1,"one opportunity slot compiled"

card=.nil; savings=.nil
do cp over row["CONDITIONAL_PARTICIPANTS"]
  if cp["elementId"]="CARD_OFFER" then card=cp
  if cp["elementId"]="SAVINGS_PATH" then savings=cp
end
call assert card<>.nil & savings<>.nil,"both conditional alternatives present"
call assert card["whenConditionRefs"][1]["id"]="CARD_ELIGIBLE","card shown only after positive internal decision"
call assert savings["whenConditionRefs"][1]["id"]="CARD_NOT_ELIGIBLE","savings path selected from alternative decision"
call assert card["suppressConditionRefs"][1]["id"]="SERVICE_RESTRICTION","service restriction can suppress commercial offer"
call assert savings["suppressConditionRefs"][1]["id"]="SERVICE_RESTRICTION","service restriction can suppress alternative offer"
call assert card["presentationClass"]="COMMERCIAL_OPPORTUNITY","card presentation class"
call assert card["unknownConditionPolicy"]="OMIT" & savings["unknownConditionPolicy"]="OMIT","unknown decisions never become offers"

cardResource=""; savingsResource=""
do d over pkg~definitions
  if d["definitionId"]="CARD_OFFER_VIEW" then cardResource=d["resourceBindings"][1]["resourceRef"]["resourceId"]
  if d["definitionId"]="SAVINGS_PATH_VIEW" then savingsResource=d["resourceBindings"][1]["resourceRef"]["resourceId"]
end
call assert cardResource="BANK.CARD.PREAPPROVED.GOLD","card content is fixed external resource"
call assert savingsResource="BANK.SAVINGS.CREDIT_BUILDING","savings content is fixed external resource"

/* v0.11 authoring preview evaluates only explicit test outcomes. Production
   authority remains BANK.INTERNAL_SCORING / BANK.SERVICE_CONTROL. */
compiler=.WireUICompiler~new
sc=.WireUIPreviewScenario~new("CARD","1","CUSTOMER",.true,"HUMAN_VISUAL","HOME",pub~value["release"]~ref)
sc~setConditionOutcome("CARD_ELIGIBLE","TRUE")~setConditionOutcome("CARD_NOT_ELIGIBLE","FALSE")~setConditionOutcome("SERVICE_RESTRICTION","FALSE")~seal
r=compiler~previewManifest(p~workspace,pkg,sc); call must r,"card preview"; m=r~value
call assert previewHas(m,"CARD_OFFER"),"eligible card offer participates in preview"
call assert \previewHas(m,"SAVINGS_PATH"),"ineligible savings alternative absent"

sc=.WireUIPreviewScenario~new("SAVINGS","1","CUSTOMER",.true,"HUMAN_VISUAL","HOME",pub~value["release"]~ref)
sc~setConditionOutcome("CARD_ELIGIBLE","FALSE")~setConditionOutcome("CARD_NOT_ELIGIBLE","TRUE")~setConditionOutcome("SERVICE_RESTRICTION","FALSE")~seal
r=compiler~previewManifest(p~workspace,pkg,sc); call must r,"savings preview"; m=r~value
call assert \previewHas(m,"CARD_OFFER"),"ineligible card offer never appears"
call assert previewHas(m,"SAVINGS_PATH"),"eligible savings path participates"

sc=.WireUIPreviewScenario~new("BOTH","1","CUSTOMER",.true,"HUMAN_VISUAL","HOME",pub~value["release"]~ref)
sc~setConditionOutcome("CARD_ELIGIBLE","TRUE")~setConditionOutcome("CARD_NOT_ELIGIBLE","TRUE")~setConditionOutcome("SERVICE_RESTRICTION","FALSE")~seal
r=compiler~previewManifest(p~workspace,pkg,sc); call must r,"capacity preview"; m=r~value
call assert previewCount(m)=1,"presentation capacity arbitrates simultaneously-valid opportunities"

sc=.WireUIPreviewScenario~new("RESTRICTED","1","CUSTOMER",.true,"HUMAN_VISUAL","HOME",pub~value["release"]~ref)
sc~setConditionOutcome("CARD_ELIGIBLE","TRUE")~setConditionOutcome("CARD_NOT_ELIGIBLE","FALSE")~setConditionOutcome("SERVICE_RESTRICTION","TRUE")~seal
r=compiler~previewManifest(p~workspace,pkg,sc); call must r,"restricted preview"; m=r~value
call assert previewCount(m)=0,"service restriction suppresses otherwise-valid commercial opportunity"

say "PASS test_conditional_arbitration_model"
exit 0

previewHas: procedure
  use arg m,eid; do c over m["compositions"]; do p over c["placements"]; if p["elementId"]=eid then return .true; end; end; return .false
previewCount: procedure
  use arg m; n=0; do c over m["compositions"]; n+=c["placements"]~items; end; return n
condition: procedure
  use arg p,id,sourceKind,sourceRef,op,expected,authority
  s=.table~new; s["publishVersion"]="1"; s["sourceKind"]=sourceKind; s["sourceRef"]=sourceRef; s["operator"]=op; if expected<>.nil then s["expectedValue"]=expected; s["authorityRef"]=authority
  call put p,"DESIGN.CONDITION.DRAFT",id,s; return
projection: procedure
  use arg p,id,elementId,definitionId,resourceId,version,address,resourceClass,action
  s=.table~new; s["publishVersion"]="1"; s["profile"]="HUMAN_VISUAL"; s["elementId"]=elementId; s["componentId"]="CARD"; s["definitionId"]=definitionId; s["action"]=action; s["styleRole"]="opportunity"; s["materialRole"]="opportunity"; s["bindings"] = .table~new
  rr=.table~new; rr["resourceId"]=resourceId; rr["version"]=version; rr["contentAddress"]=address; rr["resourceClass"]=resourceClass; rr["locale"]="en-GB"
  rb=.table~new; rb["role"]="PRIMARY_CONTENT"; rb["resourceRef"]=rr; rb["required"] = .true; s["resourceBindings"] = .array~of(rb)
  call put p,"DESIGN.PROJECTION.DRAFT",id,s; return
placement: procedure
  use arg elementId,projectionId,conditionId
  p=.table~new; p["elementId"]=elementId; p["projectionId"]=projectionId; p["region"]="opportunities"; p["order"]=10; p["span"]=12; p["rowSpan"]=1; p["align"]="STRETCH"; p["viewportClass"]="DEFAULT"; p["whenMode"]="ALL"; p["whenConditionIds"] = .array~of(conditionId); p["suppressConditionIds"] = .array~of("SERVICE_RESTRICTION"); p["presentationClass"]="COMMERCIAL_OPPORTUNITY"; return p
component: procedure
  use arg v,primitive; s=.table~new; s["publishVersion"]=v; s["primitive"]=primitive; return s
element: procedure
  use arg v,typ,fields,actions; s=.table~new; s["publishVersion"]=v; s["semanticType"]=typ; s["fields"]=fields; s["actions"]=actions; s["audiencePolicyRef"]="AUTHENTICATED"; return s
put: procedure
  use arg p,verb,id,spec
  payload=.table~new; payload["artifactId"]=id; payload["spec"]=spec
  op=.WireUIDesignOperation~new("op-"p~revision"-"id,verb,p~revision,.nil,payload,"TEST","conditional arbitration")
  r=p~applyOperation(op); call must r,verb" "id; return
must: procedure
  use arg r,msg; if \r~ok then do; say "FAIL" msg r~code r~detail; exit 1; end; return
assert: procedure
  use arg cond,msg; if \cond then do; say "FAIL" msg; exit 1; end; return
::requires "WireUIBuilderAll.cls"
