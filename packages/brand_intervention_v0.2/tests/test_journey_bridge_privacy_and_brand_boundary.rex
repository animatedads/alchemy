j=.BrandJourney~new('safe-journey','Barbie Example / account 123 / 12 Private Road')
t=.BrandJourneyTouchpoint~new('t1','SUPPORT','BRAND_INTERACTION:EPISODE:E1','CHAT','2026-08-23T10:00:00Z','OPEN','UNRESOLVED',.true,.true,.false); t~addBrandFunction('PROMOTIONAL_WORK'); t~addBrandOpportunity('RETENTION'); t~seal; call assertTrue j~addTouchpoint(t),'add'; call assertTrue j~seal~ok,'journey'
a=.BrandJourneyEngine~new~evaluate(j); call assertTrue a~ok,'assessment'
r=.BrandInterventionJourneyBridge~new~fromJourney('ctx',j,a~value,'FRUSTRATED',80); call assertTrue r~ok,'bridge'; c=r~value
text=c~canonicalText
call assertEqual 0,text~pos('Barbie'),'name absent'; call assertEqual 0,text~pos('Private'),'address absent'; call assertTrue text~pos('PROMOTIONAL_WORK')>0,'brand significance retained'
/* Brand context does not manufacture an explicit sales state. */
call assertFalse c~explicitSalesInProgress,'no sales state from promotional tag'
say 'PASS test_journey_bridge_privacy_and_brand_boundary'
exit 0
assertTrue: procedure; use arg v,l; if \v then do; say 'FAIL:' l; exit 1; end; return
assertFalse: procedure; use arg v,l; if v then do; say 'FAIL:' l; exit 1; end; return
assertEqual: procedure; use arg e,a,l; if e\==a then do; say 'FAIL:' l 'expected='e 'actual='a; exit 1; end; return
::requires 'BrandIntervention.cls'
::requires 'BrandInterventionJourneyBridge.cls'
