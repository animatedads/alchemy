call test_curl_transport_fake
say "PASS test_curl_transport_fake"
exit 0

test_curl_transport_fake:
  expectedDigest = readBinary("fixtures/fake_curl.sha512")~changestr('0d'x, "")~changestr('0a'x, "")~strip
  allow = .CivicAllowList~new
  ignore = allow~add("https", "api.postcodes.io", "/postcodes/{postcode}")
  headers = .directory~new
  headers["Accept"] = "application/json"
  client = .CivicClient~new(.CivicCurlTransport~new("./fixtures/fake_curl.sh"), allow)
  fetchResult = client~get("https://api.postcodes.io/postcodes/FAKE", headers, 5)
  call assertTrue fetchResult~ok, "curl port path returns a document"
  doc = fetchResult~document
  call assertEqual "CURL", doc~transportName, "curl transport identity retained"
  call assertEqual 200, doc~status, "curl status parsed from raw headers"
  call assertEqual '"fake-curl-v01"', doc~header("ETag"), "curl ETag retained"
  call assertEqual 7, doc~bodyBytes~length, "binary response body length retained including NUL/FF/CRLF"
  call assertTrue doc~bodyBytes~pos('00'x) > 0, "binary NUL survives transport"
  call assertTrue doc~bodyBytes~pos('ff'x) > 0, "binary FF survives transport"
  call assertEqual expectedDigest, doc~bodyDigest, "binary body SHA-512 is exact"
  return

::requires "TestSupport.cls"
::requires "CivicClient.cls"
