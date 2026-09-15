parse source . . here
call directory here

body = readBinary("fixtures/faa_swim_aim_fns_jyr.xml")
digestPort = .CivicDigestPort~new
headers = .directory~new
properties = .directory~new
bodyDigest = digestPort~sha512Bytes(body)
sourceIdentity = "JMS:" || c2x("SOLACE") || ":" || c2x("AIM_FNS") || ":" || c2x("ID:SWIM:JYR:NOTAM:FAIL")
queueDoc = .CivicQueueDocument~new(sourceIdentity, "FAA.SWIM.AIM_FNS", "QPKG-NOTAM-FAIL", "ID:SWIM:JYR:NOTAM:FAIL", "SOLACE", "AIM_FNS", "TEXT", body, bodyDigest, -
  headers, properties, digestPort~sha512Bytes(.CivicQueueMapCodec~encode(headers)), digestPort~sha512Bytes(.CivicQueueMapCodec~encode(properties)), -
  "", "", "", "", "", 4, "NOT_FOR_OPERATIONAL_USE")
swim = .CivicSwimXmlAdapter~new~parse(queueDoc)
call assertTrue swim~ok, "base SWIM document parses"
base = .CivicAimFnsSimpleTextAdapter~new~project(swim~document)
call assertTrue base~ok, "base simpleText projects"
adapter = .CivicNotamRunwayClosureAdapter~new

p = .CivicAimFnsSimpleTextProjection~new(swim~document, "!JYR BAD001 JYR RWY 17/35 CLSD 2608261100-2608270001", "/test/simpleText", 1)
o = adapter~project(p)
call assertTrue \o~ok, "malformed NOTAM number rejected"
call assertEqual "NOTAM_NUMBER_INVALID", o~errorCode, "number rejection code"

p = .CivicAimFnsSimpleTextProjection~new(swim~document, "!JYR 08/001 JYR TWY A CLSD 2608261100-2608270001", "/test/simpleText", 1)
o = adapter~project(p)
call assertTrue \o~ok, "taxiway grammar not guessed as runway grammar"
call assertEqual "NOTAM_KEYWORD_UNSUPPORTED", o~errorCode, "keyword rejection code"

p = .CivicAimFnsSimpleTextProjection~new(swim~document, "!JYR 08/001 JYR RWY 17/35 U/S 2608261100-2608270001", "/test/simpleText", 1)
o = adapter~project(p)
call assertTrue \o~ok, "non-closure condition not guessed"
call assertEqual "NOTAM_CONDITION_UNSUPPORTED", o~errorCode, "condition rejection code"

p = .CivicAimFnsSimpleTextProjection~new(swim~document, "!JYR 08/001 JYR RWY 17/35 CLSD EXC 2608261100-2608270001", "/test/simpleText", 1)
o = adapter~project(p)
call assertTrue \o~ok, "extra body tokens fail closed"
call assertEqual "NOTAM_RUNWAY_CLOSURE_SHAPE_UNSUPPORTED", o~errorCode, "extra token rejection code"

p = .CivicAimFnsSimpleTextProjection~new(swim~document, "!JYR 08/001 JYR RWY 17/35 CLSD 260826110-2608270001", "/test/simpleText", 1)
o = adapter~project(p)
call assertTrue \o~ok, "malformed time token rejected"
call assertEqual "NOTAM_TIME_RANGE_INVALID", o~errorCode, "time rejection code"

p = .CivicAimFnsSimpleTextProjection~new(swim~document, "!BNA 09/013 BNA RWY 36 CLSD 2609011200-2609011800EST", "/test/simpleText", 1)
o = adapter~project(p)
call assertTrue o~ok, "EST end qualifier supported lexically"
call assertEqual "2609011800", o~projection~effectiveEndToken, "EST lexical date retained"
call assertEqual "ESTIMATED", o~projection~endQualifier, "EST qualifier explicit"
call assertEqual "2609011200-2609011800EST", o~projection~rawTimeRange, "EST source token retained exactly"

p = .CivicAimFnsSimpleTextProjection~new(swim~document, "!ICT 10/001 MEJ RWY 17/35 CLSD 2610011200-PERM", "/test/simpleText", 1)
o = adapter~project(p)
call assertTrue o~ok, "PERM end qualifier supported lexically"
call assertEqual "PERM", o~projection~effectiveEndToken, "PERM token retained"
call assertEqual "PERMANENT", o~projection~endQualifier, "PERM qualifier explicit"

wrongClassDoc = .CivicQueueDocument~new("JMS:WRONGCLASS", "FAA.SWIM.AIM_FNS", "QPKG-WC", "ID:WC", "SOLACE", "AIM_FNS", "TEXT", body, bodyDigest, -
  headers, properties, digestPort~sha512Bytes(.CivicQueueMapCodec~encode(headers)), digestPort~sha512Bytes(.CivicQueueMapCodec~encode(properties)), -
  "", "", "", "", "", 4, "OPERATIONAL")
wrongSwim = .CivicSwimXmlDocument~new(wrongClassDoc, .CivicSwimPolicy~XML_GENERATION, "fixture", "message:Message")
wrongSimple = .CivicAimFnsSimpleTextProjection~new(wrongSwim, "!JYR 08/001 JYR RWY 17/35 CLSD 2608261100-2608270001", "/test/simpleText", 1)
o = adapter~project(wrongSimple)
call assertTrue \o~ok, "wrong source-use classification rejected"
call assertEqual "NOTAM_USE_CLASSIFICATION_MISMATCH", o~errorCode, "classification rejection code"

say "PASS test_notam_fail_closed_v013"
exit 0

::requires "TestSupport.cls"
::requires "CivicNotam.cls"
