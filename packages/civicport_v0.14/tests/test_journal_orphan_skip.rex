call test_journal_orphan_skip
say "PASS test_journal_orphan_skip"
exit 0

test_journal_orphan_skip:
  root = civicTestTempDir("civic_orphanfile")
  recordsDir = root || "/records"
  call SysMkDir recordsDir
  orphanPath = recordsDir || "/CIVICDOC000000000001.body"
  s = .Stream~new(orphanPath)
  opened = s~open("WRITE REPLACE")
  call assertTrue opened~caselessEquals("READY:"), "orphan test file opens"
  written = s~charOut("orphan from interrupted pre-journal write")
  ignore = s~close

  body = readBinary("fixtures/postcodes_io_SW1A1AA.body")
  headers200 = readBinary("fixtures/postcodes_io_SW1A1AA.headers")
  allow = .CivicAllowList~new
  ignore = allow~add("https", "api.postcodes.io", "/postcodes/{postcode}")
  transport = .CivicTestSequenceTransport~new
  ignore = transport~addHttp(200, "OK", headers200, body)
  journal = .CivicJournal~new(root)
  cache = .CivicCache~new(.CivicClient~new(transport, allow), journal)
  fetch = cache~get("https://api.postcodes.io/postcodes/SW1A%201AA")
  call assertEqual "CIVICDOC000000000002", fetch~bodyRecordId, "journal skips orphan record filename instead of wedging append"
  call assertEqual 1, journal~count, "only published journal record counts"
  return civicTestRemoveTree(root)

::requires "TestSupport.cls"
::requires "CacheTestSupport.cls"
