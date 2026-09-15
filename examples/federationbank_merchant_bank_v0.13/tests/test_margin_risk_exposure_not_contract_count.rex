mb=.FederationBankMerchantBank~new
p=mb~createPortfolio("PF-RISKEXP","CLIENT-RISKEXP","GBP")
mb~bookTrade(.MBDerivativeTrade~new("TR-RISK-A","PF-RISKEXP","CLIENT-RISKEXP","CFD","LONG","GBP",6000000,0,0,"",1,"IDX","","IDX","08:00"))
mb~bookTrade(.MBDerivativeTrade~new("TR-RISK-B","PF-RISKEXP","CLIENT-RISKEXP","CFD","SHORT","GBP",6000000,0,0,"",1,"IDX","","IDX","08:01"))
v=.MBValuationSnapshot~new("VAL-RISKEXP","PF-RISKEXP","09:00","GBP",1000000,0,12000000,"MKTSET",0,"CURRENT",2,1000000)
mb~recordValuation(v)
policy=.MBRiskPolicy~new("POL-RISKEXP",6,0,3600)
a=mb~assessMargin("ASS-RISKEXP","PF-RISKEXP",v,policy,0,"09:01")
call assertEq 12000000,v~grossExposure,"gross live contractual exposure retained"
call assertEq 1000000,v~riskExposure,"risk exposure can be lower after economic netting"
if a~requiredMargin>=2000000 then raise syntax 88.900 array("ASSERT_RISK_MARGIN","margin must use risk exposure, not pretend live contracts vanished",a~requiredMargin)
call assertEq 2,p~openTradeCount,"both CFD promises remain live"
say "PASS test_margin_risk_exposure_not_contract_count"
exit 0
::routine assertEq
  use strict arg expected,actual,label
  if expected<>actual then raise syntax 88.900 array("ASSERT_EQ",label,"expected",expected,"actual",actual)
::requires "FederationBankMerchantBank.cls"
