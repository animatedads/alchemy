mb=.FederationBankMerchantBank~new
permit=.MBDecisionEvidence~new("PERMITTED","PERMITTED","LEGAL-ROOT","POL-ROOT")
src=.MBReferenceDocumentEvidence~new("DOC-ROOT","REF-AUTH","urn:test:root","Root discovery","1","09:00","","SOURCE_OBSERVED")
mb~recordReferenceDocumentEvidence(src)
a=.MBInstrumentResolutionEvidence~new("RES-ROOT-A",src~documentEvidenceId,"ROOT-EQ","ISIN-ROOT","XLON","GBP","LINE-A","CRSTGB22","ORDINARY","GBP","GBP","A","09:00")
b=.MBInstrumentResolutionEvidence~new("RES-ROOT-B",src~documentEvidenceId,"ROOT-EQ","ISIN-ROOT","XAMS","EUR","LINE-B","CUSTNL2A","ORDINARY","EUR","EUR","B","09:00")
mb~recordInstrumentResolutionEvidence(a); mb~recordInstrumentResolutionEvidence(b)
ia=mb~instrumentIdentityFromEvidence("RES-ROOT-A","GBP",1,"ISSUER-ROOT")
ib=mb~instrumentIdentityFromEvidence("RES-ROOT-B","EUR",1,"ISSUER-ROOT")
mb~registerProduct(.MBDerivativeProductDefinition~new("CFD-ROOT-A","1","CFD","ROOT-EQ","GBP","CASH",permit,"","",1,ia))
mb~registerProduct(.MBDerivativeProductDefinition~new("CFD-ROOT-B","1","CFD","ROOT-EQ","EUR","CASH",permit,"","",1,ib))
mb~createPortfolio("PF-ROOT-A","CLIENT-ROOT","GBP"); mb~createPortfolio("PF-ROOT-B","MM-ROOT","EUR")
mb~bookTrade(.MBDerivativeTrade~new("TR-ROOT-CLIENT","PF-ROOT-A","CLIENT-ROOT","CFD","LONG","GBP",1000000,0,0,"",1,"ROOT","CFD-ROOT-A","ROOT-EQ","09:00"))
mb~recordFXEvidence(.MBFXEvidence~new("FX-ROOT","FX-AUTH","GBP","EUR",1.20,"09:01","CURRENT"))
h1trade=.MBDerivativeTrade~new("TR-ROOT-H1","PF-ROOT-B","MM-ROOT","CFD","SHORT","EUR",1200000,0,0,"",1,"ROOT","CFD-ROOT-B","ROOT-EQ","09:01","MM-ROOT","EXTERNAL_HEDGE")
mb~bookCFDOffset("INT-ROOT-1","H-ROOT-1","TR-ROOT-CLIENT",h1trade,"FX-ROOT","AUTH","09:01")
-- Neutralise the first hedge leg with a same-currency opposite contract.
h2trade=.MBDerivativeTrade~new("TR-ROOT-H2","PF-ROOT-B","MM-ROOT","CFD","LONG","EUR",1200000,0,0,"",1,"ROOT","CFD-ROOT-B","ROOT-EQ","09:02","MM-ROOT","EXTERNAL_HEDGE")
mb~bookCFDOffset("INT-ROOT-2","H-ROOT-2","TR-ROOT-H1",h2trade,"","AUTH","09:02")
if mb~rootCFDTradeIdForHedge("H-ROOT-1")<>"TR-ROOT-CLIENT" then raise syntax 88.900 array("root mismatch for first hedge")
if mb~rootCFDTradeIdForHedge("H-ROOT-2")<>"TR-ROOT-CLIENT" then raise syntax 88.900 array("root mismatch for nested hedge")
roots=mb~rootsAffectedByInstrumentEvidence("RES-ROOT-B")
if roots~items<>1 | roots[1]<>"TR-ROOT-CLIENT" then raise syntax 88.900 array("affected roots not deduplicated",roots~items)
say "PASS test_hedge_book_root_discovery"
exit 0
::requires "FederationBankMerchantBank.cls"
