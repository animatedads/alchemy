mb=.FederationBankMerchantBank~new
call seed mb
base=mb~assessCFDHedgeBook("BOOK-DISP-BASE","T0","09:04")
steps=.array~new
steps~append(.MBHedgeRemediationPlanStep~new("S1",1,"RESTORE_FUNGIBILITY","H1",0,"","restore transferability evidence"))
plan=.MBHedgeRemediationPlan~new("PLAN-DISP","REM1","T0","BOOK-DISP-BASE","MAKER","POL1","09:05",steps)
mb~proposeHedgeRemediationPlan(plan)
mb~approveHedgeRemediationPlan(.MBHedgeRemediationPlanApproval~new("APR-DISP","PLAN-DISP","CHECKER","AUTH-CHECKER","POL1","09:06"))

d=.MBHedgeRemediationPlanStepDispatchEvidence~new("DSP1","PLAN-DISP","S1",1,"MERCHANT_EXECUTION_ROUTER","ORDER-123","AUTH-DISPATCH","09:07","POL1","accepted by execution channel")
mb~recordHedgeRemediationPlanStepDispatchEvidence(d)
call assertEq "EXECUTING",plan~state,"dispatch observation starts execution lifecycle but proves no fill"
call assertEq "ORDER-123",mb~hedgeRemediationPlanStepDispatchEvidence("DSP1")~sourceRef,"dispatch evidence is attributable"
call assertEq 1,mb~hedgeRemediationPlanDispatchEvidenceFor("PLAN-DISP")~items,"dispatch is separately queryable"
call assertEq 0,mb~hedgeRemediationPlanExecutionEvidenceFor("PLAN-DISP")~items,"dispatch is not fabricated into execution result"
call assertEq "OPEN",mb~hedgeRemediation("REM1")~state,"dispatch alone cannot cure risk"
say "PASS test_remediation_plan_dispatch_evidence"
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
::routine assertEq
  use strict arg expected,actual,label
  if expected<>actual then raise syntax 88.900 array("ASSERT_EQ",label,"expected",expected,"actual",actual)
::requires "FederationBankMerchantBank.cls"
