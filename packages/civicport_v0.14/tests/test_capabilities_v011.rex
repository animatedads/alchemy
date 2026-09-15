caps = .CivicCapabilities~v11
call assertEqual 13, caps~items, "v0.11 capability count"
call assertEqual "CIVIC_SOURCE_CATALOG", caps[12], "v0.11 adds source catalogue capability"
call assertEqual "CIVIC_GENERATION_NEGOTIATION", caps[13], "v0.11 adds exact caller-driven generation negotiation"
say "PASS test_capabilities_v011"
exit 0
::requires "TestSupport.cls"
::requires "CivicCore.cls"
