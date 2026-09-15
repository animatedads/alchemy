call addPath
catalog = .FederationBankCasePolicyFixtures~publishedCatalog
engine = .RelationshipCaseEngine~new(catalog)
now = .DateTime~new
r = engine~openCase(.RelationshipCaseOpenRequest~new("CASE-1", "SERVICE_CASE", "STAFF-1", "TELLER", now))
.RelationshipCaseTestSupport~assertTrue(r~ok, "open service case")
c = r~value
.RelationshipCaseTestSupport~assertEqual("NEW", c~state, "policy initial state")
tr = engine~transition(c, .RelationshipCaseCommand~new("CMD-1", "START_TRIAGE", "STAFF-1", "TELLER", now + .TimeSpan~new(0,0,0,0,1)))
.RelationshipCaseTestSupport~assertTrue(tr~ok, "triage transition")
.RelationshipCaseTestSupport~assertEqual("TRIAGE", c~state, "triage state")
.RelationshipCaseTestSupport~assertTrue(c~events~items = 2, "open+transition events")
.RelationshipCaseTestSupport~assertTrue(c~events[2]~policyIdentity <> "", "event carries exact policy identity")
say "PASS test_policy_driven_case"
exit 0
addPath: return
::requires "TestSupport.cls"
::requires "FederationBankCasePolicyFixtures.cls"
::requires "RelationshipCase.cls"
::requires "InstitutionalPolicy.cls"
