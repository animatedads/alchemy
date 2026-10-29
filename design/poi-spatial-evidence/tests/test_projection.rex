/* Deterministic POI projection tests. Run with ooRexx:
 * rexx design/poi-spatial-evidence/tests/test_projection.rex
 */
call test
exit 0

test:
  ledgerFile = 'design/poi-spatial-evidence/src/PoiEvidenceLedger.cls'
  presentationFile = 'design/poi-spatial-evidence/src/PoiEvidencePresentation.cls'
  .local~testPassed = 0
  .local~testFailed = 0
  ledger = .PoiEvidenceLedger~new
  a = .PoiEvidenceRecord~new('r1','subjectA','glasgow','2028-12-01','DATE_ONLY','media:1','CANDIDATE','')
  b = .PoiEvidenceRecord~new('r2','subjectB','glasgow','2028-12-01','DATE_ONLY','media:2','CANDIDATE','')
  c = .PoiEvidenceRecord~new('r3','subjectB','glasgow','2028-12-01T12:00Z','RESOLVED_INTERVAL','media:3','REVIEWED','')
  d = .PoiEvidenceRecord~new('r4','subjectA','glasgow','2028-12-01T12:00Z','RESOLVED_INTERVAL','media:4','REVIEWED','')
  call assertTrue (a~candidateWith(b) = .false), 'date only never implies overlap'
  call assertTrue (c~candidateWith(d) = .true), 'explicit identical interval is candidate'
  call assertTrue (a~candidateWith(c) = .false), 'mixed resolution does not overlap'
  ledger~append(a)
  ledger~append(d)
  presentation = .PoiEvidencePresentation~new(ledger)
  rows = presentation~subjectRows('subjectA')
  call assertTrue (rows~items = 2), 'subject rows preserve both records'
  call assertTrue (rows[1]~at('temporalCertainty') == 'NOT_ASSESSED'), 'certainty not invented'
  call assertTrue (presentation~mediaPanel(.false) == 'HIDDEN_PRESENTATION_ONLY'), 'hide is presentation only'
  edge = presentation~edgeCandidate(c,d)
  call assertTrue (edge~at('classification') == 'TEMPORAL_SPATIAL_CANDIDATE'), 'never contact'
  edge = presentation~edgeCandidate(a,b)
  call assertTrue (edge~at('classification') == 'NO_RELATIONSHIP'), 'date only no relationship'
  say 'POI TESTS PASSED:' .local~testPassed 'FAILED:' .local~testFailed
  if .local~testFailed > 0 then exit 1
  return
assertTrue:
  use arg condition, label
  if condition then do
    .local~testPassed = .local~testPassed + 1
    return
  end
  .local~testFailed = .local~testFailed + 1
  say 'FAIL:' label
  return

::requires '../src/PoiEvidenceLedger.cls'
::requires '../src/PoiEvidencePresentation.cls'
