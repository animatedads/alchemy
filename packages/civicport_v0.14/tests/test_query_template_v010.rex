endpoint = .CivicAviationWeatherAdapter~endpointTemplate
call assertEqual "ids={station}&format=json", endpoint~queryTemplate, "METAR endpoint pins query template"
allow = .CivicAllowList~new
ignore = allow~add(endpoint~scheme, endpoint~host, endpoint~pathTemplate, endpoint~allowQuery, endpoint~port, endpoint~queryTemplate)
call assertTrue allow~permits(.CivicAviationWeatherAdapter~metarUrl("egll")), "exact METAR station query is permitted"
call assertTrue \allow~permits("https://aviationweather.gov/api/data/metar?format=json&ids=EGLL"), "query order is part of authority"
call assertTrue \allow~permits("https://aviationweather.gov/api/data/metar?ids=EGLL&format=json&hours=24"), "extra history query is not implicitly authorized"
call assertTrue \allow~permits("https://aviationweather.gov/api/data/metar?ids=EGLL,KJFK&format=json"), "multi-station widening is rejected"
call assertTrue \allow~permits("https://aviationweather.gov/api/data/metar?bbox=50,-1,52,1&format=json"), "bbox widening is rejected"
call assertEqual "https://aviationweather.gov/api/data/metar?ids=EGLL&format=json", .CivicAviationWeatherAdapter~metarUrl("egll"), "station URL is normalized without caller URL control"
call assertTrue allow~describe[1]~pos("?ids={station}&format=json") > 0, "allow-list description includes query contract"
say "PASS test_query_template_v010"
exit 0
::requires "TestSupport.cls"
::requires "CivicAviationWeather.cls"
