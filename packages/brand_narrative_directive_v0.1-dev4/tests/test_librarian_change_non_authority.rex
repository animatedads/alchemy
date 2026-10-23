intervention = .TestNarrativeFixture~intervention
governance = .TestNarrativeFixture~governance('APPROVE_CONTROLLED_PILOT', .true)
projected = .BrandNarrativeProjectionEngine~new~project(intervention, governance, 'DIR-LIB-CHANGE')
if \projected~ok then signal fail

assessment = .CmsNarrativeEvidenceAssessment~new('BRIEF-LIB6', 'NARRATIVE-LIB6', 'EDITORIAL_REVIEW_EVIDENCE_ONLY', 'references current; truth and publication approval remain external', 'APPROVED', 2, '2026-10-15T08:00:00Z', '2026-10-15T09:00:00Z')
commAdapted = .BrandNarrativeExternalReviewAdapter~fromCommunicationsAssessment(assessment, 'COMM-LIB6', 'COMMUNICATIONS:NARRATIVE:BRIEF-LIB6:NARRATIVE-LIB6')
if \commAdapted~ok then signal fail

p0 = .LibrarianTimePoint~new(1000, 'Etc/UTC', 'fixture')
p1 = .LibrarianTimePoint~new(2000, 'Etc/UTC', 'fixture')
p2 = .LibrarianTimePoint~new(3000, 'Etc/UTC', 'fixture')
ledger = .LibrarianChangeLedger~new
ledger~append(.LibrarianChange~new('a', '', .LibrarianPositionObservation~new('a', 'EVENT-CONFLICT', 'CLAIM-C', 'PUB-A', 'ORIGIN-A', 'SUPPORT', p0, p0), 'ORIGINAL'))
ledger~append(.LibrarianChange~new('b', 'a', .LibrarianPositionObservation~new('b', 'EVENT-CONFLICT', 'CLAIM-C', 'PUB-A', 'ORIGIN-A', 'UNCLASSIFIED', p1, p1), 'RETRACTION'))
ledger~append(.LibrarianChange~new('c', 'a', .LibrarianPositionObservation~new('c', 'EVENT-CONFLICT', 'CLAIM-C', 'PUB-B', 'ORIGIN-A', 'DISPUTE', p2, p2), 'CORRECTION'))
comparison = ledger~compare('EVENT-CONFLICT', 'CLAIM-C', p2, p2, 'PARTIAL')
libAdapted = .BrandNarrativeExternalReviewAdapter~fromLibrarianChange(comparison, 'LIB-CONFLICT', 'LIBRARIAN:CHANGE:EVENT-CONFLICT:CLAIM-C:P2', 'EVENT-CONFLICT', 'CLAIM-C')
if \libAdapted~ok then signal fail
if libAdapted~value~snapshot~pos('CONFLICTED=1') == 0 then signal fail

reviews = .Array~of(commAdapted~value, libAdapted~value)
handoffResult = .BrandNarrativeHandoffEngine~new~prepare(projected~value, governance, 'HANDOFF-LIB6', 'NARRATIVE-LIB6', reviews, .TestNarrativeAuthorityVerifier~new)
if \handoffResult~ok then signal fail
handoff = handoffResult~value
if handoff~stage \== 'READY_FOR_EXTERNAL_AUTHORITY_REVIEW' then signal fail
if handoff~publicationAuthority \== 'NONE' then signal fail
if handoff~authorityMode \== 'NO_DISPATCH' then signal fail
if handoff~reviews~items \== 2 then signal fail
say 'PASS Librarian dev6 conflict remains visible evidence and cannot itself hold or approve narrative handoff'
exit 0
fail:
say 'FAIL librarian change non-authority'
exit 1
::requires 'TestBrandNarrativeFixtures.cls'
::requires 'CommunicationsNarrativeEvidence.cls'
::requires 'LibrarianRetraction.cls'
