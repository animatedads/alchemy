now=.DateTime~new
start=now-.InstitutionalPolicyTime~seconds(3600)
finish=now+.InstitutionalPolicyTime~seconds(86400)
profile=.InstitutionalPolicyAuthorityProfile~new('SECURITY-COMMERCE-GOV','5.0',start,finish)
ignored=profile~addGrant(.InstitutionalPolicyAuthorityGrant~new('AUTHOR','SECURITY-POLICY-TEAM','AUTHOR','SECURITY-PAYMENT',start,finish)~seal)
ignored=profile~addGrant(.InstitutionalPolicyAuthorityGrant~new('SEC-APP','SECURITY-DIRECTOR','APPROVER','SECURITY-PAYMENT',start,finish,'BOARD','','SECURITY')~seal)
ignored=profile~addGrant(.InstitutionalPolicyAuthorityGrant~new('FIN-APP','FINANCE-DIRECTOR','APPROVER','SECURITY-PAYMENT',start,finish,'BOARD','','FINANCE')~seal)
ignored=profile~addGrant(.InstitutionalPolicyAuthorityGrant~new('PUB','SECURITY-RELEASE','PUBLISHER','SECURITY-PAYMENT',start,finish)~seal)
authRule=.InstitutionalPolicyAuthorityRule~new('PAYMENT-GOV','SECURITY-PAYMENT',.true,'OPTIONAL')
ignored=authRule~addApprovalRequirement(.InstitutionalPolicyApprovalRequirement~new('SECURITY','SECURITY',1,'REQUIRED')~seal)
ignored=authRule~addApprovalRequirement(.InstitutionalPolicyApprovalRequirement~new('FINANCE','FINANCE',1,'REQUIRED')~seal)
ignored=profile~addRule(authRule~seal)
ignored=profile~seal

framework=.SecurityPolicyFramework~new('SECURITY-PAYMENT','5.0',now,.nil,'SECURITY-POLICY-TEAM','SECURITY-DIRECTOR','')
rule=.SecurityPolicyRule~new('GOLD-HOLD',10,'PURCHASE_HIGH_VALUE_LIQUID_ASSET','HOLD','material identity uncertainty requires human confirmation')
ignored=rule~requireFinding('IDENTITY_CONTINUITY_CONCERN')
ignored=rule~addConstraint('OUT_OF_BAND_CONFIRMATION_REQUIRED')
ignored=framework~addRule(rule~seal)
ignored=framework~seal

sec=.InstitutionalPolicyApprovalAttestation~new('S-1',framework~policyId,framework~version,framework~semanticIdentity,'SECURITY-DIRECTOR',now,'WORKFLOW','SEC-100')~seal
fin=.InstitutionalPolicyApprovalAttestation~new('F-1',framework~policyId,framework~version,framework~semanticIdentity,'FINANCE-DIRECTOR',now,'WORKFLOW','FIN-200')~seal
request=.InstitutionalPolicyPublicationRequest~new(framework,'SECURITY-RELEASE',now)
ignored=request~addApproval(sec)
ignored=request~addApproval(fin)
evaluator=.InstitutionalPolicyAuthorityEvaluator~new(profile,.SecurityMultiVerifier~new)
catalog=.SecurityPolicyCatalog~new(.nil,.nil,evaluator)
published=catalog~publish(framework,request)
call assertTrue published~ok,'security payment policy requires and receives Security + Finance authority'
record=catalog~publicationRecord(framework~policyId,framework~version)~value
selections=record~authorityDecision~approvalSelections
call assertEqual 2,selections~items,'two institutional approvals snapshotted'
call assertEqual 'VERIFIED_APPROVAL_EVIDENCE',record~assuranceMode,'verified multi-party assurance retained'

missingReq=.InstitutionalPolicyPublicationRequest~new(framework,'SECURITY-RELEASE',now)
ignored=missingReq~addApproval(sec)
missing=evaluator~evaluate(framework,missingReq)
call assertTrue \missing~ok,'Finance cannot be silently omitted for payment security policy'
call assertEqual 'APPROVAL_REQUIREMENT_UNSATISFIED',missing~code,'missing Finance has explicit governance failure'

say 'PASS test_policy_multiparty_authority_integration'
exit 0
assertTrue: procedure
 use arg v,l
 if v=.false then do; say 'FAIL:' l; exit 1; end
 return
assertEqual: procedure
 use arg e,a,l
 if e<>a then do; say 'FAIL:' l 'expected='e 'actual='a; exit 1; end
 return
::class SecurityMultiVerifier public
::method verify
 use arg approval, policy, profile
 if approval~matches(policy)=.false then return .InstitutionalPolicyEvidenceVerification~new(.false,'MISMATCH')
 return .InstitutionalPolicyEvidenceVerification~new(.true,'VERIFIED','institutional workflow evidence',approval~evidenceIdentity)
::requires 'SecurityEffect.cls'
