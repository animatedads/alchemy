mb=.FederationBankMerchantBank~new
p=mb~createPortfolio("PF-1","CLIENT-1","GBP")
t1=.MBDerivativeTrade~new("T-CFD-1","PF-1","CLIENT-1","CFD","LONG","GBP",1000000,0,0,"","1","MKT-FTSE")
t2=.MBDerivativeTrade~new("T-OPT-1","PF-1","CLIENT-1","OPTION","LONG","GBP",500000,100,25000,"20261231","10","MKT-ABC")
mb~bookTrade(t1)
mb~bookTrade(t2)
call assertEq 2,p~tradeCount,"two trades"
call assertEq 1500000,p~grossNotional,"gross notional"
call assertTrue mb~journal~retainedNodeCount>=3,"journal records portfolio and trades"
point=mb~journalPoint
snap=mb~journal~stateAt(point)
call assertTrue snap~hasIndex("trade:T-CFD-1"),"journal reconstruction contains CFD"
call assertTrue snap~hasIndex("trade:T-OPT-1"),"journal reconstruction contains option"
say "PASS test_product_and_journal"
exit 0
::routine assertEq
  use strict arg expected,actual,label
  if expected<>actual then raise syntax 88.900 array("ASSERT_EQ",label,"expected",expected,"actual",actual)
::routine assertTrue
  use strict arg actual,label
  if \actual then raise syntax 88.900 array("ASSERT_TRUE",label)
::requires "FederationBankMerchantBank.cls"
