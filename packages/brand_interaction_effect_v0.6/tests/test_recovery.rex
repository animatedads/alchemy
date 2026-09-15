f=.BrandInteractionObservation~new('f1','f1','SERVICE_FAILURE','INTERACTION_EVENT:f1','DELIVERY','INBOUND'); f~seal
c=.BrandInteractionObservation~new('c1','c1','CUSTOMER_UTTERANCE','INTERACTION_EVENT:c1','CHAT','INBOUND'); c~putAssessment('CUSTOMER_SENTIMENT','ANGRY'); c~seal
r=.BrandInteractionObservation~new('r1','r1','AGENT_UTTERANCE','INTERACTION_EVENT:r1','CHAT','OUTBOUND'); r~addPurpose('APOLOGY'); r~addPurpose('SERVICE_RESOLUTION'); r~addTag('BRAND_OPPORTUNITY/RECOVERY'); r~seal
ep=.BrandInteractionEpisode~new('recovery'); ep~addObservation(f); ep~addObservation(c); ep~addObservation(r); call assertTrue ep~seal~ok,'episode seals'
d=.BrandInteractionEngine~new~evaluate(ep)~value
call assertTrue d~containsCode('SERVICE_RECOVERY_SUPPORT'),'recovery support retained'
call assertTrue d~containsCode('CUSTOMER_NEGATIVE_STATE_PRESENT'),'prior problem not erased'
say 'PASS test_recovery'
exit 0
assertTrue: procedure; use arg v,l; if \v then do; say 'FAIL:' l; exit 1; end; return
::requires 'BrandInteractionEffect.cls'
