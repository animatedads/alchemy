intervention = .TestNarrativeFixture~intervention
governance = .TestNarrativeFixture~governance("APPROVE_CONTROLLED_PILOT", .true)
ref1 = .BrandNarrativeEvidenceReference~new("COMM-1", "COMMUNICATIONS_DISCOVERY", "COMMUNICATION_RECORD:42", "EDITORIAL_REVIEW", "2026-10-09T17:30:00Z", "NO_DISPATCH")
ref1~seal
ref2 = .BrandNarrativeEvidenceReference~new("LIB-1", "LIBRARIAN_V2", "LIBRARIAN_EVENT:7", "ATTRIBUTED", "2026-10-09T17:31:00Z", "EVIDENCE_ONLY")
ref2~seal
refs = .Array~of(ref1, ref2)
projected = .BrandNarrativeProjectionEngine~new~project(intervention, governance, "DIR-1", refs)
if \projected~ok then signal fail
packet = projected~value
if packet~directiveKind \== "PROPOSE_ADAPTATION" then signal fail
if packet~runtimeEffect \== "ADAPT" then signal fail
if packet~rolloutMode \== "CONTROLLED_PILOT" then signal fail
if packet~status \== "PROPOSED_NOT_ACTIVE" then signal fail
if packet~activationAuthorityRequired \== "EXTERNAL_NARRATIVE_AUTHORITY_REQUIRED" then signal fail
if packet~objectives~items < 2 then signal fail
if packet~contextEvidence~items \== 2 then signal fail
if packet~toDirectory["schema"] \== "brand.narrative.directive/0.1" then signal fail
material = packet~reasoningMaterial
if material~pos("DIRECTIVE_NOT_ACTIVATION") == 0 then signal fail
if material~pos("UPSTREAM_GOVERNANCE_SNAPSHOT_BEGIN") == 0 then signal fail
say "PASS positive governed projection remains proposed"
exit 0
fail:
say "FAIL positive projection"
exit 1
::requires "TestBrandNarrativeFixtures.cls"
