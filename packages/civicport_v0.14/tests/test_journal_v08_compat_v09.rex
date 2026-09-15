call test_journal_v08_compat_v09
say "PASS test_journal_v08_compat_v09"
exit 0

test_journal_v08_compat_v09:
  root = civicTestTempDir("civic_v08_journal_compat")
  commandText = "cp -a -- fixtures/journal_v08/. " || civicShellQuote(root || "/")
  address system commandText
  call assertEqual 0, rc, "copy pinned v0.8.1 journal fixture"

  journal = .CivicJournal~new(root)
  call assertEqual 1, journal~count, "v0.9 reads pinned v0.8.1 journal"
  record = journal~record("CIVICDOC000000000001")
  call assertTrue record \== .nil, "legacy record is recoverable"
  call assertEqual "", record~document~request~credentialRef, "legacy journal reconstructs empty credential reference"
  call assertEqual 200, record~document~status, "legacy HTTP status survives"
  call assertEqual "cf099f0e0b5307badcb2d69d059363b4fe3d523f59a8637572268f4f3d96eb86a0e0b60585f31e9745da6a67ac1d3e92c787eb3163bfc79b30baa97b3d9e3da2", record~document~bodyDigest, "legacy body identity survives journal format upgrade"
  call assertEqual '"civicport-v01-fixture"', record~document~header("ETag"), "legacy validator survives"
  return civicTestRemoveTree(root)

::requires "TestSupport.cls"
::requires "CacheTestSupport.cls"
::requires "CivicPostcode.cls"
::requires "CivicCache.cls"
