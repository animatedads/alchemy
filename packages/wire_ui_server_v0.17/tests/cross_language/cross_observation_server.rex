parse arg mode rest
if mode="" then mode="emit"
b=.OurLadyAirFixture~build
app=b["app"]
obs=.WireUIObservationDefinition~new("CANCEL_FLOW_ENTERED","1","CANCELLATION_JOURNEY_EVIDENCE",.array~of("flowRef","elementInstance","state"),"CLIENT_APPLICATION_ASSERTED")
r=app~registerObservationDefinition(obs); call must r,"register"
sub=.WireUISubscription~new("OBS.CANCEL","3","authorised cancellation-flow factual observations","POLICY.CANCEL.OBS@1")
ignore=sub~addObservation(obs~exactKey)
app~addSubscription(sub)
r=app~activateSubscription("OBS.CANCEL"); call must r,"activate"
out=app~drainOutbound
plan=.nil
do m over out; if m["type"]=.WireUIProtocol~OBSERVATION_PLAN then plan=m; end
if plan==.nil then do; say "FAIL no plan"; exit 3; end

select
  when mode="emit" then do
    say "PLAN" json(plan)
    exit 0
  end
  when mode="accept" then do
    parse var rest subscription revision point purpose strength flowRef elementInstance state
    m=.table~new
    m["type"]=.WireUIProtocol~INTERACTION_OBSERVATION
    m["messageId"]="cross-observation-1"
    m["subscription"]=subscription; m["subscriptionRevision"]=revision; m["point"]=point
    m["purpose"]=purpose; m["evidenceStrength"]=strength
    payload=.table~new; payload["flowRef"]=flowRef; payload["elementInstance"]=elementInstance; payload["state"]=state
    m["observation"]=payload
    r=app~receive(m); call must r,"accept"
    record=r~value
    say "RESULT" r~code record~pointId record~observation["flowRef"] record~observation["state"]
    exit 0
  end
  otherwise do; say "FAIL unknown mode" mode; exit 2; end
end

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
      out ||= quote(k)":"json(value[k]); first=.false
    end
    return out"}"
  end
  if value~isA(.array) then do
    out="["
    do i=1 to value~items; if i>1 then out ||= ","; out ||= json(value[i]); end
    return out"]"
  end
  s=value~string; if datatype(s,"N") then return s
  return quote(s)
quote: procedure
  use arg s
  s=changestr('\\',s,'\\\\'); s=changestr('"',s,'\\"'); s=changestr('0a'x,s,'\\n'); s=changestr('0d'x,s,'\\r')
  return '"'s'"'

::requires "OurLadyAirFixture.cls"
::requires "WireUIObservationDefinition.cls"
