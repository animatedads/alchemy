/* Customer frustration is an assessed state, not a historical fact. */
c = .BrandInteractionObservation~new('c1','c1','CUSTOMER_UTTERANCE','INTERACTION_EVENT:c1','CHAT','INBOUND')
c~putAssessment('CUSTOMER_SENTIMENT','FRUSTRATED'); c~seal

a = .BrandInteractionObservation~new('a1','a1','AGENT_UTTERANCE','INTERACTION_EVENT:a1','CHAT','OUTBOUND')
a~putAssessment('COMMUNICATION_STYLE','PROFILE')
a~putDimension('SASS',86); a~putDimension('ABRUPTNESS',94); a~putDimension('DISMISSIVENESS',91); a~putDimension('CLOSURE_STRENGTH',95); a~seal

m = .BrandInteractionObservation~new('m1','m1','SUBSCRIPTION_MANAGEMENT_OPENED','INTERACTION_EVENT:m1','WEB','INBOUND'); m~seal
x = .BrandInteractionObservation~new('x1','x1','SUBSCRIPTION_CANCELLED','INTERACTION_EVENT:x1','BILLING','INBOUND'); x~seal

ep = .BrandInteractionEpisode~new('sass-exit'); ep~addObservation(c); ep~addObservation(a); ep~addObservation(m); ep~addObservation(x); call assertTrue ep~seal~ok,'episode seals'
r=.BrandInteractionEngine~new~evaluate(ep); call assertTrue r~ok,'evaluates'; d=r~value
call assertTrue d~containsCode('STYLE_COMMERCIAL_EXIT_ASSOCIATION'),'style exit finding'
call assertTrue d~containsCode('INTERPERSONAL_TERMINATION_REGISTER'),'termination register'
call assertTrue d~hypotheses~items > 0,'causal hypothesis emitted'
h=d~hypotheses[1]
call assertEqual 'CANDIDATE_NOT_PROVEN',h~causalStatus,'causal humility'
call assertTrue h~mechanisms~items >= 2,'mechanisms retained'
call assertTrue .BrandInteractionExplainer~informal(d)~pos('too much sass') > 0,'human rendering'
say 'PASS test_sass_commercial_exit'
exit 0
assertTrue: procedure; use arg v,l; if \v then do; say 'FAIL:' l; exit 1; end; return
assertEqual: procedure; use arg e,a,l; if e \== a then do; say 'FAIL:' l 'expected='e 'actual='a; exit 1; end; return
::requires 'BrandInteractionEffect.cls'
