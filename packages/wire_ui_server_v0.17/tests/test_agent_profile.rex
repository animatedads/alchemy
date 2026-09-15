b=.OurLadyAirFixture~build
app=b["app"]; journey=b["journey"]
r=app~offerInteractionProfile("agentOffer")
call must r,"offer agent profile"
p=app~drainOutbound
call expect p~items=2 & p[1]["operations"][1]["slot"]="visible", "detection offers visible semantic affordance"
call expect p[2]["type"]=.WireUIProtocol~INTERACTION_PROFILE_OFFER & p[2]["profiles"][2]=.WireUIProtocol~PROFILE_AI_AGENT_OPTIMISED, "canonical interaction profile offer emitted"
offerId=p[2]["offerId"]
m=.table~new
m["type"]=.WireUIProtocol~UI_ACTION; m["messageId"]="agent-select-1"; m["applicationId"]=app~applicationId
m["sessionId"]=app~sessionId; m["accessPointId"]=app~accessPointId; m["viewRef"]=app~view~viewRef
m["elementInstance"]="agentOffer"; m["action"]=.WireUIProtocol~INTERACTION_PROFILE_SELECT
detail=.table~new; detail["offerId"]=offerId; detail["profileId"]=.WireUIProtocol~PROFILE_AI_AGENT_OPTIMISED
m["detail"]=detail; m["renderedRevision"]=app~view~revision
r=app~receive(m)
call must r,"profile action"
call expect app~interactionProfile=.WireUIProtocol~PROFILE_AI_AGENT_OPTIMISED, "explicit profile selected"
call expect journey~currentState="AI_SEARCH", "journey switches to machine-semantic projection"
call expect active(app,"UI.AGENT.SEARCH") & active(app,"UI.AGENT.OFFERS"), "agent semantic definitions staged"
call expect \active(app,"UI.FLIGHT_SELECTION"), "human decorative journey definitions released"
defs=app~requiredDefinitions
seenAgent=.false; seenHuman=.false
do d over defs
 if d["definitionId"]="AGENT_OFFER_SET" then seenAgent=.true
 if d["definitionId"]="OLA_FLIGHT_SELECTOR" then seenHuman=.true
end
call expect seenAgent & \seenHuman, "definition projection is agent-optimised"
say "PASS agent profile v0.3"
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
