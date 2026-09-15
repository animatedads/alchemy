call test_allowlist
say "PASS test_allowlist"
exit 0

test_allowlist:
  allow = .CivicAllowList~new
  ignore = allow~add("https", "api.postcodes.io", "/postcodes/{postcode}")
  call assertTrue allow~permits("https://api.postcodes.io/postcodes/SW1A%201AA"), "named template segment accepted"
  call assertTrue \allow~permits("https://evil.example/postcodes/SW1A%201AA"), "different host rejected"
  call assertTrue \allow~permits("http://api.postcodes.io/postcodes/SW1A%201AA"), "scheme downgrade rejected"
  call assertTrue \allow~permits("https://api.postcodes.io/postcodes/SW1A%201AA?callback=x"), "query rejected unless template opts in"
  call assertTrue \allow~permits("https://api.postcodes.io/admin/postcodes/SW1A%201AA"), "different path rejected"
  call assertTrue \allow~permits("https://user@api.postcodes.io/postcodes/SW1A%201AA"), "userinfo URL rejected"
  call assertTrue \allow~permits("https://api.postcodes.io/postcodes/a%2Fb"), "encoded slash in dynamic segment rejected"
  call assertTrue \allow~permits("https://api.postcodes.io/postcodes/%2E%2E"), "encoded traversal segment rejected"

  fixtureTransport = .CivicFixtureTransport~new
  client = .CivicClient~new(fixtureTransport, allow)
  fetchResult = client~get("https://evil.example/postcodes/SW1A%201AA")
  call assertTrue \fetchResult~ok, "client blocks non-allowlisted request before transport"
  call assertEqual "URL_NOT_ALLOWED", fetchResult~errorCode, "blocked request has explicit error"

  ignore = allow~add("https", "example.invalid", "/later")
  call assertTrue \client~allowList~permits("https://example.invalid/later"), "client keeps sealed allow-list snapshot"
  call assertTrue client~allowList~sealed, "client allow-list snapshot is sealed"
  return

::requires "TestSupport.cls"
::requires "CivicClient.cls"
