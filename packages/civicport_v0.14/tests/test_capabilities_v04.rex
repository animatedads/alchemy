caps = .CivicCapabilities~v04
call assertEqual 4, caps~items, "v0.4 capability count"
call assertEqual "CIVIC_HTTP", caps[1], "HTTP capability retained"
call assertEqual "CIVIC_JSON", caps[2], "JSON capability retained"
call assertEqual "CIVIC_ETAG_CACHE", caps[3], "cache capability retained"
call assertEqual "CIVIC_READONLY_RELATION", caps[4], "read-only relation capability advertised"
say "PASS test_capabilities_v04"
exit 0
::requires "TestSupport.cls"
::requires "CivicCore.cls"
