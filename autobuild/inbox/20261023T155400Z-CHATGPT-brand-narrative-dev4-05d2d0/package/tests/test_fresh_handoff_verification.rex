intervention = .TestNarrativeFixture~intervention
governance = .TestNarrativeFixture~governance("APPROVE_CONTROLLED_PILOT", .true)
projected = .BrandNarrativeProjectionEngine~new~project(intervention, governance, "DIR-HANDOFF")
if \projected~ok then signal fail
directive = projected~value
engine = .BrandNarrativeHandoffEngine~new
missing = engine~prepare(directive, governance, "HANDOFF-1")
if missing~ok then signal fail
if missing~code \== "FRESH_AUTHORITY_VERIFICATION_REQUIRED" then signal fail
ready = engine~prepare(directive, governance, "HANDOFF-2", "", .nil, .TestNarrativeAuthorityVerifier~new)
if \ready~ok then signal fail
handoff = ready~value
if handoff~stage \== "READY_FOR_NARRATIVE_SELECTION" then signal fail
if handoff~authorityMode \== "NO_DISPATCH" then signal fail
if handoff~publicationAuthority \== "NONE" then signal fail
if handoff~verificationRef == "" then signal fail
wrongPolicy = engine~prepare(directive, governance, "HANDOFF-3", "", .nil, .TestNarrativeAuthorityVerifier~new("WRONG_POLICY"))
if wrongPolicy~ok then signal fail
if wrongPolicy~code \== "AUTHORITY_VERIFICATION_POLICY_REF_MISMATCH" then signal fail
wrongGov = engine~prepare(directive, governance, "HANDOFF-4", "", .nil, .TestNarrativeAuthorityVerifier~new("WRONG_GOVERNANCE"))
if wrongGov~ok then signal fail
if wrongGov~code \== "AUTHORITY_VERIFICATION_GOVERNANCE_REF_MISMATCH" then signal fail
denied = engine~prepare(directive, governance, "HANDOFF-5", "", .nil, .TestNarrativeAuthorityVerifier~new("DENY"))
if denied~ok then signal fail
if denied~code \== "AUTHORITY_VERIFICATION_DENIED" then signal fail
say "PASS effectful handoff requires fresh exact authority verification"
exit 0
fail:
say "FAIL fresh handoff verification"
exit 1
::requires "TestBrandNarrativeFixtures.cls"
