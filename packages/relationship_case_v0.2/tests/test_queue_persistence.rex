catalog = .FederationBankCasePolicyFixtures~publishedCatalog
repo = .RelationshipCaseRepository~new
engine = .RelationshipCaseEngine~new(catalog, .nil, repo)
now = .DateTime~new
opened = engine~openCase(.RelationshipCaseOpenRequest~new("PERSIST-1", "COMPLAINT", "A1", "COMPLAINTS", now))
.RelationshipCaseTestSupport~assertTrue(opened~ok, "open")
c = opened~value
subject = .RelationshipCaseElement~new("SUB-PERSIST", "SUBJECT", "CUSTOMER", "SUBJECT_OF", "CRM", "CUSTOMER:88", "IDENTITY_REFERENCE", now, "INTERNAL")~seal
.RelationshipCaseTestSupport~assertTrue(engine~attachElement(c, subject, "A1", "COMPLAINTS", now)~ok, "attach")
codec = .RelationshipCaseQueuePersistenceSupport~newCodec
graph = codec~encode(c)
restored = codec~decode(graph)
.RelationshipCaseTestSupport~assertEqual("PERSIST-1", restored~caseId, "case id")
.RelationshipCaseTestSupport~assertEqual(c~revision, restored~revision, "revision")
.RelationshipCaseTestSupport~assertEqual(c~events~items, restored~events~items, "events")
.RelationshipCaseTestSupport~assertEqual("CUSTOMER:88", restored~elements[1]~sourceRef, "subject ref")
repo2 = .RelationshipCaseRepository~new
.RelationshipCaseTestSupport~assertTrue(repo2~add(restored)~ok, "reindex restored case")
.RelationshipCaseTestSupport~assertEqual(1, repo2~casesForSubject("CRM", "CUSTOMER:88")~items, "restored subject index")
engine2 = .RelationshipCaseEngine~new(catalog, .nil, repo2)
cmd = .RelationshipCaseCommand~new("CMD-RESTART", "START_TRIAGE", "A1", "COMPLAINTS", .DateTime~new)
.RelationshipCaseTestSupport~assertTrue(engine2~transition(restored, cmd)~ok, "post-restart transition")
.RelationshipCaseTestSupport~assertEqual(3, restored~events~items, "post-restart event appended")
.RelationshipCaseTestSupport~assertEqual("PERSIST-1:EV:3:STATE_CHANGED", restored~events[3]~eventId, "event id remains collision-free")
say "PASS test_queue_persistence"
exit 0
::requires "TestSupport.cls"
::requires "FederationBankCasePolicyFixtures.cls"
::requires "RelationshipCaseQueuePersistence.cls"
::requires "InstitutionalPolicy.cls"
