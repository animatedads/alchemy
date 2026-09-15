/* Explicit sales during unresolved service is a finding.  Merely marking the
   interaction promotional is not. */
j=.BrandJourney~new("journey-sales")
t1=.BrandJourneyTouchpoint~new("t1","SUPPORT","E1","CHAT",.nil,"OPEN","UNRESOLVED",.true,.true,.false); t1~addBrandFunction("PROMOTIONAL_WORK"); t1~seal; j~addTouchpoint(t1)
t2=.BrandJourneyTouchpoint~new("t2","SALES","E2","CHAT",.nil,"UNRESOLVED","UNRESOLVED",.true,.true,.true); t2~seal; j~addTouchpoint(t2)
h=.BrandJourneyHandoff~new("h1","t1","t2","SUPPORT","SALES","CONTEXT_CARRIED",.false,.true,60); h~seal; j~addHandoff(h); j~seal
a=.BrandJourneyEngine~new~evaluate(j)~value
call assertTrue a~containsFinding("COMMERCIAL_TRANSITION_WHILE_UNRESOLVED"),"explicit sale during unresolved journey"
call assertEqual 1,a~explicitSalesCount,"one explicit sale"

j2=.BrandJourney~new("journey-no-sale")
x=.BrandJourneyTouchpoint~new("x1","SUPPORT","E3","CHAT",.nil,"OPEN","UNRESOLVED",.true,.true,.false); x~addBrandFunction("PROMOTIONAL_WORK"); x~seal; j2~addTouchpoint(x); j2~seal
a2=.BrandJourneyEngine~new~evaluate(j2)~value
call assertTrue a2~containsFinding("SERVICE_AS_SALES_JOURNEY"),"brand experience remains service as sales"
call assertFalse a2~containsFinding("COMMERCIAL_TRANSITION_WHILE_UNRESOLVED"),"no sales authority invented"
call assertEqual 0,a2~explicitSalesCount,"no explicit sale"
say "PASS test_unresolved_sales_boundary"
exit 0
assertTrue: procedure; use arg x,m; if x \== .true then raise syntax 88.900 array(m); return
assertFalse: procedure; use arg x,m; if x \== .false then raise syntax 88.900 array(m); return
assertEqual: procedure; use arg e,a,m; if e \== a then raise syntax 88.900 array(m||" expected="||e||" actual="||a); return
::requires "BrandJourney.cls"
