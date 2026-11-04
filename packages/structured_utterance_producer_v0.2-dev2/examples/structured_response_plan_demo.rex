/* Application/provider-neutral analogue of a strict response-plan handoff. */
producer=.StructuredUtteranceProducer~new
plan=.StructuredUtteranceGenerationPlan~new('PLAN-DEMO-1','UTT-DEMO-1','AGENT','CHAT','CUSTOMER-TURN-1','ORCHESTRATOR','EXAMPLE-APP','PROVIDER:INV:1','MODEL:EXAMPLE','RESPONSE:PLAN:1')
plan~addBrandDomain('SUPPORT');plan~addBrandFunction('REPUTATIONAL_WORK');plan~addBrandOpportunity('TRUST_MAINTENANCE')
seg=.StructuredUtteranceSegment~new('s1','Sure, let me help you with that.','SERVICE_RESOLUTION','NONE','DERIVED_NONCUSTOMER')
plan~addSegment(seg)
act=.UtteranceCommunicativeAct~new('a1','SERVICE_RESOLUTION');act~addSegmentId('s1');plan~addAct(act)
intent=.UtteranceGenerationIntent~new('i1','a1','ASSIST_CUSTOMER','HELPFUL','ISSUE_PROGRESS');intent~addConstraint('DO_NOT_INFER_SALES_AUTHORITY');plan~addGenerationIntent(intent)
plan~seal
r=producer~produce(plan)
say 'plan:' plan~pointId
say 'utterance:' r~value~utterancePoint
say 'delivery:' r~value~deliveryText
say 'source mode:' r~value~sourceMode
exit 0
::requires 'StructuredUtteranceProducer.cls'
