catalog = .FederationBankCasePolicyFixtures~publishedCatalog
repo = .RelationshipCaseRepository~new
engine = .RelationshipCaseEngine~new(catalog, .nil, repo)
now = .DateTime~new
ids = .array~of("C-COMPLAINT", "C-EXTERNAL", "C-SERVICE")
types = .array~of("COMPLAINT", "EXTERNAL_PRESSURE", "SERVICE_CASE")
do i = 1 to ids~items
  r = engine~openCase(.RelationshipCaseOpenRequest~new(ids[i], types[i], "STAFF", "COMPLIANCE", now))
  .RelationshipCaseTestSupport~assertTrue(r~ok, "open case " || ids[i])
  el = .RelationshipCaseElement~new("SUB-" || i, "SUBJECT", "CUSTOMER", "SUBJECT_OF", "FEDERATIONBANK_CORE", "CUSTOMER:42", "IDENTITY_REFERENCE", now, "INTERNAL")~seal
  engine~attachElement(r~value, el, "STAFF", "COMPLIANCE", now)
end
cases = repo~casesForSubject("FEDERATIONBANK_CORE", "CUSTOMER:42")
.RelationshipCaseTestSupport~assertEqual(3, cases~items, "same customer retains distinct concurrent cases")
.RelationshipCaseTestSupport~assertEqual("C-COMPLAINT", cases[1]~caseId, "stable index order")
.RelationshipCaseTestSupport~assertTrue(cases[1]~state = "NEW" & cases[2]~state = "NEW" & cases[3]~state = "NEW", "no global customer case status")
say "PASS test_multiple_cases_same_subject"
exit 0
::requires "TestSupport.cls"
::requires "FederationBankCasePolicyFixtures.cls"
::requires "RelationshipCase.cls"
::requires "InstitutionalPolicy.cls"
