now = .DateTime~new
assessment = .InteractionAssessment~new('IA-1','IE-1','SECURITY_RELEVANCE','RESTRICTED_PRODUCT_MISUSE_POSSIBLE','RULE_ENGINE','HARDWORLD','',80,now)~seal
finding = .SecurityFindingFactory~external('F-EXT-1','RESTRICTED_PRODUCT_MISUSE_POSSIBLE','CONCERN','BARBIE',80,'INTERACTION_EVENT',assessment,'cross-domain assessment retained',now,now + .TimeSpan~new(0,0,1,0,0))
call assertEqual 'INTERACTION_EVENT',finding~sourceDomain,'source domain retained'
call assertEqual 1,finding~evidence~items,'source evidence retained'
call assertTrue finding~evidence[1]~sourceObject == assessment,'exact rich source object retained'
call assertEqual 'RESTRICTED_PRODUCT_MISUSE_POSSIBLE',assessment~value,'external assessment remains its own semantics'
say 'PASS test_interaction_event_integration'
exit 0
assertTrue: procedure
  use arg v,l
  if v = .false then do; say 'FAIL:' l; exit 1; end
  return
assertEqual: procedure
  use arg e,a,l
  if e <> a then do; say 'FAIL:' l; exit 1; end
  return
::requires 'InteractionEvent.cls'
::requires 'SecurityEffect.cls'
