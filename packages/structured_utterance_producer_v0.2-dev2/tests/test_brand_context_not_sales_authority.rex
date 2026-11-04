p=.StructuredUtteranceProducer~new
plan=.StructuredUtteranceGenerationPlan~new('PLAN-BRAND-1','UTT-BRAND-1')
plan~addBrandDomain('SUPPORT')
plan~addBrandFunction('PROMOTIONAL_WORK')
plan~addBrandFunction('REPUTATIONAL_WORK')
plan~addBrandFunction('COMMERCIAL_RELATIONSHIP_WORK')
plan~addBrandOpportunity('RETENTION')
seg=.StructuredUtteranceSegment~new('s1','I can help troubleshoot the router.','SERVICE_RESOLUTION','NONE','DERIVED_NONCUSTOMER');plan~addSegment(seg)
act=.UtteranceCommunicativeAct~new('a1','SERVICE_RESOLUTION');act~addSegmentId('s1');plan~addAct(act)
intent=.UtteranceGenerationIntent~new('i1','a1','TROUBLESHOOT_ROUTER','HELPFUL','ISSUE_PROGRESS');plan~addGenerationIntent(intent)
call assertTrue plan~seal~ok,'brand plan seals'
r=p~produce(plan);call assertTrue r~ok,'brand plan produces'
u=r~value~utterance
call assertTrue u~brandContext~isPromotionalWork,'support can be promotional work'
call assertTrue u~brandContext~isReputationalWork,'support can be reputational work'
call assertFalse u~hasExplicitSalesProposition,'brand significance does not manufacture sales proposition'
say 'PASS test_brand_context_not_sales_authority'
exit 0
assertTrue: procedure; use arg v,l; if \v then do; say 'FAIL:' l; exit 1; end; return
assertFalse: procedure; use arg v,l; if v then do; say 'FAIL:' l; exit 1; end; return
::requires 'StructuredUtteranceProducer.cls'
