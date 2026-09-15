catalog = .FederationBankCasePolicyFixtures~publishedCatalog
sink = .RelationshipCaseMemoryEventSink~new
service = .RelationshipCaseService~new(catalog, .nil, .nil, sink)
now = .DateTime~new
p = .directory~new; p["caseId"] = "SVC-C-1"; p["caseType"] = "COMPLAINT"
open = .RelationshipCaseServiceEnvelope~new("CMD-OPEN-1", "CASE.OPEN", "STAFF-1", "COMPLAINTS", p, "CORR-1", "", now)
reply = service~handle(open)
.RelationshipCaseServiceTestSupport~assertTrue(reply~ok, "open through service")
.RelationshipCaseServiceTestSupport~assertEqual("SVC-C-1", reply~caseId, "open case id")
subject = .RelationshipCaseElement~new("EL-SUB-1", "SUBJECT", "CUSTOMER", "SUBJECT_OF", "CRM", "CRM:CUSTOMER:42", "CRM_REFERENCE", now, "INTERNAL")~seal
ap = .directory~new; ap["caseId"] = "SVC-C-1"; ap["element"] = subject
attach = .RelationshipCaseServiceEnvelope~new("CMD-ATTACH-1", "CASE.ATTACH_ELEMENT", "STAFF-1", "COMPLAINTS", ap, "CORR-1", "CMD-OPEN-1", now)
reply = service~handle(attach)
.RelationshipCaseServiceTestSupport~assertTrue(reply~ok, "attach CRM subject reference")
tp = .directory~new; tp["caseId"] = "SVC-C-1"; tp["action"] = "START_TRIAGE"
reply = service~handle(.RelationshipCaseServiceEnvelope~new("CMD-TRIAGE-1", "CASE.TRANSITION", "STAFF-1", "COMPLAINTS", tp, "CORR-1", "CMD-ATTACH-1", now))
.RelationshipCaseServiceTestSupport~assertTrue(reply~ok, "transition")
.RelationshipCaseServiceTestSupport~assertEqual("TRIAGE", reply~value~state, "triage state")
q = .directory~new; q["caseId"] = "SVC-C-1"; q["viewerRole"] = "TELLER"
get = service~handle(.RelationshipCaseServiceEnvelope~new("CMD-GET-1", "CASE.GET", "TELLER-2", "TELLER", q, "CORR-GET", "", now))
.RelationshipCaseServiceTestSupport~assertTrue(get~ok, "policy projected get")
.RelationshipCaseServiceTestSupport~assertEqual("COMPLAINT", get~value~caseType, "visible complaint type")
sp = .directory~new; sp["sourceSystem"] = "CRM"; sp["sourceRef"] = "CRM:CUSTOMER:42"; sp["viewerRole"] = "TELLER"
bySubject = service~handle(.RelationshipCaseServiceEnvelope~new("CMD-SUBJECT-1", "CASE.FOR_SUBJECT", "TELLER-2", "TELLER", sp))
.RelationshipCaseServiceTestSupport~assertTrue(bySubject~ok, "subject lookup")
.RelationshipCaseServiceTestSupport~assertEqual(1, bySubject~value~items, "one case for CRM subject")
.RelationshipCaseServiceTestSupport~assertEqual(3, sink~events~items, "three committed mutation events")
.RelationshipCaseServiceTestSupport~assertTrue(sink~events[1]~policyIdentity <> "", "service event retains exact policy identity")
say "PASS test_service_commands"
exit 0
::requires "TestSupport.cls"
::requires "FederationBankCasePolicyFixtures.cls"
::requires "RelationshipCaseService.cls"
::requires "InstitutionalPolicy.cls"
