parse source . . here
classes = .array~of(.CivicQueueMapCodec, .CivicQueueDocument, .CivicQueueJournalRecord, .CivicQueueJournalAppendResult, .CivicQueueJournal)
do cls over classes
  call assertTrue cls~isSubclassOf(.CivicAlchemyObject), cls~id || " inherits CivicAlchemyObject"
  call assertTrue cls~isSubclassOf(.AlchemyObject), cls~id || " inherits AlchemyObject"
end
call directory here
root = "tmp_queue_journal_v012"
"rm -rf" root
body = readBinary("fixtures/faa_swim_aim_fns_jyr.xml")
digestPort = .CivicDigestPort~new
headers = .directory~new
headers["JMSMESSAGEID"] = "ID:SWIM:JYR:1"
headers["JMSTYPE"] = "AIM_FNS"
properties = .directory~new
properties["source"] = "AIM_NMS_Publication"
headerDigest = digestPort~sha512Bytes(.CivicQueueMapCodec~encode(headers))
propertyDigest = digestPort~sha512Bytes(.CivicQueueMapCodec~encode(properties))
bodyDigest = digestPort~sha512Bytes(body)
sourceIdentity = "JMS:" || c2x("SOLACE") || ":" || c2x("AIM_FNS") || ":" || c2x("ID:SWIM:JYR:1")
doc = .CivicQueueDocument~new(sourceIdentity, "FAA.SWIM.AIM_FNS", "QPKG-1", "ID:SWIM:JYR:1", "SOLACE", "AIM_FNS", "TEXT", body, bodyDigest, -
  headers, properties, headerDigest, propertyDigest, "2026-08-24T19:00:00Z", "2026-08-24T19:00:01Z", "2026-08-24T19:00:00Z", "CORR-1", "", 4, "NOT_FOR_OPERATIONAL_USE")

journal = .CivicQueueJournal~new(root)
first = journal~append(doc)
call assertTrue first~ok, "first queue document journal append"
call assertTrue \first~duplicate, "first append is not duplicate"
call assertEqual 1, journal~count, "journal count after first append"
call assertEqual bodyDigest, first~record~document~bodyDigest, "body digest preserved"
call assertEqual "NOT_FOR_OPERATIONAL_USE", first~record~document~useClassification, "use policy preserved"

again = journal~append(doc)
call assertTrue again~ok, "identical source redelivery accepted"
call assertTrue again~duplicate, "identical source redelivery marked duplicate"
call assertEqual first~record~recordId, again~record~recordId, "duplicate reuses durable record"
call assertEqual 1, journal~count, "duplicate does not append a second record"

changedBody = body || " "
changedDigest = digestPort~sha512Bytes(changedBody)
changed = .CivicQueueDocument~new(sourceIdentity, "FAA.SWIM.AIM_FNS", "QPKG-2", "ID:SWIM:JYR:1", "SOLACE", "AIM_FNS", "TEXT", changedBody, changedDigest, -
  headers, properties, headerDigest, propertyDigest, "2026-08-24T19:00:02Z", "2026-08-24T19:00:03Z", "2026-08-24T19:00:02Z", "CORR-1", "", 4, "NOT_FOR_OPERATIONAL_USE")
conflict = journal~append(changed)
call assertTrue \conflict~ok, "same JMS identity with changed evidence is rejected"
call assertEqual "SOURCE_IDENTITY_CONFLICT", conflict~errorCode, "identity conflict code"
call assertEqual 1, journal~count, "conflict does not append"

reloaded = .CivicQueueJournal~new(root)
call assertEqual 1, reloaded~count, "journal reload count"
restored = reloaded~recordForSource(sourceIdentity)~document
call assertEqual body, restored~bodyText, "exact persisted TextMessage string restored"
call assertEqual "AIM_NMS_Publication", restored~properties["source"], "JMS properties restored"
call assertEqual "AIM_FNS", restored~header("JMSTYPE"), "JMS headers restored"
call assertEqual doc~evidenceIdentity, restored~evidenceIdentity, "evidence identity survives restart"

say "PASS test_queue_journal_v012"
"rm -rf" root
exit 0
::requires "TestSupport.cls"
::requires "CivicQueueEvidence.cls"
