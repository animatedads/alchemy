mb=.FederationBankMerchantBank~new
p=mb~createPortfolio("PF-DEF-CFD","CLIENT-DEF","GBP")
hp=mb~createPortfolio("PF-DEF-H","MM-DEF","GBP")
mb~bookTrade(.MBDerivativeTrade~new("TR-DEF-CFD","PF-DEF-CFD","CLIENT-DEF","CFD","LONG","GBP",6000000,0,0,"",1,"IDX-D","","IDX-D","08:00"))
v=.MBValuationSnapshot~new("VAL-DEF-CFD","PF-DEF-CFD","09:00","GBP",0,0,6000000,"MKTSET-D")
mb~recordValuation(v)
policy=.MBRiskPolicy~new("POL-DEF",6,0,3600)
a=mb~assessMargin("ASS-DEF","PF-DEF-CFD",v,policy,0,"09:01")
c=mb~issueMarginCall("CALL-DEF","ASS-DEF","09:02","10:02")
i=mb~defaultMarginCall("CALL-DEF","NEUT-REQ-1","MB-RISK-AUTH","10:03")
mb~recordMarketEvidence(.MBMarketEvidence~new("MKT-DEF","EXCHANGE-A","IDX-D","10:04","GBP",100,"CURRENT"))
results=.directory~new
off=.MBDerivativeTrade~new("TR-DEF-OFF","PF-DEF-H","MM-DEF","CFD","SHORT","GBP",6000000,0,0,"",1,"IDX-D","","IDX-D","10:04","MM-DEF","EXTERNAL_HEDGE")
results["TR-DEF-CFD"]=.MBCFDNeutralisationResult~new("NR-1","TR-DEF-CFD",off,"",250000,300000,"MKT-DEF","MB-CLOSEOUT-AUTH")
x=mb~executeRiskNeutralisation("NEUT-REQ-1","NEUT-EXEC-1",results,"10:05","MB-CLOSEOUT-AUTH")
call assertEq "COMPLETE",x~state,"risk neutralisation completes"
call assertEq 300000,x~signedNetSettlement,"difference becomes contractual settlement amount"
orig=p~trade("TR-DEF-CFD")
call assertEq "OPEN",orig~status,"default neutralisation does not delete original CFD"
call assertEq "ACTIVE",orig~contractState,"original promise remains perpetual/live"
call assertEq "CLOSED",orig~clientViewState,"front end can show close completed"
call assertEq "OPEN",hp~trade("TR-DEF-OFF")~status,"reversing CFD remains live"
o=mb~createNeutralisationSettlementObligation("OBL-DEF","NEUT-EXEC-1")
call assertEq "CLIENT-DEF",o~debtor,"positive difference owed by client"
call assertEq 300000,o~amount,"net difference is settlement obligation"
call assertEq "UNSETTLED",o~status,"no Core cash movement in Merchant package"
call expectCloseOutBlocked mb,"NEUT-REQ-1","legacy close-out method cannot destroy CFD contracts"
say "PASS test_default_cfd_risk_neutralisation"
exit 0
::routine assertEq
  use strict arg expected,actual,label
  if expected<>actual then raise syntax 88.900 array("ASSERT_EQ",label,"expected",expected,"actual",actual)
::routine expectCloseOutBlocked
  use strict arg mb,instructionId,label
  r=.directory~new
  r["TR-DEF-CFD"]=.MBCloseOutTradeResult~new("X","TR-DEF-CFD","MKT-DEF",0,0,"A")
  caught=.false
  signal on syntax name gotSyntax
  mb~executeCloseOut(instructionId,"BAD",r,"10:06","A")
  signal off syntax
  if \caught then raise syntax 88.900 array("ASSERT_EXPECTED_SYNTAX",label)
  return
gotSyntax:
  caught=.true
  signal off syntax
  return
::requires "FederationBankMerchantBank.cls"
