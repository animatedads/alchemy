call test_capabilities_v03
say "PASS test_capabilities_v03"
exit 0

test_capabilities_v03:
  caps = .CivicCapabilities~v03
  call assertEqual 3, caps~items, "v0.3 capability set has exactly three claims"
  call assertEqual "CIVIC_HTTP", caps[1], "HTTP capability retained"
  call assertEqual "CIVIC_JSON", caps[2], "JSON capability retained"
  call assertEqual "CIVIC_ETAG_CACHE", caps[3], "v0.3 adds only ETag cache capability"
  return

::requires "TestSupport.cls"
::requires "CivicCache.cls"
