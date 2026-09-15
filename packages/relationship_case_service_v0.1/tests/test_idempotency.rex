catalog = .FederationBankCasePolicyFixtures~publishedCatalog
service = .RelationshipCaseService~new(catalog)
p = .directory~new; p["caseId"] = "IDEM-1"; p["caseType"] = "SERVICE_CASE"
cmd = .RelationshipCaseServiceEnvelope~new("IDEMPOTENT-CMD", "CASE.OPEN", "STAFF-A", "SERVICE", p)
r1 = service~handle(cmd)
.RelationshipCaseServiceTestSupport~assertTrue(r1~ok, "first command")
r2 = service~handle(cmd)
.RelationshipCaseServiceTestSupport~assertTrue(r2~ok, "replay succeeds")
.RelationshipCaseServiceTestSupport~assertEqual("IDEMPOTENT_REPLAY", r2~code, "replay code")
.RelationshipCaseServiceTestSupport~assertEqual(1, service~state~auditEvents~items, "replay does not duplicate event")
conflict = .RelationshipCaseServiceEnvelope~new("IDEMPOTENT-CMD", "CASE.OPEN", "STAFF-B", "SERVICE", p)
r3 = service~handle(conflict)
.RelationshipCaseServiceTestSupport~assertTrue(\r3~ok, "same id different actor rejected")
.RelationshipCaseServiceTestSupport~assertEqual("COMMAND_ID_CONFLICT", r3~code, "conflict code")
say "PASS test_idempotency"
exit 0
::requires "TestSupport.cls"
::requires "FederationBankCasePolicyFixtures.cls"
::requires "RelationshipCaseService.cls"
::requires "InstitutionalPolicy.cls"
