intervention = .TestNarrativeFixture~intervention
governance = .TestNarrativeFixture~governance("NO_CHANGE", .false)
projected = .BrandNarrativeProjectionEngine~new~project(intervention, governance, "DIR-NOCHANGE")
if \projected~ok then signal fail
handoffResult = .BrandNarrativeHandoffEngine~new~prepare(projected~value, governance, "HANDOFF-NOCHANGE")
if \handoffResult~ok then signal fail
handoff = handoffResult~value
if handoff~stage \== "EVIDENCE_ONLY_NO_RUNTIME_CHANGE" then signal fail
if handoff~verificationRef \== "" then signal fail
if handoff~authorityMode \== "NO_DISPATCH" then signal fail
say "PASS no-change handoff remains evidence-only without invented verifier requirement"
exit 0
fail:
say "FAIL no-change handoff"
exit 1
::requires "TestBrandNarrativeFixtures.cls"
