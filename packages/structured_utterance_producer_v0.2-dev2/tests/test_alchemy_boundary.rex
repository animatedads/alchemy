p=.StructuredUtteranceProducer~new
plan=.StructuredUtteranceGenerationPlan~new('PLAN-ALCHEMY-1','UTT-ALCHEMY-1')
call assertTrue p~isA(.AlchemyObject),'producer is Alchemy object'
call assertTrue plan~isA(.AlchemyObject),'plan is Alchemy object'
seg=.StructuredUtteranceSegment~new('s1','hello','GENERAL','NONE','DERIVED_NONCUSTOMER');plan~addSegment(seg)
call assertTrue plan~seal~ok,'plan seals'
r=p~produce(plan);call assertTrue r~ok,'produce succeeds'
call assertTrue r~value~isA(.AlchemyObject),'production record is Alchemy object'
call assertTrue p~instrumentationEvents~items >= 2,'producer instrumentation exists'
call assertTrue plan~instrumentationEvents~items >= 2,'plan instrumentation exists'
say 'PASS test_alchemy_boundary'
exit 0
assertTrue: procedure; use arg v,l; if \v then do; say 'FAIL:' l; exit 1; end; return
::requires 'StructuredUtteranceProducer.cls'
