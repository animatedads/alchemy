now = .DateTime~new
assessment = .InteractionAssessment~new('IA-MAP-1','IE-MAP-1','SECURITY_RELEVANCE','RESTRICTED_PRODUCT_MISUSE_POSSIBLE','RULE_ENGINE','HARDWORLD','',80,now)~seal
signal = .SecurityExternalSignal~new('INTERACTION_EVENT',assessment~value,'BARBIE',assessment~assessmentId,now,assessment~confidence,assessment,'third-party report remains an external assessment')

policy = .SecurityEvidenceMappingPolicy~new('SECURITY-MAP-INTERACTION','1.0','SECURITY_TEAM','RISK_COMMITTEE')
rule = .SecurityEvidenceMappingRule~new('MAP-IE-RESTRICTED-1','INTERACTION_EVENT','RESTRICTED_PRODUCT_MISUSE_POSSIBLE','RESTRICTED_PRODUCT_MISUSE_POSSIBLE','CONCERN',85,3600)~seal
call assertTrue policy~addRule(rule),'mapping rule added'
policy~seal
call assertTrue policy~publicationEligible,'mapping policy approved and sealed'

bridge = .SecurityExternalEvidenceBridge~new
mapped = bridge~map(signal,policy)
call assertTrue mapped~ok,'external signal maps under fixed policy'
finding = mapped~value
call assertEqual 'RESTRICTED_PRODUCT_MISUSE_POSSIBLE',finding~findingKind,'mapped kind fixed by mapping rule'
call assertEqual 'CONCERN',finding~findingState,'mapping does not turn allegation into fact'
call assertEqual 'INTERACTION_EVENT',finding~sourceDomain,'source domain retained'
call assertEqual 2,finding~evidence~items,'source evidence and mapping-policy evidence retained'
call assertTrue finding~evidence[1]~sourceObject == assessment,'exact rich source object retained'
call assertTrue finding~evidence[2]~sourceObject == policy,'exact mapping policy retained'
call assertEqual 80,finding~confidence,'mapping respects source confidence below cap'
call assertTrue finding~effectiveUntil > finding~effectiveFrom,'mapping creates explicit freshness window'

unknown = .SecurityExternalSignal~new('INTERACTION_EVENT','UNRELATED_SIGNAL','BARBIE','IA-X',now,90,.nil,'irrelevant')
none = bridge~map(unknown,policy)
call assertTrue none~ok,'unmapped external signal is not an error'
call assertTrue none~value == .nil,'unmapped signal produces no security finding'
call assertEqual 'NO_MAPPING',none~detail,'no mapping is explicit'

say 'PASS test_external_mapping_policy'
exit 0
assertTrue: procedure
  use arg v,l
  if v = .false then do; say 'FAIL:' l; exit 1; end
  return
assertEqual: procedure
  use arg e,a,l
  if e <> a then do; say 'FAIL:' l 'expected='e 'actual='a; exit 1; end
  return
::requires 'InteractionEvent.cls'
::requires 'SecurityEffect.cls'
