mb=.FederationBankMerchantBank~new
p=mb~createPortfolio("PF-CO","CLIENT-CO","GBP")
mb~bookTrade(.MBDerivativeTrade~new("TR-CO-1","PF-CO","CLIENT-CO","OPTION","LONG","GBP",6000000,10000,100000,"2026-12-31",1,"IDX-A","","IDX-A","08:00"))
mb~bookTrade(.MBDerivativeTrade~new("TR-CO-2","PF-CO","CLIENT-CO","OPTION","LONG","GBP",6000000,10000,100000,"2026-12-31",1,"IDX-B","","IDX-B","08:01"))
v=.MBValuationSnapshot~new("VAL-CO-1","PF-CO","09:00","GBP",0,0,12000000,"MKTSET-CO")
mb~recordValuation(v)
policy=.MBRiskPolicy~new("POL-CO",6,0,3600)
a=mb~assessMargin("ASS-CO-1","PF-CO",v,policy,0,"09:01")
call assertEq "MARGIN_DEFICIT",a~state,"close-out portfolio in deficit"
c=mb~issueMarginCall("CALL-CO-1","ASS-CO-1","09:02","10:02")
call expectSyntax mb,"DEFAULTMARGINCALL",.array~of("CALL-CO-1","CLOSE-EARLY","MB-RISK-AUTH","10:01"),"cannot default before cure deadline"
i=mb~defaultMarginCall("CALL-CO-1","CLOSE-CO-1","MB-RISK-AUTH","10:03")
call assertEq "DEFAULTED",c~state,"call defaulted after deadline"

mb~recordMarketEvidence(.MBMarketEvidence~new("MKT-CO-A","EXCHANGE-A","IDX-A","10:04","GBP",10100,"CURRENT"))
mb~recordMarketEvidence(.MBMarketEvidence~new("MKT-CO-B","EXCHANGE-B","IDX-B","10:04","GBP",9800,"CURRENT"))
partial=.directory~new
partial["TR-CO-1"]=.MBCloseOutTradeResult~new("RES-A","TR-CO-1","MKT-CO-A",400000,500000,"MB-CLOSEOUT-AUTH")
call expectSyntax mb,"EXECUTECLOSEOUT",.array~of("CLOSE-CO-1","EXEC-PARTIAL",partial,"10:05","MB-CLOSEOUT-AUTH"),"whole book required for close-out"
call assertEq 2,p~openTradeCount,"failed close-out leaves book untouched"

results=.directory~new
results["TR-CO-1"]=.MBCloseOutTradeResult~new("RES-A2","TR-CO-1","MKT-CO-A",400000,500000,"MB-CLOSEOUT-AUTH")
results["TR-CO-2"]=.MBCloseOutTradeResult~new("RES-B2","TR-CO-2","MKT-CO-B",-150000,-200000,"MB-CLOSEOUT-AUTH")
x=mb~executeCloseOut("CLOSE-CO-1","EXEC-CO-1",results,"10:05","MB-CLOSEOUT-AUTH")
call assertEq "COMPLETE",x~state,"close-out execution complete"
call assertEq 2,x~tradeCount,"both option contracts legally terminated"
call assertEq 300000,x~signedNetSettlement,"trade obligations net contractually"
call assertEq 0,p~openTradeCount,"portfolio positions closed"
call assertEq "EXECUTED",i~state,"instruction executed"

o=mb~createCloseOutSettlementObligation("OBL-CO-1","EXEC-CO-1")
call assertEq "CLIENT-CO",o~debtor,"positive net means client owes Merchant Bank"
call assertEq "FEDERATIONBANK_MERCHANT_BANK",o~creditor,"Merchant Bank is creditor"
call assertEq 300000,o~amount,"net contractual obligation amount"
call assertEq "UNSETTLED",o~status,"obligation awaits arm's-length settlement"
call expectNoLedger mb,"close-out still has no Retail Ledger authority"

say "PASS test_closeout_execution_netting"
exit 0
::routine assertEq
  use strict arg expected,actual,label
  if expected<>actual then raise syntax 88.900 array("ASSERT_EQ",label,"expected",expected,"actual",actual)
::routine expectSyntax
  use strict arg target,method,args,label
  caught=.false
  signal on syntax name gotSyntax
  target~sendWith(method,args)
  signal off syntax
  if \caught then raise syntax 88.900 array("ASSERT_EXPECTED_SYNTAX",label)
  return
gotSyntax:
  caught=.true
  signal off syntax
  return
::routine expectNoLedger
  use strict arg target,label
  caught=.false
  signal on syntax name gotNoMethod
  target~postLedger("ANY")
  signal off syntax
  if \caught then raise syntax 88.900 array("ASSERT_EXPECTED_NO_METHOD",label)
  return
gotNoMethod:
  caught=.true
  signal off syntax
  return
::requires "FederationBankMerchantBank.cls"
