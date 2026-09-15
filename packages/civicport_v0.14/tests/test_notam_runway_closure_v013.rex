parse source . . here
call directory here

classes = .array~of(.CivicNotamPolicy, .CivicNotamProjectionResult, .CivicNotamRunwayClosureProjection, .CivicNotamRunwayClosureAdapter)
do cls over classes
  call assertTrue cls~isSubclassOf(.CivicAlchemyObject), cls~id || " inherits CivicAlchemyObject"
  call assertTrue cls~isSubclassOf(.AlchemyObject), cls~id || " inherits AlchemyObject"
end

body = readBinary("fixtures/faa_swim_aim_fns_jyr.xml")
digestPort = .CivicDigestPort~new
headers = .directory~new
headers["JMSMESSAGEID"] = "ID:SWIM:JYR:NOTAM:1"
properties = .directory~new
headerDigest = digestPort~sha512Bytes(.CivicQueueMapCodec~encode(headers))
propertyDigest = digestPort~sha512Bytes(.CivicQueueMapCodec~encode(properties))
bodyDigest = digestPort~sha512Bytes(body)
sourceIdentity = "JMS:" || c2x("SOLACE") || ":" || c2x("AIM_FNS") || ":" || c2x("ID:SWIM:JYR:NOTAM:1")
queueDoc = .CivicQueueDocument~new(sourceIdentity, "FAA.SWIM.AIM_FNS", "QPKG-NOTAM-1", "ID:SWIM:JYR:NOTAM:1", "SOLACE", "AIM_FNS", "TEXT", body, bodyDigest, -
  headers, properties, headerDigest, propertyDigest, "2026-08-24T19:00:00Z", "2026-08-24T19:00:01Z", "2026-08-24T19:00:00Z", "", "", 4, "NOT_FOR_OPERATIONAL_USE")

swim = .CivicSwimXmlAdapter~new~parse(queueDoc)
call assertTrue swim~ok, "SWIM XML parses"
simple = .CivicAimFnsSimpleTextAdapter~new~project(swim~document)
call assertTrue simple~ok, "simpleText projects"

parsed = .CivicNotamRunwayClosureAdapter~new~project(simple~projection)
call assertTrue parsed~ok, "narrow runway closure NOTAM projects"
notam = parsed~projection

call assertEqual "faa.swim.aim-fns.notam-runway-closure/0.1", notam~generation, "NOTAM mapping generation"
call assertEqual "!JYR 08/001 JYR RWY 17/35 CLSD 2608261100-2608270001", notam~rawText, "raw simpleText preserved"
call assertEqual "JYR", notam~accountableLocation, "accountable location"
call assertEqual "08/001", notam~notamNumber, "NOTAM number token"
call assertEqual "JYR", notam~affectedLocation, "affected location"
call assertEqual "RWY", notam~keyword, "keyword"
call assertEqual "17/35", notam~runwayDesignator, "runway designator"
call assertEqual "CLSD", notam~condition, "condition"
call assertEqual "2608261100", notam~effectiveStartToken, "start token preserved"
call assertEqual "2608270001", notam~effectiveEndToken, "end token preserved"
call assertEqual "EXACT", notam~endQualifier, "exact end qualifier"
call assertEqual "2608261100-2608270001", notam~rawTimeRange, "time range preserved"
call assertEqual "NOT_FOR_OPERATIONAL_USE", notam~useClassification, "non-operational use classification retained"
call assertEqual "PUBLIC_RELEASE_PREAPPROVED_NDRB", notam~releaseClassification, "release classification retained"
call assertEqual "EVIDENCE_ONLY_NOT_FOR_OPERATIONAL_USE", notam~operationalDisposition, "operational disposition explicit"
call assertEqual simple~projection~sourcePath, notam~sourcePath, "rich XML source path retained"
call assertEqual queueDoc~evidenceIdentity, notam~simpleTextProjection~swimDocument~queueDocument~evidenceIdentity, "queue evidence remains authoritative parent"
call assertTrue notam~identity~pos("CIVIC-NOTAM-RWY-CLSD-V1:") = 1, "NOTAM identity generation pinned"
call assertTrue notam~effectiveStartToken~class == .String, "start token remains ordinary lexical String"
call assertTrue notam~effectiveEndToken~class == .String, "end token remains ordinary lexical String"

prov = notam~provenance
call assertEqual queueDoc~evidenceIdentity, prov["queueEvidenceIdentity"], "provenance carries queue evidence identity"
call assertEqual "EVIDENCE_ONLY_NOT_FOR_OPERATIONAL_USE", prov["operationalDisposition"], "provenance carries non-operational disposition"

say "PASS test_notam_runway_closure_v013"
exit 0

::requires "TestSupport.cls"
::requires "CivicNotam.cls"
