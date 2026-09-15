j=.BrandJourney~new("effect-j")
t1=.BrandJourneyTouchpoint~new("t1","SUPPORT","E1","CHAT",.nil,"OPEN","UNRESOLVED",.true,.true,.false); t1~seal; j~addTouchpoint(t1)
t2=.BrandJourneyTouchpoint~new("t2","BILLING","E2","BILLING",.nil,"UNRESOLVED","UNRESOLVED",.true,.true,.false); t2~seal; j~addTouchpoint(t2)
h=.BrandJourneyHandoff~new("h1","t1","t2","SUPPORT","BILLING","CONTEXT_LOST",.true,.true,90); h~seal; j~addHandoff(h); j~seal
a=.BrandJourneyEngine~new~evaluate(j)~value
fs=.BrandJourneyEffectBridge~findingsFromAssessment(a)
call assertTrue fs~items>0,"effect findings produced"
found=.false
do f over fs
  if f~code="CROSS_DOMAIN_CONTEXT_LOSS" then do
    found=.true
    call assertEqual "CONCERN",f~polarity,"context loss polarity"
  end
end
call assertTrue found,"context loss finding bridged"
say "PASS test_effect_bridge"
exit 0
assertTrue: procedure; use arg x,m; if x \== .true then raise syntax 88.900 array(m); return
assertEqual: procedure; use arg e,a,m; if e \== a then raise syntax 88.900 array(m||" expected="||e||" actual="||a); return
::requires "BrandJourneyEffectBridge.cls"
