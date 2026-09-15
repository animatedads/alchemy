o=.BrandInteractionObservation~new('o1','e1','AGENT_UTTERANCE','INTERACTION_EVENT:e1','CHAT','OUTBOUND')
o~addTag('CONTEXT/SECURITY_SENSITIVE_SERVICE_INTERACTION'); o~addTag('EXPLICIT_SALES_PROPOSITION')
o~addPurpose('WARNLAW'); o~addPurpose('REFUSE_ILLEGAL_ASSISTANCE'); o~addPurpose('SALESPROP'); o~seal
ep=.BrandInteractionEpisode~new('security-sales'); ep~addObservation(o); call assertTrue ep~seal~ok,'episode seals'
r=.BrandInteractionEngine~new~evaluate(ep); call assertTrue r~ok,'evaluates'; d=r~value
call assertTrue d~containsCode('SECURITY_SALES_COLLISION'),'collision identified'
call assertTrue .BrandInteractionExplainer~informal(d)~pos('lost the plot') > 0,'informal explanation'
say 'PASS test_security_sales_collision'
exit 0
assertTrue: procedure; use arg v,l; if \v then do; say 'FAIL:' l; exit 1; end; return
::requires 'BrandInteractionEffect.cls'
