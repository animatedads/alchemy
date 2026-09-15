ctx=.BrandExperienceContext~serviceAsSales
ctx~addDomain('SECURITY'); ctx~addOpportunity('REPUTATIONAL_RISK')
u=.StructuredUtterance~new('shannon-1','AGENT','CHAT','customer-risk',ctx)
u~addContextTag('SECURITY_SENSITIVE_SERVICE_INTERACTION'); u~addCorrelation('journey-42')
s1=.StructuredUtteranceSegment~new('s1','I cannot advise you on how to do anything illegal.','WARNLAW'); s1~addRole('REFUSE_ILLEGAL_ASSISTANCE'); call assertTrue s1~seal~ok,'warn seals'; u~addSegment(s1)
s2=.StructuredUtteranceSegment~new('s2','Would ','SALESPROP'); call assertTrue s2~seal~ok,'sales prefix seals'; u~addSegment(s2)
s3=.StructuredUtteranceSegment~new('s3','Barbie','SALESPROP','CUSTNAME','CUSTOMER_SPECIFIC','[CUSTOMER_RELATED_PERSON]','ABSTRACT_ONLY'); e3=.UtteranceLineageEdge~new('e3','COPIED_FROM_CUSTOMER','CUSTOMER_PROMPT:person:1','CUSTOMER_SPECIFIC'); s3~addLineage(e3); call assertTrue s3~seal~ok,'name seals'; u~addSegment(s3)
s4=.StructuredUtteranceSegment~new('s4',' like an extra bag?','SALESPROP'); call assertTrue s4~seal~ok,'suffix seals'; u~addSegment(s4); call assertTrue u~seal~ok,'utterance seals'
ev=.StructuredUtteranceInteractionBridge~toEvent(u,'agent-e1','shannon.reply')~value
lib=.InteractionCaptureLibrary~new; call assertTrue lib~captureEvent(ev)~ok,'event capture'
ep=.BrandInteractionEventBridge~episodeFromCorrelation(lib,'journey-42','shannon-brand')~value
d=.BrandInteractionEngine~new~evaluate(ep)~value
call assertTrue d~containsCode('SECURITY_SALES_COLLISION'),'end-to-end collision'
call assertEqual 0,ep~canonicalText~pos('Barbie'),'brand episode does not retain customer name'
say 'PASS test_structured_shannon_end_to_end'
exit 0
assertTrue: procedure; use arg v,l; if \v then do; say 'FAIL:' l; exit 1; end; return
assertEqual: procedure; use arg e,a,l; if e \== a then do; say 'FAIL:' l 'expected='e 'actual='a; exit 1; end; return
::requires 'StructuredUtterance.cls'
::requires 'StructuredUtteranceInteractionBridge.cls'
::requires 'InteractionEvent.cls'
::requires 'BrandInteractionEffect.cls'
::requires 'BrandInteractionEventBridge.cls'
