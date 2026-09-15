call test_runtime_metar_v010
say "PASS test_runtime_metar_v010"
exit 0

test_runtime_metar_v010:
  call assertTrue .CivicMetarApiContract~isSubclassOf(.AlchemyObject), "METAR API contract inherits house base"
  contract = .CivicMetarApiContract~new
  call assertEqual "civic.metar.lookup/0.1", contract~contractGeneration, "METAR contract generation pinned"
  call assertEqual "aviationweather.metar/0.1", contract~mappingGeneration, "METAR mapping generation pinned"
  call assertEqual "civic.metar.lookup", contract~abilityId, "METAR ability id pinned"

  descriptor = contract~descriptor("civic")
  call assertTrue descriptor~readOnly, "METAR ability is read only"
  good = .directory~new
  good["station_icao"] = .JsonString~new("EGLL")
  call assertTrue descriptor~validateInput(good)~ok, "METAR station input validates"
  do forbidden over .array~of("url", "hours", "bbox")
    injected = good~copy
    injected[forbidden] = "forbidden"
    check = descriptor~validateInput(injected)
    call assertTrue \check~ok, "METAR API rejects caller property " || forbidden
    call assertEqual "ABILITY_SCHEMA_ADDITIONAL_PROPERTY", check~code, "extra METAR selector rejected by exact schema"
  end

  root = civicTestTempDir("civic_metar_contract_v010")
  transport = .CivicTestSequenceTransport~new
  ignore = transport~addHttp(200, "OK", readBinary("fixtures/aviationweather_EGLL_fixture.headers"), readBinary("fixtures/aviationweather_EGLL_fixture.body"))
  allow = .CivicAllowList~new
  endpoint = .CivicAviationWeatherAdapter~endpointTemplate
  ignore = allow~add(endpoint~scheme, endpoint~host, endpoint~pathTemplate, endpoint~allowQuery, endpoint~port, endpoint~queryTemplate)
  cache = .CivicCache~new(.CivicClient~new(transport, allow), .CivicJournal~new(root))
  outcome = cache~get(.CivicAviationWeatherAdapter~metarUrl("EGLL"))
  call assertTrue outcome~ok, "METAR fixture cache fetch succeeds"
  output = contract~projectCacheResult(outcome)
  outputCheck = descriptor~validateOutput(output)
  call assertTrue outputCheck~ok, "METAR evidence projection satisfies exact output schema"
  call assertEqual "civic.metar.lookup/0.1", output["contract_generation"], "METAR output carries contract generation"
  call assertEqual "aviationweather.metar/0.1", output["mapping_generation"], "METAR output carries mapping generation"
  call assertEqual 2, output["observations"]~items, "Runtime API preserves all observations"

  first = output["observations"][1]
  second = output["observations"][2]
  call assertEqual "/0", first["source_pointer"], "first API observation has exact source pointer"
  call assertEqual "/1", second["source_pointer"], "second API observation has exact source pointer"
  call assertTrue first["evidence_identity"] \== second["evidence_identity"], "collection observations have distinct evidence identities"
  call assertEqual "21.0", first["values"]["temperature_c"], "METAR numeric lexical representation remains parser-native"
  call assertTrue first["values"]["temperature_c"]~isA(.String), "METAR numeric output remains ooRexx String"
  call assertEqual "PRESENT_NULL", first["field_states"]["wind_gust_kt"], "explicit null METAR gust remains distinct"
  call assertTrue \first["values"]~hasIndex("wind_gust_kt"), "null gust is omitted from API values"
  call assertTrue \first["values"]~hasIndex("wdir"), "union wind direction is not silently projected"
  call assertTrue \first["values"]~hasIndex("visib"), "union visibility is not silently projected"
  call assertTrue \first["values"]~hasIndex("clouds"), "structured clouds are not silently projected"

  pin = contract~profilePin("civic-test-client", "1", "civic", "tests/RuntimeCivicContractFixture_v1.cls", "metar-handler-v1")
  call assertEqual "civicport-metar", pin~profile~profileId, "METAR profile has its own identity family"
  call assertTrue pin~profile~canonicalText~pos("aviationweather.metar/0.1") > 0, "METAR profile canonical text incorporates mapping generation"

  emptyRoot = civicTestTempDir("civic_metar_contract_204_v010")
  transport204 = .CivicTestSequenceTransport~new
  headers204 = "HTTP/1.1 204 No Content" || '0d0a'x || "Content-Type: application/json" || '0d0a0d0a'x
  ignore = transport204~addHttp(204, "No Content", headers204, "")
  cache204 = .CivicCache~new(.CivicClient~new(transport204, allow), .CivicJournal~new(emptyRoot))
  outcome204 = cache204~get(.CivicAviationWeatherAdapter~metarUrl("EGLL"))
  call assertTrue outcome204~ok, "HTTP 204 is an evidence document"
  output204 = contract~projectCacheResult(outcome204)
  call assertEqual 0, output204["observations"]~items, "204 projects a truthful empty observation collection"
  call assertTrue descriptor~validateOutput(output204)~ok, "204 empty collection satisfies METAR output contract"

  ignore = civicTestRemoveTree(emptyRoot)
  ignore = civicTestRemoveTree(root)
  return

::requires "TestSupport.cls"
::requires "CacheTestSupport.cls"
::requires "CivicAviationWeatherRuntime.cls"
