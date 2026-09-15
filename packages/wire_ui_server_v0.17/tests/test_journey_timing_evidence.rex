/* Factual journey timing evidence: authoritative server events, correlation and no duplicate effects. */
clock=.TestTimingClock~new(.array~of(1000,2000,3000,4000,5000,6000))
view=.WireUIView~new("TIMING.VIEW","root")
root=.table~new; root["visible"]=.true
call must view~createInstance("root","ROOT@1",root)
search=.table~new; search["visible"]=.true; search["action"]="FLIGHT.SEARCH.SUBMIT"
call must view~createInstance("search","SEARCH@1",search,"root")
view~setActionAvailable("search","FLIGHT.SEARCH.SUBMIT",.true)

projection=.WireUIProjection~new
app=.TimingApplication~new("APP-TIME","SESSION-TIME","AP-TIME",view,projection)
call must app~setTimingClock(clock)
call must app~registerDefinition(.WireUIElementDefinition~new("ROOT","1","PANEL"))
call must app~registerDefinition(.WireUIElementDefinition~new("SEARCH","1","FORM","FLIGHT.SEARCH.SUBMIT"))
call must app~registerDefinition(.WireUIElementDefinition~new("OFFERS","1","OFFER_LIST"))
sa=.WireUISubscription~new("UI.SEARCH","1","search"); sa~addDefinition("ROOT@1"); sa~addDefinition("SEARCH@1"); app~addSubscription(sa)
sb=.WireUISubscription~new("UI.OFFERS","1","offers"); sb~addDefinition("OFFERS@1"); app~addSubscription(sb)
journey=.WireUIJourneyPlan~new
journey~defineState("SEARCH",.array~of("UI.SEARCH"),.array~new,.array~new)
journey~defineState("OFFERS",.array~of("UI.OFFERS"),.array~new,.array~new)
journey~allowTransition("SEARCH","OFFERS","FLIGHT.SEARCH.SUBMIT","customer submitted search")
call must journey~enter("SEARCH","INITIAL")
planner=.WireUIDefinitionPlanner~new
app~attachJourney(journey,planner)
call must planner~apply(app,journey)

msg=.table~new
msg["type"]=.WireUIProtocol~UI_ACTION
msg["protocolVersion"]=.WireUIProtocol~VERSION
msg["messageId"]="MSG-SEARCH-1"
msg["applicationId"]="APP-TIME"
msg["sessionId"]="SESSION-TIME"
msg["accessPointId"]="AP-TIME"
msg["viewRef"]="TIMING.VIEW"
msg["elementInstance"]="search"
msg["action"]="FLIGHT.SEARCH.SUBMIT"
msg["renderedRevision"]=view~revision
r=app~receive(msg); call must r
call assert journey~currentState="OFFERS","search advances authoritative journey"

records=app~journeyTimingRecords
call assert records~items=4,"four factual timing records"
call assert records[1]~eventId="SEMANTIC_ACTION_VALIDATED","validated timing first"
call assert records[2]~eventId="OFFERS_AVAILABLE","business-ready milestone second"
call assert records[3]~eventId="JOURNEY_STATE_ENTERED","journey entry third"
call assert records[4]~eventId="SEMANTIC_ACTION_COMPLETED","completion timing last"
call assert records[1]~clockMicros=1000 & records[4]~clockMicros=4000,"injected server clock preserved"
do i=1 to records~items
  call assert records[i]~correlationId="MSG-SEARCH-1","correlation preserved record "i
end
call assert records[1]~journeyState="SEARCH","validation captured prior state"
call assert records[3]~journeyState="OFFERS","journey entry captured new state"
interval=records[4]~elapsedMicrosSince(records[1]); call must interval
call assert interval~value=3000,"factual server handling interval"
wire=records[2]~asWire
call assert wire["source"]="SERVER_AUTHORITATIVE","timing provenance explicit"
call assert wire["detail"]["offerCount"]=3,"server milestone detail retained"
call assert \app~snapshot~hasIndex("journeyTimings"),"timings not silently exposed in UI snapshot"

/* Transport redelivery must not manufacture timing evidence. */
dup=app~receive(msg)
call assert dup~ok & dup~code="DUPLICATE","duplicate action deduplicated"
call assert app~journeyTimingRecords~items=4,"duplicate creates no timing records"

/* Rejected/stale actions are not labelled as validated/completed. */
stale=.table~new
do k over msg~allIndexes; stale[k]=msg[k]; end
stale["messageId"]="MSG-STALE"
stale["renderedRevision"]=view~revision+1
bad=app~receive(stale)
call assert \bad~ok,"stale action rejected"
call assert app~journeyTimingRecords~items=4,"rejected action creates no accepted timing evidence"

drained=app~drainJourneyTimings
call assert drained~items=4,"timing evidence drains explicitly"
call assert app~journeyTimingRecords~items=0,"drain clears server ledger"
say "PASS factual journey timing evidence"
exit 0

::class TimingApplication subclass WireUIApplication public
::method dispatchSemanticAction
  use arg action,message
  if action<>"FLIGHT.SEARCH.SUBMIT" then return .WireUIResult~failure("ACTION_NOT_IMPLEMENTED",action)
  detail=.table~new; detail["offerCount"]=3
  correlation=""; if message~hasIndex("messageId") then correlation=message["messageId"]
  mark=self~recordJourneyTiming("OFFERS_AVAILABLE",correlation,detail)
  if \mark~ok then return mark
  evidence=.table~new; evidence["offerCount"]=3
  advanced=self~advanceJourney("OFFERS","FLIGHT.SEARCH.SUBMIT",evidence,correlation)
  if \advanced~ok then return advanced
  return .WireUIResult~success("OFFERS","SEARCH_COMPLETE")

::class TestTimingClock public
::method init
  expose values index
  use arg values
  index=0
::method nowMicros
  expose values index
  index+=1
  if index>values~items then return values[values~items]
  return values[index]
::method wallStamp
  expose index
  return "TEST-T"index

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
