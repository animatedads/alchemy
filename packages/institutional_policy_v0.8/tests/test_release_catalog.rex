now = .DateTime~new
cut = now + .TimeSpan~new(0,0,30,0,0)

p1 = .InstitutionalPolicyRelease~new('BUSINESS-POLICY','1.0',now - .TimeSpan~new(0,1,0,0,0),cut,'POLICY_AUTHOR','POLICY_BOARD','',.nil,'PAYLOAD-A')~seal
p2 = .InstitutionalPolicyRelease~new('BUSINESS-POLICY','1.1',cut,.nil,'POLICY_AUTHOR','POLICY_BOARD','1.0',.nil,'PAYLOAD-B')~seal
call assertTrue p1~publicationEligible,'v1 publishable'
call assertTrue p2~publicationEligible,'v1.1 publishable'
call assertEqual 'FIXED_REVIEWABLE_VERSIONED_ARTIFACT',p1~executionModel,'execution model fixed'

catalog = .InstitutionalPolicyCatalog~new
call assertTrue catalog~publish(p1)~ok,'publish predecessor'
record = catalog~publicationRecord('BUSINESS-POLICY','1.0')
call assertTrue record~ok,'publication record retained'
call assertEqual p1~semanticIdentity,record~value~policyIdentity,'publication record binds exact policy identity'
call assertTrue catalog~publish(p2)~ok,'publish exact handover successor'
call assertEqual '1.0',catalog~resolve('BUSINESS-POLICY',now)~value~version,'old policy resolves before cut'
call assertEqual '1.1',catalog~resolve('BUSINESS-POLICY',cut)~value~version,'new policy owns exact boundary'

overlap = .InstitutionalPolicyRelease~new('BUSINESS-POLICY','1.2',cut + .TimeSpan~new(0,0,1,0,0),.nil,'POLICY_AUTHOR','POLICY_BOARD','1.1',.nil,'PAYLOAD-C')~seal
call assertEqual 'POLICY_EFFECTIVE_RANGE_OVERLAP',catalog~publish(overlap)~code,'overlap rejected'
unapproved = .InstitutionalPolicyRelease~new('OTHER','1.0',now,.nil,'POLICY_AUTHOR','', '', .nil,'X')~seal
call assertEqual 'POLICY_NOT_APPROVED',catalog~publish(unapproved)~code,'unapproved release rejected'
invalidRange = .InstitutionalPolicyRelease~new('INVALID','1.0',cut,now,'A','B','',.nil,'X')~seal
call assertEqual 'POLICY_EFFECTIVE_RANGE_INVALID',catalog~publish(invalidRange)~code,'inverted effective range rejected'

say 'PASS test_release_catalog'
exit 0
assertTrue: procedure
  use arg value,label
  if value = .false then do; say 'FAIL:' label; exit 1; end
  return
assertEqual: procedure
  use arg expected,actual,label
  if expected <> actual then do; say 'FAIL:' label 'expected='expected 'actual='actual; exit 1; end
  return
::requires 'InstitutionalPolicy.cls'
