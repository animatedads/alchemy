v=.VectorMeridianMarkets~new
s=.VMMAlgorithmStrategy~new("ALG-INV-1","1.0","INVENTORY_SKEW","SRC-HASH-I","MODEL-I",600000,700000,"POL-VMM-ALG-2")
v~registerStrategy(s); v~enableStrategy("ALG-INV-1","VMM-RISK")
r=.VMMFlowRequest~new("RFQ-I1","HSBA.L","CFD","SHORT","GBP",500000,"REL-9","FEDERATIONBANK_MERCHANT_BANK","20260828T101000")
q=v~requestQuote(r,"ALG-INV-1","Q-I1",8.25,10,"20260828T101005")
t=v~executeQuote("VMM-T-1","Q-I1","20260828T101001","VMM-EXEC")
call assertEq "LONG",t~principalSide,"principal side"
call assertEq 500000,v~inventoryFor("HSBA.L"),"inventory after execution"
call expectInventoryLimit v
v~setKillSwitch(.true,"VMM-INDEPENDENT-RISK","SURVEILLANCE_HALT","20260828T101100")
call expectKilled v
v~setKillSwitch(.false,"VMM-INDEPENDENT-RISK","HALT_CLEARED","20260828T101200")
call assertEq 0,v~killSwitchActive,"kill switch released"
sur=.VMMSurveillanceEvidence~new("SURV-1","FLOW_TOXICITY_ALERT","VMM-INDEPENDENT-SURVEILLANCE","SURV-RUN-88","20260828T101050","HIGH","opaque flow cluster; no customer identity")
v~recordSurveillanceEvidence(sur)
say "PASS test_algo_inventory_kill_switch"
exit 0

::routine expectInventoryLimit
  use strict arg v
  signal on syntax name gotSyntax
  r=.VMMFlowRequest~new("RFQ-I2","HSBA.L","CFD","SHORT","GBP",300000,"REL-10","FEDERATIONBANK_MERCHANT_BANK","20260828T101010")
  v~requestQuote(r,"ALG-INV-1","Q-I2",8.26,10,"20260828T101015")
  signal off syntax
  raise syntax 88.900 array("inventory limit unexpectedly bypassed")
gotSyntax:
  signal off syntax
  return

::routine expectKilled
  use strict arg v
  signal on syntax name gotSyntax
  r=.VMMFlowRequest~new("RFQ-K","BARC.L","CFD","LONG","GBP",1000,"REL-K","FEDERATIONBANK_MERCHANT_BANK","20260828T101101")
  v~requestQuote(r,"ALG-INV-1","Q-K",3.2,10,"20260828T101105")
  signal off syntax
  raise syntax 88.900 array("kill switch unexpectedly bypassed")
gotSyntax:
  signal off syntax
  return

::routine assertEq
  use strict arg expected,actual,label
  if expected<>actual then raise syntax 88.900 array("ASSERT_EQ",label,"expected",expected,"actual",actual)

::requires "VectorMeridianMarkets.cls"
