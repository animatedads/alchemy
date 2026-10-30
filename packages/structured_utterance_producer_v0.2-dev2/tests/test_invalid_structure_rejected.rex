p=.StructuredUtteranceProducer~new
plan=.StructuredUtteranceGenerationPlan~new('PLAN-BAD-1','UTT-BAD-1')
seg=.StructuredUtteranceSegment~new('s1','hello','GENERAL','NONE','DERIVED_NONCUSTOMER');plan~addSegment(seg)
act=.UtteranceCommunicativeAct~new('a1','GENERAL');act~addSegmentId('missing-segment');plan~addAct(act)
call assertTrue plan~seal~ok,'plan seals component objects without guessing cross-links'
r=p~produce(plan)
call assertFalse r~ok,'invalid Structured Utterance graph rejected at materialisation'
call assertEqual 'STRUCTURED_UTTERANCE_INVALID',r~code,'producer preserves structural boundary'
call assertEqual 'UTTERANCE_ACT_SEGMENT_MISSING',r~detail,'downstream validation code retained'
say 'PASS test_invalid_structure_rejected'
exit 0
assertTrue: procedure; use arg v,l; if \v then do; say 'FAIL:' l; exit 1; end; return
assertFalse: procedure; use arg v,l; if v then do; say 'FAIL:' l; exit 1; end; return
assertEqual: procedure; use arg e,a,l; if e \== a then do; say 'FAIL:' l 'expected='e 'actual='a; exit 1; end; return
::requires 'StructuredUtteranceProducer.cls'
