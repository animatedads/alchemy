b=.OurLadyAirFixture~build
app=b["app"]; journey=b["journey"]; planner=b["planner"]
call expect active(app,"UI.SEARCH"), "search active"
call expect active(app,"UI.FLIGHT_OFFERS") & active(app,"UI.FLIGHT_SELECTION") & active(app,"UI.PASSENGER_DETAILS"), "pages 2-4 prefetched"
call expect \active(app,"UI.INSURANCE.TERMS"), "insurance terms remain on-demand"
r=planner~apply(app,journey)
call must r,"repeat apply"
call expect r~value["activated"]~items=0 & r~value["deactivated"]~items=0, "repeat plan causes no subscription churn"
r=planner~requestOnDemand(app,journey,"INSURANCE_TERMS","UI.INSURANCE.TERMS")
call must r,"on demand request"
call expect active(app,"UI.INSURANCE.TERMS"), "explicit on-demand activation"
call expect r~value["activated"]~items=1, "exactly requested capability activated"
r=journey~enter("FLIGHT_OFFERS","FLIGHT.SEARCH.SUBMIT",.table~new)
call must r,"journey transition"
r=planner~apply(app,journey)
call must r,"offer plan"
call expect \active(app,"UI.SEARCH"), "old search subscription removed differentially"
call expect r~value["deactivated"]~items>=1, "delta reports deactivation"
h=journey~transitionHistory
call expect h~items=1 & h[1]~fromState="SEARCH" & h[1]~toState="FLIGHT_OFFERS", "transition evidence recorded"
say "PASS journey planner v0.3"
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
