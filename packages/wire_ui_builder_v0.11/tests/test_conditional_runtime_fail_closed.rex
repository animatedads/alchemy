/* A WIRE-UI/0.1 Server which does not yet evaluate v0.9 conditional participants
   must fail closed: the conditional-only definition is registered in the sealed
   catalogue for provenance, but is not subscribed/delivered as ACTIVE. */
p=.WireUIBuilderProject~new("COND_RUNTIME","Conditional runtime fail-closed")
call put p,"DESIGN.COMPONENT.DRAFT","CARD",component("1","SEMANTIC_RECORD")
call put p,"DESIGN.ELEMENT.DRAFT","BAG_ASSISTANCE",element("1","SERVICE_ASSISTANCE",.array~of("bagStatus"),.array~of("BAG.RECOVERY.OPEN"))

c=.table~new; c["publishVersion"]="1"; c["sourceKind"]="FACT"; c["sourceRef"]="BAG_IRREGULARITY.STATUS"; c["operator"]="EQ"; c["expectedValue"]="LOST"; c["authorityRef"]="FLYLO.BAGGAGE"
call put p,"DESIGN.CONDITION.DRAFT","LOST_BAG",c
pol=.table~new; pol["publishVersion"]="1"; pol["precedence"]=.array~of("URGENT_SERVICE"); caps=.table~new; caps["attention"]=1; pol["capacities"]=caps
call put p,"DESIGN.PRESENTATION_POLICY.DRAFT","CUSTOMER_ATTENTION",pol

pr=.table~new; pr["publishVersion"]="1"; pr["profile"]="HUMAN_VISUAL"; pr["elementId"]="BAG_ASSISTANCE"; pr["componentId"]="CARD"; pr["definitionId"]="BAG_ASSISTANCE_VIEW"; pr["action"]="BAG.RECOVERY.OPEN"; pr["styleRole"]="service.alert"; pr["materialRole"]="service.alert"; pr["bindings"]=.table~new
rr=.table~new; rr["resourceId"]="FLYLO.BAG.RECOVERY.ALERT"; rr["version"]="4"; rr["contentAddress"]="sha512-fixed-resource-4"; rr["resourceClass"]="GRAPHIC"; rr["locale"]="en-GB"
rb=.table~new; rb["role"]="PRIMARY_CONTENT"; rb["resourceRef"]=rr; rb["required"] = .true; pr["resourceBindings"] = .array~of(rb)
call put p,"DESIGN.PROJECTION.DRAFT","BAG_ASSISTANCE_PROJECTION",pr

j=.table~new; j["publishVersion"]="1"; j["initialState"]="LAST_FLIGHT"; j["initialFlowId"]="MAIN"
f=.table~new; f["flowId"]="MAIN"; f["initialState"]="LAST_FLIGHT"; j["flows"] = .array~of(f)
s=.table~new; s["stateId"]="LAST_FLIGHT"; s["flowId"]="MAIN"; s["ACTIVE"] = .array~of("BAG_ASSISTANCE"); s["PREFETCH"] = .array~new; s["ON_DEMAND"] = .array~new; j["states"] = .array~of(s); j["transitions"] = .array~new
call put p,"DESIGN.JOURNEY.DRAFT","CUSTOMER_JOURNEY",j

co=.table~new; co["publishVersion"]="1"; co["journeyId"]="CUSTOMER_JOURNEY"; co["profile"]="HUMAN_VISUAL"; co["stateId"]="LAST_FLIGHT"; co["layoutModel"]="GRID12"; co["presentationPolicyId"]="CUSTOMER_ATTENTION"
pl=.table~new; pl["elementId"]="BAG_ASSISTANCE"; pl["projectionId"]="BAG_ASSISTANCE_PROJECTION"; pl["region"]="attention"; pl["order"]=10; pl["span"]=12; pl["rowSpan"]=1; pl["align"]="STRETCH"; pl["viewportClass"]="DEFAULT"; pl["whenMode"]="ALL"; pl["whenConditionIds"] = .array~of("LOST_BAG"); pl["suppressConditionIds"] = .array~new; pl["presentationClass"]="URGENT_SERVICE"; co["placements"] = .array~of(pl)
call put p,"DESIGN.COMPOSITION.DRAFT","LAST_FLIGHT_LAYOUT",co

