e=.MBDecisionEvidence~new("PERMITTED","PERMITTED","LEGAL-SHEL","POL-SHEL")
mb=.FederationBankMerchantBank~new
lon=.MBInstrumentIdentity~new("SHELL-EQ","GB00BP6MXD84","XLON","ORDINARY","GBP","GBP","GBP",1,"SHELL-PLC")
ams=.MBInstrumentIdentity~new("SHELL-EQ","GB00BP6MXD84","XAMS","ORDINARY","EUR","EUR","EUR",1,"SHELL-PLC")
mb~registerProduct(.MBDerivativeProductDefinition~new("SHEL-LON","1","CFD","SHELL-EQ","GBP","CASH",e,"","",1,lon))
mb~registerProduct(.MBDerivativeProductDefinition~new("SHEL-AMS","1","CFD","SHELL-EQ","EUR","CASH",e,"","",1,ams))
mb~createPortfolio("PF-LON","CLIENT-SHEL","GBP")
mb~createPortfolio("PF-AMS-H","MM-AMS","EUR")
mb~bookTrade(.MBDerivativeTrade~new("TR-LON","PF-LON","CLIENT-SHEL","CFD","LONG","GBP",1000000,0,0,"",1,"SHEL","SHEL-LON","SHELL-EQ","09:00"))
mb~recordFXEvidence(.MBFXEvidence~new("FX-SIZE","FX-AUTH","GBP","EUR",1.2,"09:01","CURRENT"))
off=.MBDerivativeTrade~new("TR-AMS","PF-AMS-H","MM-AMS","CFD","SHORT","EUR",1200000,0,0,"",1,"SHELL","SHEL-AMS","SHELL-EQ","09:01","MM-AMS","EXTERNAL_HEDGE")
h=mb~bookCFDOffset("INT-SHEL","H-SHEL","TR-LON",off,"FX-SIZE","MB-TRADE-AUTH","09:01")
call assertEq "CROSS_LISTED_HEDGE",h~relationshipType,"same ISIN but different venue/currency is not exact offset"
mb~recordHedgeFungibilityEvidence(.MBHedgeFungibilityEvidence~new("FUNG-SHEL","H-SHEL","GB/NL",.true,.true,.true,.true,.true,"MB-LEGAL-MARKET-AUTH","LEGAL-FUNG-SHEL","09:01"))
mb~recordFXEvidence(.MBFXEvidence~new("FX-NOW","FX-AUTH","GBP","EUR",1.1,"10:00","CURRENT"))
a=mb~assessHedgeRisk("HRA-SHEL","H-SHEL","FX-NOW","","","","10:00")
call assertEq "RESIDUAL_RISK",a~riskState,"FX movement reopens translated risk"
if abs(a~directionalExposure) < 90000 | abs(a~directionalExposure) > 92000 then raise syntax 88.900 array("ASSERT_RANGE","expected roughly 90909 GBP residual","actual",a~directionalExposure)
if a~fxTranslationExposure < 90000 then raise syntax 88.900 array("ASSERT_FX_DRIFT","FX drift retained")
call assertEq "OPEN",mb~portfolio("PF-LON")~trade("TR-LON")~status,"original CFD still live after front-end close"
say "PASS test_cross_listed_fx_drift"
exit 0
::routine assertEq
  use strict arg expected,actual,label
  if expected<>actual then raise syntax 88.900 array("ASSERT_EQ",label,"expected",expected,"actual",actual)
::requires "FederationBankMerchantBank.cls"
