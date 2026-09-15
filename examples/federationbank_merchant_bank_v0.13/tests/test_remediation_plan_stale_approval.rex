mb=.FederationBankMerchantBank~new
call seed mb
mb~assessCFDHedgeBook("BOOK-P3","T0","09:04")
steps=.array~new
steps~append(.MBHedgeRemediationPlanStep~new("S1",1,"REHOME_CUSTODY","H1",0,"","move custody route"))
plan=.MBHedgeRemediationPlan~new("PLAN-STALE","REM1","T0","BOOK-P3","MAKER-A","POL1","09:05",steps)
mb~proposeHedgeRemediationPlan(plan)
-- Any fresh whole-book observation invalidates the approval baseline.
mb~assessCFDHedgeBook("BOOK-P3-NEW","T0","09:06")
apr=.MBHedgeRemediationPlanApproval~new("APR-STALE","PLAN-STALE","CHECKER-B","AUTH-CHECKER","POL1","09:07")
call expectApproveFail mb,apr,"stale plan may not be approved after whole-book state advances"
call assertEq "PROPOSED",plan~state,"stale approval does not mutate plan"
say "PASS test_remediation_plan_stale_approval"
exit 0
::routine seed
  use strict arg mb
  mb~createPortfolio("PC","CLIENT","GBP"); mb~createPortfolio("PH1","MM1","GBP")
  mb~bookTrade(.MBDerivativeTrade~new("T0","PC","CLIENT","CFD","LONG","GBP",100,0,0,"",1,"X","","EQ-X","09:00"))
  old=.MBDerivativeTrade~new("T1","PH1","MM1","CFD","SHORT","GBP",100,0,0,"",1,"X","","EQ-X","09:01","MM1","EXTERNAL_HEDGE")
  mb~bookCFDOffset("I1","H1","T0",old,"","AUTH","09:01")
  mb~recordHedgeEquivalenceEvidence(.MBHedgeEquivalenceEvidence~new("E1","H1",1,"","09:02","GB","AUTH","BLOCK","LEGAL1","","",.true,.false,.false,.false,.false,"BLOCKED"))
  mb~reassessHedgeRiskFromLatestKnown("R1","H1","E1","09:02")
  mb~openHedgeRemediation("REM1","H1","R1","POL1","09:03")
  return
::routine expectApproveFail
  use strict arg mb,approval,label
  caught=.false
  signal on syntax name got
  mb~approveHedgeRemediationPlan(approval)
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
