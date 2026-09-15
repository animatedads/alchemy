j=.BrandJourney~new('safe-j','Barbie Example / account 123 / 12 Private Road','CUSTOMER_RELATIONSHIP')
t=.BrandJourneyTouchpoint~new('t1','SUPPORT','EVENT:1','CHAT',.nil,'OPEN','IN_PROGRESS',.true,.true,.false); t~addBrandFunction('PROMOTIONAL_WORK'); t~seal; j~addTouchpoint(t)
t2=.BrandJourneyTouchpoint~new('t2','DELIVERY','EVENT:2','DELIVERY',.nil,'IN_PROGRESS','RESOLVED',.true,.false,.false); t2~addBrandFunction('PROMOTIONAL_WORK'); t2~seal; j~addTouchpoint(t2); j~seal
a=.BrandJourneyEngine~new~evaluate(j); call assertTrue a~ok,'journey evaluates'; assessment=a~value
call assertTrue assessment~containsFinding('SERVICE_AS_SALES_JOURNEY'),'service is brand/promotional work'
r=.BrandJourneyPopulationBridge~fromJourney('o1',j,assessment,'2026-08-23T10:00:00Z','SUPPORT_RESOLUTION','RELATIONSHIP_PRESERVED',60,'JOURNEY-V3','JT1','PROC','MODEL'); call assertTrue r~ok,'bridge builds observation'; o=r~value
text=o~canonicalText
call assertEqual 0,text~pos('Barbie'),'customer identity not copied'
call assertEqual 0,text~pos('Private Road'),'customer address not copied'
call assertFalse o~hasExposure('SERVICE_AS_SALES_JOURNEY'),'brand significance does not become risk/sales exposure'
call assertFalse o~hasExposure('PROMOTIONAL_WORK'),'promotional work does not become action authority'
call assertTrue o~hasModifier('RELATIONSHIP_PRESERVED_ACROSS_TOUCHPOINTS'),'safe journey outcome modifier retained'
say 'PASS test_journey_bridge_privacy_and_sales_boundary'
exit 0
assertTrue: procedure; use arg v,l; if \v then do; say 'FAIL:' l; exit 1; end; return
assertFalse: procedure; use arg v,l; if v then do; say 'FAIL:' l; exit 1; end; return
assertEqual: procedure; use arg e,a,l; if e\==a then do; say 'FAIL:' l 'expected='e 'actual='a; exit 1; end; return
::requires 'BrandJourneyPopulationBridge.cls'
