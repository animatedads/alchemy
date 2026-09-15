caps = .CivicCapabilities~v07
call assertEqual 6, caps~items, "v0.7 capability count"
call assertEqual "CIVIC_HTTP", caps[1], "HTTP remains first capability"
call assertEqual "CIVIC_JSON", caps[2], "JSON remains second capability"
call assertEqual "CIVIC_ETAG_CACHE", caps[3], "cache remains third capability"
call assertEqual "CIVIC_READONLY_RELATION", caps[4], "read-only relation remains fourth capability"
call assertEqual "CIVIC_PROMOTION", caps[5], "explicit promotion remains fifth capability"
call assertEqual "CIVIC_ACCESS_STATE", caps[6], "v0.7 adds operational access evidence"
say "PASS test_capabilities_v07"
exit 0
::requires "TestSupport.cls"
::requires "CivicCore.cls"
