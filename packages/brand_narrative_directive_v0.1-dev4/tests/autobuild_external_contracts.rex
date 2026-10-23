/* Contract doubles verify the Brand adapter surface on r13196 without pretending
 * Communications/Librarian are installed on GitHub main. Exact external-source
 * integration is tracked separately by SOURCE_PROVENANCE.md. */

c = .CmsNarrativeEvidenceAssessment~new
cr = .BrandNarrativeExternalReviewAdapter~fromCommunicationsAssessment(c, 'COMM-AB', 'COMM:CURRENT')
if \cr~ok then signal fail
if cr~value~authorityMode \== 'NO_DISPATCH' then signal fail

p = .LibrarianPositionComparison~new
pr = .BrandNarrativeExternalReviewAdapter~fromLibrarianPosition(p, 'LIB-POS-AB', 'LIB:POS')
if \pr~ok then signal fail
if pr~value~snapshot~pos('OMISSION_ASSESSMENT=NOT_ESTABLISHED') == 0 then signal fail

ch = .LibrarianChangeComparison~new
chr = .BrandNarrativeExternalReviewAdapter~fromLibrarianChange(ch, 'LIB-CH-AB', 'LIB:CHANGE', 'EVENT-A', 'PROP-A')
if \chr~ok then signal fail
if chr~value~snapshot~pos('RETRACTION_MEANING=RETRACTED_NOT_FALSE') == 0 then signal fail
if chr~value~snapshot~pos('CONFLICTED=1') == 0 then signal fail

origin = .LibrarianOriginEvidence~new
orr = .BrandNarrativeExternalReviewAdapter~fromLibrarianOrigin(origin, 'LIB-OR-AB', 'LIB:ORIGIN', 'PUB-A', 'PUB-B')
if \orr~ok then signal fail
if orr~value~snapshot~pos('RELATIONSHIP=SHARED_DECLARED_ORIGIN') == 0 then signal fail
if orr~value~snapshot~pos('INDEPENDENCE_VERDICT=NOT_ESTABLISHED') == 0 then signal fail
if orr~value~snapshot~pos('ORIGIN_AUTHORITY=DECLARED_NOT_VERIFIED') == 0 then signal fail

say 'PASS Autobuild external evidence contract adapters remain non-authoritative'
exit 0
fail:
say 'FAIL Autobuild external evidence contract adapters'
exit 1

::class CmsNarrativeEvidenceAssessment public
::method status; return 'EDITORIAL_REVIEW_EVIDENCE_ONLY'
::method reason; return 'contract-double-current-review'
::method toJson; return '{"authority":"NO_DISPATCH","claimAuthority":"NOT_VERIFIED","publicationAuthority":"NONE"}'

::class LibrarianPositionComparison public
::method eventId; return 'EVENT-A'
::method propositionId; return 'PROP-A'
::method coverage; return 'PARTIAL'
::method articles; return 2
::method sources; return 2
::method origins; return 1
::method support; return 1
::method dispute; return 1
::method neutral; return 0
::method unclassified; return 0
::method omissionAssessment; return 'NOT_ESTABLISHED'
::method biasVerdict; return 'NOT_DETERMINED'

::class LibrarianChangeComparison public
::method coverage; return 'PARTIAL'
::method articles; return 3
::method sources; return 2
::method origins; return 1
::method support; return 0
::method dispute; return 0
::method neutral; return 0
::method unclassified; return 0
::method retracted; return 1
::method conflicted; return 1
::method biasVerdict; return 'NOT_DETERMINED'

::class LibrarianOriginEvidence public
::method independenceVerdict; return 'NOT_ESTABLISHED'
::method relationship
  use strict arg first, second
  return 'SHARED_DECLARED_ORIGIN'
::method trace
  use strict arg source
  return 'WIRE-DECLARED'

::requires 'BrandNarrativeDirective.cls'
