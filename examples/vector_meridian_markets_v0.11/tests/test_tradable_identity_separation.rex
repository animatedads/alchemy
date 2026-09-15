v=.VectorMeridianMarkets~new
s=.VMMAlgorithmStrategy~new("ALG-DUAL-1","2.0","MULTI_LISTING_MM","SRC-DUAL","MODEL-DUAL",1000000,2000000,"POL-DUAL")
v~registerStrategy(s); v~enableStrategy("ALG-DUAL-1","VMM-RISK")
us=.VMMTradableInstrument~new("CITI-US","CITI","US1729674242","XNYS","ORDINARY","USD","USD","USD","RES-CITI-US")
uk=.VMMTradableInstrument~new("CITI-UK","CITI","GB00CITI0001","XLON","ORDINARY","GBP","GBP","GBP","RES-CITI-UK")
call assertEq 0,us~sameTradableLine(uk),"different listing/ISIN not same legal line"
r1=.VMMFlowRequest~new("RFQ-DUAL-US","CITI-US","CFD","LONG","USD",100000,"REL-DUAL-US","FEDERATIONBANK_MERCHANT_BANK","20260828T120000","",us)
r2=.VMMFlowRequest~new("RFQ-DUAL-UK","CITI-UK","CFD","LONG","GBP",100000,"REL-DUAL-UK","FEDERATIONBANK_MERCHANT_BANK","20260828T120001","",uk)
v~requestQuote(r1,"ALG-DUAL-1","Q-DUAL-US",100,10,"20260828T120010")
v~requestQuote(r2,"ALG-DUAL-1","Q-DUAL-UK",80,10,"20260828T120011")
v~executeQuote("T-DUAL-US","Q-DUAL-US","20260828T120002","VMM-EXEC")
v~executeQuote("T-DUAL-UK","Q-DUAL-UK","20260828T120003","VMM-EXEC")
call assertEq -100000,v~inventoryFor(us),"US listing inventory"
call assertEq -100000,v~inventoryFor(uk),"UK listing inventory"
if us~identityKey=uk~identityKey then raise syntax 88.900 array("dual-listed identities collapsed")
say "PASS test_tradable_identity_separation"
exit 0

::routine assertEq
  use strict arg expected,actual,label
  if expected<>actual then raise syntax 88.900 array("ASSERT_EQ",label,"expected",expected,"actual",actual)

::requires "VectorMeridianMarkets.cls"
