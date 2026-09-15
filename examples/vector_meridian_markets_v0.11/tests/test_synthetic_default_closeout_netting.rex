v=.VectorMeridianMarkets~new
x=.VMMInstitutionalSyntheticService~new(v)
c=.VMMInstitutionalCounterparty~new("AJI","ALL_JAPAN_INSURANCE","REL-AJI","JP","KYC-AJI","ISDA-AJI","CSA-AJI","VMM-ONBOARD")
x~registerCounterparty(c)
x~setRiskPolicy(.VMMSyntheticRiskPolicy~new("SYN-RISK-JPY","JPY",100000000000,50000000000,100,"POL-SYN-JPY"),"VMM-RISK")
p=.VMMPortfolioReferencePosition~new("P-DEF-NET","AJI","JGB-NET","JAPAN_GOVERNMENT","SOVEREIGN_BOND","JPY",10000000,"ALL_JAPAN_INSURANCE","","BOOK-NET","","VAL-NET")
s=.VMMPortfolioSnapshot~new("SNAP-DEF-NET","AJI","ALL_JAPAN_INSURANCE","JPY","20260828",.array~of(p),"AJI-POSITIONS-NET","","VMM-PORTFOLIO")
x~registerPortfolioSnapshot(s)
x~createOffer("OFF-DEF-NET","REQ-DEF-NET","AJI","SNAP-DEF-NET","JPY",10000000,5,25,120000,"20260901","20310831","20260828T140000","20260828T132100","MODEL-NET","MKT-NET","RISK-NET")
k=x~acceptOffer("CON-DEF-NET","OFF-DEF-NET","20260828T132200","ALL_JAPAN_INSURANCE","AJI-SIGNER")
/* 6% portfolio loss -> 5% protection fraction -> 500,000 VMM liability. */
x~setCollateralTerms(k~contractId,.VMMSyntheticCollateralTerms~new("CSA-NET","JPY",0,0,0,"COLLATERAL-POLICY-NET"),"VMM-COLLATERAL")
val=x~valueContract("VAL-DEF-NET",k~contractId,9400000,"20260828T150000","MKT-VAL-NET","MODEL-VAL-NET","VMM-VALUATION")
call assertNear 500000,val~vmmLiabilityMtm,0.01,"expected liability for margin setup"
mc=x~issueVariationMarginCall("CALL-DEF-NET",k~contractId,val~valuationId,"20260828T151000","VMM-COLLATERAL")
call assertNear 500000,mc~amount,0.01,"variation margin call equals liability"
vm=.VMMSyntheticCollateralTransfer~new("VM-DEF-NET",k~contractId,mc~callId,"JPY",500000,"VMM_TO_COUNTERPARTY","CUSTODIAN-NET","CONTROL-VM-NET","20260828T152000","VMM-COLLATERAL")
x~recordCollateralTransfer(vm)
/* Segregated IM is deliberately visible but excluded from automatic close-out netting. */
x~setInitialMarginTerms(k~contractId,.VMMSyntheticInitialMarginTerms~new("IM-TERMS-NET","JPY",190000,"SOVEREIGN_BOND",500,"IM-POLICY-NET"),"VMM-COLLATERAL")
im=.VMMSyntheticInitialMarginTransfer~new("IM-DEF-NET",k~contractId,"JPY","JGB-IM-NET","SOVEREIGN_BOND",200000,500,"VECTOR_MERIDIAN_MARKETS_LTD","ALL_JAPAN_INSURANCE","CUSTODIAN-NET","CONTROL-IM-NET","20260828T153000","VMM-COLLATERAL")
x~recordInitialMarginTransfer(im)
/* Outstanding premium supports the client payment default. */
pp=.VMMSyntheticPremiumPeriod~new("PREM-DEF-NET","JPY","20260901","20260930","20261005",120000,"SCHED-NET")
x~setPremiumSchedule(k~contractId,.array~of(pp),"VMM-OTC-OPS")
x~recordPremiumAccrual("ACCR-DEF-NET",k~contractId,pp~periodId,30,30,"20260930","ACCR-EVID-NET","VMM-FINANCE")

d=.VMMInstitutionalDefaultCloseoutService~new(x)
d~setPolicy(.VMMSyntheticDefaultPolicy~new("DEF-POL-NET","JPY",2,1,3,"ISDA-2002-CLOSEOUT-AMOUNT","POL-DEFAULT-NET"),"VMM-LEGAL")
ev=d~declareDefault("DEF-NET-1",k~contractId,"FAILURE_TO_PAY_PREMIUM","ALL_JAPAN_INSURANCE","2026-10-06","2026-10-06","UNPAID-PREMIUM-NET","VMM-LEGAL")
d~assessUncured("UNCURED-NET-1",ev~eventId,"2026-10-09","CURE-PERIOD-EXPIRED","VMM-LEGAL")
t=d~electTermination("TERM-NET-1",ev~eventId,"VECTOR_MERIDIAN_MARKETS_LTD","2026-10-09","TERMINATION-NOTICE-NET","VALUATION-AGENT-NET","VMM-LEGAL")
call assertEq "TERMINATED",k~state,"uncured default permits explicit termination election"
co=d~determineCloseout("CLOSE-NET-1",t~terminationId,-1500000,"2026-10-10","ISDA-CLOSEOUT-METHODOLOGY","MKT-CLOSEOUT-NET","CSA-NETTING-EVIDENCE","VMM-VALUATION-CONTROL")
call assertNear 500000,co~cashVariationMarginPosted,0.01,"cash VM enters close-out netting"
call assertNear 190000,co~segregatedInitialMarginRecognized,0.01,"segregated IM remains visible separately"
call assertNear -1000000,co~netAmountToVMM,0.01,"cash VM offsets VMM gross close-out payable"
call assertEq "VMM_PAYABLE",co~netDirection,"net close-out direction from VMM perspective"
/* Internal hedge unwind economics are VMM evidence, not a client close-out component. */
h=d~recordHedgeAttribution("HEDGE-ATTR-NET",t~terminationId,-4000000,"2026-10-10","EXEC-HEDGE-LOSS-NET","HEDGE-ATTR-METHOD","VMM-HEDGE-CONTROL")
call assertNear -4000000,h~hedgePnl,0.01,"large VMM hedge loss is retained as separate attribution evidence"
call assertNear -1000000,co~netAmountToVMM,0.01,"hedge loss cannot rewrite legal close-out amount"
settle=d~settleCloseout("SETTLE-NET-1",co~closeoutId,"2026-10-11","BANK-CLOSEOUT-PAYMENT","VMM-TREASURY")
call assertNear 1000000,settle~amount,0.01,"cash settlement equals net close-out amount"
call assertEq "VECTOR_MERIDIAN_MARKETS_LTD",settle~payerEntity,"VMM pays net close-out when amount is negative"
call assertEq "ALL_JAPAN_INSURANCE",settle~payeeEntity,"institutional counterparty receives close-out payment"
call assertNear 0,d~effectiveCashCollateralPosted(k~contractId),0.01,"cash VM is disposed through settled netting"
say "PASS test_synthetic_default_closeout_netting"
exit 0
::routine assertEq
  use strict arg expected,actual,label
  if expected<>actual then raise syntax 88.900 array("ASSERT_EQ",label,"expected",expected,"actual",actual)
::routine assertNear
  use strict arg expected,actual,tolerance,label
  if abs(expected-actual)>tolerance then raise syntax 88.900 array("ASSERT_NEAR",label,"expected",expected,"actual",actual)
::requires "VMMDefaultCloseout.cls"
