/*
 * Deterministic CivicPort v0.12 SWIM Queue Fabric demonstration.
 *
 * This uses the Java-neutral JMSBridgeMessage class only.  It does not open a
 * JMS connection and consumes no SWIFT/SCDS credentials.
 */
parse source . . sourceFile
scriptDir = filespec("LOCATION", sourceFile)
store = scriptDir || "tmp_swim_demo_store"
journalRoot = scriptDir || "tmp_swim_demo_journal"
"rm -rf" store journalRoot

codec = .JMSBridgeQueueCodecFactory~newCodec
manager = .ObjectQueueManager~new(store, codec)
made = manager~createQueue("FAA.SWIM.AIM_FNS", "PERMANENT", "FAA-SWIM", 0, "civicport")
if \made~ok then do
  say "queue create failed:" made~code made~detail
  exit 1
end

body = readBinary(scriptDir || "../tests/fixtures/faa_swim_aim_fns_jyr.xml")
headers = .directory~new
headers["JMSMESSAGEID"] = "ID:JYR:DEMO"
properties = .directory~new
properties["source"] = "AIM_NMS_Publication"
message = .JMSBridgeMessage~new("ID:JYR:DEMO", "TEXT", body, headers, properties, "SOLACE", "AIM_FNS", "2026-08-24T19:00:00Z")
options = .table~new
options["persistent"] = .true
options["sourceManager"] = "JMS:faa-swim"
accepted = manager~acceptTransfer("jms:faa-swim:ID:JYR:DEMO", "FAA.SWIM.AIM_FNS", message, options, "civicport")
if \accepted~ok then do
  say "queue accept failed:" accepted~code accepted~detail
  exit 1
end

journal = .CivicQueueJournal~new(journalRoot)
ingested = .CivicQueueIngestor~new(manager, journal, "FAA.SWIM.AIM_FNS", "civicport", "NOT_FOR_OPERATIONAL_USE")~pumpOne
if \ingested~ok then do
  say "ingest failed:" ingested~code ingested~message
  exit 1
end

queueDocument = ingested~record~document
swim = .CivicSwimXmlAdapter~new~parse(queueDocument)
if \swim~ok then do
  say "SWIM parse failed:" swim~errorCode swim~message
  exit 1
end
projection = .CivicAimFnsSimpleTextAdapter~new~project(swim~document)
if \projection~ok then do
  say "AIM FNS projection failed:" projection~errorCode projection~message
  exit 1
end

say "ingest:" ingested~code
say "queue evidence:" queueDocument~evidenceIdentity
say "stored body SHA-512:" queueDocument~bodyDigest
say "use classification:" swim~document~useClassification
say "release classification:" swim~document~releaseClassification
say "source path:" projection~projection~sourcePath
say "simpleText:" projection~projection~simpleText

"rm -rf" store journalRoot
exit 0

readBinary: procedure
  use arg path
  input = .Stream~new(path)
  opened = input~open("READ")
  if \opened~caselessEquals("READY:") then raise syntax 93.900 additional("Cannot open " || path)
  available = input~chars
  if available > 0 then bytes = input~charIn(1, available)
  else bytes = ""
  ignore = input~close
  return bytes

::requires "CivicQueueIngress.cls"
::requires "CivicSwim.cls"
