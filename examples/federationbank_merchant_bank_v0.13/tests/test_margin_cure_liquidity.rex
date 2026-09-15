mb=.FederationBankMerchantBank~new
mb~createPortfolio("PF-LIQ","CLIENT-LIQ","GBP")
v=.MBValuationSnapshot~new("VAL-LIQ-1","PF-LIQ","2026-08-26T09:00:00Z","GBP",500000,0,3000000,"MKT-LIQ-1")
mb~recordValuation(v)
policy=.MBRiskPolicy~new("POL-LIQ",6,1200000,3600)
a1=mb~assessMargin("ASS-LIQ-1","PF-LIQ",v,policy,700000,"2026-08-26T09:00:01Z")
call assertEq "MARGIN_DEFICIT",a1~state,"liquidity deficit opens"
call assertEq 500000,a1~deficit,"liquidity deficit amount"
c=mb~issueMarginCall("CALL-LIQ-1","ASS-LIQ-1","2026-08-26T09:01:00Z","2026-08-26T10:01:00Z")

le=.MBLiquidityEvidence~new("LIQ-EV-2","PF-LIQ","GBP",1300000,"MB-TREASURY-AUTH","TREASURY-CASH-44","2026-08-26T09:20:00Z")
mb~recordLiquidityEvidence(le)
a2=mb~assessMarginWithLiquidityEvidence("ASS-LIQ-2","PF-LIQ",v,policy,"LIQ-EV-2","2026-08-26T09:20:01Z")
call assertEq "COMPLIANT",a2~state,"new Treasury liquidity cures facts"
r=mb~cureMarginCall("CALL-LIQ-1","CURE-LIQ-1","LIQUIDITY","LIQ-EV-2","MB-TREASURY-AUTH","ASS-LIQ-2","2026-08-26T09:20:02Z")
call assertEq "CURED",c~state,"call cured"
call assertEq "LIQUIDITY",r~mechanism,"cure mechanism retained"
call assertEq "LIQ-EV-2",r~evidenceRef,"liquidity evidence retained"
call expectSyntax mb,"DEFAULTMARGINCALL",.array~of("CALL-LIQ-1","CLOSE-NO","MB-RISK-AUTH","2026-08-26T10:02:00Z"),"cured call cannot default"

say "PASS test_margin_cure_liquidity"
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
::requires "FederationBankMerchantBank.cls"
