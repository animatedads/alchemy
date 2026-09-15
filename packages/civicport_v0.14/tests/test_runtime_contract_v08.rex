call test_runtime_contract_v08
say "PASS test_runtime_contract_v08"
exit 0

test_runtime_contract_v08:
  call assertTrue .CivicApiFieldContract~isSubclassOf(.AlchemyObject), "API field contract inherits house base"
  call assertTrue .CivicPostcodeApiContract~isSubclassOf(.AlchemyObject), "postcode API contract inherits house base"
  call assertTrue .CivicApiProfilePin~isSubclassOf(.AlchemyObject), "API profile pin inherits house base"
  contract = .CivicPostcodeApiContract~new
  call assertEqual "civic.postcode.lookup/0.1", contract~contractGeneration, "contract generation pinned"
  call assertEqual "postcodes.io.postcode/0.2", contract~mappingGeneration, "mapping generation pinned"
  call assertEqual "civic.postcode.lookup", contract~abilityId, "ability id pinned"

  descriptor = contract~descriptor("civic")
  call assertEqual "CIVIC_LOOKUP", descriptor~kind, "ability kind"
  call assertTrue descriptor~readOnly, "ability is read only"
  call assertEqual 1, descriptor~requiredAliases~items, "one runtime alias"
  call assertEqual "civic", descriptor~requiredAliases[1], "runtime alias pinned"

  goodInput = .directory~new
  goodInput["postcode"] = "SW1A 1AA"
  goodCheck = descriptor~validateInput(goodInput)
  call assertTrue goodCheck~ok, "valid postcode input satisfies schema"

  missingInput = .directory~new
  missingCheck = descriptor~validateInput(missingInput)
  call assertTrue \missingCheck~ok, "missing postcode rejected by schema"
  call assertEqual "ABILITY_SCHEMA_REQUIRED_MISSING", missingCheck~code, "missing postcode schema code"

  extraInput = .directory~new
  extraInput["postcode"] = "SW1A 1AA"
  extraInput["url"] = "https://evil.invalid/"
  extraCheck = descriptor~validateInput(extraInput)
  call assertTrue \extraCheck~ok, "client cannot inject URL through API contract"
  call assertEqual "ABILITY_SCHEMA_ADDITIONAL_PROPERTY", extraCheck~code, "URL injection rejected by schema"

  root = civicTestTempDir("civic_contract_v08")
  transport = .CivicTestSequenceTransport~new
  rawHeaders = "HTTP/1.1 200 OK" || "0d0a"x || "Content-Type: application/json" || "0d0a"x || 'ETag: "contract-v08"' || "0d0a0d0a"x
  body = '{"status":200,"result":{"postcode":"SW1A 1AA","country":"England","admin_district":null}}'
  ignore = transport~addHttp(200, "OK", rawHeaders, body)
  allow = .CivicAllowList~new
  endpoint = .CivicPostcodeAdapter~endpointTemplate
  ignore = allow~add(endpoint~scheme, endpoint~host, endpoint~pathTemplate, endpoint~allowQuery, endpoint~port)
  client = .CivicClient~new(transport, allow)
  cache = .CivicCache~new(client, .CivicJournal~new(root))
  cacheOutcome = cache~get("https://api.postcodes.io/postcodes/SW1A%201AA")
  call assertTrue cacheOutcome~ok, "fixture cache fetch succeeds"
  output = contract~projectCacheResult(cacheOutcome)
  outputCheck = descriptor~validateOutput(output)
  call assertTrue outputCheck~ok, "projected observation satisfies exact output schema"
  call assertEqual "civic.postcode.lookup/0.1", output["contract_generation"], "output carries exact contract generation"
  call assertEqual "postcodes.io.postcode/0.2", output["mapping_generation"], "output carries exact mapping generation"
  call assertEqual "SW1A 1AA", output["values"]["postcode"], "postcode projected"
  call assertEqual "England", output["values"]["country"], "country projected"
  call assertEqual "PRESENT_NULL", output["field_states"]["admin_district"], "present null remains distinct"
  call assertTrue \output["values"]~hasIndex("admin_district"), "present null does not invent a string value"
  call assertEqual "ABSENT", output["field_states"]["region"], "absent optional field remains distinct"
  call assertTrue \output["values"]~hasIndex("region"), "absent field does not invent value"

  tampered = output~copy
  tampered["mapping_generation"] = "postcodes.io.postcode/0.3"
  tamperCheck = descriptor~validateOutput(tampered)
  call assertTrue \tamperCheck~ok, "mapping generation drift violates output contract"
  call assertEqual "ABILITY_SCHEMA_CONST_MISMATCH", tamperCheck~code, "mapping generation const enforces pin"

  numericRoot = civicTestTempDir("civic_contract_number_v08")
  numericTransport = .CivicTestSequenceTransport~new
  numericBody = '{"status":200,"result":{"postcode":"SW1A 1AA","country":"England","longitude":1.2300e+04}}'
  ignore = numericTransport~addHttp(200, "OK", rawHeaders, numericBody)
  numericClient = .CivicClient~new(numericTransport, allow)
  numericCache = .CivicCache~new(numericClient, .CivicJournal~new(numericRoot))
  numericOutcome = numericCache~get("https://api.postcodes.io/postcodes/SW1A%201AA")
  call assertTrue numericOutcome~ok, "numeric fixture cache fetch succeeds"
  numericOutput = contract~projectCacheResult(numericOutcome)
  call assertEqual "1.2300e+04", numericOutput["values"]["longitude"], "numeric lexical representation remains parser-native"
  call assertTrue numericOutput["values"]["longitude"]~isA(.String), "numeric API value remains ooRexx String"
  numericCheck = descriptor~validateOutput(numericOutput)
  call assertTrue numericCheck~ok, "parser-native numeric string satisfies declared Ability number schema without CivicPort coercion"

  ignore = civicTestRemoveTree(numericRoot)
  ignore = civicTestRemoveTree(root)
  return

::requires "TestSupport.cls"
::requires "CacheTestSupport.cls"
::requires "CivicRuntime.cls"
