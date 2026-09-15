/* Deterministic v0.14 SWIM -> narrow NOTAM runway-closure evidence demo. */
parse source . . sourceFile
base = filespec("LOCATION", sourceFile)
fixture = base || "../tests/fixtures/faa_swim_aim_fns_jyr.xml"

body = readBinary(fixture)
digestPort = .CivicDigestPort~new
headers = .directory~new
properties = .directory~new
queueDoc = .CivicQueueDocument~new( -
  "JMS:" || c2x("SOLACE") || ":" || c2x("AIM_FNS") || ":" || c2x("ID:DEMO:JYR"), -
  "FAA.SWIM.AIM_FNS", "QPKG-DEMO", "ID:DEMO:JYR", "SOLACE", "AIM_FNS", "TEXT", body, digestPort~sha512Bytes(body), -
  headers, properties, digestPort~sha512Bytes(.CivicQueueMapCodec~encode(headers)), digestPort~sha512Bytes(.CivicQueueMapCodec~encode(properties)), -
  "", "", "", "", "", 4, "NOT_FOR_OPERATIONAL_USE")

swim = .CivicSwimXmlAdapter~new~parse(queueDoc)
if \swim~ok then do
  say "SWIM parse failed:" swim~errorCode swim~message
  exit 2
end
simple = .CivicAimFnsSimpleTextAdapter~new~project(swim~document)
if \simple~ok then do
  say "simpleText projection failed:" simple~errorCode simple~message
  exit 2
end
parsed = .CivicNotamRunwayClosureAdapter~new~project(simple~projection)
if \parsed~ok then do
  say "NOTAM projection failed:" parsed~errorCode parsed~message
  exit 2
end

notam = parsed~projection
say "generation:" notam~generation
say "raw:" notam~rawText
say "accountable:" notam~accountableLocation
say "number:" notam~notamNumber
say "affected:" notam~affectedLocation
say "keyword:" notam~keyword
say "runway:" notam~runwayDesignator
say "condition:" notam~condition
say "start-token:" notam~effectiveStartToken
say "end-token:" notam~effectiveEndToken
say "end-qualifier:" notam~endQualifier
say "use:" notam~useClassification
say "operational-disposition:" notam~operationalDisposition
say "source-path:" notam~sourcePath
exit 0

readBinary: procedure
  use arg path
  input = .Stream~new(path)
  opened = input~open("READ")
  if \opened~caselessEquals("READY:") then raise syntax 93.900 additional("Unable to read fixture " || path)
  bytes = ""
  if input~chars > 0 then bytes = input~charIn(1, input~chars)
  ignore = input~close
  return bytes

::requires "CivicNotam.cls"
