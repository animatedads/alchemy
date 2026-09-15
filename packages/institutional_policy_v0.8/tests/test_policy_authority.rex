now = .DateTime~new
start = now - .TimeSpan~new(0,0,1,0,0)
finish = now + .TimeSpan~new(0,1,0,0,0)

profile = .InstitutionalPolicyAuthorityProfile~new('MAIN-GOVERNANCE','2.0',start,finish)
call must profile~addGrant(.InstitutionalPolicyAuthorityGrant~new('G-AUTH','ALICE','AUTHOR','SECURITY-COMMERCE',start,finish,'POLICY-BOARD','HR:ALICE')~seal), 'author grant'
call must profile~addGrant(.InstitutionalPolicyAuthorityGrant~new('G-APPROVE','BOB','APPROVER','SECURITY-COMMERCE',start,finish,'POLICY-BOARD','BOARD:BOB')~seal), 'approver grant'
call must profile~addGrant(.InstitutionalPolicyAuthorityGrant~new('G-PUBLISH','RELEASE-BOT','PUBLISHER','SECURITY-COMMERCE',start,finish,'OPS-BOARD','DEPLOY:RELEASE-BOT')~seal), 'publisher grant'
call must profile~addRule(.InstitutionalPolicyAuthorityRule~new('R-SEC','SECURITY-COMMERCE',.true,'REQUIRED')~seal), 'authority rule'
ignored = profile~seal

profileReordered = .InstitutionalPolicyAuthorityProfile~new('MAIN-GOVERNANCE','2.0',start,finish)
call must profileReordered~addRule(.InstitutionalPolicyAuthorityRule~new('R-SEC','SECURITY-COMMERCE',.true,'REQUIRED')~seal), 'reordered rule'
call must profileReordered~addGrant(.InstitutionalPolicyAuthorityGrant~new('G-PUBLISH','RELEASE-BOT','PUBLISHER','SECURITY-COMMERCE',start,finish,'OPS-BOARD','DEPLOY:RELEASE-BOT')~seal), 'reordered publisher grant'
call must profileReordered~addGrant(.InstitutionalPolicyAuthorityGrant~new('G-APPROVE','BOB','APPROVER','SECURITY-COMMERCE',start,finish,'POLICY-BOARD','BOARD:BOB')~seal), 'reordered approver grant'
call must profileReordered~addGrant(.InstitutionalPolicyAuthorityGrant~new('G-AUTH','ALICE','AUTHOR','SECURITY-COMMERCE',start,finish,'POLICY-BOARD','HR:ALICE')~seal), 'reordered author grant'
ignored = profileReordered~seal
call assertEqual profile~semanticIdentity,profileReordered~semanticIdentity,'authority profile identity is insertion-order independent'

policy = .InstitutionalPolicyRelease~new('SECURITY-COMMERCE','1.0',now,.nil,'ALICE','BOB','',.nil,'SECURITY-PAYLOAD-A')~seal
approval = .InstitutionalPolicyApprovalAttestation~new('APP-1',policy~policyId,policy~version,policy~semanticIdentity,'BOB',now,'WORKFLOW_RECORD','CHANGE-4242')~seal
request = .InstitutionalPolicyPublicationRequest~new(policy,'RELEASE-BOT',now)
call assertTrue request~addApproval(approval), 'approval accepted into request'
verifier = .TestPolicyEvidenceVerifier~new('APP-1')
evaluator = .InstitutionalPolicyAuthorityEvaluator~new(profile,verifier)
catalog = .InstitutionalPolicyCatalog~new(.nil,.nil,.nil,.nil,evaluator)
result = catalog~publish(policy,request)
call assertTrue result~ok, 'authorized publication succeeds'
recordResult = catalog~publicationRecord(policy~policyId,policy~version)
call assertTrue recordResult~ok, 'publication record exists'
record = recordResult~value
call assertEqual 'VERIFIED_APPROVAL_EVIDENCE',record~assuranceMode,'verified approval assurance recorded'
call assertEqual 'RELEASE-BOT',record~publisherId,'publisher recorded'
call assertEqual 'G-AUTH',record~authorityDecision~authorGrantId,'author grant snapshotted'
call assertEqual 'G-APPROVE',record~authorityDecision~approverGrantId,'approver grant snapshotted'
call assertEqual 'G-PUBLISH',record~authorityDecision~publisherGrantId,'publisher grant snapshotted'
call assertEqual profile~semanticIdentity,record~authorityDecision~authorityProfileIdentity,'exact authority profile identity snapshotted'
call assertEqual 1,record~authorityDecision~approvalEvidenceIdentities~items,'verified evidence retained'

