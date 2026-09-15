parse arg interactionRoot
if interactionRoot='' then do; say 'SKIP interaction root'; exit 0; end
/* Deliberately include raw personal data in the source event.  The bridge must
   retain only event semantics, controlled tags/purposes and scalar assessments. */
e=.InteractionEvent~new('e1','CUSTOMER_UTTERANCE',.InteractionReference~new('CUSTOMER','Barbie Example','CUSTOMER_SPECIFIC','CUSTOMER','CUSTOMER_INPUT'),'CHAT','chat.in','INBOUND')
e~addCorrelation('journey-private')
e~addContent(.InteractionContentElement~new('x','CUSTOMER_TEXT','Barbie lives at 12 Private Road','CUSTOMER_SENSITIVE','[CUSTOMER DISCLOSED SENSITIVE MATTER]','ABSTRACT_ONLY','CUSTOMER_INPUT'))
e~addTag('BRAND_FUNCTION/REPUTATIONAL_WORK'); e~seal
lib=.InteractionCaptureLibrary~new; call assertTrue lib~captureEvent(e)~ok,'event captured'
a=.InteractionAssessmentFactory~sentiment('a1','e1','FRUSTRATED','sentiment-model','model-x',88); a~seal; call assertTrue lib~attachAssessment(a)~ok,'assessment attached'
r=.BrandInteractionEventBridge~episodeFromCorrelation(lib,'journey-private','privacy-episode'); call assertTrue r~ok,'episode built'
ep=r~value
text=ep~canonicalText
call assertEqual 0,text~pos('Barbie'),'name absent'
call assertEqual 0,text~pos('Private Road'),'address absent'
call assertTrue text~pos('FRUSTRATED') > 0,'semantic assessment retained'
call assertTrue text~pos('REPUTATIONAL_WORK') > 0,'brand semantics retained'
say 'PASS test_interaction_bridge_privacy'
exit 0
assertTrue: procedure; use arg v,l; if \v then do; say 'FAIL:' l; exit 1; end; return
assertEqual: procedure; use arg e,a,l; if e \== a then do; say 'FAIL:' l 'expected='e 'actual='a; exit 1; end; return
::requires 'BrandInteractionEffect.cls'
::requires 'BrandInteractionEventBridge.cls'
::requires 'InteractionEvent.cls'
