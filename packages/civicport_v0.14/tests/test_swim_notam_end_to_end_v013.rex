parse source . . here
call directory here

store = "tmp_swim_notam_e2e_store"
journalRoot = "tmp_swim_notam_e2e_journal"
"rm -rf" store journalRoot

call assertEqual "0.1-dev7-fb1", .CivicQueueIngressBuild~JMS_QUEUE_BRIDGE_VERSION, "v0.14 pins consolidated JMS bridge dev7-fb1 TEXT-compatible core"

codec = .JMSBridgeQueueCodecFactory~newCodec
manager = .ObjectQueueManager~new(store, codec)
call assertTrue manager~createQueue("FAA.SWIM.AIM_FNS", "PERMANENT", "FAA-SWIM", 0, "civicport")~ok, "queue create"
body = readBinary("fixtures/faa_swim_aim_fns_jyr.xml")
headers = .directory~new
headers["JMSMESSAGEID"] = "ID:JYR:NOTAM:E2E"
message = .JMSBridgeMessage~new("ID:JYR:NOTAM:E2E", "TEXT", body, headers, .directory~new, "SOLACE", "AIM_FNS")
options = .table~new
options["persistent"] = .true
options["sourceManager"] = "JMS:faa-swim"
call assertTrue manager~acceptTransfer("jms:faa-swim:ID:JYR:NOTAM:E2E", "FAA.SWIM.AIM_FNS", message, options, "civicport")~ok, "bridge package accepted"

journal = .CivicQueueJournal~new(journalRoot)
ingested = .CivicQueueIngestor~new(manager, journal, "FAA.SWIM.AIM_FNS", "civicport", "NOT_FOR_OPERATIONAL_USE")~pumpOne
call assertTrue ingested~ok, "queue evidence ingested"
call assertEqual "JOURNALLED_ACKED", ingested~code, "journal before ACK result"

queueDocument = ingested~record~document
swim = .CivicSwimXmlAdapter~new~parse(queueDocument)
call assertTrue swim~ok, "journalled queue evidence parsed as rich XML"
simple = .CivicAimFnsSimpleTextAdapter~new~project(swim~document)
call assertTrue simple~ok, "AIM FNS simpleText projected"
notam = .CivicNotamRunwayClosureAdapter~new~project(simple~projection)
call assertTrue notam~ok, "NOTAM runway closure projected from durable queue evidence"
call assertEqual "JYR", notam~projection~affectedLocation, "affected location survives full pipeline"
call assertEqual "17/35", notam~projection~runwayDesignator, "runway survives full pipeline"
call assertEqual "CLSD", notam~projection~condition, "condition survives full pipeline"
call assertEqual queueDocument~evidenceIdentity, notam~projection~provenance["queueEvidenceIdentity"], "NOTAM provenance reaches exact queue evidence"
call assertEqual "EVIDENCE_ONLY_NOT_FOR_OPERATIONAL_USE", notam~projection~operationalDisposition, "full pipeline remains non-operational evidence"

say "PASS test_swim_notam_end_to_end_v013"
"rm -rf" store journalRoot
exit 0

::requires "TestSupport.cls"
::requires "CivicQueueIngress.cls"
::requires "CivicNotam.cls"
