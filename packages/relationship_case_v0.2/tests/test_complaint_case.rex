catalog = .FederationBankCasePolicyFixtures~publishedCatalog
engine = .RelationshipCaseEngine~new(catalog)
now = .DateTime~new
r = engine~openCase(.RelationshipCaseOpenRequest~new("CASE-COMP-1", "COMPLAINT", "STAFF-1", "TELLER", now))
.RelationshipCaseTestSupport~assertTrue(r~ok, "open complaint")
c = r~value
.RelationshipCaseTestSupport~assertEqual("HIGH", c~priority, "complaint priority policy")
interaction = .RelationshipCaseElement~new("EL-I", "INTERACTION", "BRANCH_COMPLAINT", "ORIGINATING_INTERACTION", "INTERACTION_EVENT", "INTERACTION_EVENT:INT-1", "EVIDENCE", now, "INTERNAL")~seal
.RelationshipCaseTestSupport~assertTrue(engine~attachElement(c, interaction, "STAFF-1", "TELLER", now)~ok, "interaction reference")
.RelationshipCaseTestSupport~assertTrue(engine~transition(c, .RelationshipCaseCommand~new("C1", "START_TRIAGE", "STAFF-1", "TELLER", now))~ok, "complaint triage")
.RelationshipCaseTestSupport~assertTrue(engine~transition(c, .RelationshipCaseCommand~new("C2", "START_INVESTIGATION", "STAFF-2", "COMPLAINTS", now))~ok, "complaint investigation requires interaction")
.RelationshipCaseTestSupport~assertEqual("INVESTIGATION", c~state, "complaint investigation")
denied = engine~transition(c, .RelationshipCaseCommand~new("C3", "RECORD_OUTCOME", "STAFF-2", "COMPLAINTS", now))
.RelationshipCaseTestSupport~assertTrue(\denied~ok, "outcome needs assessment")
assessment = .RelationshipCaseElement~new("EL-A", "ASSESSMENT", "SERVICE_FAILURE", "ASSESSMENT", "FB_OPERATIONS", "ASSESSMENT:OPS-1", "PROFESSIONAL_ASSESSMENT", now, "INTERNAL")~seal
engine~attachElement(c, assessment, "STAFF-2", "COMPLAINTS", now)
.RelationshipCaseTestSupport~assertTrue(engine~transition(c, .RelationshipCaseCommand~new("C4", "RECORD_OUTCOME", "STAFF-2", "COMPLAINTS", now))~ok, "outcome after assessment")
comm = .RelationshipCaseElement~new("EL-C", "COMMUNICATION", "CUSTOMER_FINAL_RESPONSE", "CUSTOMER_COMMUNICATION", "INTERACTION_EVENT", "INTERACTION_EVENT:INT-2", "EVIDENCE", now, "INTERNAL")~seal
engine~attachElement(c, comm, "STAFF-2", "COMPLAINTS", now)
.RelationshipCaseTestSupport~assertTrue(engine~transition(c, .RelationshipCaseCommand~new("C5", "RECORD_CUSTOMER_COMMUNICATION", "STAFF-2", "COMPLAINTS", now))~ok, "resolve after communication")
.RelationshipCaseTestSupport~assertEqual("RESOLVED", c~state, "complaint resolved")
say "PASS test_complaint_case"
exit 0
::requires "TestSupport.cls"
::requires "FederationBankCasePolicyFixtures.cls"
::requires "RelationshipCase.cls"
::requires "InstitutionalPolicy.cls"
