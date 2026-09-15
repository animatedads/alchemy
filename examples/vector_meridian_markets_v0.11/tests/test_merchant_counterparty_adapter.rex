v=.VectorMeridianMarkets~new
s=.VMMAlgorithmStrategy~new("ALG-MB-1","1.0","MARKET_MAKER","SRC-MB","MODEL-MB",1000000,2000000,"POL-MB")
v~registerStrategy(s); v~enableStrategy("ALG-MB-1","VMM-RISK")
r=.VMMFlowRequest~new("RFQ-MB","CITI.L","CFD","LONG","GBP",100000,"REL-OPAQUE-MB","FEDERATIONBANK_MERCHANT_BANK","20260828T103000")
q=v~requestQuote(r,"ALG-MB-1","Q-MB",80,8,"20260828T103005")
t=v~executeQuote("VMM-MB-T1","Q-MB","20260828T103001","VMM-EXEC")
a=.VectorMeridianFederationMerchantAdapter~new
mt=a~asMerchantExternalHedgeTrade(t,"MB-HEDGE-VMM-1","MB-PF-VMM","ALAN_CORP_PENSIONS","CFD","","CITI")
call assertEq "VECTOR_MERIDIAN_MARKETS_LTD",mt~counterpartyEntity,"VMM remains separate legal counterparty"
call assertEq "EXTERNAL_HEDGE",mt~sourceType,"Merchant Bank sees external hedge"
call assertEq "SHORT",mt~side,"hedge side inherited from VMM principal trade"
mb=.FederationBankMerchantBank~new("FEDERATIONBANK_MERCHANT_BANK")
mb~createPortfolio("MB-PF-VMM","ALAN_CORP_PENSIONS","GBP")
mb~bookTrade(mt)
e=.MBCounterpartyRiskEvidence~new("CP-VMM-1","MB-HEDGE-VMM-1","VECTOR_MERIDIAN_MARKETS_LTD",15000,18000,"FEDERATIONBANK_MERCHANT_RISK","VMM-CREDIT-20260828","20260828T103100")
mb~recordCounterpartyRiskEvidence(e)
call assertEq 18000,e~replacementCost,"VMM replacement risk retained"
say "PASS test_merchant_counterparty_adapter"
exit 0

::routine assertEq
  use strict arg expected,actual,label
  if expected<>actual then raise syntax 88.900 array("ASSERT_EQ",label,"expected",expected,"actual",actual)

::requires "VectorMeridianFederationMerchantAdapter.cls"
