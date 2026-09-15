mb=.FederationBankMerchantBank~new
mb~registerRelationship(.MBMerchantRelationship~new("REL-SUM","CLIENT-SUM","RETAIL-LINK-SUM","LINK-AUTH","08:00"))
p=mb~createPortfolio("PF-SUM","CLIENT-SUM","GBP","REL-SUM")
hp=mb~createPortfolio("PF-SUM-H","MM-SUM","GBP")
mb~bookTrade(.MBDerivativeTrade~new("TR-SUM","PF-SUM","CLIENT-SUM","CFD","LONG","GBP",1000000,0,0,"",1,"IDX-SUM","","IDX-SUM","08:01"))
off=.MBDerivativeTrade~new("TR-SUM-H","PF-SUM-H","MM-SUM","CFD","SHORT","GBP",1000000,0,0,"",1,"IDX-SUM","","IDX-SUM","08:02","MM-SUM","EXTERNAL_HEDGE")
mb~bookCFDOffset("INT-SUM","H-SUM","TR-SUM",off,"","MB-TRADE-AUTH","08:02")
v=.MBValuationSnapshot~new("VAL-SUM","PF-SUM","08:03","GBP",0,0,1000000,"MKTSET-SUM",0,"CURRENT",1,0)
mb~recordValuation(v)
a=mb~assessMargin("ASS-SUM","PF-SUM",v,.MBRiskPolicy~new("POL-SUM",6,0,3600),0,"08:03")
s=mb~positionSummaryForRelationship("REL-SUM")
call assertEq 0,s~positionCount,"client position summary excludes economically closed CFD"
call assertEq 1,p~monitoredContractCount,"original CFD still monitored as live contract"
call assertEq 1,hp~monitoredContractCount,"reversing hedge also monitored as live contract"
say "PASS test_position_summary_client_view_count"
exit 0
::routine assertEq
  use strict arg expected,actual,label
  if expected<>actual then raise syntax 88.900 array("ASSERT_EQ",label,"expected",expected,"actual",actual)
::requires "FederationBankMerchantBank.cls"
