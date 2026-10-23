intervention = .TestNarrativeFixture~intervention
/* A positive governance decision cannot itself be sealed without managed policy.
   Prove the source boundary remains fail closed before projection. */
rules = .BrandInterventionGovernanceRuleSet~new("TEST-RULES", 45, 25, .true, .true)
rules~seal
recommendation = .BrandInterventionGovernanceRecommendation~new("REC-UNMANAGED", .BrandInterventionGovernanceConstant~DISPOSITION_CONTROLLED_PILOT, .BrandInterventionConstant~KIND_TONE, "PROMISING_ASSOCIATION", 5, 25, .TestGovernanceBinding~new, rules)
recommendation~addRationale("TEST")
recommendation~addCondition("NAMED_EXTERNAL_AUTHORITY_REQUIRED")
recommendation~addProhibition("AUTOMATIC_EXECUTION")
recommendation~seal
authority = .BrandInterventionGovernanceAuthority~new("AUTH-TEST", "HUMAN_REVIEW_BOARD", .BrandInterventionConstant~KIND_TONE)
decision = .BrandInterventionGovernanceDecision~new("GOV-UNMANAGED", recommendation, authority, "APPROVE_CONTROLLED_PILOT", "GOVERNANCE_DECISION:UNMANAGED", "2026-10-09T18:00:00Z")
sealed = decision~seal
if sealed~ok then signal fail
if sealed~code \== "POSITIVE_DECISION_REQUIRES_OPERATIVE_POLICY_SELECTION" then signal fail
say "PASS unmanaged positive narrative change blocked at governance boundary"
exit 0
fail:
say "FAIL unmanaged positive boundary"
exit 1
::requires "TestBrandNarrativeFixtures.cls"
