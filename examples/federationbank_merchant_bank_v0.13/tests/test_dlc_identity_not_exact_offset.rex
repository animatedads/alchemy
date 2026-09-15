e=.MBDecisionEvidence~new("PERMITTED","PERMITTED","LEGAL-RIO","POL-RIO")
mb=.FederationBankMerchantBank~new
plc=.MBInstrumentIdentity~new("RIO-DLC-EQ","GB0007188757","XLON","DLC_ORDINARY","GBP","GBP","GBP",1,"RIO-TINTO-PLC")
limited=.MBInstrumentIdentity~new("RIO-DLC-EQ","AU000000RIO1","XASX","DLC_ORDINARY","AUD","AUD","AUD",1,"RIO-TINTO-LIMITED")
mb~registerProduct(.MBDerivativeProductDefinition~new("RIO-PLC-CFD","1","CFD","RIO-DLC-EQ","GBP","CASH",e,"","",1,plc))
mb~registerProduct(.MBDerivativeProductDefinition~new("RIO-LTD-CFD","1","CFD","RIO-DLC-EQ","AUD","CASH",e,"","",1,limited))
mb~createPortfolio("PF-RIO-PLC","CLIENT-RIO","GBP")
mb~createPortfolio("PF-RIO-LTD-H","MM-AUS","AUD")
mb~bookTrade(.MBDerivativeTrade~new("TR-RIO-PLC","PF-RIO-PLC","CLIENT-RIO","CFD","LONG","GBP",1000000,0,0,"",1,"RIO","RIO-PLC-CFD","RIO-DLC-EQ","09:00"))
mb~recordFXEvidence(.MBFXEvidence~new("FX-RIO","FX-AUTH","GBP","AUD",2,"09:01","CURRENT"))
off=.MBDerivativeTrade~new("TR-RIO-LTD","PF-RIO-LTD-H","MM-AUS","CFD","SHORT","AUD",2000000,0,0,"",1,"RIO","RIO-LTD-CFD","RIO-DLC-EQ","09:01","MM-AUS","EXTERNAL_HEDGE")
h=mb~bookCFDOffset("INT-RIO","H-RIO","TR-RIO-PLC",off,"FX-RIO","MB-TRADE-AUTH","09:01")
call assertEq "DLC_EQUIVALENCE",h~relationshipType,"DLC economic equivalence is not exact legal instrument identity"
call assertEq "EQUIVALENCE_UNPROVED",h~equivalenceState,"DLC equivalence requires continuing fungibility evidence"
call assertEq "OPEN",mb~portfolio("PF-RIO-PLC")~trade("TR-RIO-PLC")~status,"London legal contract remains live"
call assertEq "OPEN",mb~portfolio("PF-RIO-LTD-H")~trade("TR-RIO-LTD")~status,"Australian hedge contract remains live"
say "PASS test_dlc_identity_not_exact_offset"
exit 0
::routine assertEq
  use strict arg expected,actual,label
  if expected<>actual then raise syntax 88.900 array("ASSERT_EQ",label,"expected",expected,"actual",actual)
::requires "FederationBankMerchantBank.cls"
