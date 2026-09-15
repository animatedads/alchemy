endpoint = .CivicEndpointTemplate~new("https", "example.invalid", "/source/{id}")
d1 = .CivicSourceDescriptor~new("example.source", "example.source/1", "CIVIC_TEST", "SINGULAR", "NONE", "UNIMPLEMENTED_1", endpoint, "civic.example.lookup", "civic.example.lookup/1")
d2 = .CivicSourceDescriptor~new("example.source", "example.source/2", "CIVIC_TEST", "SINGULAR", "NONE", "UNIMPLEMENTED_2", endpoint, "civic.example.lookup", "civic.example.lookup/2")
catalog = .CivicSourceCatalog~new(.array~of(d1, d2))

preferred2 = catalog~negotiate("example.source", .array~of("example.source/2", "example.source/1"))
call assertTrue preferred2~ok, "caller preference order can prefer generation 2"
call assertEqual "example.source/2", preferred2~descriptor~mappingGeneration, "generation 2 selected exactly"
preferred1 = catalog~negotiate("example.source", .array~of("example.source/1", "example.source/2"))
call assertTrue preferred1~ok, "caller preference order can prefer generation 1"
call assertEqual "example.source/1", preferred1~descriptor~mappingGeneration, "generation 1 selected exactly"
none = catalog~negotiate("example.source", .array~of("example.source/3"))
call assertTrue \none~ok, "no acceptable exact generation fails closed"
call assertEqual "GENERATION_NOT_ACCEPTABLE", none~errorCode, "no-match generation code"
duplicateToken = catalog~negotiate("example.source", .array~of("example.source/1", "example.source/1"))
call assertTrue \duplicateToken~ok, "duplicate accepted-generation tokens are rejected before selection"
call assertEqual "GENERATION_TOKEN_DUPLICATE", duplicateToken~errorCode, "duplicate generation token code"

selection = catalog~select("example.source", .array~of("example.source/2"))
call assertTrue \selection~ok, "metadata generation can exist without executable adapter implementation"
call assertEqual "ADAPTER_IMPLEMENTATION_UNAVAILABLE", selection~errorCode, "catalogue does not use reflection for unknown adapter ids"

caught = .false
signal on syntax name duplicateGeneration
badCatalog = .CivicSourceCatalog~new(.array~of(d1, d1))
signal off syntax
call assertTrue .false, "duplicate exact source generation must be rejected"
duplicateGeneration:
signal off syntax
caught = .true
call assertTrue caught, "duplicate source generation rejection observed"

caughtAbility = .false
d3 = .CivicSourceDescriptor~new("other.source", "other.source/1", "CIVIC_TEST", "SINGULAR", "NONE", "UNIMPLEMENTED_3", endpoint, "civic.example.lookup", "civic.example.lookup/1")
signal on syntax name duplicateAbility
badAbilityCatalog = .CivicSourceCatalog~new(.array~of(d1, d3))
signal off syntax
call assertTrue .false, "duplicate exact ability generation must be rejected"
duplicateAbility:
signal off syntax
caughtAbility = .true
call assertTrue caughtAbility, "duplicate ability generation rejection observed"

say "PASS test_catalog_negotiation_v011"
exit 0

::requires "TestSupport.cls"
::requires "CivicCatalog.cls"
