call test_failure_boundaries
say "PASS test_failure_boundaries"
exit 0

test_failure_boundaries:
  allow = .CivicAllowList~new
  ignore = allow~add("https", "api.postcodes.io", "/postcodes/{postcode}")

  transport = .CivicFixtureTransport~new
  raw = "HTTP/1.1 404 Not Found" || '0d0a'x || "Content-Type: application/json" || '0d0a0d0a'x
  ignore = transport~add(.CivicFixture~new("GET", "https://api.postcodes.io/postcodes/MISSING", 404, "Not Found", raw, '{"status":404}'))
  client = .CivicClient~new(transport, allow)
  fetchResult = client~get("https://api.postcodes.io/postcodes/MISSING")
  call assertTrue fetchResult~ok, "HTTP 404 is transport-success evidence, not transport failure"
  call assertEqual 404, fetchResult~document~status, "404 status retained as document"
  call assertTrue \fetchResult~document~isHttpSuccess, "404 is not mislabelled HTTP success"
  call assertEqual "OK", fetchResult~document~parseStatus, "declared 404 JSON body is still parsed as response evidence"
  call assertEqual 404, fetchResult~document~parsed["status"], "404 JSON payload retained independently of HTTP success semantics"

  secretHeaders = .directory~new
  secretHeaders["Authorization"] = "Basic should-never-enter-a-document"
  safeCurlClient = .CivicClient~new(.CivicCurlTransport~new("./fixtures/fake_curl.sh"), allow)
  secretFetch = safeCurlClient~get("https://api.postcodes.io/postcodes/SECRET", secretHeaders, 5)
  call assertTrue \secretFetch~ok, "credential-bearing request header is rejected"
  call assertEqual "INVALID_HEADER", secretFetch~errorCode, "credential rejection is explicit"
  call assertTrue secretFetch~document == .nil, "rejected credential is never materialised in a document"

  hostHeaders = .directory~new
  hostHeaders["Host"] = "evil.example"
  hostFetch = safeCurlClient~get("https://api.postcodes.io/postcodes/HOST", hostHeaders, 5)
  call assertTrue \hostFetch~ok, "caller cannot override transport Host routing"
  call assertEqual "INVALID_HEADER", hostFetch~errorCode, "Host override rejection is explicit"

  failingClient = .CivicClient~new(.CivicCurlTransport~new("./fixtures/failing_curl.sh"), allow)
  failedFetch = failingClient~get("https://api.postcodes.io/postcodes/FAIL", .nil, 5)
  call assertTrue \failedFetch~ok, "transport failure does not manufacture a CivicDocument"
  call assertEqual "HTTP_TRANSPORT_ERROR", failedFetch~errorCode, "transport failure has explicit code"
  call assertTrue failedFetch~document == .nil, "transport failure carries no document"

  caps = .CivicCapabilities~v02
  call assertEqual 2, caps~items, "v0.2 advertises only implemented capabilities"
  call assertEqual "CIVIC_HTTP", caps[1], "HTTP capability retained"
  call assertEqual "CIVIC_JSON", caps[2], "v0.2 advertises CIVIC_JSON"
  return

::requires "TestSupport.cls"
::requires "CivicClient.cls"