pub=p~publish("COND_RUNTIME_RELEASE","1"); call mustDesign pub,"publish"
pkg=pub~value["package"]
wire=.table~new; wire["releaseRef"]=pkg~releaseRef~asWire; wire["contentAddress"]=pkg~contentAddress; wire["definitions"]=pkg~definitions; wire["journeyPlans"]=pkg~journeyPlans; wire["materials"]=pkg~materials; wire["experiments"]=pkg~experiments
catalogue=.WireUICompiledCatalogue~new(wire)
view=.WireUIView~new("COND.RUNTIME","root"); projection=.WireUIProjection~new
app=.WireUIApplication~new("cond-runtime","sess-cond","ap-cond",view,projection)
r=app~bindCompiledRelease(catalogue,.WireUIProtocol~PROFILE_HUMAN_VISUAL); call mustRuntime r,"bind"

/* Exact definition is retained server-side, but old runtime never subscribes it. */
call assert app~definition("BAG_ASSISTANCE_VIEW@1")<>.nil,"sealed definition registered for provenance"
subscribed=.false
do sub over app~activeSubscriptions
  do key over sub~definitionKeys
    if key="BAG_ASSISTANCE_VIEW@1" then subscribed=.true
  end
end
call assert \subscribed,"conditional-only definition absent from active subscriptions"
jm=app~journeyPlanMessage; call mustRuntime jm,"journey plan"
call assert jm~value["active"]~items=0,"legacy server sees no active subscription for unknown conditional admission"
call assert pkg~journeyPlans[1]["states"][1]["CONDITIONAL_PARTICIPANTS"]~items=1,"new runtime has explicit conditional participant contract available"
call assert pkg~journeyPlans[1]["unknownConditionalRuntimePolicy"]="OMIT","compiled unknown-runtime policy is omit"

/* Browser-authorisation boundary is also fail closed: the definition exists in
   the sealed server catalogue but is absent from the renderer manifest. */
policy=.WireUIRenderProfilePolicy~new("generic")
call mustRuntime policy~registerFingerprint("large.fine.rm0.light.d1.s1.r1","large-fine"),"profile mapping"
call mustRuntime app~setRenderProfilePolicy(policy),"render policy"
hello=.table~new; hello["type"]=.WireUIProtocol~UI_HELLO; hello["messageId"]="cond-hello"; hello["applicationId"]=app~applicationId; hello["sessionId"]=app~sessionId; hello["accessPointId"]=app~accessPointId; hello["capabilityFingerprint"]="large.fine.rm0.light.d1.s1.r1"
caps=.table~new; caps["viewportClass"]="large"; caps["pointer"]="fine"; hello["renderCapabilities"]=caps
call mustRuntime app~receive(hello),"hello"
out=app~drainOutbound; rp=out[1]
call assert rp["definitions"]~items=0,"conditional-only definition absent from browser renderer manifest"
forged=.table~new; forged["type"]=.WireUIProtocol~UI_DEFINITION_REQUIRED; forged["messageId"]="cond-forged"; forged["manifestId"]=rp["manifestId"]; forged["profileId"]="large-fine"
f=.table~new; f["id"]="BAG_ASSISTANCE_VIEW"; f["version"]=1; f["contentAddress"]=app~definition("BAG_ASSISTANCE_VIEW@1")~contentAddress; forged["definitions"]=.array~of(f)
r=app~receive(forged)
call assert \r~ok & r~code="DEFINITION_NOT_AUTHORISED_BY_MANIFEST","browser cannot probe conditional-only definition from catalogue"

say "PASS test_conditional_runtime_fail_closed"
exit 0

component: procedure
  use arg v,primitive; s=.table~new; s["publishVersion"]=v; s["primitive"]=primitive; return s
element: procedure
  use arg v,typ,fields,actions; s=.table~new; s["publishVersion"]=v; s["semanticType"]=typ; s["fields"]=fields; s["actions"]=actions; s["audiencePolicyRef"]="PUBLIC"; return s
put: procedure
  use arg p,verb,id,spec
  payload=.table~new; payload["artifactId"]=id; payload["spec"]=spec
  op=.WireUIDesignOperation~new("op-"p~revision"-"id,verb,p~revision,.nil,payload,"TEST","conditional runtime fail-closed")
  r=p~applyOperation(op); call mustDesign r,verb" "id; return
mustDesign: procedure
  use arg r,msg; if \r~ok then do; say "FAIL" msg r~code r~detail; exit 1; end; return
mustRuntime: procedure
  use arg r,msg; if \r~ok then do; say "FAIL" msg r~code r~detail; exit 1; end; return
assert: procedure
  use arg cond,msg; if \cond then do; say "FAIL" msg; exit 1; end; return
::requires "WireUIBuilderAll.cls"
::requires "WireUIAll.cls"
