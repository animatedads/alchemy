/* Deterministic CivicPort v0.14 durable-journal NOTAM evidence-surface demo. */
parse source . . sourceFile
base = filespec("LOCATION", sourceFile)
root = base || "tmp_notam_journal_surface_demo"
"rm -rf" root

body = readBinary(base || "../tests/fixtures/faa_swim_aim_fns_jyr.xml")
journal = .CivicQueueJournal~new(root)
valid = queueDocument(body, "ID:DEMO:NOTAM:VALID")
validAppend = journal~append(valid)
if \validAppend~ok then do
  say "journal append failed:" validAppend~errorCode validAppend~message
  exit 2
end
unsupported = queueDocument(body~changestr("RWY 17/35 CLSD", "TWY A CLSD"), "ID:DEMO:NOTAM:UNSUPPORTED")
unsupportedAppend = journal~append(unsupported)
if \unsupportedAppend~ok then do
  say "unsupported evidence append failed:" unsupportedAppend~errorCode unsupportedAppend~message
  exit 2
end

scan = .CivicNotamJournalProjector~new~scan(journal)
say "journal records:" journal~count
say "runway-closure projections:" scan~projectedCount
say "projection diagnostics:" scan~diagnosticCount
if scan~projectedCount > 0 then do
  item = scan~projections[1]
  say "journal record:" item~recordId
  say "source identity:" item~sourceIdentity
  say "runway:" item~projection~runwayDesignator
  say "condition:" item~projection~condition
  say "start-token:" item~projection~effectiveStartToken
  say "end-token:" item~projection~effectiveEndToken
  say "operational-disposition:" item~projection~operationalDisposition
end
if scan~diagnosticCount > 0 then do
  diagnostic = scan~diagnostics[1]
  say "diagnostic record:" diagnostic~recordId
  say "diagnostic stage:" diagnostic~stage
  say "diagnostic code:" diagnostic~errorCode
end

"rm -rf" root
exit 0

queueDocument: procedure
  use arg body, messageId
  digestPort = .CivicDigestPort~new
  headers = .directory~new
  headers["JMSMESSAGEID"] = messageId
  properties = .directory~new
  sourceIdentity = "JMS:" || c2x("SOLACE") || ":" || c2x("AIM_FNS") || ":" || c2x(messageId)
  return .CivicQueueDocument~new(sourceIdentity, "FAA.SWIM.AIM_FNS", "QPKG-" || c2x(messageId), messageId, "SOLACE", "AIM_FNS", "TEXT", body, digestPort~sha512Bytes(body), -
    headers, properties, digestPort~sha512Bytes(.CivicQueueMapCodec~encode(headers)), digestPort~sha512Bytes(.CivicQueueMapCodec~encode(properties)), -
    "2026-08-28T12:00:00Z", "2026-08-28T12:00:01Z", "2026-08-28T12:00:00Z", "", "", 4, "NOT_FOR_OPERATIONAL_USE")

readBinary: procedure
  use arg path
  input = .Stream~new(path)
  opened = input~open("READ")
  if \opened~caselessEquals("READY:") then raise syntax 93.900 additional("Unable to read fixture " || path)
  bytes = ""
  if input~chars > 0 then bytes = input~charIn(1, input~chars)
  ignore = input~close
  return bytes

::requires "CivicNotamJournal.cls"
