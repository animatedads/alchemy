call test_civic_promotion_conflict_v019
say "PASS test_civic_promotion_conflict_v019"
exit 0

test_civic_promotion_conflict_v019:
  first = makeObservation("England", "civic_hw_conflict_a")
  second = makeObservation("Wales", "civic_hw_conflict_b")
  obsA = first["observation"]
  obsB = second["observation"]
  world = .RYTAWorldState~new("CIVIC-CONFLICT-WORLD")

  grantA = .CivicPromotionGrant~new("CIVIC-CONFLICT-A", obsA, "country", "CIVIC_COUNTRY", -
    "TEST_HUMAN_AUTHORITY", "CIVIC-CONFLICT-POLICY", "COUNTRY-A")
  grantB = .CivicPromotionGrant~new("CIVIC-CONFLICT-B", obsB, "country", "CIVIC_COUNTRY", -
    "TEST_HUMAN_AUTHORITY", "CIVIC-CONFLICT-POLICY", "COUNTRY-B")
  applyStatus = .CivicPromotionApplier~apply(.array~of(grantA, grantB), world)
  call assertEqual 0, applyStatus~applied, "disagreeing civic grants are not arbitrarily applied"
  call assertEqual 1, applyStatus~conflicts, "disagreement becomes one HardWorld conflict"
  fact = world~fact("CIVIC_COUNTRY")
  call assertEqual "CONFLICT", fact~knowledgeState, "HardWorld records civic disagreement as CONFLICT"
  call assertEqual 2, fact~evidence~promotions~items, "both source observations survive conflict bundle"

  ignore = civicTestRemoveTree(first["root"])
  return civicTestRemoveTree(second["root"])

makeObservation: procedure
  use arg country, prefix
  root = civicTestTempDir(prefix)
  body = '{"status":200,"result":{"postcode":"SW1A 1AA","country":"' || country || '"}}'
  headers = "HTTP/1.1 200 OK" || '0d0a'x || "Content-Type: application/json" || '0d0a0d0a'x
  transport = .CivicTestSequenceTransport~new
  ignore = transport~addHttp(200, "OK", headers, body)
  allow = .CivicAllowList~new
  endpoint = .CivicPostcodeAdapter~endpointTemplate
  ignore = allow~add(endpoint~scheme, endpoint~host, endpoint~pathTemplate, endpoint~allowQuery, endpoint~port)
  cache = .CivicCache~new(.CivicClient~new(transport, allow), .CivicJournal~new(root))
  cacheOutcome = cache~get("https://api.postcodes.io/postcodes/SW1A%201AA")
  observed = .CivicObservationFactory~observe(cacheOutcome, .CivicPostcodeAdapter~new)
  if \observed~ok then raise syntax 93.900 additional("Fixture observation failed: " || observed~message)
  box = .directory~new
  box["root"] = root
  box["observation"] = observed~observation
  return box

::requires "TestSupport.cls"
::requires "CacheTestSupport.cls"
::requires "CivicHardWorld.cls"
