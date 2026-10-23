intervention = .TestNarrativeFixture~intervention
governance = .TestNarrativeFixture~governance("APPROVE_CONTROLLED_PILOT", .true)
projected = .BrandNarrativeProjectionEngine~new~project(intervention, governance, "DIR-COMM")
if \projected~ok then signal fail
assessment = .CmsNarrativeEvidenceAssessment~new("BRIEF-1", "NARRATIVE-1", "EDITORIAL_REVIEW_EVIDENCE_ONLY", "references current; truth, prose and approval unverified", "APPROVED", 3, "2026-10-11T18:00:00Z", "2026-10-11T19:00:00Z")
adapted = .BrandNarrativeExternalReviewAdapter~fromCommunicationsAssessment(assessment, "COMM-REVIEW-1", "COMMUNICATIONS:NARRATIVE:BRIEF-1:NARRATIVE-1")
if \adapted~ok then signal fail
review = adapted~value
if review~reviewKind \== "COMMUNICATIONS_NARRATIVE_EVIDENCE" then signal fail
if review~authorityMode \== "NO_DISPATCH" then signal fail
if review~claimAuthority \== "NOT_VERIFIED" then signal fail
if review~evidenceMaturity \== "LIBRARIAN_EXPERIMENTAL" then signal fail
if review~snapshot~pos('"authority":"NO_DISPATCH"') == 0 then signal fail
reviews = .Array~of(review)
handoffResult = .BrandNarrativeHandoffEngine~new~prepare(projected~value, governance, "HANDOFF-COMM", "NARRATIVE-1", reviews, .TestNarrativeAuthorityVerifier~new)
if \handoffResult~ok then signal fail
handoff = handoffResult~value
if handoff~stage \== "READY_FOR_EXTERNAL_AUTHORITY_REVIEW" then signal fail
if handoff~publicationAuthority \== "NONE" then signal fail
if handoff~reviews~items \== 1 then signal fail
say "PASS current Communications dev10 review remains NO_DISPATCH and can only advance to external authority review"
exit 0
fail:
say "FAIL communications review adapter"
exit 1
::requires "TestBrandNarrativeFixtures.cls"
::requires "CommunicationsNarrativeEvidence.cls"
