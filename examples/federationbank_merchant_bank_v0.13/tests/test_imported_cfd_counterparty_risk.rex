e=.MBDecisionEvidence~new("PERMITTED","PERMITTED","LEGAL-CP","POL-CP")
mb=.FederationBankMerchantBank~new
id=.MBInstrumentIdentity~new("IDX-CP","ISIN-CP","XLON","ORDINARY","GBP","GBP","GBP",1,"ISSUER-CP")
mb~registerProduct(.MBDerivativeProductDefinition~new("CFD-CP","1","CFD","IDX-CP","GBP","CASH",e,"","",1,id))
mb~createPortfolio("PF-CLIENT-CP","CLIENT-CP","GBP")
mb~createPortfolio("PF-MM-CP","EXTERNAL-MM-42","GBP")
mb~bookTrade(.MBDerivativeTrade~new("TR-CLIENT-CP","PF-CLIENT-CP","CLIENT-CP","CFD","LONG","GBP",2000000,0,0,"",1,"CP","CFD-CP","IDX-CP","09:00"))
off=.MBDerivativeTrade~new("TR-MM-CP","PF-MM-CP","EXTERNAL-MM-42","CFD","SHORT","GBP",2000000,0,0,"",1,"CP","CFD-CP","IDX-CP","09:01","EXTERNAL-MM-42","EXTERNAL_HEDGE")
mb~bookCFDOffset("INT-CP","H-CP","TR-CLIENT-CP",off,"","MB-TRADE-AUTH","09:01")
mb~recordCounterpartyRiskEvidence(.MBCounterpartyRiskEvidence~new("CP-EV-1","TR-MM-CP","EXTERNAL-MM-42",420000,120000,"MB-COUNTERPARTY-RISK","CP-MODEL-1","09:05"))
a=mb~assessHedgeRisk("HRA-CP","H-CP","","","CP-EV-1","","09:05")
call assertEq 0,a~directionalExposure,"directional exposure is net zero"
call assertEq 420000,a~counterpartyExposure,"external counterparty exposure retained"
call assertEq 120000,a~replacementCost,"replacement cost retained"
call assertEq "RESIDUAL_RISK",a~riskState,"net zero market risk is not zero counterparty risk"
call assertEq 1,a~monitoringRequired,"imported hedge stays monitored"
say "PASS test_imported_cfd_counterparty_risk"
exit 0
::routine assertEq
  use strict arg expected,actual,label
  if expected<>actual then raise syntax 88.900 array("ASSERT_EQ",label,"expected",expected,"actual",actual)
::requires "FederationBankMerchantBank.cls"
