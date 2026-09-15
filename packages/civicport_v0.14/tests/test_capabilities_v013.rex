caps = .CivicCapabilities~v13
call assertEqual 16, caps~items, "v0.13 capability count"
call assertEqual "CIVIC_NOTAM_RUNWAY_CLOSURE", caps[16], "v0.13 adds narrow NOTAM runway-closure evidence capability"
say "PASS test_capabilities_v013"
exit 0
::requires "TestSupport.cls"
::requires "CivicCore.cls"
