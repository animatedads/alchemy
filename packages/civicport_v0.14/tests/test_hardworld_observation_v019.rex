call test_hardworld_observation_v019
say "PASS test_hardworld_observation_v019"
exit 0

test_hardworld_observation_v019:
  root = civicTestTempDir("civic_hw_obs")
  body = readBinary("fixtures/postcodes_io_SW1A1AA.body")
  headers = readBinary("fixtures/postcodes_io_SW1A1AA.headers")
  transport = .CivicTestSequenceTransport~new
  ignore = transport~addHttp(200, "OK", headers, body)
  allow = .CivicAllowList~new
  endpoint = .CivicPostcodeAdapter~endpointTemplate
  ignore = allow~add(endpoint~scheme, endpoint~host, endpoint~pathTemplate, endpoint~allowQuery, endpoint~port)
  cache = .CivicCache~new(.CivicClient~new(transport, allow), .CivicJournal~new(root))
  url = "https://api.postcodes.io/postcodes/SW1A%201AA"

  world = .RYTAWorldState~new("CIVIC-OBS-WORLD")
  call assertTrue \world~hasFact("CIVIC_COUNTRY"), "world starts without civic fact"
  cacheOutcome = cache~get(url)
  call assertTrue cacheOutcome~ok, "fixture cache fetch succeeds"
  adapter = .CivicPostcodeAdapter~new
  observed = .CivicObservationFactory~observe(cacheOutcome, adapter)
  call assertTrue observed~ok, "successful mapped cache result becomes CivicObservation"
  civicObservation = observed~observation

  call assertTrue \world~hasFact("CIVIC_COUNTRY"), "creating an observation does not mutate HardWorld"
  call assertEqual "postcodes.io.postcode/0.2", civicObservation~mappingId, "mapping generation retained"
  call assertEqual cacheOutcome~document~bodyDigest, civicObservation~bodyDigest, "exact body digest retained"
  call assertEqual cacheOutcome~bodyRecordId, civicObservation~bodyRecordId, "body journal id retained"
  call assertEqual "PRESENT", civicObservation~fieldState("country"), "present mapped field distinguished"
  call assertEqual "England", civicObservation~field("country"), "country retains parser-native scalar"
  call assertEqual "ABSENT", civicObservation~fieldState("region"), "missing optional member remains absent"
  call assertEqual "UNMAPPED", civicObservation~fieldState("not_a_field"), "unknown projection name is not guessed"
  call assertEqual "/result/country", civicObservation~fieldDefinition("country")~pointer, "explicit JSON pointer retained"

  rich = civicObservation~richValue("country")
  call assertTrue rich~nativeObject == civicObservation, "rich evidence retains native CivicObservation"
  call assertEqual "PRESENT", rich~evidenceState, "rich evidence state is present"
  call assertTrue rich~scalarProjectionAllowed, "country has explicit scalar projection"
  call assertEqual "England", rich~scalarValue, "rich scalar keeps exact parser-native value"
  call assertEqual 1, rich~sourceCount, "one civic source reference retained"
  sourceRef = rich~sources[1]
  call assertTrue sourceRef~nativeObject == civicObservation~document, "source reference reaches native CivicDocument"
  call assertEqual "JSON", sourceRef~sourceFormat, "source format explicit"
  call assertEqual "CIVIC_HTTP", sourceRef~sourceKind, "network evidence kind explicit but non-authoritative"
  call assertEqual "/result/country", sourceRef~sourcePath, "source pointer retained"
  call assertEqual "SHA512:" || civicObservation~bodyDigest, sourceRef~sourceDocumentIdentity, "source document identity binds exact bytes"

  absentRich = civicObservation~richValue("region")
  call assertEqual "ABSENT", absentRich~evidenceState, "absent field stays absent evidence"
  call assertTrue \absentRich~scalarProjectionAllowed, "absence is not invented as a scalar"

  canonicalA = civicObservation~algorithmCanonicalText
  civicObservation~mappingResult~row["country"] = "Scotland"
  ignore = adapter~mapping~addField("later_field", "/result/later", .false, "STRING", .true)
  call assertEqual "England", civicObservation~field("country"), "mutable mapping result cannot rewrite frozen observation value"
  call assertTrue \civicObservation~hasField("later_field"), "later adapter mutation cannot widen frozen observation shape"
  canonicalB = civicObservation~algorithmCanonicalText
  call assertEqual canonicalA, canonicalB, "frozen CivicObservation canonical form is deterministic despite source-object mutation"
  call assertTrue canonicalA~pos(civicObservation~bodyDigest) > 0, "canonical evidence binds body digest"
  call assertTrue canonicalA~pos("/result/country") > 0, "canonical evidence binds mapping pointer"

  return civicTestRemoveTree(root)

::requires "TestSupport.cls"
::requires "CacheTestSupport.cls"
::requires "CivicHardWorld.cls"
