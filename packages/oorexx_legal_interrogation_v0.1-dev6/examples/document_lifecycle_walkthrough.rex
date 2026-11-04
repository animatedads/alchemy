/* Small dev3 lifecycle demonstration. */
source = .directory~new
source["kind"] = "CONTRACT"
source["title"] = "Example agreement"
request = .LegalInterrogationDocumentRequest~new("WALK3", "fixture:walk3", source, "CONTRACT", "example-agreement")
docPort = .LegalInterrogationDocumentPort~new
r = docPort~begin(request)
session = r~value
say "DOCUMENT:" r~code "sourceObjectRetained=" (session~sourceObject == source)

port = .LegalInterrogationIntentionPort~new
clause = .LegalInterrogationClause~new("C1", source, "clause 1", "Customer shall pay Supplier within 30 days.")
r = port~execute(session, "INGEST_CLAUSE", clause, "SOURCE_ADAPTER", session~id)
say "INGEST:" r~code "revision=" session~revision
say "NEXT:" port~discover(session)~value~intentions[1]~name
say "NOTE: complete interrogation is exercised by tests/test_lifecycle.rex"

::requires "LegalInterrogationDocumentPort.cls"
