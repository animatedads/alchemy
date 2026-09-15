j=.BrandJourney~new("journey-loss","private-account-123")
t1=.BrandJourneyTouchpoint~new("t1","SUPPORT","E1","CHAT",.nil,"OPEN","UNRESOLVED",.true,.true,.false); t1~seal; j~addTouchpoint(t1)
t2=.BrandJourneyTouchpoint~new("t2","BILLING","E2","BILLING",.nil,"UNRESOLVED","UNRESOLVED",.true,.true,.false); t2~seal; j~addTouchpoint(t2)
h=.BrandJourneyHandoff~new("h1","t1","t2","SUPPORT","BILLING","CONTEXT_LOST",.true,.true,120); h~seal; j~addHandoff(h)
j~seal
r=.BrandJourneyEngine~new~evaluate(j); a=r~value
call assertTrue a~containsFinding("CROSS_DOMAIN_CONTEXT_LOSS"),"context loss finding"
call assertTrue a~containsFinding("CUSTOMER_REPEAT_BURDEN"),"repeat burden finding"
call assertTrue a~containsFinding("UNRESOLVED_STATE_CARRIED"),"unresolved carry finding"
call assertEqual 1,a~contextLossCount,"context loss count"
call assertEqual 1,a~repeatBurdenCount,"repeat burden count"
say "PASS test_context_loss_repeat_burden"
exit 0
assertTrue: procedure; use arg x,m; if x \== .true then raise syntax 88.900 array(m); return
assertEqual: procedure; use arg e,a,m; if e \== a then raise syntax 88.900 array(m||" expected="||e||" actual="||a); return
::requires "BrandJourney.cls"
