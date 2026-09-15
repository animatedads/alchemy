mb=.FederationBankMerchantBank~new
src=.MBReferenceDocumentEvidence~new("DOC-ATT-1","REFERENCE-AUTH","urn:test:attestation","Instrument resolution fixture","1","09:00","","CONTENT_BOUND")
mb~recordReferenceDocumentEvidence(src)
e=.MBInstrumentResolutionEvidence~new("RES-ATT-GBP",src~documentEvidenceId,"ATT-EQ","ISIN-ATT","XLON","GBP","SEDOL-ATT-GBP","CRSTGB22","ORDINARY","GBP","GBP","line=GBP","09:00")
mb~recordInstrumentResolutionEvidence(e)
i=mb~instrumentIdentityFromEvidence(e~evidenceId,"GBP",1,"ISSUER-ATT")
permit=.MBDecisionEvidence~new("PERMITTED","PERMITTED","LEGAL-ATT","POL-ATT")
p=.MBDerivativeProductDefinition~new("CFD-ATT","7","CFD","ATT-EQ","GBP","CASH",permit,"","",1,i)
mb~registerProduct(p)

a=.MBInstrumentResolutionAttestation~new("ATTEST-1","CFD-ATT","7","RES-ATT-GBP",i~settlementLineKey,"PRODUCT-REFERENCE-AUTH","REF-SIGNATURE-1","09:01")
mb~attestProductInstrumentResolution(a)
call assertEq "ATTEST-1",mb~productInstrumentResolutionAttestation("CFD-ATT")~attestationId,"product attestation retained"
call assertEq "RES-ATT-GBP",mb~instrumentResolutionAttestation("ATTEST-1")~resolutionEvidenceRef,"exact resolution evidence retained"
call assertEq i~settlementLineKey,mb~instrumentResolutionAttestation("ATTEST-1")~settlementLineKey,"exact settlement line retained"

bad=.MBInstrumentResolutionAttestation~new("ATTEST-BAD-LINE","CFD-ATT","7","RES-ATT-GBP","ISIN-ATT|XLON|USD|WRONG|CRSTGB22","PRODUCT-REFERENCE-AUTH","REF-BAD-LINE","09:02")
caught=.false
signal on syntax name badLine
mb~attestProductInstrumentResolution(bad)
signal off syntax
signal badLineChecked
badLine:
  signal off syntax
  caught=.true
badLineChecked:
if \caught then raise syntax 88.900 array("ASSERT_EXPECTED_SYNTAX","wrong settlement line attestation must fail")

badVersion=.MBInstrumentResolutionAttestation~new("ATTEST-BAD-VERSION","CFD-ATT","6","RES-ATT-GBP",i~settlementLineKey,"PRODUCT-REFERENCE-AUTH","REF-BAD-VERSION","09:03")
caught=.false
signal on syntax name badVersionCaught
mb~attestProductInstrumentResolution(badVersion)
signal off syntax
signal badVersionChecked
badVersionCaught:
  signal off syntax
  caught=.true
badVersionChecked:
if \caught then raise syntax 88.900 array("ASSERT_EXPECTED_SYNTAX","wrong product version attestation must fail")

plain=.MBInstrumentIdentity~new("ATT-EQ","ISIN-PLAIN","XLON","ORDINARY","GBP","GBP","GBP")
mb~registerProduct(.MBDerivativeProductDefinition~new("CFD-PLAIN","1","CFD","ATT-EQ","GBP","CASH",permit,"","",1,plain))
noEvidence=.MBInstrumentResolutionAttestation~new("ATTEST-NO-EVIDENCE","CFD-PLAIN","1","RES-ATT-GBP",plain~settlementLineKey,"PRODUCT-REFERENCE-AUTH","REF-NO-EVIDENCE","09:04")
caught=.false
signal on syntax name noEvidenceCaught
mb~attestProductInstrumentResolution(noEvidence)
signal off syntax
signal noEvidenceChecked
noEvidenceCaught:
  signal off syntax
  caught=.true
noEvidenceChecked:
if \caught then raise syntax 88.900 array("ASSERT_EXPECTED_SYNTAX","unresolved product cannot be attested")

say "PASS test_instrument_resolution_attestation"
exit 0

::routine assertEq
  use strict arg expected,actual,label
  if expected<>actual then raise syntax 88.900 array("ASSERT_EQ",label,"expected",expected,"actual",actual)

::requires "FederationBankMerchantBank.cls"
