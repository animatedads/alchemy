v=.VectorMeridianMarkets~new
s=.VMMAlgorithmStrategy~new("ALG-RISK-1","2.0","PROPRIETARY_SIGNAL","SRC-RISK","MODEL-RISK",1000,1000,"POL-RISK")
v~registerStrategy(s); v~enableStrategy("ALG-RISK-1","VMM-RISK")
limits=.VMMFirmRiskLimits~new("RISK-USD-1","USD",1000,1000,1000000,100,"POL-FIRM-RISK")
v~setFirmRiskLimits(limits,"VMM-INDEPENDENT-RISK")
i=.VMMTradableInstrument~new("XYZ-US","XYZ","US000000XYZ1","XNAS","ORDINARY","USD","USD","USD","RES-XYZ-US")
d1=.VMMAlgorithmDecision~new("DEC-RISK-1","ALG-RISK-1",i,"BUY",100,"20260828T124000","MKT-RISK-1","SIG-RISK-1","VMM-ALGO")
v~recordAlgorithmDecision(d1); v~createProprietaryOrder("ORD-RISK-1","DEC-RISK-1","MARKET",0,"20260828T124001","VMM-ALGO-EXEC")
v~fillMarketOrder("FILL-RISK-1","ORD-RISK-1","XNAS-1",100,10,"20260828T124002","EXTERNAL_CLEARER")
v~recordMarketMark(.VMMMarketMark~new("MARK-RISK-1",i,8,"20260828T124003","VMM-MARKET-DATA","FEED-1"))
d2=.VMMAlgorithmDecision~new("DEC-RISK-2","ALG-RISK-1",i,"SELL",50,"20260828T124004","MKT-RISK-2","SIG-RISK-2","VMM-ALGO")
v~recordAlgorithmDecision(d2); o2=v~createProprietaryOrder("ORD-RISK-2","DEC-RISK-2","LIMIT",8.1,"20260828T124005","VMM-ALGO-EXEC")
snap=v~evaluateRisk("RISK-SNAP-LOSS","USD","20260828T124006","VMM-INDEPENDENT-RISK",.true)
call assertEq "MAX_LOSS",snap~breachCode,"loss limit breach"
call assertEq 1,v~killSwitchActive,"firm risk breach trips VMM kill switch"
call assertEq "CANCELLED",o2~state,"kill switch cancels resting algo order"
say "PASS test_risk_kill_switch_order_cancel"
exit 0

::routine assertEq
  use strict arg expected,actual,label
  if expected<>actual then raise syntax 88.900 array("ASSERT_EQ",label,"expected",expected,"actual",actual)

::requires "VectorMeridianMarkets.cls"
