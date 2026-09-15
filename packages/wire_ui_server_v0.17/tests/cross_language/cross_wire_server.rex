/* Cross-process fixture endpoint for JS v0.3.1 integration acceptance. */
parse arg mode rest
if mode="" then mode="emit"
b=.OurLadyAirFixture~build
app=b["app"]; journey=b["journey"]; planner=b["planner"]

select
  when mode="emit" then do
    r=app~journeyPlanMessage; call must r,"plan"
    say "PLAN" json(r~value)
    r=app~offerInteractionProfile("agentOffer"); call must r,"offer"
    say "OFFER" json(r~value)
    exit 0
  end
  when mode="ondemand" then do
    parse var rest planId planRevision capability subscription
    m=.table~new; m["type"]=.WireUIProtocol~UI_ON_DEMAND_REQUEST; m["messageId"]="cross-od"
    m["planId"]=planId; m["planRevision"]=planRevision; m["capability"]=capability; m["subscription"]=subscription
    r=app~receive(m); call must r,"ondemand"
    say "RESULT" r~code active(app,subscription)
    exit 0
  end
  when mode="profile" then do
    parse var rest offerId profileId renderedRevision
    r=app~offerInteractionProfile("agentOffer"); call must r,"offer"
    offer=r~value
    if offer["offerId"]\=offerId then do; say "FAIL offer id mismatch" offer["offerId"] offerId; exit 3; end
    m=.table~new; m["type"]=.WireUIProtocol~UI_ACTION; m["messageId"]="cross-profile"
    m["applicationId"]=app~applicationId; m["sessionId"]=app~sessionId; m["accessPointId"]=app~accessPointId
    m["viewRef"]=app~view~viewRef; m["elementInstance"]="agentOffer"; m["action"]=.WireUIProtocol~INTERACTION_PROFILE_SELECT
    m["renderedRevision"]=renderedRevision
    detail=.table~new; detail["offerId"]=offerId; detail["profileId"]=profileId; m["detail"]=detail
    r=app~receive(m); call must r,"profile"
    say "RESULT" app~interactionProfile journey~currentState
    defs=app~requiredDefinitions
    do d over defs
      if d["definitionId"]="AGENT_SEARCH_STATE" | d["definitionId"]="AGENT_OFFER_SET" then say "DEF" json(d)
    end
    exit 0
  end
  otherwise do
    say "FAIL unknown mode" mode
    exit 2
  end
end

active: procedure
 use arg app,id
 do s over app~activeSubscriptions; if s~subscriptionId=id then return 1; end
 return 0

must: procedure
 use arg r,l
 if \r~ok then do; say "FAIL" l r~code r~detail; exit 4; end
 return

json: procedure
  use arg value
  if value==.nil then return "null"
  if value~isA(.string) then do
    s=value~string
    if datatype(s,"N") then return s
  end
  if value==.true then return "true"
  if value==.false then return "false"
  if value~isA(.table) | value~isA(.directory) then do
    keys=value~allIndexes; keys~sort
    out="{"; first=.true
    do k over keys
      if \first then out ||= ","
      out ||= quote(k)":"json(value[k])
      first=.false
    end
    return out"}"
  end
  if value~isA(.array) then do
    out="["
    do i=1 to value~items
      if i>1 then out ||= ","
      out ||= json(value[i])
    end
    return out"]"
  end
  s=value~string
  if datatype(s,"N") then return s
  return quote(s)

quote: procedure
  use arg s
  s=changestr('\\',s,'\\\\')
  s=changestr('"',s,'\\"')
  s=changestr('0a'x,s,'\\n')
  s=changestr('0d'x,s,'\\r')
  return '"'s'"'

::requires "OurLadyAirFixture.cls"
