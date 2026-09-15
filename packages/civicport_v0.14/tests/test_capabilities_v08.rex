caps = .CivicCapabilities~v08
call assertEqual 7, caps~items, "v0.8 capability count"
call assertEqual "CIVIC_HTTP", caps[1], "HTTP remains first capability"
call assertEqual "CIVIC_JSON", caps[2], "JSON remains second capability"
call assertEqual "CIVIC_ETAG_CACHE", caps[3], "cache remains third capability"
call assertEqual "CIVIC_READONLY_RELATION", caps[4], "read-only relation remains fourth capability"
call assertEqual "CIVIC_PROMOTION", caps[5], "explicit promotion remains fifth capability"
call assertEqual "CIVIC_ACCESS_STATE", caps[6], "access state remains sixth capability"
call assertEqual "CIVIC_API_CONTRACT", caps[7], "v0.8 adds pinned API contract capability"
say "PASS test_capabilities_v08"
exit 0
::requires "TestSupport.cls"
::requires "CivicCore.cls"
