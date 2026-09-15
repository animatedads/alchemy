call test_cache_key
say "PASS test_cache_key"
exit 0

test_cache_key:
  r1 = .CivicRequest~new("https://API.POSTCODES.IO:443/postcodes/SW1A%201AA?b=2&a=1")
  r2 = .CivicRequest~new("https://api.postcodes.io/postcodes/SW1A%201AA?b=2&a=1")
  r3 = .CivicRequest~new("https://api.postcodes.io/postcodes/SW1A%201AA?a=1&b=2")
  k1 = .CivicCacheKey~forRequest(r1)
  k2 = .CivicCacheKey~forRequest(r2)
  k3 = .CivicCacheKey~forRequest(r3)
  call assertEqual k1, k2, "scheme/host/default port structural normalisation is stable"
  call assertTrue k1 \== k3, "query order remains identity; generic port does not guess source semantics"
  call assertTrue k1~pos("?b=2&a=1") > 0, "raw query order is preserved in cache key"
  return

::requires "TestSupport.cls"
::requires "CacheTestSupport.cls"
