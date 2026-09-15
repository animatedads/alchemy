now = .DateTime~new
start = now - .TimeSpan~new(0,0,1,0,0)

profile = .InstitutionalPolicyAuthorityProfile~new('SECURITY-GOVERNANCE','1.0',start,.nil)
ignored = profile~addGrant(.InstitutionalPolicyAuthorityGrant~new('SEC-AUTHOR','SECURITY_TEAM','AUTHOR','SECURITY-POLICY-CORE',start,.nil,'SECURITY-BOARD','HR:SECURITY_TEAM')~seal)
ignored = profile~addGrant(.InstitutionalPolicyAuthorityGrant~new('SEC-APPROVER','RISK_COMMITTEE','APPROVER','SECURITY-POLICY-CORE',start,.nil,'SECURITY-BOARD','BOARD:RISK')~seal)
ignored = profile~addGrant(.InstitutionalPolicyAuthorityGrant~new('SEC-PUBLISHER','SECURITY_RELEASE','PUBLISHER','SECURITY-POLICY-CORE',start,.nil,'SECURITY-BOARD','DEPLOY:SECURITY')~seal)
ignored = profile~addRule(.InstitutionalPolicyAuthorityRule~new('SEC-PUB-RULE','SECURITY-POLICY-CORE',.true,'REQUIRED')~seal)
ignored = profile~seal

framework = .SecurityPolicyFramework~new('SECURITY-POLICY-CORE','4.0',now,.nil,'SECURITY_TEAM','RISK_COMMITTEE','')
rule = .SecurityPolicyRule~new('ALLOW-READ',100,'READ_OWN_BOOKING','ALLOW','ordinary own-booking read remains available')~seal
call assertTrue framework~addRule(rule),'rule added'
ignored = framework~seal
approval = .InstitutionalPolicyApprovalAttestation~new('SEC-APPROVAL-1',framework~policyId,framework~version,framework~semanticIdentity,'RISK_COMMITTEE',now,'CHANGE_RECORD','CAB-771')~seal
request = .InstitutionalPolicyPublicationRequest~new(framework,'SECURITY_RELEASE',now)
ignored = request~addApproval(approval)
evaluator = .InstitutionalPolicyAuthorityEvaluator~new(profile,.SecurityApprovalVerifier~new)
catalog = .SecurityPolicyCatalog~new(.nil,.nil,evaluator)
result = catalog~publish(framework,request)
call assertTrue result~ok,'SecurityPolicyCatalog enforces shared publication authority'
record = catalog~publicationRecord(framework~policyId,framework~version)~value
call assertEqual 'VERIFIED_APPROVAL_EVIDENCE',record~assuranceMode,'security publication carries verified authority assurance'
call assertEqual profile~semanticIdentity,record~authorityDecision~authorityProfileIdentity,'security publication binds exact governance profile'
call assertEqual 'SECURITY_RELEASE',record~publisherId,'security publisher retained'

badFramework = .SecurityPolicyFramework~new('SECURITY-POLICY-CORE','4.1',now + .TimeSpan~new(0,1,0,0,0),.nil,'SECURITY_TEAM','RISK_COMMITTEE','4.0')~seal
badRequest = .InstitutionalPolicyPublicationRequest~new(badFramework,'RISK_COMMITTEE',now)
bad = evaluator~evaluate(badFramework,badRequest)
call assertTrue \bad~ok,'approver identity alone does not imply publisher authority'
call assertEqual 'PUBLISHER_AUTHORITY_DENIED',bad~code,'publisher authority is separately scoped'

say 'PASS test_policy_authority_integration'
exit 0
assertTrue: procedure
  use arg v,l
  if v = .false then do; say 'FAIL:' l; exit 1; end
  return
assertEqual: procedure
  use arg e,a,l
  if e <> a then do; say 'FAIL:' l 'expected='e 'actual='a; exit 1; end
  return

::class SecurityApprovalVerifier public
::method verify
  use arg attestation, policy, profile
  if attestation~matches(policy,policy~approvedBy) = .false then return .InstitutionalPolicyEvidenceVerification~new(.false,'MISMATCH')
  if attestation~evidenceKind <> 'CHANGE_RECORD' then return .InstitutionalPolicyEvidenceVerification~new(.false,'UNTRUSTED_KIND')
  if attestation~evidenceRef <> 'CAB-771' then return .InstitutionalPolicyEvidenceVerification~new(.false,'UNKNOWN_CHANGE')
  return .InstitutionalPolicyEvidenceVerification~new(.true,'VERIFIED','change-control record verified',attestation~evidenceIdentity)

::requires 'SecurityEffect.cls'
