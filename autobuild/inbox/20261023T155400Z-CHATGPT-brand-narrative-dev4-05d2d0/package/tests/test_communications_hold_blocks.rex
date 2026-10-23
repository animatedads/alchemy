intervention = .TestNarrativeFixture~intervention
governance = .TestNarrativeFixture~governance("APPROVE_CONTROLLED_PILOT", .true)
projected = .BrandNarrativeProjectionEngine~new~project(intervention, governance, "DIR-COMM-HOLD")
if \projected~ok then signal fail
assessment = .CmsNarrativeEvidenceAssessment~new("BRIEF-2", "NARRATIVE-2", "HOLD_RETRACTION", "source retracted", "APPROVED", 1, "2026-10-11T18:00:00Z", "2026-10-11T19:00:00Z")
adapted = .BrandNarrativeExternalReviewAdapter~fromCommunicationsAssessment(assessment, "COMM-REVIEW-HOLD", "COMMUNICATIONS:NARRATIVE:BRIEF-2:NARRATIVE-2")
if \adapted~ok then signal fail
reviews = .Array~of(adapted~value)
handoffResult = .BrandNarrativeHandoffEngine~new~prepare(projected~value, governance, "HANDOFF-COMM-HOLD", "NARRATIVE-2", reviews, .TestNarrativeAuthorityVerifier~new)
if \handoffResult~ok then signal fail
if handoffResult~value~stage \== "HELD_EXTERNAL_REVIEW" then signal fail
say "PASS Communications HOLD status blocks progression without becoming a Brand verdict"
exit 0
fail:
say "FAIL communications hold mapping"
exit 1
::requires "TestBrandNarrativeFixtures.cls"
::requires "CommunicationsNarrativeEvidence.cls"
