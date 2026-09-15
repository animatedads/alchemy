v=.VectorMeridianMarkets~new
s=.VMMAlgorithmStrategy~new("ALG-NFR-1","2.0","MARKET_MAKER","SRC-NFR","MODEL-NFR",1000000,2000000,"POL-NFR")
v~registerStrategy(s); v~enableStrategy("ALG-NFR-1","VMM-RISK")
i=.VMMTradableInstrument~new("BARC-L","BARC","GB0031348658","XLON","ORDINARY","GBP","GBP","GBP","RES-BARC-L")
r=.VMMFlowRequest~new("RFQ-NFR","BARC-L","CFD","LONG","GBP",100000,"REL-OPAQUE-NFR","FEDERATIONBANK_MERCHANT_BANK","20260828T122000","",i)
v~requestQuote(r,"ALG-NFR-1","Q-NFR",3.2,10,"20260828T122005")
call expectNoPreHedge v

d=.VMMAlgorithmDecision~new("DEC-INDEPENDENT-1","ALG-NFR-1",i,"BUY",50000,"20260828T122001","MKT-SNAPSHOT-77","SIGNAL-RUN-77","VMM-ALGO-AUTH")
v~recordAlgorithmDecision(d)
o=v~createProprietaryOrder("ORD-PROP-1","DEC-INDEPENDENT-1","LIMIT",3.19,"20260828T122002","VMM-ALGO-EXEC")
call assertEq "PROPRIETARY_SIGNAL",o~origin,"independent proprietary order has its own evidence path"
call assertEq "",o~parentTradeId,"proprietary order does not point at customer RFQ/trade"
say "PASS test_no_front_run_unexecuted_flow"
exit 0

::routine expectNoPreHedge
  use strict arg v
  signal on syntax name gotSyntax
  v~createInventoryHedgeOrder("ORD-BAD-PREHEDGE","T-NOT-EXECUTED","ALG-NFR-1",100000,"LIMIT",3.19,"20260828T122001","VMM-ALGO-EXEC")
  signal off syntax
  raise syntax 88.900 array("unexecuted customer RFQ unexpectedly enabled pre-hedge")
gotSyntax:
  signal off syntax
  return

::routine assertEq
  use strict arg expected,actual,label
  if expected<>actual then raise syntax 88.900 array("ASSERT_EQ",label,"expected",expected,"actual",actual)

::requires "VectorMeridianMarkets.cls"
