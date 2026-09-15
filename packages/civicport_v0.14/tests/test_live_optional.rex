live = value("CIVICPORT_LIVE_TEST",, "ENVIRONMENT")
if live \= "1" then do
  say "SKIP test_live_optional (set CIVICPORT_LIVE_TEST=1)"
  exit 0
end
allow = .CivicAllowList~new
ignore = allow~add("https", "api.postcodes.io", "/postcodes/{postcode}")
client = .CivicClient~new(.CivicCurlTransport~new, allow)
fetchResult = client~get("https://api.postcodes.io/postcodes/SW1A%201AA", .nil, 15)
call assertTrue fetchResult~ok, "live transport returns an HTTP document"
doc = fetchResult~document
call assertTrue doc~status >= 100 & doc~status <= 599, "live status is retained"
call assertTrue doc~bodyDigest~length = 128, "live body has SHA-512 digest"
contentType = doc~header("Content-Type")
if contentType \== .nil then do
  if contentType~lower~pos("json") > 0 then call assertEqual "OK", doc~parseStatus, "declared live JSON is parsed in v0.2"
end
say "LIVE status=" || doc~status || " digest=" || doc~bodyDigest
say "PASS test_live_optional"
exit 0

::requires "TestSupport.cls"
::requires "CivicClient.cls"
