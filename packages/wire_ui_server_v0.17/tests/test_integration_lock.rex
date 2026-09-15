/* Integration-lock acceptance: exact versions + canonical journey/on-demand/profile wire. */
b=.OurLadyAirFixture~build
app=b["app"]; journey=b["journey"]; planner=b["planner"]

/* exact definition versions coexist without implicit latest resolution */
d2=.WireUIElementDefinition~new("OLA_SEARCH_FORM","2","FORM","FLIGHT.SEARCH.SUBMIT")
call must app~registerDefinition(d2), "register v2"
call expect app~definition("OLA_SEARCH_FORM@1") \== .nil, "v1 remains addressable"
call expect app~definition("OLA_SEARCH_FORM@2") \== .nil, "v2 independently addressable"
call expect app~definition("OLA_SEARCH_FORM") == .nil, "bare id has no implicit latest resolution"

/* canonical server-authored plan consumed by JS v0.3.1 */
r=app~journeyPlanMessage
call must r,"journey plan wire"
p=r~value
call expect p["type"]=.WireUIProtocol~UI_JOURNEY_PLAN, "UI_JOURNEY_PLAN emitted"
call expect p["active"][1]["name"]="UI.SEARCH", "active entry canonical"
call expect p["prefetch"]~items=3, "prefetch entries canonical"
call expect p["onDemand"]~items=1 & p["onDemand"][1]["capability"]="INSURANCE_TERMS", "capability distinct from subscription"
call expect p["onDemand"][1]["name"]="UI.INSURANCE.TERMS", "on-demand subscription named"

/* exact plan/revision/capability mapping is required for activation */
m=.table~new
m["type"]=.WireUIProtocol~UI_ON_DEMAND_REQUEST; m["messageId"]="od-1"
m["planId"]=p["planId"]; m["planRevision"]=p["revision"]
m["capability"]="INSURANCE_TERMS"; m["subscription"]="UI.INSURANCE.TERMS"
r=app~receive(m)
call must r,"canonical on-demand"
call expect active(app,"UI.INSURANCE.TERMS"), "canonical on-demand activates exact subscription"

bad=.table~new
bad["type"]=.WireUIProtocol~UI_ON_DEMAND_REQUEST; bad["messageId"]="od-bad"
bad["planId"]=p["planId"]; bad["planRevision"]=p["revision"]
bad["capability"]="INSURANCE_TERMS"; bad["subscription"]="UI.FLIGHT_SELECTION"
r=app~receive(bad)
call expect \r~ok & r~code="ON_DEMAND_SUBSCRIPTION_MISMATCH", "capability cannot redirect to another subscription"

/* profile offer and JS-native detail.profileId are accepted directly. */
r=app~offerInteractionProfile("agentOffer")
call must r,"profile offer"
offer=r~value
out=app~drainOutbound
seen=.false
do x over out
  if x~hasIndex("type") then if x["type"]=.WireUIProtocol~INTERACTION_PROFILE_OFFER then seen=.true
end
call expect seen, "INTERACTION_PROFILE_OFFER emitted"
a=.table~new
a["type"]=.WireUIProtocol~UI_ACTION; a["messageId"]="agent-js-native"
a["applicationId"]=app~applicationId; a["sessionId"]=app~sessionId; a["accessPointId"]=app~accessPointId
a["viewRef"]=app~view~viewRef; a["elementInstance"]="agentOffer"; a["action"]=.WireUIProtocol~INTERACTION_PROFILE_SELECT
a["renderedRevision"]=app~view~revision
detail=.table~new; detail["offerId"]=offer["offerId"]; detail["profileId"]=.WireUIProtocol~PROFILE_AI_AGENT_OPTIMISED
a["detail"]=detail
r=app~receive(a)
call must r,"JS-native profile action"
call expect app~interactionProfile=.WireUIProtocol~PROFILE_AI_AGENT_OPTIMISED, "detail.profileId accepted without adapter flattening"
call expect journey~currentState="AI_SEARCH", "profile selection advances authoritative journey"

say "PASS integration lock exact-version/wire contract"
exit 0

active: procedure
 use arg app,id
 do s over app~activeSubscriptions; if s~subscriptionId=id then return .true; end
 return .false
must: procedure
 use arg r,l
 if \r~ok then do; say "FAIL" l r~code r~detail; exit 1; end
 return
expect: procedure
 use arg c,l
 if \c then do; say "FAIL" l; exit 1; end
 say "ok" l
 return
::requires "OurLadyAirFixture.cls"
