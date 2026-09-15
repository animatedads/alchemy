mb=.FederationBankMerchantBank~new
mb~createPortfolio("A","C","GBP"); mb~createPortfolio("B","M","GBP")
mb~bookTrade(.MBDerivativeTrade~new("T1","A","C","CFD","LONG","GBP",100,0,0,"",1,"X","","EQ-X","09:00"))
mb~bookCFDOffset("I1","H1","T1",.MBDerivativeTrade~new("T2","B","M","CFD","SHORT","GBP",100,0,0,"",1,"X","","EQ-X","09:01","M","EXTERNAL_HEDGE"),"","AUTH","09:01")
mb~recordHedgeEquivalenceEvidence(.MBHedgeEquivalenceEvidence~new("E1","H1",1,"","09:02","GB","AUTH","BLOCK","LEGAL1","","",.true,.false,.false,.false,.false,"BLOCKED"))
risk=mb~reassessHedgeRiskFromLatestKnown("R1","H1","E1","09:02")
rem=mb~openHedgeRemediation("REM1","H1","R1","POL1","09:03")
act=.MBHedgeRemediationActionEvidence~new("A1","REM1","RISK_REDUCTION","MB-TRADE-AUTH","REDUCE-BOOK-1","09:05")
mb~recordHedgeRemediationAction(act)
call expectResolveFail mb,"REM1","A1","R1","09:06","risk reduction cannot erase impaired equivalence"
call assertEq "ACTION_RECORDED",rem~state,"risk reduction evidence remains auditable but unresolved"
call assertEq "HEDGE_IMPAIRED",mb~hedgeRelationship("H1")~economicState,"impaired hedge remains monitored"
say "PASS test_hedge_remediation_risk_reduction_not_enough"
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
