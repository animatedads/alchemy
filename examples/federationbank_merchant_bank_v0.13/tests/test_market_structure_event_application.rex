mb=.FederationBankMerchantBank~new
src=.MBReferenceDocumentEvidence~new("DOC-MS-1","CUSTODY-AUTH","urn:test:market-structure","Market structure fixture","1","09:00","","SOURCE_OBSERVED")
mb~recordReferenceDocumentEvidence(src)
a=.MBInstrumentResolutionEvidence~new("RES-MS-A",src~documentEvidenceId,"MS-EQ","ISIN-MS","XLON","GBP","LINE-GBP","CRSTGB22","ORDINARY","GBP","GBP","line=A","09:00")
b=.MBInstrumentResolutionEvidence~new("RES-MS-B",src~documentEvidenceId,"MS-EQ","ISIN-MS","XAMS","EUR","LINE-EUR","CUSTNL2A","ORDINARY","EUR","EUR","line=B","09:00")
c=.MBInstrumentResolutionEvidence~new("RES-MS-C",src~documentEvidenceId,"MS-EQ","ISIN-MS","XSTO","SEK","LINE-SEK","CUSTSESS","ORDINARY","SEK","SEK","line=C","09:00")
mb~recordInstrumentResolutionEvidence(a); mb~recordInstrumentResolutionEvidence(b); mb~recordInstrumentResolutionEvidence(c)
ia=mb~instrumentIdentityFromEvidence("RES-MS-A","GBP",1,"ISSUER-MS")
ib=mb~instrumentIdentityFromEvidence("RES-MS-B","EUR",1,"ISSUER-MS")
permit=.MBDecisionEvidence~new("PERMITTED","PERMITTED","LEGAL-MS","POL-MS")
mb~registerProduct(.MBDerivativeProductDefinition~new("CFD-MS-A","1","CFD","MS-EQ","GBP","CASH",permit,"","",1,ia))
mb~registerProduct(.MBDerivativeProductDefinition~new("CFD-MS-B","1","CFD","MS-EQ","EUR","CASH",permit,"","",1,ib))
mb~createPortfolio("PF-MS-A","CLIENT-MS","GBP")
mb~createPortfolio("PF-MS-B","MM-MS","EUR")
mb~bookTrade(.MBDerivativeTrade~new("TR-MS-A","PF-MS-A","CLIENT-MS","CFD","LONG","GBP",1000000,0,0,"",1,"MS","CFD-MS-A","MS-EQ","09:00"))
mb~recordFXEvidence(.MBFXEvidence~new("FX-MS","FX-AUTH","GBP","EUR",1.20,"09:01","CURRENT"))
off=.MBDerivativeTrade~new("TR-MS-B","PF-MS-B","MM-MS","CFD","SHORT","EUR",1200000,0,0,"",1,"MS","CFD-MS-B","MS-EQ","09:01","MM-MS","EXTERNAL_HEDGE")
h=mb~bookCFDOffset("INT-MS","H-MS","TR-MS-A",off,"FX-MS","TRADE-AUTH","09:01")
call assertEq "CROSS_LISTED_HEDGE",h~relationshipType,"cross-listed fixture established"

baseline=.MBMarketStructureEvent~new("MSE-MS-1","BASELINE_FUNGIBILITY","09:02","GB/NL","MARKET-STRUCTURE-AUTH","REF-MS-BASE","LEGAL-MS-BASE","RES-MS-B",.true,.true,.true,.true,.true,"BASELINE_AVAILABLE")
eq1=mb~applyMarketStructureEventToHedge(baseline,"H-MS","EQE-MS-1")
call assertEq 1,eq1~version,"first market-structure application creates equivalence v1"
call assertEq "EQUIVALENT",h~equivalenceState,"healthy market structure establishes equivalence"

sanction=.MBMarketStructureEvent~new("MSE-MS-2","JURISDICTIONAL_RESTRICTION","11:17","NL","SANCTIONS-AUTH","SANCTION-77","LEGAL-SANCTION-77","RES-MS-B",.true,.false,.false,.false,.false,"TRANSFER_RESTRICTED")
eq2=mb~applyMarketStructureEventToHedge(sanction,"H-MS","EQE-MS-2")
call assertEq 2,eq2~version,"second market-structure application advances evidence stream"
call assertEq "EQE-MS-1",eq2~supersedesEvidenceRef,"event-derived evidence supersedes current version"
call assertEq "IMPAIRED",h~equivalenceState,"market-structure restriction impairs hedge immediately"
call assertEq "HEDGE_IMPAIRED",h~economicState,"no new price tick is required for impairment"
call assertEq "EQE-MS-2",mb~marketStructureApplicationEvidenceRef("MSE-MS-2","H-MS"),"event application provenance retained"

unrelated=.MBMarketStructureEvent~new("MSE-MS-3","CUSTODY_RESTRICTION","11:18","SE","CUSTODY-AUTH","CUSTODY-88","LEGAL-CUSTODY-88","RES-MS-C",.false,.false,.false,.false,.false,"UNRELATED_LINE_BLOCKED")
caught=.false
signal on syntax name unrelatedCaught
mb~applyMarketStructureEventToHedge(unrelated,"H-MS","EQE-MS-3")
signal off syntax
signal unrelatedChecked
unrelatedCaught:
  signal off syntax
  caught=.true
unrelatedChecked:
if \caught then raise syntax 88.900 array("ASSERT_EXPECTED_SYNTAX","market event for unrelated settlement line must not alter hedge")
call assertEq 2,mb~latestHedgeEquivalenceEvidence("H-MS")~version,"rejected event does not advance hedge evidence"

say "PASS test_market_structure_event_application"
exit 0

::routine assertEq
  use strict arg expected,actual,label
  if expected<>actual then raise syntax 88.900 array("ASSERT_EQ",label,"expected",expected,"actual",actual)

::requires "FederationBankMerchantBank.cls"
