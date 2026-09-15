call test_journal_recovery
say "PASS test_journal_recovery"
exit 0

test_journal_recovery:
  root = civicTestTempDir("civic_recovery")
  body = readBinary("fixtures/postcodes_io_SW1A1AA.body")
  headers200 = readBinary("fixtures/postcodes_io_SW1A1AA.headers")
  headers304 = "HTTP/1.1 304 Not Modified" || '0d0a'x || 'ETag: "civicport-v01-fixture"' || '0d0a0d0a'x
  allow = .CivicAllowList~new
  ignore = allow~add("https", "api.postcodes.io", "/postcodes/{postcode}")
  firstTransport = .CivicTestSequenceTransport~new
  ignore = firstTransport~addHttp(200, "OK", headers200, body)
  firstJournal = .CivicJournal~new(root)
  firstCache = .CivicCache~new(.CivicClient~new(firstTransport, allow), firstJournal)
  url = "https://api.postcodes.io/postcodes/SW1A%201AA"
  firstFetch = firstCache~get(url)
  savedRecordId = firstFetch~bodyRecordId
  savedDigest = firstFetch~document~bodyDigest

  secondTransport = .CivicTestSequenceTransport~new
  ignore = secondTransport~addHttp(304, "Not Modified", headers304, "")
  recoveredJournal = .CivicJournal~new(root)
  recoveredCache = .CivicCache~new(.CivicClient~new(secondTransport, allow), recoveredJournal)
  call assertEqual 1, recoveredJournal~count, "journal reconstructs stored HTTP document"
  recoveredFetch = recoveredCache~get(url)
  call assertTrue recoveredFetch~ok, "recovered cache can revalidate"
  call assertEqual "REVALIDATED", recoveredFetch~cacheState, "recovered cache preserves validator semantics"
  call assertEqual savedRecordId, recoveredFetch~bodyRecordId, "304 after restart links original durable body record"
  call assertEqual savedDigest, recoveredFetch~document~bodyDigest, "exact body survives journal reconstruction"
  call assertEqual '"civicport-v01-fixture"', secondTransport~request(1)~headers~first("If-None-Match"), "recovered ETag drives conditional request"
  call assertEqual 2, recoveredJournal~count, "revalidation observation appends after restart"
  return civicTestRemoveTree(root)

::requires "TestSupport.cls"
::requires "CacheTestSupport.cls"
