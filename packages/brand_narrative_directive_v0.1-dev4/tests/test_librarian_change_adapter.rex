p0 = .LibrarianTimePoint~new(1000, 'Etc/UTC', 'fixture')
p1 = .LibrarianTimePoint~new(2000, 'Etc/UTC', 'fixture')
p2 = .LibrarianTimePoint~new(3000, 'Etc/UTC', 'fixture')
ledger = .LibrarianChangeLedger~new
ledger~append(.LibrarianChange~new('a', '', .LibrarianPositionObservation~new('a', 'EVENT-RET', 'CLAIM-A', 'PUB-A', 'ORIGIN-A', 'SUPPORT', p0, p0), 'ORIGINAL'))
ledger~append(.LibrarianChange~new('b', 'a', .LibrarianPositionObservation~new('b', 'EVENT-RET', 'CLAIM-A', 'PUB-A', 'ORIGIN-A', 'UNCLASSIFIED', p1, p1), 'RETRACTION'))
linear = ledger~compare('EVENT-RET', 'CLAIM-A', p2, p2, 'PARTIAL')
adapted = .BrandNarrativeExternalReviewAdapter~fromLibrarianChange(linear, 'LIB-CHANGE-1', 'LIBRARIAN:CHANGE:EVENT-RET:CLAIM-A:P2', 'EVENT-RET', 'CLAIM-A')
if \adapted~ok then signal fail
review = adapted~value
if review~reviewKind \== 'LIBRARIAN_CHANGE_LINEAGE' then signal fail
if review~status \== 'CHANGE_LINEAGE_EVIDENCE_ONLY' then signal fail
if review~authorityMode \== 'EVIDENCE_ONLY' then signal fail
if review~claimAuthority \== 'NOT_VERIFIED' then signal fail
if review~snapshot~pos('RETRACTED=1') == 0 then signal fail
if review~snapshot~pos('CONFLICTED=0') == 0 then signal fail
if review~snapshot~pos('RETRACTION_MEANING=RETRACTED_NOT_FALSE') == 0 then signal fail
if review~snapshot~pos('OMISSION_ASSESSMENT=NOT_ESTABLISHED') == 0 then signal fail
if review~snapshot~pos('BIAS_VERDICT=NOT_DETERMINED') == 0 then signal fail
if review~snapshot~pos('TRUTH_VERDICT=NOT_DETERMINED') == 0 then signal fail
if review~snapshot~pos('SCOPE_BINDING=CALLER_SUPPLIED_NOT_VERIFIED_BY_COMPARISON') == 0 then signal fail

ledger~append(.LibrarianChange~new('c', 'a', .LibrarianPositionObservation~new('c', 'EVENT-RET', 'CLAIM-A', 'PUB-B', 'ORIGIN-A', 'DISPUTE', p2, p2), 'CORRECTION'))
branched = ledger~compare('EVENT-RET', 'CLAIM-A', p2, p2, 'PARTIAL')
branchedAdapted = .BrandNarrativeExternalReviewAdapter~fromLibrarianChange(branched, 'LIB-CHANGE-2', 'LIBRARIAN:CHANGE:EVENT-RET:CLAIM-A:P2-BRANCH', 'EVENT-RET', 'CLAIM-A')
if \branchedAdapted~ok then signal fail
if branchedAdapted~value~snapshot~pos('CONFLICTED=1') == 0 then signal fail
if branchedAdapted~value~snapshot~pos('RETRACTED=0') == 0 then signal fail

missingScope = .BrandNarrativeExternalReviewAdapter~fromLibrarianChange(branched, 'LIB-CHANGE-3', 'LIBRARIAN:CHANGE:UNSCOPED', '', 'CLAIM-A')
if missingScope~ok then signal fail
if missingScope~code \== 'LIBRARIAN_CHANGE_EVENT_SCOPE_REQUIRED' then signal fail
say 'PASS Librarian dev6 retraction/conflict lineage remains detached evidence with caller-bound scope'
exit 0
fail:
say 'FAIL librarian change adapter'
exit 1
::requires 'BrandNarrativeDirective.cls'
::requires 'LibrarianRetraction.cls'
