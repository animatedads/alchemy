call test_journal_integrity
say "PASS test_journal_integrity"
exit 0

test_journal_integrity:
  root = civicTestTempDir("civic_integrity")
  body = readBinary("fixtures/postcodes_io_SW1A1AA.body")
  headers200 = readBinary("fixtures/postcodes_io_SW1A1AA.headers")
  allow = .CivicAllowList~new
  ignore = allow~add("https", "api.postcodes.io", "/postcodes/{postcode}")
  transport = .CivicTestSequenceTransport~new
  ignore = transport~addHttp(200, "OK", headers200, body)
  journal = .CivicJournal~new(root)
  cache = .CivicCache~new(.CivicClient~new(transport, allow), journal)
  fetch = cache~get("https://api.postcodes.io/postcodes/SW1A%201AA")
  bodyPath = journal~recordsDirectory || "/" || fetch~bodyRecordId || ".body"
  call writeBinaryReplace bodyPath, "tampered"

  corruptionCaught = .false
  signal on syntax name expectedBodyCorruption
  badJournal = .CivicJournal~new(root)
  signal off syntax
  call assertTrue .false, "tampered body must not recover"
expectedBodyCorruption:
  signal off syntax
  corruptionCaught = .true
  call assertTrue corruptionCaught, "body digest corruption fails closed"
  call civicTestRemoveTree root

  root2 = civicTestTempDir("civic_torntail")
  journalPath = root2 || "/civic.journal"
  call writeBinaryReplace journalPath, "CIVICDOC000000000001|deadbeef"
  tornCaught = .false
  signal on syntax name expectedTornTail
  badTail = .CivicJournal~new(root2)
  signal off syntax
  call assertTrue .false, "unterminated journal tail must not recover"
expectedTornTail:
  signal off syntax
  tornCaught = .true
  call assertTrue tornCaught, "torn journal tail fails closed"
  return civicTestRemoveTree(root2)

writeBinaryReplace:
  use arg path, bytes
  s = .Stream~new(path)
  opened = s~open("WRITE REPLACE")
  if \opened~caselessEquals("READY:") then raise syntax 93.900 additional("Cannot write test file")
  if bytes~length > 0 then written = s~charOut(bytes)
  ignore = s~close
  return .true

::requires "TestSupport.cls"
::requires "CacheTestSupport.cls"
