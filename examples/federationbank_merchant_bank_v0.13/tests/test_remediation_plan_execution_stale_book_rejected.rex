mb=.FederationBankMerchantBank~new
call seed mb
base=mb~assessCFDHedgeBook("BOOK-S-BASE","T0","09:04")
steps=.array~new; steps~append(.MBHedgeRemediationPlanStep~new("S1",1,"NEUTRALISE_EXISTING_HEDGE","H1",100,"","neutralise old hedge"))
plan=.MBHedgeRemediationPlan~new("PLAN-S","REM1","T0","BOOK-S-BASE","MAKER","POL1","09:05",steps)
-- directional residual planning requires reduction, so first create residual by adding another short.
-- Instead, this test uses a net-zero plan with a non-directional restore step to exercise stale proof.
steps=.array~new; steps~append(.MBHedgeRemediationPlanStep~new("S1",1,"RESTORE_FUNGIBILITY","H1",0,"","restore transferability"))
plan=.MBHedgeRemediationPlan~new("PLAN-S","REM1","T0","BOOK-S-BASE","MAKER","POL1","09:05",steps)
mb~proposeHedgeRemediationPlan(plan)
mb~approveHedgeRemediationPlan(.MBHedgeRemediationPlanApproval~new("APR-S","PLAN-S","CHECKER","AUTH-C","POL1","09:06"))
mb~recordHedgeRemediationPlanStepExecutionEvidence(.MBHedgeRemediationPlanStepExecutionEvidence~new("EX-S","PLAN-S","S1",1,"COMPLETED","MARKET_STRUCTURE_AUTHORITY","RESTORE-1","AUTH-R","RESTORE-OBJ",0,"09:07","POL1"))
oldProof=mb~assessCFDHedgeBook("BOOK-S-OLD","T0","09:08")
newProof=mb~assessCFDHedgeBook("BOOK-S-NEW","T0","09:09")
call expectVerifyFail mb,"VER-S","PLAN-S","BOOK-S-OLD","09:10","stale whole-book proof rejected"
call assertEq "EVIDENCE_COMPLETE",plan~state,"rejected stale proof does not mutate plan"
say "PASS test_remediation_plan_execution_stale_book_rejected"
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
::routine expectVerifyFail
  use strict arg mb,vid,pid,bid,at,label
  caught=.false
  signal on syntax name got
  mb~verifyHedgeRemediationPlanExecution(vid,pid,bid,at)
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
