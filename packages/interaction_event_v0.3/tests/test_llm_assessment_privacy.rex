lib = .InteractionCaptureLibrary~new
e = .InteractionEvent~new('llm1','CUSTOMER_UTTERANCE',.nil,'CHAT','CHAT.POST_TURN','INBOUND')
e~seal
call assertTrue lib~captureEvent(e)~ok, 'event captured'

a = .InteractionAssessmentFactory~sentiment('lla','llm1','VERY_NEGATIVE','sentiment-llm','sent-v7',89)
a~addDimension('INTENSITY',91)
a~addDetailElement(.InteractionContentElement~new('ld1','ASSESSOR_EXPLANATION','Jane Example says account 12345 is useless','CUSTOMER_SPECIFIC','customer expressed strong dissatisfaction about service','ABSTRACT_ONLY','MODEL_DERIVED','llm-output-1','',89))
a~addDetailElement(.InteractionContentElement~new('ld2','STYLE_SIGNAL','PROFANITY_PRESENT','DERIVED_NONCUSTOMER','','RETAIN','MODEL_DERIVED','llm-output-1','',96))
a~seal
call assertTrue lib~attachAssessment(a)~ok, 'assessment attached'

r = lib~projectEvent('llm1')
call assertTrue r~ok, 'projection succeeds'
pa = r~value~assessments[1]
call assertEqual 'VERY_NEGATIVE', pa~value, 'controlled assessment retained'
call assertEqual 2, pa~details~items, 'safe semantic residue from model details retained'
text = ''
do d over pa~details; text ||= '|' || d~value; end
call assertTrue text~pos('Jane Example') = 0, 'model-repeated name removed'
call assertTrue text~pos('12345') = 0, 'model-repeated account id removed'
call assertTrue text~pos('customer expressed strong dissatisfaction about service') > 0, 'model explanation abstraction retained'
call assertTrue text~pos('PROFANITY_PRESENT') > 0, 'derived noncustomer style signal retained'
say 'PASS test_llm_assessment_privacy'
exit 0
assertTrue: procedure; use arg v,l; if \v then do; say 'FAIL:' l; exit 1; end; return
assertEqual: procedure; use arg e,a,l; if e \== a then do; say 'FAIL:' l 'expected='e 'actual='a; exit 1; end; return
::requires 'InteractionEvent.cls'
