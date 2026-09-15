v=.VectorMeridianMarkets~new
s=.VMMAlgorithmStrategy~new("ALG-MM-1","1.0","ADAPTIVE_SPREAD","SRC-HASH-1","MODEL-1",1000000,2000000,"POL-VMM-ALG-1")
v~registerStrategy(s)
v~enableStrategy("ALG-MM-1","VMM-RISK-COMMITTEE")
r=.VMMFlowRequest~new("RFQ-1","CITI.L","CFD","LONG","GBP",250000,"REL-OPAQUE-8","FEDERATIONBANK_MERCHANT_BANK","20260828T100000")
q=v~requestQuote(r,"ALG-MM-1","Q-1",100,12,"20260828T100005")
call assertEq "SHORT",q~principalSide,"VMM prices the opposite principal side"
call assertEq 0,r~customerEntity~length,"no customer legal identity present"
call expectBadFlow
say "PASS test_sanitized_flow"
exit 0

::routine expectBadFlow
  signal on syntax name gotSyntax
  x=.VMMFlowRequest~new("RFQ-X","CITI.L","CFD","LONG","GBP",1,"REL-X","FEDERATIONBANK_MERCHANT_BANK","20260828T100000","ALAN_CORP_PENSIONS")
  signal off syntax
  raise syntax 88.900 array("customer identity unexpectedly accepted",x)
gotSyntax:
  signal off syntax
  return

::routine assertEq
  use strict arg expected,actual,label
  if expected<>actual then raise syntax 88.900 array("ASSERT_EQ",label,"expected",expected,"actual",actual)

::requires "VectorMeridianMarkets.cls"
