now = .DateTime~new
start = now - .TimeSpan~new(0,0,1,0,0)
profile = .InstitutionalPolicyAuthorityProfile~new('LOW-RISK-GOV','1.0',start,.nil)
ignored = profile~addGrant(.InstitutionalPolicyAuthorityGrant~new('GA','AUTHOR-1','AUTHOR','LOW-RISK',start,.nil,'BOARD','')~seal)
ignored = profile~addGrant(.InstitutionalPolicyAuthorityGrant~new('GB','APPROVER-1','APPROVER','LOW-RISK',start,.nil,'BOARD','')~seal)
ignored = profile~addGrant(.InstitutionalPolicyAuthorityGrant~new('GC','OPS-1','PUBLISHER','LOW-RISK',start,.nil,'BOARD','')~seal)
ignored = profile~addRule(.InstitutionalPolicyAuthorityRule~new('RULE-LOW','LOW-RISK',.true,'OPTIONAL')~seal)
ignored = profile~seal
policy = .InstitutionalPolicyRelease~new('LOW-RISK','1.0',now,.nil,'AUTHOR-1','APPROVER-1','',.nil,'PAYLOAD')~seal
request = .InstitutionalPolicyPublicationRequest~new(policy,'OPS-1',now)
evaluator = .InstitutionalPolicyAuthorityEvaluator~new(profile)
catalog = .InstitutionalPolicyCatalog~new(.nil,.nil,.nil,.nil,evaluator)
result = catalog~publish(policy,request)
call assertTrue result~ok,'role-authorized internal policy can publish without signature/workflow verifier when rule permits'
record = catalog~publicationRecord('LOW-RISK','1.0')~value
call assertEqual 'ROLE_AUTHORITY',record~assuranceMode,'assurance truthfully says role authority only'

legacy = .InstitutionalPolicyRelease~new('LEGACY','1.0',now,.nil,'A','B','',.nil,'X')~seal
legacyCatalog = .InstitutionalPolicyCatalog~new
call assertTrue legacyCatalog~publish(legacy)~ok,'v0.1 identifier-only publication remains compatible'
legacyRecord = legacyCatalog~publicationRecord('LEGACY','1.0')~value
call assertEqual 'IDENTIFIER_ONLY',legacyRecord~assuranceMode,'legacy assurance is not overclaimed'

say 'PASS test_authority_optional_evidence'
exit 0
assertTrue: procedure
  use arg v,l
  if v = .false then do; say 'FAIL:' l; exit 1; end
  return
assertEqual: procedure
  use arg e,a,l
  if e <> a then do; say 'FAIL:' l 'expected='e 'actual='a; exit 1; end
  return
::requires 'InstitutionalPolicy.cls'
