mb=.FederationBankMerchantBank~new
src=.MBReferenceDocumentEvidence~new("DOC-SURV","REF-AUTH","urn:test:surveillance","Surveillance fixture","1","09:00","","SOURCE_OBSERVED")
mb~recordReferenceDocumentEvidence(src)
a=.MBInstrumentResolutionEvidence~new("RES-SURV-A",src~documentEvidenceId,"SURV-EQ","ISIN-SURV","XLON","GBP","LINE-GBP","CRSTGB22","ORDINARY","GBP","GBP","line=A","09:00")
b=.MBInstrumentResolutionEvidence~new("RES-SURV-B",src~documentEvidenceId,"SURV-EQ","ISIN-SURV","XAMS","EUR","LINE-EUR","CUSTNL2A","ORDINARY","EUR","EUR","line=B","09:00")
c=.MBInstrumentResolutionEvidence~new("RES-SURV-C",src~documentEvidenceId,"OTHER-EQ","ISIN-OTHER","XSTO","SEK","LINE-SEK","CUSTSESS","ORDINARY","SEK","SEK","line=C","09:00")
mb~recordInstrumentResolutionEvidence(a); mb~recordInstrumentResolutionEvidence(b); mb~recordInstrumentResolutionEvidence(c)
ia=mb~instrumentIdentityFromEvidence("RES-SURV-A","GBP",1,"ISSUER-S")
ib=mb~instrumentIdentityFromEvidence("RES-SURV-B","EUR",1,"ISSUER-S")
permit=.MBDecisionEvidence~new("PERMITTED","PERMITTED","LEGAL-S","POL-S")
mb~registerProduct(.MBDerivativeProductDefinition~new("CFD-S-A","1","CFD","SURV-EQ","GBP","CASH",permit,"","",1,ia))
mb~registerProduct(.MBDerivativeProductDefinition~new("CFD-S-B","1","CFD","SURV-EQ","EUR","CASH",permit,"","",1,ib))
mb~createPortfolio("PF-S-A","CLIENT-S","GBP"); mb~createPortfolio("PF-S-B","MM-S","EUR")
mb~bookTrade(.MBDerivativeTrade~new("TR-S-A","PF-S-A","CLIENT-S","CFD","LONG","GBP",1000000,0,0,"",1,"S","CFD-S-A","SURV-EQ","09:00"))
mb~recordFXEvidence(.MBFXEvidence~new("FX-S","FX-AUTH","GBP","EUR",1.20,"09:01","CURRENT"))
off=.MBDerivativeTrade~new("TR-S-B","PF-S-B","MM-S","CFD","SHORT","EUR",1200000,0,0,"",1,"S","CFD-S-B","SURV-EQ","09:01","MM-S","EXTERNAL_HEDGE")
mb~bookCFDOffset("INT-S","H-S","TR-S-A",off,"FX-S","TRADE-AUTH","09:01")
ids=mb~hedgeIds
call assertEq 1,ids~items,"one hedge discovered"
call assertEq "H-S",ids[1],"hedge inventory stable"
affected=mb~hedgesAffectedByInstrumentEvidence("RES-SURV-B")
call assertEq 1,affected~items,"exact offset line identifies hedge"
call assertEq "H-S",affected[1],"affected hedge exact"
call assertEq 0,mb~hedgesAffectedByInstrumentEvidence("RES-SURV-C")~items,"unrelated line does not match by rough economic similarity"
say "PASS test_surveillance_discovery"
exit 0
::routine assertEq
  use strict arg expected,actual,label
  if expected<>actual then raise syntax 88.900 array("ASSERT_EQ",label,"expected",expected,"actual",actual)
::requires "FederationBankMerchantBank.cls"
