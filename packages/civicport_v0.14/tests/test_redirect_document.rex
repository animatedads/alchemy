call test_redirect_document
say "PASS test_redirect_document"
exit 0

test_redirect_document:
  allow = .CivicAllowList~new
  ignore = allow~add("https", "api.postcodes.io", "/postcodes/{postcode}")
  transport = .CivicFixtureTransport~new
  raw = "HTTP/1.1 302 Found" || '0d0a'x || "Location: https://api.postcodes.io/postcodes/SW1A%201AB" || '0d0a0d0a'x
  ignore = transport~add(.CivicFixture~new("GET", "https://api.postcodes.io/postcodes/OLD", 302, "Found", raw, "redirect-body"))
  client = .CivicClient~new(transport, allow)
  fetchResult = client~get("https://api.postcodes.io/postcodes/OLD")
  call assertTrue fetchResult~ok, "302 is still an HTTP evidence document"
  doc = fetchResult~document
  call assertEqual 302, doc~status, "redirect status retained, not followed/mutated"
  call assertEqual "https://api.postcodes.io/postcodes/SW1A%201AB", doc~header("location"), "redirect target retained as header evidence"
  call assertEqual "redirect-body", doc~bodyBytes, "redirect body belongs to redirect document"
  return

::requires "TestSupport.cls"
::requires "CivicClient.cls"
