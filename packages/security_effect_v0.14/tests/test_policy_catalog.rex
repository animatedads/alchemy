now = .DateTime~new
catalog = .SecurityPolicyCatalog~new

p1 = .SecurityPolicyFramework~new('SECURITY-POLICY-CORE','1.0',now - .TimeSpan~new(0,1,0,0,0),now - .TimeSpan~new(0,0,1,0,0),'SECURITY_TEAM','RISK_COMMITTEE')
r1 = .SecurityPolicyRule~new('BASE-1',100,'PUBLIC_READ','ALLOW','historical baseline')~seal
call assertTrue p1~addRule(r1),'v1 rule added'
p1~seal
call assertTrue p1~publicationEligible,'v1 publication eligible'
call assertTrue catalog~publish(p1)~ok,'v1 published'

p2 = .SecurityPolicyFramework~new('SECURITY-POLICY-CORE','1.1',now,.nil,'SECURITY_TEAM','RISK_COMMITTEE','1.0')
r2 = .SecurityPolicyRule~new('BASE-2',100,'PUBLIC_READ','CAUTION','new approved consequence')~seal
call assertTrue p2~addRule(r2),'v1.1 rule added'
p2~seal
call assertTrue catalog~publish(p2)~ok,'v1.1 published with explicit supersession'

oldTime = now - .TimeSpan~new(0,0,30,0,0)
oldResolved = catalog~resolve('SECURITY-POLICY-CORE',oldTime)
call assertTrue oldResolved~ok,'historical policy resolves'
call assertEqual '1.0',oldResolved~value~version,'historical version is 1.0'
newResolved = catalog~resolve('SECURITY-POLICY-CORE',now)
call assertTrue newResolved~ok,'current policy resolves'
call assertEqual '1.1',newResolved~value~version,'current version is 1.1'
call assertEqual '1.0',newResolved~value~supersedes,'supersession lineage retained'

bad = .SecurityPolicyFramework~new('SECURITY-POLICY-CORE','2.0',now + .TimeSpan~new(0,1,0,0,0),.nil,'SECURITY_TEAM','','1.1')~seal
call assertEqual 'POLICY_NOT_APPROVED',catalog~publish(bad)~code,'unapproved policy cannot publish'
missing = .SecurityPolicyFramework~new('OTHER-POLICY','1.1',now,.nil,'SECURITY_TEAM','RISK_COMMITTEE','1.0')~seal
call assertEqual 'SUPERSEDED_POLICY_NOT_FOUND',catalog~publish(missing)~code,'supersedes must name a published predecessor'
overlap = .SecurityPolicyFramework~new('SECURITY-POLICY-CORE','1.2',now + .TimeSpan~new(0,0,30,0,0),.nil,'SECURITY_TEAM','RISK_COMMITTEE','1.1')~seal
call assertEqual 'POLICY_EFFECTIVE_RANGE_OVERLAP',catalog~publish(overlap)~code,'catalog refuses ambiguous overlapping effective ranges'


/* Exact [from,until) handover is legal and unambiguous. */
cut = now + .TimeSpan~new(0,2,0,0,0)
c2 = .SecurityPolicyCatalog~new
h1 = .SecurityPolicyFramework~new('HANDOVER','1.0',now,cut,'SECURITY_TEAM','RISK_COMMITTEE')~seal
h2 = .SecurityPolicyFramework~new('HANDOVER','1.1',cut,.nil,'SECURITY_TEAM','RISK_COMMITTEE','1.0')~seal
call assertTrue c2~publish(h1)~ok,'handover predecessor published'
call assertTrue c2~publish(h2)~ok,'exact effective boundary does not overlap'
call assertEqual '1.1',c2~resolve('HANDOVER',cut)~value~version,'new policy owns exact boundary instant'

say 'PASS test_policy_catalog'
exit 0
assertTrue: procedure
  use arg v,l
  if v = .false then do; say 'FAIL:' l; exit 1; end
  return
assertEqual: procedure
  use arg e,a,l
  if e <> a then do; say 'FAIL:' l 'expected='e 'actual='a; exit 1; end
  return
::requires 'TestSupport.cls'
