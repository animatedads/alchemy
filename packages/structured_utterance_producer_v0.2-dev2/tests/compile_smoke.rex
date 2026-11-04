p = .StructuredUtteranceProducer~new
plan = .StructuredUtteranceGenerationPlan~new('PLAN-1','UTT-1','AGENT','CHAT','CUSTOMER-TURN-1','ORCHESTRATOR','APP-1','PROVIDER:INV:1','MODEL:TEST','PLAN:RESPONSE:1')
seg = .StructuredUtteranceSegment~new('s1','Sure, let me help you with that.','SERVICE_RESOLUTION','NONE','DERIVED_NONCUSTOMER')
call assertTrue plan~addSegment(seg), 'segment accepted'
act = .UtteranceCommunicativeAct~new('a1','SERVICE_RESOLUTION','MODEL','MODEL:TEST')
act~addSegmentId('s1')
call assertTrue plan~addAct(act), 'act accepted'
intent = .UtteranceGenerationIntent~new('i1','a1','ASSIST_CUSTOMER','HELPFUL','ISSUE_PROGRESS','MODEL','MODEL:TEST',95)
call assertTrue plan~addGenerationIntent(intent), 'intent accepted'
call assertTrue plan~seal~ok, 'plan seals'
r = p~produce(plan)
call assertTrue r~ok, 'producer succeeds'
call assertEqual 'Sure, let me help you with that.', r~value~deliveryText, 'delivery rendered from structure'
call assertEqual 'AUTHORITATIVE_STRUCTURED_PLAN', r~value~sourceMode, 'source mode explicit'
say 'PASS compile_smoke'
exit 0
assertTrue: procedure; use arg v,l; if \v then do; say 'FAIL:' l; exit 1; end; return
assertEqual: procedure; use arg e,a,l; if e \== a then do; say 'FAIL:' l 'expected='e 'actual='a; exit 1; end; return
::requires 'StructuredUtteranceProducer.cls'
