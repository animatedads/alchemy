e=.MBDecisionEvidence~new("PERMITTED","PERMITTED","LEGAL-ADR","POL-ADR")
mb=.FederationBankMerchantBank~new
ord=.MBInstrumentIdentity~new("NATWEST-EQ","GB00BM8PJY71","XLON","ORDINARY","GBP","GBP","GBP",1,"NATWEST")
adr=.MBInstrumentIdentity~new("NATWEST-EQ","US6390572070","XNYS","ADR","USD","USD","USD",2,"NATWEST-ADR-DEPOSITARY")
mb~registerProduct(.MBDerivativeProductDefinition~new("NWG-LON","1","CFD","NATWEST-EQ","GBP","CASH",e,"","",1,ord))
mb~registerProduct(.MBDerivativeProductDefinition~new("NWG-ADR","1","CFD","NATWEST-EQ","USD","CASH",e,"","",1,adr))
mb~createPortfolio("PF-NWG","CLIENT-NWG","GBP")
mb~createPortfolio("PF-NWG-H","MM-NY","USD")
mb~bookTrade(.MBDerivativeTrade~new("TR-NWG-LON","PF-NWG","CLIENT-NWG","CFD","LONG","GBP",1000000,0,0,"",1,"NWG","NWG-LON","NATWEST-EQ","09:00"))
mb~recordFXEvidence(.MBFXEvidence~new("FX-NWG-SIZE","FX-AUTH","GBP","USD",1.25,"09:01","CURRENT"))
off=.MBDerivativeTrade~new("TR-NWG-ADR","PF-NWG-H","MM-NY","CFD","SHORT","USD",1250000,0,0,"",1,"NWG","NWG-ADR","NATWEST-EQ","09:01","MM-NY","EXTERNAL_HEDGE")
h=mb~bookCFDOffset("INT-NWG","H-NWG","TR-NWG-LON",off,"FX-NWG-SIZE","MB-TRADE-AUTH","09:01")
call assertEq "DEPOSITARY_HEDGE",h~relationshipType,"ADR hedge classified as depositary relationship"
mb~recordHedgeFungibilityEvidence(.MBHedgeFungibilityEvidence~new("FUNG-NWG-1","H-NWG","GB/US",.true,.true,.true,.true,.true,"MB-LEGAL-MARKET-AUTH","LEGAL-FUNG-1","09:02"))
a1=mb~assessHedgeRisk("HRA-NWG-1","H-NWG","FX-NWG-SIZE","","","","09:02")
call assertEq "NET_ZERO_MARKET_RISK_WITH_MONITORING",a1~riskState,"pre-sanction hedge economically aligned"
mb~recordHedgeFungibilityEvidence(.MBHedgeFungibilityEvidence~new("FUNG-NWG-2","H-NWG","GB/US",.false,.false,.false,.false,.false,"MB-SANCTIONS-AUTH","LEGAL-SANCTION-77","10:00"))
mb~recordBasisRiskEvidence(.MBBasisRiskEvidence~new("BASIS-NWG-2","H-NWG",380000,"MB-MARKET-RISK","BASIS-MODEL-77","10:00","RESTRICTED"))
a2=mb~assessHedgeRisk("HRA-NWG-2","H-NWG","FX-NWG-SIZE","BASIS-NWG-2","","FUNG-NWG-2","10:00")
call assertEq "IMPAIRED",a2~equivalenceState,"sanction breaks prior fungibility"
call assertEq "HEDGE_IMPAIRED",a2~riskState,"sanctioned illiquid leg is no longer a clean hedge"
call assertEq 380000,a2~basisExposure,"illiquidity/basis dislocation retained"
call assertEq 1,a2~monitoringRequired,"client closed view never removes sanctions risk monitoring"
say "PASS test_sanctions_fungibility_impairment"
exit 0
::routine assertEq
  use strict arg expected,actual,label
  if expected<>actual then raise syntax 88.900 array("ASSERT_EQ",label,"expected",expected,"actual",actual)
::requires "FederationBankMerchantBank.cls"
