call test_json_number_journal
say "PASS test_json_number_journal"
exit 0

test_json_number_journal:
  root = civicTestTempDir("civic_numbers")
  body = '{"status":200,"result":{"postcode":"SW1A 1AA","country":"England","precise":1.2300e+04,"huge":90071992547409931234567890}}'
  headers = "HTTP/1.1 200 OK" || '0d0a'x || "Content-Type: application/json" || '0d0a'x || 'ETag: "numbers"' || '0d0a0d0a'x
  allow = .CivicAllowList~new
  ignore = allow~add("https", "api.postcodes.io", "/postcodes/{postcode}")
  transport = .CivicTestSequenceTransport~new
  ignore = transport~addHttp(200, "OK", headers, body)
  journal = .CivicJournal~new(root)
  cache = .CivicCache~new(.CivicClient~new(transport, allow), journal)
  fetch = cache~get("https://api.postcodes.io/postcodes/SW1A%201AA")
  call assertEqual "1.2300e+04", fetch~document~parsed["result"]["precise"], "ooRexx JSON numeric lexical form is not converted by CivicPort"
  call assertEqual "90071992547409931234567890", fetch~document~parsed["result"]["huge"], "large JSON number remains parser-native string"

  recovered = .CivicJournal~new(root)
  recoveredDoc = recovered~record(fetch~bodyRecordId)~document
  call assertEqual "1.2300e+04", recoveredDoc~parsed["result"]["precise"], "journal recovery replays exact bytes without numeric conversion layer"
  call assertEqual "90071992547409931234567890", recoveredDoc~parsed["result"]["huge"], "journal recovery preserves large numeric lexical form"
  return civicTestRemoveTree(root)

::requires "TestSupport.cls"
::requires "CacheTestSupport.cls"
