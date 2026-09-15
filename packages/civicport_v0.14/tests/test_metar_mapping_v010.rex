rawHeaders = readBinary("fixtures/aviationweather_EGLL_fixture.headers")
body = readBinary("fixtures/aviationweather_EGLL_fixture.body")
allow = .CivicAllowList~new
endpoint = .CivicAviationWeatherAdapter~endpointTemplate
ignore = allow~add(endpoint~scheme, endpoint~host, endpoint~pathTemplate, endpoint~allowQuery, endpoint~port, endpoint~queryTemplate)
transport = .CivicTestSequenceTransport~new
ignore = transport~addHttp(200, "OK", rawHeaders, body)
client = .CivicClient~new(transport, allow)
fetch = client~get(.CivicAviationWeatherAdapter~metarUrl("EGLL"))
call assertTrue fetch~ok, "fixture METAR fetch succeeds"
call assertEqual "OK", fetch~document~parseStatus, "METAR JSON parses"
adapter = .CivicAviationWeatherAdapter~new
mapped = adapter~mapAll(fetch~document)
call assertTrue mapped~ok, "METAR collection mapping succeeds"
call assertEqual "aviationweather.metar/0.1", mapped~mappingId, "METAR mapping generation pinned"
items = mapped~items
call assertEqual 2, items~items, "all source observations are retained"
call assertEqual "/0", items[1]~sourcePointer, "first source pointer retained"
call assertEqual "/1", items[2]~sourcePointer, "second source pointer retained"
call assertEqual "EGLL", items[1]~row["station_icao"], "station mapped"
call assertEqual "2026-08-23T15:20:00.000Z", items[1]~row["report_time"], "report time mapped"
call assertEqual "21.0", items[1]~row["temperature_c"]~string, "temperature lexical form preserved"
call assertEqual "METAR", items[1]~row["metar_type"], "METAR type mapped"
call assertEqual "SPECI", items[2]~row["metar_type"], "SPECI item retained independently"
call assertTrue \items[1]~row~hasIndex("wdir"), "union wind direction is not flattened"
call assertTrue \items[1]~row~hasIndex("clouds"), "structured clouds are not flattened"
tree = fetch~document~parsed
call assertTrue tree[1]["clouds"]~isA(.Array), "native cloud array remains in document"
call assertEqual "VRB", tree[2]["wdir"]~string, "union string wind direction remains native evidence"
call assertEqual "6.0", tree[2]["visib"]~string, "union numeric visibility remains native evidence"

badBody = body~changestr('"icaoId":"EGLL","receiptTime":"2026-08-23T14:51', '"icaoId":"KJFK","receiptTime":"2026-08-23T14:51')
transport2 = .CivicTestSequenceTransport~new
ignore = transport2~addHttp(200, "OK", rawHeaders, badBody)
badFetch = .CivicClient~new(transport2, allow)~get(.CivicAviationWeatherAdapter~metarUrl("EGLL"))
badMapped = adapter~mapAll(badFetch~document)
call assertTrue \badMapped~ok, "returned station mismatch invalidates whole collection"
call assertEqual "SCHEMA_STATION_MISMATCH", badMapped~errorCode, "station mismatch is explicit"

transport3 = .CivicTestSequenceTransport~new
emptyHeaders = "HTTP/1.1 204 No Content" || '0d0a'x || '0d0a'x
ignore = transport3~addHttp(204, "No Content", emptyHeaders, "")
emptyFetch = .CivicClient~new(transport3, allow)~get(.CivicAviationWeatherAdapter~metarUrl("EGLL"))
emptyMapped = adapter~mapAll(emptyFetch~document)
call assertTrue emptyMapped~ok, "official 204 no-data response maps as empty collection"
call assertEqual 0, emptyMapped~items~items, "204 yields zero observations rather than a fabricated row"
say "PASS test_metar_mapping_v010"
exit 0
::requires "TestSupport.cls"
::requires "CacheTestSupport.cls"
::requires "CivicAviationWeather.cls"
