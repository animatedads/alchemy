/* Support episode -> Delivery episode -> journey, with explicit semantic
   residue but no raw customer data. */
o1=.BrandInteractionObservation~new("o1","e1","AGENT_UTTERANCE","INTERACTION_EVENT:e1","CHAT","OUTBOUND")
o1~addTag("BRAND_FUNCTION/PROMOTIONAL_WORK"); o1~addPurpose("APOLOGY"); o1~seal
e1=.BrandInteractionEpisode~new("ep1"); e1~addObservation(o1); e1~addOpportunity("RETENTION"); e1~seal
r1=.BrandJourneyInteractionBridge~touchpointFromEpisode(e1,"t1","SUPPORT","CHAT",.nil,"OPEN","UNRESOLVED",.true,.true)
call assertTrue r1~ok,"support bridge"
t1=r1~value
call assertFalse t1~explicitSalesProposition,"promotional work is not sales proposition"
call assertTrue t1~hasBrandFunction("PROMOTIONAL_WORK"),"brand function carried"

o2=.BrandInteractionObservation~new("o2","e2","DELIVERY_COMPLETED","INTERACTION_EVENT:e2","DELIVERY","INBOUND")
o2~addTag("BRAND_FUNCTION/REPUTATIONAL_WORK"); o2~seal
e2=.BrandInteractionEpisode~new("ep2"); e2~addObservation(o2); e2~addOpportunity("TRUST_RECOVERY"); e2~seal
r2=.BrandJourneyInteractionBridge~touchpointFromEpisode(e2,"t2","DELIVERY","DELIVERY",.nil,"UNRESOLVED","RESOLVED",.true,.false)
call assertTrue r2~ok,"delivery bridge"
j=.BrandJourney~new("bridge-j"); j~addTouchpoint(t1); j~addTouchpoint(r2~value)
h=.BrandJourneyHandoff~new("h1","t1","t2","SUPPORT","DELIVERY","CONTEXT_CARRIED",.false,.true,600); h~seal; j~addHandoff(h); j~seal
a=.BrandJourneyEngine~new~evaluate(j)~value
call assertTrue a~containsFinding("SERVICE_RECOVERY_ACROSS_DOMAIN"),"cross-domain recovery"
call assertTrue a~containsFinding("SERVICE_AS_SALES_JOURNEY"),"service as sales across journey"
say "PASS test_brand_interaction_bridge"
exit 0
assertTrue: procedure; use arg x,m; if x \== .true then raise syntax 88.900 array(m); return
assertFalse: procedure; use arg x,m; if x \== .false then raise syntax 88.900 array(m); return
::requires "BrandJourneyInteractionBridge.cls"
