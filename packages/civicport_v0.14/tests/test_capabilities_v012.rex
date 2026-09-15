caps = .CivicCapabilities~v12
call assertEqual 15, caps~items, "v0.12 capability count"
call assertEqual "CIVIC_QUEUE_EVIDENCE", caps[14], "v0.12 adds durable queue evidence capability"
call assertEqual "CIVIC_SWIM_XML", caps[15], "v0.12 adds SWIM XML evidence capability"
say "PASS test_capabilities_v012"
exit 0
::requires "TestSupport.cls"
::requires "CivicCore.cls"
