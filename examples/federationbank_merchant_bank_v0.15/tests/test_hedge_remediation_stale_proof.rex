mb=.FederationBankMerchantBank~new
mb~createPortfolio("A","C","GBP"); mb~createPortfolio("B","M","GBP")
mb~bookTrade(.MBDerivativeTrade~new("T1","A","C","CFD","LONG","GBP",100,0,0,"",1,"X","","EQ-X","09:00"))
h=mb~bookCFDOffset("I1","H1","T1",.MBDerivativeTrade~new("T2","B","M","CFD","SHORT","GBP",100,0,0,"",1,"X","","EQ-X","09:01","M","EXTERNAL_HEDGE"),"","AUTH","09:01")
mb~recordHedgeEquivalenceEvidence(.MBHedgeEquivalenceEvidence~new("E1","H1",1,"","09:02","GB","AUTH","BLOCK","LEGAL1","","",.true,.false,.false,.false,.false,"BLOCKED"))
mb~reassessHedgeRiskFromLatestKnown("R1","H1","E1","09:02")
rem=mb~openHedgeRemediation("REM1","H1","R1","POL1","09:03")
mb~recordHedgeEquivalenceEvidence(.MBHedgeEquivalenceEvidence~new("E2","H1",2,"E1","10:00","GB","AUTH","RELEASE","LEGAL2","","",.true,.true,.true,.true,.true,"RESTORED"))
old=mb~reassessHedgeRiskFromLatestKnown("R2","H1","E2","10:00")
latest=mb~reassessHedgeRiskFromLatestKnown("R3","H1","E2","10:01")
mb~recordHedgeRemediationAction(.MBHedgeRemediationActionEvidence~new("A1","REM1","REHOME_CUSTODY","RISK-AUTH","CUSTODY-REHOME","10:01"))
call expectResolveFail mb,"REM1","A1","R2","10:02","stale proof cannot resolve current remediation"
call assertEq "ACTION_RECORDED",rem~state,"failed stale proof leaves remediation open"
mb~resolveHedgeRemediation("REM1","A1","R3","10:03")
call assertEq "RESOLVED",rem~state,"latest assessment may resolve"
say "PASS test_hedge_remediation_stale_proof"
exit 0
::routine expectResolveFail
  use strict arg mb,rem,action,assessment,at,label
  caught=.false
  signal on syntax name got
  mb~resolveHedgeRemediation(rem,action,assessment,at)
  signal off syntax
  if \caught then raise syntax 88.900 array("ASSERT_EXPECTED_SYNTAX",label)
  return
got:
  signal off syntax
  caught=.true
  return
::routine assertEq
  use strict arg expected,actual,label
  if expected<>actual then raise syntax 88.900 array("ASSERT_EQ",label,"expected",expected,"actual",actual)
::requires "FederationBankMerchantBank.cls"
