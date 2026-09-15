mb=.FederationBankMerchantBank~new
src=.MBReferenceDocumentEvidence~new( -
  "DOC-CITI-DUAL-LIST-2014", -
  "CITI_MARKETS_SECURITIES_SERVICES", -
  "https://www.citigroup.com/mss/sa/dcc/swift/iso_15022/docs/2011/dual_list_sec_2.pdf", -
  "Citi ISO 15022 Settlement Instruction Requirements for Multi-Listed Securities", -
  "SR2014", -
  "2026-08-26T14:30:00+01:00", -
  "", -
  "SOURCE_OBSERVED")
mb~recordReferenceDocumentEvidence(src)

gbp=.MBInstrumentResolutionEvidence~new( -
  "RES-CITI-XLON-GBP",src~documentEvidenceId,"CITI-MULTI-LIST-FIXTURE","ISIN-MULTI-001","XLON","GBP","GB-SEDOL-GBP","CRSTGB22", -
  "ORDINARY","GBP","GBP","page2:94B-PLIS-XLON+11A-DENO-GBP","2026-08-26T14:30:00+01:00")
usd=.MBInstrumentResolutionEvidence~new( -
  "RES-CITI-XLON-USD",src~documentEvidenceId,"CITI-MULTI-LIST-FIXTURE","ISIN-MULTI-001","XLON","USD","GB-SEDOL-USD","CRSTGB22", -
  "ORDINARY","GBP","GBP","page2:94B-PLIS-XLON+11A-DENO-USD","2026-08-26T14:30:00+01:00")
ire=.MBInstrumentResolutionEvidence~new( -
  "RES-CITI-XDUB-IE",src~documentEvidenceId,"CITI-MULTI-LIST-FIXTURE","ISIN-MULTI-001","XDUB","EUR","IE-SEDOL","CITIIE2X", -
  "ORDINARY","EUR","EUR","page1:94B-PLIS-XDUB;page4:94F-SAFE-CITIIE2X","2026-08-26T14:30:00+01:00")
mb~recordInstrumentResolutionEvidence(gbp)
mb~recordInstrumentResolutionEvidence(usd)
mb~recordInstrumentResolutionEvidence(ire)

iGbp=mb~instrumentIdentityFromEvidence(gbp~evidenceId,"GBP",1,"ISSUER-FIXTURE")
iUsd=mb~instrumentIdentityFromEvidence(usd~evidenceId,"GBP",1,"ISSUER-FIXTURE")
iIre=mb~instrumentIdentityFromEvidence(ire~evidenceId,"EUR",1,"ISSUER-FIXTURE")

call assertEq "ISIN-MULTI-001",iGbp~isin,"ISIN retained"
call assertEq "XLON",iGbp~venueMic,"place of listing retained"
call assertEq "GBP",iGbp~denominationCurrency,"denomination retained"
call assertEq "GB-SEDOL-GBP",iGbp~settlementLineRef,"settlement line retained"
call assertEq "CRSTGB22",iGbp~placeOfSafekeeping,"safekeeping retained"
call assertEq "RES-CITI-XLON-GBP",iGbp~resolutionEvidenceRef,"source evidence bound to identity"

if iGbp~exactContractIdentity(iUsd) then raise syntax 88.900 array("ASSERT_FALSE","same ISIN+venue with different denomination/line must not be exact identity")
if iGbp~exactContractIdentity(iIre) then raise syntax 88.900 array("ASSERT_FALSE","same ISIN with different listing/safekeeping must not be exact identity")
if \iGbp~sameEconomicUnderlying(iUsd) then raise syntax 88.900 array("ASSERT_TRUE","economic underlying remains common")
if \iGbp~sameEconomicUnderlying(iIre) then raise syntax 88.900 array("ASSERT_TRUE","cross-market economic underlying remains common")

policy=.MBDecisionEvidence~new("PERMITTED","PERMITTED","LEGAL-CITI-FIX","POL-CITI-FIX")
p1=.MBDerivativeProductDefinition~new("CFD-CITI-GBP","1","CFD","CITI-MULTI-LIST-FIXTURE","GBP","CASH",policy,"","",1,iGbp)
p2=.MBDerivativeProductDefinition~new("CFD-CITI-USD-LINE","1","CFD","CITI-MULTI-LIST-FIXTURE","GBP","CASH",policy,"","",1,iUsd)
mb~registerProduct(p1)
mb~registerProduct(p2)

bad=.MBInstrumentIdentity~new("CITI-MULTI-LIST-FIXTURE","ISIN-MULTI-001","XLON","ORDINARY","GBP","GBP","GBP",1,"ISSUER-FIXTURE","EUR","GB-SEDOL-GBP","CRSTGB22","RES-CITI-XLON-GBP")
badProduct=.MBDerivativeProductDefinition~new("CFD-BAD-EVIDENCE","1","CFD","CITI-MULTI-LIST-FIXTURE","GBP","CASH",policy,"","",1,bad)
caught=.false
signal on syntax name evidenceMismatch
mb~registerProduct(badProduct)
signal off syntax
if \caught then raise syntax 88.900 array("ASSERT_EXPECTED_SYNTAX","evidence mismatch blocks product")
signal evidenceChecked
evidenceMismatch:
  signal off syntax
  caught=.true
evidenceChecked:
if \caught then raise syntax 88.900 array("ASSERT_EXPECTED_SYNTAX","evidence mismatch blocks product")

call assertEq "page2:94B-PLIS-XLON+11A-DENO-GBP",mb~instrumentResolutionEvidence("RES-CITI-XLON-GBP")~sourceLocator,"source locator retained"
call assertEq "SR2014",mb~referenceDocumentEvidence("DOC-CITI-DUAL-LIST-2014")~sourceVersion,"document version retained"

say "PASS test_citi_multilisted_reference_resolution"
exit 0

::routine assertEq
  use strict arg expected,actual,label
  if expected<>actual then raise syntax 88.900 array("ASSERT_EQ",label,"expected",expected,"actual",actual)

::requires "FederationBankMerchantBank.cls"
