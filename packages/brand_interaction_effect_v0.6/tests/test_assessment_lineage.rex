parse arg interactionRoot
if interactionRoot='' then do; say 'SKIP interaction root'; exit 0; end
e=.InteractionEvent~new('e-lineage','CUSTOMER_UTTERANCE',.nil,'CHAT','chat.in','INBOUND'); e~seal
lib=.InteractionCaptureLibrary~new; call assertTrue lib~captureEvent(e)~ok,'event captured'
a1=.InteractionAssessmentFactory~sentiment('a-lineage-1','e-lineage','FURIOUS','SENTIMENT-ASSESSOR','TONE-MODEL-V7',82); a1~seal; call assertTrue lib~attachAssessment(a1)~ok,'a1 attached'
a2=.InteractionAssessmentFactory~sentiment('a-lineage-2','e-lineage','FRUSTRATED','SENTIMENT-ASSESSOR','TONE-MODEL-V8',93); a2~seal; call assertTrue lib~attachAssessment(a2)~ok,'a2 attached'
r=.BrandInteractionEventBridge~episodeFromCorrelation(lib,'missing-corr','unused')
/* correlation route is not needed here; bridge directly with both assessments */
as=lib~assessmentsFor('e-lineage')
br=.BrandInteractionEventBridge~fromEvent(e,as); call assertTrue br~ok,'bridge works'
o=br~value
call assertEqual 2,o~assessmentRecords~items,'both assessments retained'
text=o~canonicalText
call assertTrue text~pos('FURIOUS')>0,'first assessment retained'
call assertTrue text~pos('FRUSTRATED')>0,'second assessment retained'
call assertTrue text~pos('TONE-MODEL-V7')>0,'v7 provenance retained'
call assertTrue text~pos('TONE-MODEL-V8')>0,'v8 provenance retained'
say 'PASS test_assessment_lineage'
exit 0
assertTrue: procedure; use arg v,l; if \v then do; say 'FAIL:' l; exit 1; end; return
assertEqual: procedure; use arg e,a,l; if e \== a then do; say 'FAIL:' l 'expected='e 'actual='a; exit 1; end; return
::requires 'BrandInteractionEffect.cls'
::requires 'BrandInteractionEventBridge.cls'
::requires 'InteractionEvent.cls'
