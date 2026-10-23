counts = .Directory~new
counts["SUPPORT"] = 4
counts["DISPUTE"] = 2
counts["NEUTRAL"] = 1
counts["UNCLASSIFIED"] = 3
comparison = .LibrarianPositionComparison~new("EVENT-1", "PROP-1", "PARTIAL", 14, 9, 10, counts)
adapted = .BrandNarrativeExternalReviewAdapter~fromLibrarianPosition(comparison, "LIB-POS-1", "LIBRARIAN:POSITION:EVENT-1:PROP-1")
if \adapted~ok then signal fail
review = adapted~value
if review~reviewKind \== "LIBRARIAN_POSITIONING" then signal fail
if review~authorityMode \== "EVIDENCE_ONLY" then signal fail
if review~claimAuthority \== "NOT_VERIFIED" then signal fail
if review~status \== "POSITION_EVIDENCE_ONLY" then signal fail
if review~snapshot~pos("COVERAGE=PARTIAL") == 0 then signal fail
if review~snapshot~pos("OMISSION_ASSESSMENT=NOT_ESTABLISHED") == 0 then signal fail
if review~snapshot~pos("BIAS_VERDICT=NOT_DETERMINED") == 0 then signal fail
say "PASS current Librarian dev4 positioning remains context-only with omission/bias unresolved"
exit 0
fail:
say "FAIL librarian position adapter"
exit 1
::requires "BrandNarrativeDirective.cls"
::requires "LibrarianPosition.cls"
