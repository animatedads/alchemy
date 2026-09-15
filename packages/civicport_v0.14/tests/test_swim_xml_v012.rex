parse source . . here
classes = .array~of(.CivicSwimPolicy, .CivicSwimParseResult, .CivicSwimXmlDocument, .CivicSwimXmlAdapter, .CivicAimFnsProjectionResult, .CivicAimFnsSimpleTextProjection, .CivicAimFnsSimpleTextAdapter)
do cls over classes
  call assertTrue cls~isSubclassOf(.CivicAlchemyObject), cls~id || " inherits CivicAlchemyObject"
  call assertTrue cls~isSubclassOf(.AlchemyObject), cls~id || " inherits AlchemyObject"
end
call directory here
body = readBinary("fixtures/faa_swim_aim_fns_jyr.xml")
digestPort = .CivicDigestPort~new
headers = .directory~new
headers["JMSMESSAGEID"] = "ID:SWIM:JYR:1"
properties = .directory~new
headerDigest = digestPort~sha512Bytes(.CivicQueueMapCodec~encode(headers))
propertyDigest = digestPort~sha512Bytes(.CivicQueueMapCodec~encode(properties))
bodyDigest = digestPort~sha512Bytes(body)
sourceIdentity = "JMS:" || c2x("SOLACE") || ":" || c2x("AIM_FNS") || ":" || c2x("ID:SWIM:JYR:1")
queueDoc = .CivicQueueDocument~new(sourceIdentity, "FAA.SWIM.AIM_FNS", "QPKG-1", "ID:SWIM:JYR:1", "SOLACE", "AIM_FNS", "TEXT", body, bodyDigest, -
  headers, properties, headerDigest, propertyDigest, "2026-08-24T19:00:00Z", "2026-08-24T19:00:01Z", "2026-08-24T19:00:00Z", "", "", 4, "NOT_FOR_OPERATIONAL_USE")

parsed = .CivicSwimXmlAdapter~new~parse(queueDoc)
call assertTrue parsed~ok, "SWIM XML parses"
swimDoc = parsed~document
call assertEqual "faa.swim.scds.xml/0.1", swimDoc~generation, "SWIM XML generation"
call assertEqual "message:Message", swimDoc~rootQName, "root qname retained"
call assertEqual "NOT_FOR_OPERATIONAL_USE", swimDoc~useClassification, "non-operational policy retained"
call assertEqual "PUBLIC_RELEASE_PREAPPROVED_NDRB", swimDoc~releaseClassification, "public-release policy retained"

projectionOutcome = .CivicAimFnsSimpleTextAdapter~new~project(swimDoc)
call assertTrue projectionOutcome~ok, "AIM FNS simpleText projection"
projection = projectionOutcome~projection
call assertEqual "!JYR 08/001 JYR RWY 17/35 CLSD 2608261100-2608270001", projection~simpleText, "simpleText preserved exactly"
call assertTrue projection~sourcePath~pos("simpleText") > 0, "rich XML source path retained"
call assertEqual queueDoc~evidenceIdentity, projection~swimDocument~queueDocument~evidenceIdentity, "queue evidence remains authoritative parent"

native1 = swimDoc~nativeDocument
native2 = swimDoc~nativeDocument
call assertTrue native1 \== native2, "native XML callers receive independent trees"
call assertEqual native1~root~qName, native2~root~qName, "independent rich trees preserve root"

badBody = "<message><event:simpleText>broken</message>"
badDigest = digestPort~sha512Bytes(badBody)
badDoc = .CivicQueueDocument~new("JMS:BAD", "FAA.SWIM.AIM_FNS", "QPKG-BAD", "ID:BAD", "SOLACE", "AIM_FNS", "TEXT", badBody, badDigest, -
  .directory~new, .directory~new, digestPort~sha512Bytes(.CivicQueueMapCodec~encode(.directory~new)), digestPort~sha512Bytes(.CivicQueueMapCodec~encode(.directory~new)), "", "", "", "", "", 4, "NOT_FOR_OPERATIONAL_USE")
badOutcome = .CivicSwimXmlAdapter~new~parse(badDoc)
call assertTrue \badOutcome~ok, "malformed XML is rejected"
call assertEqual "SWIM_XML_INVALID", badOutcome~errorCode, "malformed XML disposition"

absentBody = "<message><other>text</other></message>"
absentDigest = digestPort~sha512Bytes(absentBody)
absentDoc = .CivicQueueDocument~new("JMS:ABSENT", "FAA.SWIM.AIM_FNS", "QPKG-ABSENT", "ID:ABSENT", "SOLACE", "AIM_FNS", "TEXT", absentBody, absentDigest, -
  .directory~new, .directory~new, digestPort~sha512Bytes(.CivicQueueMapCodec~encode(.directory~new)), digestPort~sha512Bytes(.CivicQueueMapCodec~encode(.directory~new)), "", "", "", "", "", 4, "NOT_FOR_OPERATIONAL_USE")
absentSwim = .CivicSwimXmlAdapter~new~parse(absentDoc)
call assertTrue absentSwim~ok, "valid XML without simpleText remains valid SWIM XML"
absentProjection = .CivicAimFnsSimpleTextAdapter~new~project(absentSwim~document)
call assertTrue \absentProjection~ok, "missing simpleText does not invent a NOTAM projection"
call assertEqual "AIM_FNS_SIMPLE_TEXT_ABSENT", absentProjection~errorCode, "missing simpleText disposition"

say "PASS test_swim_xml_v012"
exit 0
::requires "TestSupport.cls"
::requires "CivicSwim.cls"
