caps = .CivicCapabilities~v10
call assertEqual 11, caps~items, "v0.10 capability count"
call assertEqual "CIVIC_JSON_COLLECTION", caps[10], "v0.10 adds collection mapping capability"
call assertEqual "CIVIC_METAR_OBSERVATION", caps[11], "v0.10 adds METAR observation capability"
say "PASS test_capabilities_v010"
exit 0
::requires "TestSupport.cls"
::requires "CivicCore.cls"
