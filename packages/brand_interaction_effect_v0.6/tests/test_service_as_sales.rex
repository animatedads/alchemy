o = .BrandInteractionObservation~new('o1','e1','AGENT_UTTERANCE','INTERACTION_EVENT:e1','CHAT','OUTBOUND')
o~addTag('BRAND_FUNCTION/BRAND_ENGAGEMENT')
o~addTag('BRAND_FUNCTION/PROMOTIONAL_WORK')
o~addTag('BRAND_FUNCTION/REPUTATIONAL_WORK')
o~addTag('BRAND_FUNCTION/COMMERCIAL_RELATIONSHIP_WORK')
o~addTag('BRAND_OPPORTUNITY/RETENTION')
o~addTag('NO_EXPLICIT_SALES_PROPOSITION')
o~addPurpose('APOLOGY'); o~addPurpose('SERVICE_RESOLUTION'); o~seal
ep = .BrandInteractionEpisode~new('service-journey'); ep~addObservation(o); call assertTrue ep~seal~ok,'episode seals'
r = .BrandInteractionEngine~new~evaluate(ep); call assertTrue r~ok,'evaluates'; d=r~value
call assertTrue d~containsCode('BRAND_EXPERIENCE_TOUCHPOINT'),'brand touchpoint'
call assertTrue d~containsCode('SERVICE_AS_SALES_TOUCHPOINT'),'service as sales'
call assertFalse d~containsCode('SECURITY_SALES_COLLISION'),'no invented upsell collision'
call assertTrue .BrandInteractionExplainer~informal(d)~pos('Nobody upsold anything') > 0,'informal service explanation'
say 'PASS test_service_as_sales'
exit 0
assertTrue: procedure; use arg v,l; if \v then do; say 'FAIL:' l; exit 1; end; return
assertFalse: procedure; use arg v,l; if v then do; say 'FAIL:' l; exit 1; end; return
::requires 'BrandInteractionEffect.cls'
