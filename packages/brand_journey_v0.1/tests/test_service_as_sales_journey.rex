j=.BrandJourney~new("journey-service","opaque-customer-ref")
t1=.BrandJourneyTouchpoint~new("t1","SUPPORT","E1","CHAT",.nil,"OPEN","UNRESOLVED",.true,.true,.false)
t1~addBrandFunction("PROMOTIONAL_WORK"); t1~addBrandFunction("REPUTATIONAL_WORK"); t1~seal
call assertTrue j~addTouchpoint(t1),"support added"
t2=.BrandJourneyTouchpoint~new("t2","DELIVERY","E2","DELIVERY_UPDATE",.nil,"UNRESOLVED","RESOLVED",.true,.false,.false)
t2~addBrandFunction("PROMOTIONAL_WORK"); t2~seal
call assertTrue j~addTouchpoint(t2),"delivery added"
h=.BrandJourneyHandoff~new("h1","t1","t2","SUPPORT","DELIVERY","CONTEXT_CARRIED",.false,.true,3600); h~seal; call assertTrue j~addHandoff(h),"handoff added"
call assertTrue j~seal~ok,"journey sealed"
r=.BrandJourneyEngine~new~evaluate(j); call assertTrue r~ok,"evaluation"
a=r~value
call assertTrue a~containsFinding("SERVICE_AS_SALES_JOURNEY"),"service/delivery are brand promotional work"
call assertTrue a~containsFinding("CROSS_DOMAIN_CONTINUITY"),"context continuity preserved"
call assertTrue a~containsFinding("SERVICE_RECOVERY_ACROSS_DOMAIN"),"recovery across domain"
call assertEqual 0,a~explicitSalesCount,"no explicit sale"
call assertFalse a~containsFinding("COMMERCIAL_TRANSITION_WHILE_UNRESOLVED"),"brand work does not imply sales proposition"
say "PASS test_service_as_sales_journey"
exit 0
assertTrue: procedure; use arg x,m; if x \== .true then raise syntax 88.900 array(m); return
assertFalse: procedure; use arg x,m; if x \== .false then raise syntax 88.900 array(m); return
assertEqual: procedure; use arg e,a,m; if e \== a then raise syntax 88.900 array(m||" expected="||e||" actual="||a); return
::requires "BrandJourney.cls"
