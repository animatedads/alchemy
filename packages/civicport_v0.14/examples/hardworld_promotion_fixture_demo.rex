root = civicTestTempDir("civic_demo_hw")
body = readBinary("../tests/fixtures/postcodes_io_SW1A1AA.body")
headers = readBinary("../tests/fixtures/postcodes_io_SW1A1AA.headers")
transport = .CivicTestSequenceTransport~new
ignore = transport~addHttp(200, "OK", headers, body)
allow = .CivicAllowList~new
endpoint = .CivicPostcodeAdapter~endpointTemplate
ignore = allow~add(endpoint~scheme, endpoint~host, endpoint~pathTemplate, endpoint~allowQuery, endpoint~port)
cache = .CivicCache~new(.CivicClient~new(transport, allow), .CivicJournal~new(root))
fetched = cache~get("https://api.postcodes.io/postcodes/SW1A%201AA")
observed = .CivicObservationFactory~observe(fetched, .CivicPostcodeAdapter~new)
if \observed~ok then raise syntax 93.900 additional(observed~message)
civicObservation = observed~observation

say "Evidence only:" civicObservation~field("country") "world untouched"
world = .RYTAWorldState~new("CIVIC-DEMO-WORLD")
say "Before explicit grant, has fact:" world~hasFact("CIVIC_COUNTRY")

grant = .CivicPromotionGrant~new("DEMO-CIVIC-COUNTRY", civicObservation, "country", "CIVIC_COUNTRY", -
  "DEMO_HUMAN_AUTHORITY", "DEMO-CIVIC-POLICY", "DEMO-COUNTRY-RULE")
applyStatus = .CivicPromotionApplier~apply(.array~of(grant), world)
say "Applied:" applyStatus~applied
say world~fact("CIVIC_COUNTRY")~render

ignore = civicTestRemoveTree(root)
exit 0

::requires "TestSupport.cls"
::requires "CacheTestSupport.cls"
::requires "CivicHardWorld.cls"
