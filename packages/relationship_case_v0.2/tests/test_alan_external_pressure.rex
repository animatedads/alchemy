catalog = .FederationBankCasePolicyFixtures~publishedCatalog
engine = .RelationshipCaseEngine~new(catalog)
now = .DateTime~new
r = engine~openCase(.RelationshipCaseOpenRequest~new("CASE-ALAN-1", "EXTERNAL_PRESSURE", "STAFF-COMP-1", "COMPLIANCE", now))
.RelationshipCaseTestSupport~assertTrue(r~ok, "open external-pressure case")
c = r~value
subject = .RelationshipCaseElement~new("EL-SUBJECT", "SUBJECT", "CUSTOMER", "SUBJECT_OF", "FEDERATIONBANK_CORE", "CUSTOMER:ALAN-SACCARIN", "IDENTITY_REFERENCE", now, "INTERNAL")~seal
.RelationshipCaseTestSupport~assertTrue(engine~attachElement(c, subject, "STAFF-COMP-1", "COMPLIANCE", now)~ok, "attach customer ref")
signal = .RelationshipCaseElement~new("EL-SIGNAL", "EXTERNAL_SIGNAL", "POLITICAL_TRADE_PRESSURE", "EXTERNAL_SIGNAL", "REPUTATION_FEED", "REPUTATION_HYPOTHESIS:H-85-TARIFF", "OBSERVATION_NOT_DECISION", now, "RESTRICTED")
signal~addTag("NO_CORE_BANKING_AUTHORITY"); signal~seal
.RelationshipCaseTestSupport~assertTrue(engine~attachElement(c, signal, "STAFF-COMP-1", "COMPLIANCE", now)~ok, "attach external signal")
.RelationshipCaseTestSupport~assertTrue(engine~transition(c, .RelationshipCaseCommand~new("A1", "START_TRIAGE", "STAFF-COMP-1", "COMPLIANCE", now))~ok, "triage")
.RelationshipCaseTestSupport~assertTrue(engine~transition(c, .RelationshipCaseCommand~new("A2", "START_SPECIALIST_REVIEW", "STAFF-COMP-1", "COMPLIANCE", now))~ok, "specialist review")
/* External pressure cannot become a banking action merely because it exists. */
denied = engine~transition(c, .RelationshipCaseCommand~new("A3", "MARK_ACTION_REQUIRED", "STAFF-COMP-1", "COMPLIANCE", now))
.RelationshipCaseTestSupport~assertTrue(\denied~ok, "external signal alone cannot require core action")
.RelationshipCaseTestSupport~assertEqual("CASE_TRANSITION_REQUIREMENT_MISSING", denied~code, "missing assessment/decision")
.RelationshipCaseTestSupport~assertTrue(\c~hasElement("ACCOUNT_CONTROL", "*"), "no account control invented")
/* A teller sees that restricted work exists without receiving its detail. */
p = engine~project(c, "TELLER", now)
.RelationshipCaseTestSupport~assertTrue(p~ok, "teller projection exists")
.RelationshipCaseTestSupport~assertTrue(p~value~shellOnly, "information barrier returns shell")
.RelationshipCaseTestSupport~assertEqual("RESTRICTED_CASE", p~value~caseType, "case type concealed")
/* Compliance sees the reference, but still only as observation. */
p = engine~project(c, "COMPLIANCE", now)
.RelationshipCaseTestSupport~assertTrue(p~ok, "compliance projection")
.RelationshipCaseTestSupport~assertTrue(\p~value~shellOnly, "compliance full case")
.RelationshipCaseTestSupport~assertTrue(p~value~elements~items >= 2, "compliance sees evidence refs")
say "PASS test_alan_external_pressure"
exit 0
::requires "TestSupport.cls"
::requires "FederationBankCasePolicyFixtures.cls"
::requires "RelationshipCase.cls"
::requires "InstitutionalPolicy.cls"
