::class MBRiskServiceTestSupport public
::method fixture class
  mb=.FederationBankMerchantBank~new
  src=.MBReferenceDocumentEvidence~new("DOC-RS","REF-AUTH","urn:test:risk-service","Risk service fixture","1","09:00","","SOURCE_OBSERVED")
  mb~recordReferenceDocumentEvidence(src)
  a=.MBInstrumentResolutionEvidence~new("RES-RS-A",src~documentEvidenceId,"RS-EQ","ISIN-RS","XLON","GBP","LINE-GBP","CRSTGB22","ORDINARY","GBP","GBP","line=A","09:00")
  b=.MBInstrumentResolutionEvidence~new("RES-RS-B",src~documentEvidenceId,"RS-EQ","ISIN-RS","XAMS","EUR","LINE-EUR","CUSTNL2A","ORDINARY","EUR","EUR","line=B","09:00")
  c=.MBInstrumentResolutionEvidence~new("RES-RS-X",src~documentEvidenceId,"OTHER","ISIN-X","XSTO","SEK","LINE-X","CUSTSE","ORDINARY","SEK","SEK","line=X","09:00")
  mb~recordInstrumentResolutionEvidence(a); mb~recordInstrumentResolutionEvidence(b); mb~recordInstrumentResolutionEvidence(c)
  ia=mb~instrumentIdentityFromEvidence("RES-RS-A","GBP",1,"ISSUER-RS"); ib=mb~instrumentIdentityFromEvidence("RES-RS-B","EUR",1,"ISSUER-RS")
  permit=.MBDecisionEvidence~new("PERMITTED","PERMITTED","LEGAL-RS","POL-RS")
  mb~registerProduct(.MBDerivativeProductDefinition~new("CFD-RS-A","1","CFD","RS-EQ","GBP","CASH",permit,"","",1,ia)); mb~registerProduct(.MBDerivativeProductDefinition~new("CFD-RS-B","1","CFD","RS-EQ","EUR","CASH",permit,"","",1,ib))
  mb~createPortfolio("PF-RS-A","CLIENT-RS","GBP"); mb~createPortfolio("PF-RS-B","MM-RS","EUR")
  mb~bookTrade(.MBDerivativeTrade~new("TR-RS-A","PF-RS-A","CLIENT-RS","CFD","LONG","GBP",1000000,0,0,"",1,"RS","CFD-RS-A","RS-EQ","09:00"))
  mb~recordFXEvidence(.MBFXEvidence~new("FX-RS","FX-AUTH","GBP","EUR",1.20,"09:01","CURRENT"))
  off=.MBDerivativeTrade~new("TR-RS-B","PF-RS-B","MM-RS","CFD","SHORT","EUR",1200000,0,0,"",1,"RS","CFD-RS-B","RS-EQ","09:01","MM-RS","EXTERNAL_HEDGE")
  mb~bookCFDOffset("INT-RS","H-RS","TR-RS-A",off,"FX-RS","TRADE-AUTH","09:01")
  baseline=.MBMarketStructureEvent~new("MSE-RS-BASE","BASELINE","09:02","GB/NL","MARKET-AUTH","BASE","LEGAL-BASE","RES-RS-B",.true,.true,.true,.true,.true,"AVAILABLE")
  mb~applyMarketStructureEventToHedge(baseline,"H-RS","EQE-RS-BASE")
  mb~reassessHedgeRiskFromLatestKnown("HRA-RS-BASE","H-RS","EQE-RS-BASE","09:02")
  return mb
::method payload class
  use arg key,value,key2="",value2=""
  p=.directory~new; p[key]=value; if key2<>"" then p[key2]=value2; return p
::method assertEq class
  use strict arg expected,actual,label
  if expected<>actual then raise syntax 88.900 array("ASSERT_EQ",label,"expected",expected,"actual",actual)
::method assertTrue class
  use strict arg value,label
  if \value then raise syntax 88.900 array("ASSERT_TRUE",label)

::requires "FederationBankMerchantBank.cls"
