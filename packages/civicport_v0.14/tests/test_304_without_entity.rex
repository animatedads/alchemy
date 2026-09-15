call test_304_without_entity
say "PASS test_304_without_entity"
exit 0

test_304_without_entity:
  root = civicTestTempDir("civic_304orphan")
  headers304 = "HTTP/1.1 304 Not Modified" || '0d0a'x || 'ETag: "orphan"' || '0d0a0d0a'x
  allow = .CivicAllowList~new
  ignore = allow~add("https", "api.postcodes.io", "/postcodes/{postcode}")
  transport = .CivicTestSequenceTransport~new
  ignore = transport~addHttp(304, "Not Modified", headers304, "")
  journal = .CivicJournal~new(root)
  cache = .CivicCache~new(.CivicClient~new(transport, allow), journal)
  fetch = cache~get("https://api.postcodes.io/postcodes/SW1A%201AA")
  call assertTrue \fetch~ok, "orphan 304 cannot fabricate an entity"
  call assertEqual "CACHE_304_WITHOUT_ENTITY", fetch~errorCode, "orphan 304 has explicit cache failure"
  call assertTrue fetch~observation \== .nil, "actual orphan 304 remains available as evidence"
  call assertEqual 304, fetch~observation~status, "observation is exact HTTP 304"
  call assertEqual 1, journal~count, "orphan 304 is journaled because it was actually received"
  call assertEqual "", journal~record(fetch~observationRecordId)~bodySourceRecordId, "orphan 304 has no invented body link"
  return civicTestRemoveTree(root)

::requires "TestSupport.cls"
::requires "CacheTestSupport.cls"
