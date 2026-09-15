now = .DateTime~new
start = now - .TimeSpan~new(0,0,1,0,0)
finish = now + .TimeSpan~new(0,1,0,0,0)

profile = .InstitutionalPolicyAuthorityProfile~new("LOGGING-GOVERNANCE", "1.0", start, finish)
call must profile~addGrant(.InstitutionalPolicyAuthorityGrant~new("G-AUTH", "ALICE", "AUTHOR", "WEBSITE-LOGGING", start, finish, "POLICY-BOARD", "HR:ALICE")~seal), "author grant"
call must profile~addGrant(.InstitutionalPolicyAuthorityGrant~new("G-APPROVE", "BOB", "APPROVER", "WEBSITE-LOGGING", start, finish, "POLICY-BOARD", "BOARD:BOB")~seal), "approver grant"
call must profile~addGrant(.InstitutionalPolicyAuthorityGrant~new("G-PUBLISH", "RELEASE-BOT", "PUBLISHER", "WEBSITE-LOGGING", start, finish, "OPS-BOARD", "DEPLOY:RELEASE-BOT")~seal), "publisher grant"
call must profile~addRule(.InstitutionalPolicyAuthorityRule~new("R-LOG", "WEBSITE-LOGGING", .true, "REQUIRED")~seal), "authority rule"
ignore = profile~seal

spec = .LogRuleSpec~new("governed-rule", "website", "WebsiteUI", "render", .Log~INTERNAL, .Log~INTERNAL, .Log~INFO, .LogConditionAlways~new, .array~of("memory"))
policy = .LogRuleSetPolicy~new("WEBSITE-LOGGING", "1.0", .array~of(spec), now, .nil, "ALICE", "BOB")~seal

verifier = .LoggingPolicyEvidenceVerifier~new("APP-LOG-1")
evaluator = .InstitutionalPolicyAuthorityEvaluator~new(profile, verifier)
catalog = .LogPolicyCatalog~new(.nil, .nil, .nil, .nil, evaluator)

withoutRequest = catalog~publish(policy)
call assertFalse withoutRequest~ok, "authority-governed logging policy cannot publish without publisher request"

approval = .InstitutionalPolicyApprovalAttestation~new("APP-LOG-1", policy~policyId, policy~version, policy~semanticIdentity, "BOB", now, "WORKFLOW_RECORD", "CHANGE-LOG-4242")~seal
request = .InstitutionalPolicyPublicationRequest~new(policy, "RELEASE-BOT", now)
call assertTrue request~addApproval(approval), "approval attached"
published = catalog~publish(policy, request)
call assertTrue published~ok, "authorized logging policy publication succeeds"
record = catalog~publicationRecord(policy~policyId, policy~version)~value
call assertEq "RELEASE-BOT", record~publisherId, "publisher retained"
call assertEq "G-AUTH", record~authorityDecision~authorGrantId, "author grant retained"
call assertEq "G-APPROVE", record~authorityDecision~approverGrantId, "approver grant retained"
call assertEq "G-PUBLISH", record~authorityDecision~publisherGrantId, "publisher grant retained"
call assertEq profile~semanticIdentity, record~authorityDecision~authorityProfileIdentity, "exact governance profile identity retained"
call assertEq policy~semanticIdentity, record~policyIdentity, "exact logging policy identity retained"

say "LOG_POLICY_PUBLICATION authority_profile=PASS approval_evidence=PASS separation_of_duties=ENFORCED"
say "PASS test_policy_publication_authority"
exit 0

must: procedure
  use strict arg resultObject, label
  if \resultObject~ok then raise syntax 88.900 array("setup failed:" label resultObject~code resultObject~detail)
  return
assertTrue: procedure
  use strict arg actual, message
  if actual \= .true then raise syntax 88.900 array("assertTrue failed:" message)
  return
assertFalse: procedure
  use strict arg actual, message
  if actual \= .false then raise syntax 88.900 array("assertFalse failed:" message)
  return
assertEq: procedure
  use strict arg expected, actual, message
  if expected \== actual then raise syntax 88.900 array("assertEq failed:" message "expected="expected "actual="actual)
  return

::class LoggingPolicyEvidenceVerifier public
::attribute acceptedAttestationId get
::method init
  expose acceptedAttestationId
  use strict arg id
  acceptedAttestationId = id~string
::method verify
  expose acceptedAttestationId
  use strict arg attestation, policy, profile
  if attestation == .nil then return .InstitutionalPolicyEvidenceVerification~new(.false, "NO_ATTESTATION")
  if attestation~attestationId \= acceptedAttestationId then return .InstitutionalPolicyEvidenceVerification~new(.false, "EVIDENCE_REJECTED")
  if \attestation~matches(policy, policy~approvedBy) then return .InstitutionalPolicyEvidenceVerification~new(.false, "EVIDENCE_POLICY_MISMATCH")
  return .InstitutionalPolicyEvidenceVerification~new(.true, "VERIFIED", "trusted logging policy workflow", attestation~evidenceIdentity)

::requires "LoggingPolicy.cls"
