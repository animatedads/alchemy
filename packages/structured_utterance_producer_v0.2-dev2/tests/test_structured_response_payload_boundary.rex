p=.StructuredUtteranceProducer~new
plan=.StructuredUtteranceGenerationPlan~new('PLAN-SR-1','UTT-SR-1','AGENT','CHAT','CUSTOMER-TURN-1','ORCHESTRATOR','APP-1','PROVIDER:INV:1','MODEL:TEST','RESPONSE:PLAN:1')
seg=.StructuredUtteranceSegment~new('s1','I can help with that.','SERVICE_RESOLUTION','NONE','DERIVED_NONCUSTOMER')
call assertTrue plan~addSegment(seg),'segment accepted'
act=.UtteranceCommunicativeAct~new('a1','SERVICE_RESOLUTION'); act~addSegmentId('s1'); call assertTrue plan~addAct(act),'act accepted'
intent=.UtteranceGenerationIntent~new('i1','a1','ASSIST_CUSTOMER','HELPFUL','ISSUE_PROGRESS'); call assertTrue plan~addGenerationIntent(intent),'intent accepted'
call assertTrue plan~seal~ok,'plan seals'
r=p~producePayload(plan)
call assertTrue r~ok,'domain payload produced'
payload=r~value
call assertTrue payload~isA(.StructuredUtteranceProductionPayload),'typed payload object'
call assertTrue payload~isA(.AlchemyObject),'payload is Alchemy object'
call assertEqual 'structured.utterance.production-result/0.1',payload~schema,'payload schema'
call assertEqual 'I can help with that.',payload~deliveryText,'delivery content retained in domain payload'
d=payload~asDirectory
call assertEqual payload~schema,d['schema'],'directory schema'
call assertEqual payload~recordPoint,d['recordPoint'],'record evidence point'
call assertEqual payload~utterancePoint,d['utterancePoint'],'utterance evidence point'
call assertTrue d['requestId']==.nil,'no Structured Response request vocabulary invented'
call assertTrue d['receipt']==.nil,'no receipt vocabulary invented'
call assertTrue d['warnings']==.nil,'no warning envelope invented'
call assertTrue d['errors']==.nil,'no error envelope invented'
call assertTrue d['authority']==.nil,'no authority envelope invented'
call assertTrue d['cognitiveEffects']==.nil,'no memory-specific peer envelope invented'
say 'PASS test_structured_response_payload_boundary'
exit 0
assertTrue: procedure; use arg v,l; if \v then do; say 'FAIL:' l; exit 1; end; return
assertEqual: procedure; use arg e,a,l; if e\==a then do; say 'FAIL:' l 'expected='e 'actual='a; exit 1; end; return
::requires 'StructuredUtteranceProducer.cls'
