v=.VectorMeridianMarkets~new
s=.VMMAlgorithmStrategy~new("ALG-LEG-1","2.0","LEGACY_COMPAT","SRC-LEG","MODEL-LEG",1000000,2000000,"POL-LEG")
v~registerStrategy(s); v~enableStrategy("ALG-LEG-1","VMM-RISK")
r=.VMMFlowRequest~new("RFQ-LEG","LEGACY.X","CFD","LONG","GBP",100000,"REL-LEG","FEDERATIONBANK_MERCHANT_BANK","20260828T123000")
v~requestQuote(r,"ALG-LEG-1","Q-LEG",10,10,"20260828T123005")
v~executeQuote("T-LEG","Q-LEG","20260828T123001","VMM-EXEC")
call expectNoLegacyExternalHedge v
say "PASS test_legacy_identity_cannot_external_hedge"
exit 0

::routine expectNoLegacyExternalHedge
  use strict arg v
  signal on syntax name gotSyntax
  v~createInventoryHedgeOrder("ORD-LEG","T-LEG","ALG-LEG-1",100000,"MARKET",0,"20260828T123002","VMM-ALGO-EXEC")
  signal off syntax
  raise syntax 88.900 array("legacy bare instrument unexpectedly admitted to external algo execution")
gotSyntax:
  signal off syntax
  return

::requires "VectorMeridianMarkets.cls"
