call test_metar_hardworld_v010
say "PASS test_metar_hardworld_v010"
exit 0

test_metar_hardworld_v010:
  root = civicTestTempDir("civic_metar_hw")
  transport = .CivicTestSequenceTransport~new
  ignore = transport~addHttp(200, "OK", readBinary("fixtures/aviationweather_EGLL_fixture.headers"), readBinary("fixtures/aviationweather_EGLL_fixture.body"))
  allow = .CivicAllowList~new
  endpoint = .CivicAviationWeatherAdapter~endpointTemplate
  ignore = allow~add(endpoint~scheme, endpoint~host, endpoint~pathTemplate, endpoint~allowQuery, endpoint~port, endpoint~queryTemplate)
  cache = .CivicCache~new(.CivicClient~new(transport, allow), .CivicJournal~new(root))
  outcome = cache~get(.CivicAviationWeatherAdapter~metarUrl("EGLL"))
  call assertTrue outcome~ok, "METAR cache fetch succeeds"

  adapter = .CivicAviationWeatherAdapter~new
  mappedCollection = adapter~mapAll(outcome~document)
  call assertTrue mappedCollection~ok, "METAR collection maps"
  mappedItems = mappedCollection~items
  firstResult = .CivicObservationFactory~observeMapped(outcome, mappedItems[1], adapter~mapping)
  secondResult = .CivicObservationFactory~observeMapped(outcome, mappedItems[2], adapter~mapping)
  call assertTrue firstResult~ok, "first METAR maps into generic CivicObservation"
  call assertTrue secondResult~ok, "second METAR maps into generic CivicObservation"
  first = firstResult~observation
  second = secondResult~observation
  call assertEqual "/0", first~sourcePointer, "first HardWorld observation retains source pointer"
  call assertEqual "/1", second~sourcePointer, "second HardWorld observation retains source pointer"
  call assertTrue first~identity \== second~identity, "two METAR source items have distinct observation identities"
  call assertEqual "PRESENT_NULL", first~fieldState("wind_gust_kt"), "HardWorld evidence retains explicit null state"
  call assertTrue \first~hasField("clouds"), "unprojected cloud array is not implicitly promotable"
  rich = first~richValue("temperature_c", "EGLL_TEMPERATURE_C")
  call assertEqual "21.0", rich~presentationValue, "rich evidence keeps exact METAR temperature lexical value"
  call assertEqual "/0/temp", rich~sources[1]~sourcePath, "rich evidence points to exact collection JSON pointer"

  world = .RYTAWorldState~new("CIVIC-METAR-WORLD")
  grant = .CivicPromotionGrant~new("CIVIC-METAR-TEMP-1", first, "temperature_c", "EGLL_TEMPERATURE_C", -
    "TEST_METEOROLOGICAL_AUTHORITY", "CIVIC-METAR-PROMOTION-V1", "TEMPERATURE_FROM_PINNED_METAR")
  call assertTrue \world~hasFact("EGLL_TEMPERATURE_C"), "METAR observation and grant alone do not change HardWorld"
  applied = .CivicPromotionApplier~apply(.array~of(grant), world)
  call assertEqual 1, applied~applied, "explicit METAR promotion applies once"
  fact = world~fact("EGLL_TEMPERATURE_C")
  call assertEqual "KNOWN", fact~knowledgeState, "METAR temperature becomes known only after explicit promotion"
  call assertEqual "21.0", fact~value, "promoted METAR temperature remains exact lexical value"
  call assertEqual "TEST_METEOROLOGICAL_AUTHORITY", fact~authority, "AviationWeather.gov host is not promotion authority"
  call assertTrue fact~evidence~promotions[1]~sourceObject == first, "HardWorld promotion retains selected native METAR observation"
  return civicTestRemoveTree(root)

::requires "TestSupport.cls"
::requires "CacheTestSupport.cls"
::requires "CivicAviationWeather.cls"
::requires "CivicHardWorld.cls"
