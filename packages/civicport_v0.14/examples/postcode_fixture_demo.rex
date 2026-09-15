body = readBinary("../tests/fixtures/postcodes_io_SW1A1AA.body")
rawHeaders = readBinary("../tests/fixtures/postcodes_io_SW1A1AA.headers")

endpoint = .CivicPostcodeAdapter~endpointTemplate
allow = .CivicAllowList~new
ignore = allow~add(endpoint~scheme, endpoint~host, endpoint~pathTemplate, endpoint~allowQuery, endpoint~port)

transport = .CivicFixtureTransport~new
ignore = transport~add(.CivicFixture~new("GET", "https://api.postcodes.io/postcodes/SW1A%201AA", 200, "OK", rawHeaders, body))
client = .CivicClient~new(transport, allow)
fetchResult = client~get("https://api.postcodes.io/postcodes/SW1A%201AA")
if \fetchResult~ok then do
  say fetchResult~errorCode fetchResult~message
  exit 1
end

doc = fetchResult~document
mapped = .CivicPostcodeAdapter~new~map(doc)

say doc~string
say "ETag:" doc~header("ETag")
say "parseStatus:" doc~parseStatus
say "body bytes:" doc~bodyBytes~length
say "mapping:" mapped~mappingId mapped~status
if mapped~ok then do
  say "postcode:" mapped~row["postcode"]
  say "country:" mapped~row["country"]
  say "admin district:" mapped~row["admin_district"]
end
exit 0

::routine readBinary
  use arg path
  s=.Stream~new(path); ignore=s~open("READ"); n=s~chars
  if n > 0 then data=s~charin(1,n); else data=""
  ignore=s~close
  return data

::requires "CivicClient.cls"
::requires "CivicPostcode.cls"
