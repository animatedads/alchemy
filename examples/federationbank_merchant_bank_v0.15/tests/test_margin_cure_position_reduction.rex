e=.MBDecisionEvidence~new("PERMITTED","PERMITTED","LEGAL-CSA-PR","POL-COLL-PR")
mb=.FederationBankMerchantBank~new
p=mb~createPortfolio("PF-PR","CLIENT-PR","GBP")
mb~registerCollateralAgreement(.MBCollateralAgreement~new("CSA-PR","CLIENT-PR","FEDERATIONBANK_MERCHANT_BANK","CLIENT-PR","PF-PR",1000000,"GBP",e))
mb~registerCollateralAsset(.MBCollateralAsset~new("COLL-PR","CLIENT-PR","CORE-PR","CASH_ACCOUNT","GBP",1000000,0))
mb~acknowledgeCoreControl(.MBCollateralControlReceipt~new("CTRL-PR","CSA-PR","COLL-PR","CORE-AUTH-PR","CLIENT-PR",.true,.true,"FIRST",1000000,"GBP","09:00"))
mb~bookTrade(.MBDerivativeTrade~new("TR-PR-1","PF-PR","CLIENT-PR","OPTION","LONG","GBP",6000000,10000,100000,"2026-12-31",1,"IDX-PR","","IDX-PR","08:00"))
mb~bookTrade(.MBDerivativeTrade~new("TR-PR-2","PF-PR","CLIENT-PR","OPTION","SHORT","GBP",6000000,10000,100000,"2026-12-31",1,"IDX-PR","","IDX-PR","08:01"))
v1=.MBValuationSnapshot~new("VAL-PR-1","PF-PR","09:01","GBP",0,0,12000000,"MKTSET-PR-1")
mb~recordValuation(v1)
policy=.MBRiskPolicy~new("POL-PR",6,0,3600)
a1=mb~assessMargin("ASS-PR-1","PF-PR",v1,policy,0,"09:02")
call assertEq "MARGIN_DEFICIT",a1~state,"position book over leverage"
c=mb~issueMarginCall("CALL-PR-1","ASS-PR-1","09:03","10:03")

mkt=.MBMarketEvidence~new("MKT-PR-REDUCE","EXCHANGE-A","IDX-PR","09:20","GBP",10000,"CURRENT")
mb~recordMarketEvidence(mkt)
ev=mb~closeTrade("REDUCE-PR-1","TR-PR-2","CLOSED","09:20",25000,"MKT-PR-REDUCE","MB-TRADING-AUTH")
v2=.MBValuationSnapshot~new("VAL-PR-2","PF-PR","09:21","GBP",0,0,6000000,"MKTSET-PR-2",25000,"CURRENT",1)
mb~recordValuation(v2)
a2=mb~assessMargin("ASS-PR-2","PF-PR",v2,policy,0,"09:22")
call assertEq "COMPLIANT",a2~state,"position reduction cures leverage"
r=mb~cureMarginCall("CALL-PR-1","CURE-PR-1","POSITION_REDUCTION","REDUCE-PR-1","MB-TRADING-AUTH","ASS-PR-2","09:23")
call assertEq "CURED",c~state,"position-reduction call cured"
call assertEq "POSITION_REDUCTION",r~mechanism,"reduction mechanism retained"
call assertEq 1,p~openTradeCount,"one position remains open"

say "PASS test_margin_cure_position_reduction"
exit 0
::routine assertEq
  use strict arg expected,actual,label
  if expected<>actual then raise syntax 88.900 array("ASSERT_EQ",label,"expected",expected,"actual",actual)
::requires "FederationBankMerchantBank.cls"
