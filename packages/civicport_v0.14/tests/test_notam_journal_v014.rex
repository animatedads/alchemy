parse source . . here
call directory here

root = civicTestTempDir("civic_notam_journal_v014")
journal = .CivicQueueJournal~new(root)
body = readBinary("fixtures/faa_swim_aim_fns_jyr.xml")
validDoc = civicNotamTestQueueDocument(body, "ID:NOTAM:JOURNAL:VALID")
validAppend = journal~append(validDoc)
call assertTrue validAppend~ok, "valid SWIM evidence journalled"

unsupportedBody = body~changestr("RWY 17/35 CLSD", "TWY A CLSD")
unsupportedDoc = civicNotamTestQueueDocument(unsupportedBody, "ID:NOTAM:JOURNAL:UNSUPPORTED")
unsupportedAppend = journal~append(unsupportedDoc)
call assertTrue unsupportedAppend~ok, "unsupported SWIM evidence remains durably journalled"
call assertEqual 2, journal~count, "journal retains both source records"

projector = .CivicNotamJournalProjector~new
scan = projector~scan(journal)
call assertEqual 1, scan~projectedCount, "typed runway relation candidate contains one supported projection"
call assertEqual 1, scan~diagnosticCount, "unsupported source remains explicit diagnostic"
projected = scan~projections[1]
call assertEqual validAppend~record~recordId, projected~recordId, "projection retains exact queue journal record"
call assertEqual validDoc~sourceIdentity, projected~sourceIdentity, "projection retains exact source identity"
call assertEqual "17/35", projected~projection~runwayDesignator, "journal projection carries narrow NOTAM semantics"
call assertEqual "EVIDENCE_ONLY_NOT_FOR_OPERATIONAL_USE", projected~projection~operationalDisposition, "journal projection remains non-operational"

diag = scan~diagnostics[1]
call assertEqual unsupportedAppend~record~recordId, diag~recordId, "diagnostic points to unsupported journal record"
call assertEqual "NOTAM_RUNWAY_CLOSURE", diag~stage, "diagnostic records semantic projection stage"
call assertEqual "NOTAM_KEYWORD_UNSUPPORTED", diag~errorCode, "unsupported taxiway form is not silently dropped"

bySource = projector~projectSource(journal, validDoc~sourceIdentity)
call assertTrue bySource~ok, "exact source identity projects"
call assertEqual validAppend~record~recordId, bySource~journalProjection~recordId, "source lookup remains journal-pinned"
missing = projector~projectSource(journal, "JMS:missing")
call assertTrue \missing~ok, "unknown source identity fails closed"
call assertEqual "SOURCE_IDENTITY_NOT_FOUND", missing~errorCode, "unknown source diagnostic explicit"

say "PASS test_notam_journal_v014"
call civicTestRemoveTree root
exit 0

::requires "TestSupport.cls"
::requires "CacheTestSupport.cls"
::requires "NotamTestSupport.cls"
::requires "CivicNotamJournal.cls"
