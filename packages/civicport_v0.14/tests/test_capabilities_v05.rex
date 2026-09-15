caps = .CivicCapabilities~v05
call assertEqual 5, caps~items, "v0.5 advertises exactly five capabilities"
call assertEqual "CIVIC_HTTP", caps[1], "HTTP remains first capability"
call assertEqual "CIVIC_JSON", caps[2], "JSON remains second capability"
call assertEqual "CIVIC_ETAG_CACHE", caps[3], "cache remains third capability"
call assertEqual "CIVIC_READONLY_RELATION", caps[4], "read-only relation remains fourth capability"
call assertEqual "CIVIC_PROMOTION", caps[5], "explicit promotion is the v0.5 capability"
say "PASS test_capabilities_v05"
exit 0

::requires "TestSupport.cls"
::requires "CivicCore.cls"