wrongPublisherPolicy = .InstitutionalPolicyRelease~new('SECURITY-COMMERCE','1.1',finish,.nil,'ALICE','BOB','1.0',.nil,'SECURITY-PAYLOAD-B')~seal
wrongReq = .InstitutionalPolicyPublicationRequest~new(wrongPublisherPolicy,'MALLORY',now)
wrongApproval = .InstitutionalPolicyApprovalAttestation~new('APP-2',wrongPublisherPolicy~policyId,wrongPublisherPolicy~version,wrongPublisherPolicy~semanticIdentity,'BOB',now,'WORKFLOW_RECORD','CHANGE-4243')~seal
ignored = wrongReq~addApproval(wrongApproval)
wrongResult = evaluator~evaluate(wrongPublisherPolicy,wrongReq)
call assertTrue \wrongResult~ok,'unauthorized publisher denied'
call assertEqual 'PUBLISHER_AUTHORITY_DENIED',wrongResult~code,'publisher denial code'

sameActorPolicy = .InstitutionalPolicyRelease~new('SECURITY-COMMERCE','1.2',finish,.nil,'ALICE','ALICE','1.0',.nil,'SECURITY-PAYLOAD-C')~seal
sameReq = .InstitutionalPolicyPublicationRequest~new(sameActorPolicy,'RELEASE-BOT',now)
sameResult = evaluator~evaluate(sameActorPolicy,sameReq)
call assertTrue \sameResult~ok,'author cannot self-approve under rule'
call assertEqual 'AUTHOR_APPROVER_MUST_BE_DISTINCT',sameResult~code,'separation of duties code'

missingEvidencePolicy = .InstitutionalPolicyRelease~new('SECURITY-COMMERCE','1.3',finish,.nil,'ALICE','BOB','1.0',.nil,'SECURITY-PAYLOAD-D')~seal
missingReq = .InstitutionalPolicyPublicationRequest~new(missingEvidencePolicy,'RELEASE-BOT',now)
missingResult = evaluator~evaluate(missingEvidencePolicy,missingReq)
call assertTrue \missingResult~ok,'required approval evidence enforced'
call assertEqual 'APPROVAL_EVIDENCE_NOT_VERIFIED',missingResult~code,'missing evidence code'

reusedReq = .InstitutionalPolicyPublicationRequest~new(missingEvidencePolicy,'RELEASE-BOT',now)
call assertTrue reusedReq~addApproval(approval),'old approval can be supplied as evidence object'
reusedResult = evaluator~evaluate(missingEvidencePolicy,reusedReq)
call assertTrue \reusedResult~ok,'approval for old semantic identity cannot authorize changed policy'
call assertEqual 'APPROVAL_EVIDENCE_NOT_VERIFIED',reusedResult~code,'stale approval rejected'

say 'PASS test_policy_authority'
exit 0

must: procedure
  use arg result,label
  if result~ok = .false then do; say 'FAIL:' label result~code result~detail; exit 1; end
  return
assertTrue: procedure
  use arg value,label
  if value = .false then do; say 'FAIL:' label; exit 1; end
  return
assertEqual: procedure
  use arg expected,actual,label
  if expected <> actual then do; say 'FAIL:' label 'expected='expected 'actual='actual; exit 1; end
  return

::class TestPolicyEvidenceVerifier public
::attribute acceptedAttestationId get
::method init
  expose acceptedAttestationId
  use arg id
  acceptedAttestationId = id~string
::method verify
  expose acceptedAttestationId
  use arg attestation, policy, profile
  if attestation == .nil then return .InstitutionalPolicyEvidenceVerification~new(.false,'NO_ATTESTATION')
  if attestation~attestationId <> acceptedAttestationId & attestation~attestationId <> 'APP-2' then return .InstitutionalPolicyEvidenceVerification~new(.false,'EVIDENCE_REJECTED')
  if attestation~matches(policy,policy~approvedBy) = .false then return .InstitutionalPolicyEvidenceVerification~new(.false,'EVIDENCE_POLICY_MISMATCH')
  return .InstitutionalPolicyEvidenceVerification~new(.true,'VERIFIED','trusted host workflow record',attestation~evidenceIdentity)

::requires 'InstitutionalPolicy.cls'
