call test_json_decode
say "PASS test_json_decode"
exit 0

test_json_decode:
  allow = .CivicAllowList~new
  ignore = allow~add("https", "api.postcodes.io", "/postcodes/{postcode}")
  transport = .CivicFixtureTransport~new

  goodRaw = "HTTP/1.1 200 OK" || '0d0a'x || "Content-Type: application/json; charset=utf-8" || '0d0a0d0a'x
  goodBody = '{"status":200,"result":{"postcode":"SW1A 1AA","country":"England","admin_district":"Westminster"}}'
  ignore = transport~add(.CivicFixture~new("GET", "https://api.postcodes.io/postcodes/GOOD", 200, "OK", goodRaw, goodBody))

  badRaw = "HTTP/1.1 200 OK" || '0d0a'x || "Content-Type: application/json" || '0d0a0d0a'x
  badBody = '{"status":200,"result":'
  ignore = transport~add(.CivicFixture~new("GET", "https://api.postcodes.io/postcodes/BAD", 200, "OK", badRaw, badBody))

  suffixRaw = "HTTP/1.1 200 OK" || '0d0a'x || "Content-Type: application/problem+json" || '0d0a0d0a'x
  suffixBody = '{"problem":"fixture"}'
  ignore = transport~add(.CivicFixture~new("GET", "https://api.postcodes.io/postcodes/SUFFIX", 200, "OK", suffixRaw, suffixBody))

  textRaw = "HTTP/1.1 200 OK" || '0d0a'x || "Content-Type: text/plain" || '0d0a0d0a'x
  ignore = transport~add(.CivicFixture~new("GET", "https://api.postcodes.io/postcodes/TEXT", 200, "OK", textRaw, '{"looks":"json"}'))

  client = .CivicClient~new(transport, allow)

  good = client~get("https://api.postcodes.io/postcodes/GOOD")~document
  call assertEqual "OK", good~parseStatus, "declared valid JSON is parsed"
  call assertTrue good~parsed~isA(.Directory), "parsed root retained as native Directory"
  treeCopy = good~parsed
  call assertEqual "SW1A 1AA", treeCopy["result"]["postcode"], "parsed JSON tree preserves nested value"
  treeCopy["result"]["postcode"] = "MUTATED COPY"
  call assertEqual "SW1A 1AA", good~parsed["result"]["postcode"], "caller cannot mutate CivicDocument through parsed tree"
  call assertEqual goodBody, good~bodyBytes, "parsing does not replace exact response bytes"

  bad = client~get("https://api.postcodes.io/postcodes/BAD")~document
  call assertEqual "INVALID", bad~parseStatus, "malformed declared JSON is INVALID"
  call assertTrue bad~parsed == .nil, "invalid JSON is not repaired into a tree"
  call assertEqual badBody, bad~bodyBytes, "malformed bytes remain preserved evidence"
  call assertTrue bad~bodyDigest~length = 128, "malformed bytes still receive SHA-512 evidence digest"

  suffix = client~get("https://api.postcodes.io/postcodes/SUFFIX")~document
  call assertEqual "OK", suffix~parseStatus, "+json media types are decoded"

  text = client~get("https://api.postcodes.io/postcodes/TEXT")~document
  call assertEqual "UNSUPPORTED", text~parseStatus, "JSON-looking text without JSON media type is not guessed"
  call assertTrue text~parsed == .nil, "unsupported media type has no parsed tree"
  return

::requires "TestSupport.cls"
::requires "CivicClient.cls"
