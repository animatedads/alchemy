intervention = .TestNarrativeFixture~intervention
governance = .TestNarrativeFixture~governance("PAUSE", .false)
projected = .BrandNarrativeProjectionEngine~new~project(intervention, governance, "DIR-PAUSE")
if \projected~ok then signal fail
engine = .BrandNarrativeHandoffEngine~new
missing = engine~prepare(projected~value, governance, "HANDOFF-PAUSE-1")
if missing~ok then signal fail
if missing~code \== "FRESH_AUTHORITY_VERIFICATION_REQUIRED" then signal fail
ready = engine~prepare(projected~value, governance, "HANDOFF-PAUSE-2", "", .nil, .TestNarrativeAuthorityVerifier~new)
if \ready~ok then signal fail
if ready~value~stage \== "READY_FOR_NARRATIVE_SELECTION" then signal fail
say "PASS pause/withdraw style effects also require fresh governance verification"
exit 0
fail:
say "FAIL pause handoff verification"
exit 1
::requires "TestBrandNarrativeFixtures.cls"
