parse source . . here
classes = .array~of(.CivicQueueBuildResult, .CivicJmsQueueDocumentFactory, .CivicQueueIngestResult, .CivicQueueIngestor)
do cls over classes
  call assertTrue cls~isSubclassOf(.CivicAlchemyObject), cls~id || " inherits CivicAlchemyObject"
  call assertTrue cls~isSubclassOf(.AlchemyObject), cls~id || " inherits AlchemyObject"
end
call directory here
store = "tmp_queue_ingress_store"
journalRoot = "tmp_queue_ingress_journal"
"rm -rf" store journalRoot

codec = .JMSBridgeQueueCodecFactory~newCodec
manager = .ObjectQueueManager~new(store, codec)
made = manager~createQueue("FAA.SWIM.AIM_FNS", "PERMANENT", "FAA-SWIM", 0, "civicport")
call assertTrue made~ok, "create SWIM queue"

body = readBinary("fixtures/faa_swim_aim_fns_jyr.xml")
headers = .directory~new
headers["JMSMESSAGEID"] = "ID:INGRESS:1"
headers["JMSPRIORITY"] = "4"
properties = .directory~new
properties["source"] = "AIM_NMS_Publication"
message = .JMSBridgeMessage~new("ID:INGRESS:1", "TEXT", body, headers, properties, "SOLACE", "AIM_FNS", "2026-08-24T19:00:00Z")
options = .table~new
options["persistent"] = .true
options["sourceManager"] = "JMS:faa-swim"
options["sourceQueue"] = "AIM_FNS_REMOTE"
options["correlationId"] = "CORR-1"
accepted = manager~acceptTransfer("jms:faa-swim:ID:INGRESS:1", "FAA.SWIM.AIM_FNS", message, options, "civicport")
call assertTrue accepted~ok, "accept bridge message into queue"

journal = .CivicQueueJournal~new(journalRoot)
ingestor = .CivicQueueIngestor~new(manager, journal, "FAA.SWIM.AIM_FNS", "civicport", "NOT_FOR_OPERATIONAL_USE")
first = ingestor~pumpOne
call assertTrue first~ok, "queue message journalled before ACK"
call assertEqual "JOURNALLED_ACKED", first~code, "ingest result"
call assertEqual 1, journal~count, "journal contains one message"
depth = manager~depth("FAA.SWIM.AIM_FNS", "civicport")
call assertTrue depth~ok, "queue depth after ACK"
call assertEqual 0, depth~value["ready"], "queue has no ready message after ACK"
call assertEqual body, first~record~document~bodyText, "journal retains exact bridge TextMessage string"
call assertEqual "ID:INGRESS:1", first~record~document~messageId, "JMS message id retained"
call assertEqual "NOT_FOR_OPERATIONAL_USE", first~record~document~useClassification, "SWIM use policy retained"

/* Crash-window proof: journal the second package, leave it INFLIGHT, then
   construct a new manager. Queue Fabric recovery returns INFLIGHT to READY. */
headers2 = .directory~new
headers2["JMSMESSAGEID"] = "ID:INGRESS:2"
message2 = .JMSBridgeMessage~new("ID:INGRESS:2", "TEXT", body, headers2, .directory~new, "SOLACE", "AIM_FNS", "2026-08-24T19:00:10Z")
accepted2 = manager~acceptTransfer("jms:faa-swim:ID:INGRESS:2", "FAA.SWIM.AIM_FNS", message2, options, "civicport")
call assertTrue accepted2~ok, "accept second bridge message"
claimed = manager~claim("FAA.SWIM.AIM_FNS", "civicport")
call assertTrue claimed~ok, "claim second message"
factory = .CivicJmsQueueDocumentFactory~new
built = factory~fromPackage("FAA.SWIM.AIM_FNS", claimed~value, "NOT_FOR_OPERATIONAL_USE")
call assertTrue built~ok, "build queue evidence before simulated crash"
preCrash = journal~append(built~document)
call assertTrue preCrash~ok, "journal append before simulated crash"
call assertTrue \preCrash~duplicate, "second source appended once"
call assertEqual 2, journal~count, "journal count before simulated crash"

manager2 = .ObjectQueueManager~new(store, .JMSBridgeQueueCodecFactory~newCodec)
journal2 = .CivicQueueJournal~new(journalRoot)
ingestor2 = .CivicQueueIngestor~new(manager2, journal2, "FAA.SWIM.AIM_FNS", "civicport", "NOT_FOR_OPERATIONAL_USE")
afterCrash = ingestor2~pumpOne
call assertTrue afterCrash~ok, "recovered queue message handled"
call assertEqual "DUPLICATE_ACKED", afterCrash~code, "journal duplicate suppresses crash-window replay"
call assertTrue afterCrash~duplicate, "crash-window replay marked duplicate"
call assertEqual 2, journal2~count, "crash-window replay does not append another record"
depth2 = manager2~depth("FAA.SWIM.AIM_FNS", "civicport")
call assertEqual 0, depth2~value["ready"], "recovered duplicate ACKed"

/* A local journal exception is transient: release, do not ACK or discard. */
headers3 = .directory~new
headers3["JMSMESSAGEID"] = "ID:INGRESS:3"
message3 = .JMSBridgeMessage~new("ID:INGRESS:3", "TEXT", body, headers3, .directory~new, "SOLACE", "AIM_FNS")
accepted3 = manager2~acceptTransfer("jms:faa-swim:ID:INGRESS:3", "FAA.SWIM.AIM_FNS", message3, options, "civicport")
call assertTrue accepted3~ok, "accept third message"
failing = .ExplodingQueueJournal~new
failingIngestor = .CivicQueueIngestor~new(manager2, failing, "FAA.SWIM.AIM_FNS", "civicport", "NOT_FOR_OPERATIONAL_USE")
failed = failingIngestor~pumpOne
call assertTrue \failed~ok, "journal exception fails ingest"
call assertEqual "QUEUE_JOURNAL_FAILED", failed~code, "journal exception code"
depth3 = manager2~depth("FAA.SWIM.AIM_FNS", "civicport")
call assertEqual 1, depth3~value["ready"], "journal exception releases package back to READY"

say "PASS test_queue_ingress_v012"
"rm -rf" store journalRoot
exit 0

::class ExplodingQueueJournal public
::method append
  use arg document
  raise syntax 93.900 additional("deterministic journal failure")

::requires "TestSupport.cls"
::requires "CivicQueueIngress.cls"
