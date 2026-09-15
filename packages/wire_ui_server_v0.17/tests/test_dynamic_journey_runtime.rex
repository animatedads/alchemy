say "WIRE UI DYNAMIC JOURNEY RUNTIME START"

view=.WireUIView~new("V1","root")
rootSlots=.table~new; rootSlots["visible"]=.true
call must view~createInstance("root","ROOT@1",rootSlots)

app=.WireUIApplication~new("APP","S1","AP1",view,.WireUIProjection~new)
rootDef=.WireUIElementDefinition~new("ROOT","1","PANEL")
nextDef=.WireUIElementDefinition~new("NEXT","1","FORM","NEXT.GO")
call must app~registerDefinition(rootDef)
call must app~registerDefinition(nextDef)

sa=.WireUISubscription~new("SA","1","state A"); sa~addDefinition("ROOT@1"); app~addSubscription(sa)
sb=.WireUISubscription~new("SB","1","state B"); sb~addDefinition("NEXT@1"); app~addSubscription(sb)

journey=.WireUIJourneyPlan~new
journey~defineState("A",.array~of("SA"),.array~new,.array~new)
journey~defineState("B",.array~of("SB"),.array~new,.array~new)
journey~allowTransition("A","B","GO","dynamic test")
call must journey~enter("A","START")
planner=.WireUIDefinitionPlanner~new
app~attachJourney(journey,planner)
call must planner~apply(app,journey)

blocked=app~createViewInstance("next","NEXT@1",.table~new,"root")
call assert \blocked~ok,"inactive definition must not instantiate"
call assert blocked~code="DEFINITION_NOT_AUTHORISED_FOR_ACTIVE_PLAN","inactive definition failure code"

ev=.table~new; ev["reason"]="test"
advanced=app~advanceJourney("B","GO",ev); call must advanced
call assert journey~currentState="B","journey entered B"
call assert app~subscription("SA")~active=.false,"old active subscription deactivated"
call assert app~subscription("SB")~active=.true,"new active subscription activated"

before=view~revision
slots=.table~new; slots["visible"]=.true; slots["action"]="NEXT.GO"
created=app~createViewInstance("next","NEXT@1",slots,"root"); call must created
call assert view~revision=before+1,"dynamic instance increments view revision"
call assert view~instance("next")\==.nil,"dynamic instance created"
out=app~drainOutbound
call assert out~items>=2,"journey plan and create patch emitted"
patch=out[out~items]
call assert patch["type"]=.WireUIProtocol~UI_VIEW_PATCH,"last outbound is view patch"
call assert patch["previousRevision"]=before,"patch previous revision"
call assert patch["newRevision"]=before+1,"patch new revision"
op=patch["operations"][1]
call assert op["op"]="CREATE_INSTANCE","create operation"
call assert op["instance"]["definitionKey"]="NEXT@1","exact definition key preserved"

hist=journey~transitionHistory
call assert hist~items=1,"transition evidence recorded"
call assert hist[1]~trigger="GO","transition trigger recorded"

say "WIRE UI DYNAMIC JOURNEY RUNTIME: OK"
exit 0

::routine must
  use arg r,label="operation"
  if \r~ok then do
    say "FAIL" label r~code r~detail
    exit 10
  end
  return r

::routine assert
  use arg condition,label
  if \condition then do
    say "FAIL" label
    exit 11
  end
  return

::requires "WireUIAll.cls"
