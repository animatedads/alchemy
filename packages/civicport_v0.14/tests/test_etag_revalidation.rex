call test_etag_revalidation
say "PASS test_etag_revalidation"
exit 0

test_etag_revalidation:
  root = civicTestTempDir("civic_etag")
  body = readBinary("fixtures/postcodes_io_SW1A1AA.body")
  headers200 = readBinary("fixtures/postcodes_io_SW1A1AA.headers")
  headers304 = "HTTP/1.1 304 Not Modified" || '0d0a'x || -
    'ETag: "civicport-v01-fixture"' || '0d0a'x || -
    "Date: Thu, 20 Aug 2026 20:00:00 GMT" || '0d0a0d0a'x

  allow = .CivicAllowList~new
  ignore = allow~add("https", "api.postcodes.io", "/postcodes/{postcode}")
  transport = .CivicTestSequenceTransport~new
  ignore = transport~addHttp(200, "OK", headers200, body)
  ignore = transport~addHttp(304, "Not Modified", headers304, "")
  client = .CivicClient~new(transport, allow)
  journal = .CivicJournal~new(root)
  cache = .CivicCache~new(client, journal)
  url = "https://api.postcodes.io/postcodes/SW1A%201AA"

  firstFetch = cache~get(url)
  call assertTrue firstFetch~ok, "initial cached fetch succeeds"
  call assertEqual "MISS", firstFetch~cacheState, "first fetch is cache miss"
  call assertEqual 200, firstFetch~document~status, "initial body document is 200"
  call assertEqual firstFetch~bodyRecordId, firstFetch~observationRecordId, "initial observation is the body record"
  originalFetchedAt = firstFetch~document~fetchedAt
  originalDigest = firstFetch~document~bodyDigest

  secondFetch = cache~get(url)
  call assertTrue secondFetch~ok, "304 cache resolution succeeds"
  call assertEqual "REVALIDATED", secondFetch~cacheState, "304 resolution is explicitly revalidated"
  call assertEqual 200, secondFetch~document~status, "projectable document remains the earlier body-bearing 200"
  call assertEqual originalDigest, secondFetch~document~bodyDigest, "body identity remains the earlier exact bytes"
  call assertEqual originalFetchedAt, secondFetch~document~fetchedAt, "304 does not rewrite earlier fetchedAt"
  call assertEqual 304, secondFetch~observation~status, "actual network observation remains a distinct 304 document"
  call assertEqual "", secondFetch~observation~bodyBytes, "304 document retains its actual empty body"
  call assertEqual "REVALIDATED", secondFetch~observation~cacheState, "304 observation carries revalidation context"
  call assertEqual 2, journal~count, "200 and 304 are both journaled observations"
  call assertEqual firstFetch~bodyRecordId, journal~record(secondFetch~observationRecordId)~bodySourceRecordId, "304 journal record explicitly links earlier body record"

  call assertEqual 2, transport~requestCount, "two HTTP requests occurred"
  conditionalRequest = transport~request(2)
  call assertEqual '"civicport-v01-fixture"', conditionalRequest~headers~first("If-None-Match"), "ETag emitted as conditional request header"
  return civicTestRemoveTree(root)

::requires "TestSupport.cls"
::requires "CacheTestSupport.cls"
