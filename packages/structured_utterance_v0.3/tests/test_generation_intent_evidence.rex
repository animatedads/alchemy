/* The generating model's contemporaneous intent is preserved separately from
   rendered language.  It remains evidence, not authority or retrospective fact. */
u = .StructuredUtterance~new('intent-evidence-1')
s = .StructuredUtteranceSegment~new('s1','I am done.','INFORMATION')
call assertTrue s~seal~ok,'segment seals'; u~addSegment(s)
a = .UtteranceCommunicativeAct~new('act1','INFORMATION'); a~addSegmentId('s1'); call assertTrue a~seal~ok,'act seals'; u~addAct(a)
i = .UtteranceGenerationIntent~new('intent1','act1','TERMINATE_CURRENT_DISCUSSION','POLITE_BOUNDARY','DISCUSSION_CLOSED','MODEL','model-X',92)
i~addConstraint('DO_NOT_CONTINUE_CURRENT_ARGUMENT'); call assertTrue i~seal~ok,'intent seals'; u~addGenerationIntent(i)
call assertTrue u~seal~ok,'utterance seals'

call assertTrue u~isA(.AlchemyObject),'structured utterance inherits AlchemyObject'
call assertTrue u~alchemyObjectId~length > 0,'alchemy object identity exists'
call assertTrue u~checkSurfaceContract~ok,'alchemy method surface contract passes'
metrics = u~alchemyMetrics
call assertTrue metrics['use_count'] >= 0,'alchemy metrics available'
events = u~instrumentationEvents
call assertTrue events~items >= 2,'seal instrumentation retained'

canon = u~canonicalText
call assertTrue canon~pos('TERMINATE_CURRENT_DISCUSSION') > 0,'intended act persisted'
call assertTrue canon~pos('POLITE_BOUNDARY') > 0,'intended register persisted'
call assertTrue canon~pos('DO_NOT_CONTINUE_CURRENT_ARGUMENT') > 0,'generation constraint persisted'
call assertTrue canon~pos('I am done.') > 0,'rendered language independently persisted'

pts=.StructuredUtteranceLibrary~new
call assertTrue pts~capture(u)~ok,'library captures utterance'
arr=pts~pointsMatching('intent-evidence-1','GENERATION_INTENT','TERMINATE_CURRENT_DISCUSSION')
call assertEqual 1,arr~items,'generation intent is addressable point'

say 'PASS test_generation_intent_evidence'
exit 0
assertTrue: procedure; use arg v,l; if \v then do; say 'FAIL:' l; exit 1; end; return
assertEqual: procedure; use arg e,a,l; if e \== a then do; say 'FAIL:' l 'expected='e 'actual='a; exit 1; end; return
::requires 'StructuredUtterance.cls'
