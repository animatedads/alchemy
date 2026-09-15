now = .DateTime~new
start = now - .InstitutionalPolicyTime~seconds(3600)
finish = now + .InstitutionalPolicyTime~seconds(86400)

profile = .InstitutionalPolicyAuthorityProfile~new('MULTI-GOV','3.0',start,finish)
call must profile~addGrant(.InstitutionalPolicyAuthorityGrant~new('G-AUTH','POLICY-ENGINEER','AUTHOR','SECURITY-PAYMENTS',start,finish,'GOV','HR:A')~seal), 'author grant'
call must profile~addGrant(.InstitutionalPolicyAuthorityGrant~new('G-SEC','SECURITY-DIRECTOR','APPROVER','SECURITY-PAYMENTS',start,finish,'GOV','BOARD:S','SECURITY')~seal), 'security approver grant'
call must profile~addGrant(.InstitutionalPolicyAuthorityGrant~new('G-FIN','FINANCE-DIRECTOR','APPROVER','SECURITY-PAYMENTS',start,finish,'GOV','BOARD:F','FINANCE')~seal), 'finance approver grant'
call must profile~addGrant(.InstitutionalPolicyAuthorityGrant~new('G-PUB','RELEASE-BOT','PUBLISHER','SECURITY-PAYMENTS',start,finish,'OPS','DEPLOY')~seal), 'publisher grant'
rule = .InstitutionalPolicyAuthorityRule~new('R-PAY','SECURITY-PAYMENTS',.true,'OPTIONAL')
call must rule~addApprovalRequirement(.InstitutionalPolicyApprovalRequirement~new('SECURITY-SIGNOFF','SECURITY',1,'REQUIRED',.true)~seal), 'security requirement'
call must rule~addApprovalRequirement(.InstitutionalPolicyApprovalRequirement~new('FINANCE-SIGNOFF','FINANCE',1,'REQUIRED',.true)~seal), 'finance requirement'
call must profile~addRule(rule~seal), 'multi-party rule'
ignored = profile~seal

policy = .InstitutionalPolicyRelease~new('SECURITY-PAYMENTS','3.0',now,.nil,'POLICY-ENGINEER','PRIMARY-APPROVER','',.nil,'PAYLOAD-3')~seal
secApproval = .InstitutionalPolicyApprovalAttestation~new('A-SEC',policy~policyId,policy~version,policy~semanticIdentity,'SECURITY-DIRECTOR',now,'WORKFLOW','SEC-44')~seal
finApproval = .InstitutionalPolicyApprovalAttestation~new('A-FIN',policy~policyId,policy~version,policy~semanticIdentity,'FINANCE-DIRECTOR',now,'WORKFLOW','FIN-91')~seal
request = .InstitutionalPolicyPublicationRequest~new(policy,'RELEASE-BOT',now)
ignored = request~addApproval(secApproval)
ignored = request~addApproval(finApproval)
evaluator = .InstitutionalPolicyAuthorityEvaluator~new(profile,.AllEvidenceVerifier~new)
decision = evaluator~evaluate(policy,request)
call assertTrue decision~ok,'Security + Finance approval succeeds'
sels = decision~approvalSelections
call assertEqual 2,sels~items,'two approval selections retained'
call assertEqual 'VERIFIED_APPROVAL_EVIDENCE',decision~assuranceMode,'verified multi-party assurance'

missing = .InstitutionalPolicyPublicationRequest~new(policy,'RELEASE-BOT',now)
ignored = missing~addApproval(secApproval)
missingResult = evaluator~evaluate(policy,missing)
call assertTrue \missingResult~ok,'missing Finance approval rejected'
call assertEqual 'APPROVAL_REQUIREMENT_UNSATISFIED',missingResult~code,'missing requirement code'


alt = .InstitutionalPolicyPublicationRequest~new(policy,'RELEASE-BOT',now)
ignored = alt~addApproval(finApproval)
ignored = alt~addApproval(secApproval)
altDecision = evaluator~evaluate(policy,alt)
call assertTrue altDecision~ok,'reversed approval arrival order succeeds'
call assertEqual decision~canonicalText,altDecision~canonicalText,'authority decision is independent of approval arrival order'

say 'PASS test_authority_multiparty'
exit 0
must: procedure
  use arg r,l
  if \r~ok then do; say 'FAIL:' l r~code r~detail; exit 1; end
  return
assertTrue: procedure
  use arg v,l
  if v = .false then do; say 'FAIL:' l; exit 1; end
  return
assertEqual: procedure
  use arg e,a,l
  if e <> a then do; say 'FAIL:' l 'expected='e 'actual='a; exit 1; end
  return
::class AllEvidenceVerifier public
::method verify
  use arg attestation, policy, profile
  if attestation~matches(policy) = .false then return .InstitutionalPolicyEvidenceVerification~new(.false,'MISMATCH')
  return .InstitutionalPolicyEvidenceVerification~new(.true,'VERIFIED','workflow evidence accepted',attestation~evidenceIdentity)
::requires 'InstitutionalPolicy.cls'
