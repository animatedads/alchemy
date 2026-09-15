parse source . . here
call directory here
store = "tmp_swim_e2e_store"
journalRoot = "tmp_swim_e2e_journal"
"rm -rf" store journalRoot
codec = .JMSBridgeQueueCodecFactory~newCodec
manager = .ObjectQueueManager~new(store, codec)
call assertTrue manager~createQueue("FAA.SWIM.AIM_FNS", "PERMANENT", "FAA-SWIM", 0, "civicport")~ok, "queue create"
body = readBinary("fixtures/faa_swim_aim_fns_jyr.xml")
headers = .directory~new
headers["JMSMESSAGEID"] = "ID:JYR:E2E"
message = .JMSBridgeMessage~new("ID:JYR:E2E", "TEXT", body, headers, .directory~new, "SOLACE", "AIM_FNS")
options = .table~new
options["persistent"] = .true
options["sourceManager"] = "JMS:faa-swim"
call assertTrue manager~acceptTransfer("jms:faa-swim:ID:JYR:E2E", "FAA.SWIM.AIM_FNS", message, options, "civicport")~ok, "bridge package accepted"
journal = .CivicQueueJournal~new(journalRoot)
ingested = .CivicQueueIngestor~new(manager, journal, "FAA.SWIM.AIM_FNS", "civicport", "NOT_FOR_OPERATIONAL_USE")~pumpOne
call assertTrue ingested~ok, "queue evidence ingested"
queueDocument = ingested~record~document
swim = .CivicSwimXmlAdapter~new~parse(queueDocument)
call assertTrue swim~ok, "journalled queue evidence parsed as rich XML"
projected = .CivicAimFnsSimpleTextAdapter~new~project(swim~document)
call assertTrue projected~ok, "AIM FNS simpleText projected from journalled evidence"
call assertEqual "!JYR 08/001 JYR RWY 17/35 CLSD 2608261100-2608270001", projected~projection~simpleText, "JYR simpleText survives JMS->Queue->Civic journal->XML"
call assertEqual queueDocument~evidenceIdentity, projected~projection~swimDocument~queueDocument~evidenceIdentity, "end-to-end evidence identity retained"
say "PASS test_swim_queue_end_to_end_v012"
"rm -rf" store journalRoot
exit 0
::requires "TestSupport.cls"
::requires "CivicQueueIngress.cls"
::requires "CivicSwim.cls"
