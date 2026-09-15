/* High sass is an assessment, not a cancellation rule. */
a=.BrandInteractionObservation~new('a-ok','a-ok','AGENT_UTTERANCE','INTERACTION_EVENT:a-ok','CHAT','OUTBOUND')
a~putDimension('SASS',90); a~putDimension('ABRUPTNESS',85); a~putDimension('DISMISSIVENESS',82); a~putDimension('CLOSURE_STRENGTH',40); a~seal
r=.BrandInteractionObservation~new('r-ok','r-ok','SERVICE_RESOLVED','INTERACTION_EVENT:r-ok','SUPPORT','OUTBOUND'); r~addTag('RECOVERY/SERVICE_RESOLVED'); r~seal
c=.BrandInteractionObservation~new('c-ok','c-ok','CUSTOMER_CONTINUES','INTERACTION_EVENT:c-ok','CHAT','INBOUND'); c~putAssessment('CUSTOMER_SENTIMENT','POSITIVE'); c~seal
ep=.BrandInteractionEpisode~new('sass-no-exit'); ep~addObservation(a); ep~addObservation(r); ep~addObservation(c); call assertTrue ep~seal~ok,'episode seals'
d=.BrandInteractionEngine~new~evaluate(ep)~value
call assertFalse d~containsCode('STYLE_COMMERCIAL_EXIT_ASSOCIATION'),'no sass implies cancel rule'
call assertEqual 0,d~hypotheses~items,'no invented exit hypothesis'
say 'PASS test_sass_not_cancel_rule'
exit 0
assertTrue: procedure; use arg v,l; if \v then do; say 'FAIL:' l; exit 1; end; return
assertFalse: procedure; use arg v,l; if v then do; say 'FAIL:' l; exit 1; end; return
assertEqual: procedure; use arg e,a,l; if e \== a then do; say 'FAIL:' l 'expected='e 'actual='a; exit 1; end; return
::requires 'BrandInteractionEffect.cls'
