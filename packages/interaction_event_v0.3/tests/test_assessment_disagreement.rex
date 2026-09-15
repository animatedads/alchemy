lib = .InteractionCaptureLibrary~new
e = .InteractionEvent~new('d1','CUSTOMER_UTTERANCE',.nil,'CHAT','CHAT.POST_TURN','INBOUND')
e~seal
call assertTrue lib~captureEvent(e)~ok, 'event captured'
a = .InteractionAssessmentFactory~sentiment('s1','d1','FURIOUS','model-a','sent-a',82); a~seal
b = .InteractionAssessmentFactory~sentiment('s2','d1','FRUSTRATED','model-b','sent-b',93); b~seal
call assertTrue lib~attachAssessment(a)~ok, 'a attached'
call assertTrue lib~attachAssessment(b)~ok, 'b attached'
arr = lib~assessmentsFor('d1')
call assertEqual 2, arr~items, 'both assessments retained'
call assertEqual 'FURIOUS', arr[1]~value, 'first preserved'
call assertEqual 'FRUSTRATED', arr[2]~value, 'second preserved'
say 'PASS test_assessment_disagreement'
exit 0
assertTrue: procedure; use arg v,l; if \v then do; say 'FAIL:' l; exit 1; end; return
assertEqual: procedure; use arg e,a,l; if e \== a then do; say 'FAIL:' l 'expected='e 'actual='a; exit 1; end; return
::requires 'InteractionEvent.cls'
