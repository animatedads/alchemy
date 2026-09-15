lib = .InteractionCaptureLibrary~new
e = .InteractionEvent~new('z1','AGENT_UTTERANCE')
r = lib~captureEvent(e)
call assertTrue \r~ok, 'unsealed event refused'
call assertEqual 'EVENT_NOT_SEALED', r~code, 'seal code'
e~seal
call assertTrue lib~captureEvent(e)~ok, 'sealed accepted'
call assertTrue \e~addTag('LATE_MUTATION'), 'sealed event immutable through API'
a = .InteractionAssessmentFactory~style('za','z1','style-model')
call assertTrue \a~addDimension('BAD NAME WITH SPACE',90), 'dimension names are controlled tokens'
call assertTrue \a~addDimension('EXPLANATION','Jane Example was furious'), 'dimension values cannot smuggle prose/PII'
call assertTrue a~addDimension('SASS',81), 'safe dimension accepted'
a~seal
call assertTrue lib~attachAssessment(a)~ok, 'sealed assessment accepted'
say 'PASS test_sealing_and_tokens'
exit 0
assertTrue: procedure; use arg v,l; if \v then do; say 'FAIL:' l; exit 1; end; return
assertEqual: procedure; use arg e,a,l; if e \== a then do; say 'FAIL:' l 'expected='e 'actual='a; exit 1; end; return
::requires 'InteractionEvent.cls'
