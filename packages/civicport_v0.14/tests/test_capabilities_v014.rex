caps = .CivicCapabilities~v14
call assertEqual 18, caps~items, "v0.14 capability count"
call assertEqual "CIVIC_NOTAM_READONLY_RELATION", caps[17], "v0.14 adds NOTAM read-only relation"
call assertEqual "CIVIC_NOTAM_API_CONTRACT", caps[18], "v0.14 adds NOTAM Runtime API contract"
say "PASS test_capabilities_v014"
exit 0
::requires "TestSupport.cls"
::requires "CivicCore.cls"
