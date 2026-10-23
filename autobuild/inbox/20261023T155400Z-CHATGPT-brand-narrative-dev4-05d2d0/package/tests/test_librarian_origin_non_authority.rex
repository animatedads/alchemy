intervention = .TestNarrativeFixture~intervention
governance = .TestNarrativeFixture~governance
projected = .BrandNarrativeProjectionEngine~new~project(intervention, governance, 'DIR-ORIGIN-1')
if \projected~ok then signal fail
origins = .LibrarianOriginEvidence~new
origins~add(.LibrarianOriginLink~new('PUB-A','WIRE-1','SYNDICATED','EVIDENCE-A'))
origins~add(.LibrarianOriginLink~new('PUB-B','WIRE-1','SYNDICATED','EVIDENCE-B'))
reviewResult = .BrandNarrativeExternalReviewAdapter~fromLibrarianOrigin(origins, 'LIB-ORIGIN-3', 'LIBRARIAN:ORIGIN:PUB-A:PUB-B', 'PUB-A', 'PUB-B')
if \reviewResult~ok then signal fail
reviews = .Array~of(reviewResult~value)
handoffResult = .BrandNarrativeHandoffEngine~new~prepare(projected~value, governance, 'HANDOFF-ORIGIN-1', 'STORY-CANDIDATE-1', reviews, .TestNarrativeAuthorityVerifier~new)
if \handoffResult~ok then signal fail
handoff = handoffResult~value
if handoff~stage \== 'READY_FOR_NARRATIVE_EVIDENCE_REVIEW' then signal fail
if handoff~authorityMode \== 'NO_DISPATCH' then signal fail
if handoff~publicationAuthority \== 'NONE' then signal fail
say 'PASS Librarian dev7 shared declared origin cannot promote, hold, dispatch, or publish narrative handoff'
exit 0
fail:
say 'FAIL librarian origin non-authority'
exit 1
::requires 'TestBrandNarrativeFixtures.cls'
::requires 'LibrarianOriginEvidence.cls'
