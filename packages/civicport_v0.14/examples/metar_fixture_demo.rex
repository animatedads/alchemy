body = readBinary("../tests/fixtures/aviationweather_EGLL_fixture.body")
rawHeaders = readBinary("../tests/fixtures/aviationweather_EGLL_fixture.headers")

endpoint = .CivicAviationWeatherAdapter~endpointTemplate
allow = .CivicAllowList~new
ignore = allow~add(endpoint~scheme, endpoint~host, endpoint~pathTemplate, endpoint~allowQuery, endpoint~port, endpoint~queryTemplate)

url = .CivicAviationWeatherAdapter~metarUrl("EGLL")
transport = .CivicFixtureTransport~new
ignore = transport~add(.CivicFixture~new("GET", url, 200, "OK", rawHeaders, body))
client = .CivicClient~new(transport, allow)
fetch = client~get(url, .CivicAviationWeatherAdapter~requestHeaders)
if \fetch~ok then do
  say fetch~errorCode fetch~message
  exit 1
end

mapped = .CivicAviationWeatherAdapter~new~mapAll(fetch~document)
say fetch~document~string
say "mapping:" mapped~mappingId mapped~status
say "observations:" mapped~items~items
if mapped~ok then do item over mapped~items
  say item~sourcePointer item~row["station_icao"] item~row["report_time"] item~row["metar_type"] item~row["raw_observation"]
end
say "clouds retained as native array:" fetch~document~parsed[1]["clouds"]~isA(.Array)
say "wdir retained independently of scalar projection:" fetch~document~parsed[2]["wdir"]
exit 0

::routine readBinary
  use arg path
  s=.Stream~new(path); ignore=s~open("READ"); n=s~chars
  if n > 0 then data=s~charin(1,n); else data=""
  ignore=s~close
  return data

::requires "CivicAviationWeather.cls"
::requires "CivicClient.cls"
