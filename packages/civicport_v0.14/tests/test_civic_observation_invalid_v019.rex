call test_civic_observation_invalid_v019
say "PASS test_civic_observation_invalid_v019"
exit 0

test_civic_observation_invalid_v019:
  root = civicTestTempDir("civic_hw_invalid")
  body = '{"status":200,"result":{"country":"England"}}'
  headers = "HTTP/1.1 200 OK" || '0d0a'x || "Content-Type: application/json" || '0d0a0d0a'x
  transport = .CivicTestSequenceTransport~new
  ignore = transport~addHttp(200, "OK", headers, body)
  allow = .CivicAllowList~new
  endpoint = .CivicPostcodeAdapter~endpointTemplate
  ignore = allow~add(endpoint~scheme, endpoint~host, endpoint~pathTemplate, endpoint~allowQuery, endpoint~port)
  cache = .CivicCache~new(.CivicClient~new(transport, allow), .CivicJournal~new(root))
  fetched = cache~get("https://api.postcodes.io/postcodes/SW1A%201AA")
  call assertTrue fetched~ok, "HTTP evidence remains a successful cache result"
  observed = .CivicObservationFactory~observe(fetched, .CivicPostcodeAdapter~new)
  call assertTrue \observed~ok, "mapping-invalid JSON cannot become CivicObservation"
  call assertEqual "MAPPING_INVALID", observed~errorCode, "observation failure identifies mapping boundary"
  call assertTrue observed~observation == .nil, "invalid mapping has no observation object"
  world = .RYTAWorldState~new("CIVIC-INVALID-WORLD")
  call assertTrue \world~hasFact("CIVIC_COUNTRY"), "invalid mapping cannot mutate HardWorld"
  return civicTestRemoveTree(root)

::requires "TestSupport.cls"
::requires "CacheTestSupport.cls"
::requires "CivicHardWorld.cls"
