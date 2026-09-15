call test_document_fixture
say "PASS test_document_fixture"
exit 0

test_document_fixture:
  body = readBinary("fixtures/postcodes_io_SW1A1AA.body")
  rawHeaders = readBinary("fixtures/postcodes_io_SW1A1AA.headers")
  expectedDigest = readBinary("fixtures/postcodes_io_SW1A1AA.sha512")~changestr('0d'x, "")~changestr('0a'x, "")~strip

  allow = .CivicAllowList~new
  ignore = allow~add("https", "api.postcodes.io", "/postcodes/{postcode}")
  fixtureTransport = .CivicFixtureTransport~new
  fixture = .CivicFixture~new("GET", "https://api.postcodes.io/postcodes/SW1A%201AA", 200, "OK", rawHeaders, body)
  ignore = fixtureTransport~add(fixture)
  client = .CivicClient~new(fixtureTransport, allow)

  fetchResult = client~get("https://api.postcodes.io/postcodes/SW1A%201AA")
  call assertTrue fetchResult~ok, "fixture fetch succeeds"
  doc = fetchResult~document
  call assertEqual 200, doc~status, "status retained"
  call assertEqual "OK", doc~reason, "reason retained"
  call assertEqual body, doc~bodyBytes, "body bytes retained exactly"
  call assertEqual expectedDigest, doc~bodyDigest, "SHA-512 is over exact fixture bytes"
  call assertEqual "OK", doc~parseStatus, "v0.2 parses declared JSON without changing bytes"
  call assertTrue doc~parsed~isA(.Directory), "parsed JSON tree retained as native object"
  call assertEqual "SW1A 1AA", doc~parsed["result"]["postcode"], "fixture postcode visible in parsed tree"
  call assertEqual "MISS", doc~cacheState, "v0.2 still has no cache journal"
  call assertEqual '"civicport-v01-fixture"', doc~header("etag"), "ETag retained through case-neutral header map"
  call assertEqual rawHeaders, doc~rawHeaderBytes, "raw response headers retained"
  call assertEqual "FIXTURE", doc~transportName, "transport identity retained"
  p = doc~provenance
  call assertEqual "CIVIC_HTTP_DOCUMENT", p["kind"], "provenance kind is civic document"
  call assertEqual expectedDigest, p["bodyDigest"], "provenance carries digest"
  return

::requires "TestSupport.cls"
::requires "CivicClient.cls"
