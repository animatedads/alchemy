if value("CIVICPORT_AVIATIONWEATHER_LIVE_TEST",, "ENVIRONMENT") \= "1" then do
  say "SKIP test_aviationweather_live_optional (set CIVICPORT_AVIATIONWEATHER_LIVE_TEST=1)"
  exit 0
end

station = value("CIVICPORT_AVIATIONWEATHER_STATION",, "ENVIRONMENT")
if station = "" then station = "EGLL"
allow = .CivicAllowList~new
endpoint = .CivicAviationWeatherAdapter~endpointTemplate
ignore = allow~add(endpoint~scheme, endpoint~host, endpoint~pathTemplate, endpoint~allowQuery, endpoint~port, endpoint~queryTemplate)
client = .CivicClient~new(.CivicCurlTransport~new, allow)
headers = .CivicAviationWeatherAdapter~requestHeaders
url = .CivicAviationWeatherAdapter~metarUrl(station)
fetch = client~get(url, headers)
if \fetch~ok then do
  say "FAIL test_aviationweather_live_optional:" fetch~errorCode fetch~message
  exit 1
end
mapped = .CivicAviationWeatherAdapter~new~mapAll(fetch~document)
if \mapped~ok then do
  say "FAIL test_aviationweather_live_optional:" mapped~errorCode mapped~message
  exit 1
end
say "PASS test_aviationweather_live_optional station=" station "observations=" mapped~items~items
exit 0

::requires "CivicAviationWeather.cls"
::requires "CivicClient.cls"
::requires "CivicHttpPort.cls"
