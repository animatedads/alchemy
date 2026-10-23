origins = .LibrarianOriginEvidence~new
origins~add(.LibrarianOriginLink~new('PUB-A','WIRE-1','SYNDICATED','EVIDENCE-A'))
origins~add(.LibrarianOriginLink~new('PUB-B','WIRE-1','QUOTED','EVIDENCE-B'))
adapterResult = .BrandNarrativeExternalReviewAdapter~fromLibrarianOrigin(origins, 'LIB-ORIGIN-1', 'LIBRARIAN:ORIGIN:PUB-A:PUB-B', 'PUB-A', 'PUB-B')
if \adapterResult~ok then signal fail
review = adapterResult~value
if review~reviewKind \== 'LIBRARIAN_DECLARED_ORIGIN' then signal fail
if review~status \== 'DECLARED_ORIGIN_EVIDENCE_ONLY' then signal fail
if review~authorityMode \== 'EVIDENCE_ONLY' then signal fail
if review~claimAuthority \== 'NOT_VERIFIED' then signal fail
if review~snapshot~pos('RELATIONSHIP=SHARED_DECLARED_ORIGIN') == 0 then signal fail
if review~snapshot~pos('INDEPENDENCE_VERDICT=NOT_ESTABLISHED') == 0 then signal fail
if review~snapshot~pos('ORIGIN_AUTHORITY=DECLARED_NOT_VERIFIED') == 0 then signal fail
if review~snapshot~pos('EDITORIAL_INDEPENDENCE=NOT_ESTABLISHED') == 0 then signal fail
if review~snapshot~pos('BIAS_VERDICT=NOT_DETERMINED') == 0 then signal fail
if review~snapshot~pos('CAUSAL_VERDICT=NOT_DETERMINED') == 0 then signal fail
unknown = .BrandNarrativeExternalReviewAdapter~fromLibrarianOrigin(origins, 'LIB-ORIGIN-2', 'LIBRARIAN:ORIGIN:PUB-A:PUB-C', 'PUB-A', 'PUB-C')
if \unknown~ok then signal fail
if unknown~value~snapshot~pos('RELATIONSHIP=INDEPENDENCE_NOT_ESTABLISHED') == 0 then signal fail
say 'PASS Librarian dev7 declared origin evidence remains detached and non-authoritative'
exit 0
fail:
say 'FAIL librarian origin adapter'
exit 1
::requires 'BrandNarrativeDirective.cls'
::requires 'LibrarianOriginEvidence.cls'
