mb=.FederationBankMerchantBank~new
call seed mb
base=mb~assessCFDHedgeBook("BOOK-D-BASE","T0","09:04")
steps=.array~new
steps~append(.MBHedgeRemediationPlanStep~new("S1",1,"RESTORE_FUNGIBILITY","H1",0,"","restore transferability"))
plan=.MBHedgeRemediationPlan~new("PLAN-D","REM1","T0","BOOK-D-BASE","MAKER","POL1","09:05",steps)
mb~proposeHedgeRemediationPlan(plan)
mb~approveHedgeRemediationPlan(.MBHedgeRemediationPlanApproval~new("APR-D","PLAN-D","CHECKER","AUTH-CHECKER","POL1","09:06"))
d=.MBHedgeRemediationPlanStepDispatchEvidence~new("DSP-D1","PLAN-D","S1",1,"MERCHANT_EXECUTION_ROUTER","ORDER-D1","AUTH-ROUTER","09:07","POL1","order accepted")
mb~recordHedgeRemediationPlanStepDispatchEvidence(d)

-- The observed external action is real enough to reference the affected hedge, but the evidence does not prove it came from DSP-D1.
e=.MBHedgeRemediationPlanStepExecutionEvidence~new("EX-D1","PLAN-D","S1",1,"COMPLETED","MERCHANT_CUSTODY","ACTION-D1","AUTH-CUSTODY","H1",0,"09:10","POL1")
mb~recordHedgeRemediationPlanStepExecutionEvidence(e)
a=mb~assessCFDHedgeBookAsAt("BOOK-D-CHK","T0","09:10")
c=mb~assessHedgeRemediationPlanExecutionCheckpoint("CHK-D1","PLAN-D","EX-D1","BOOK-D-CHK","09:10:31")
call assertEq "EXECUTION_DIVERGENCE",c~resultState,"correct-looking fill is not enough when a dispatch exists"
call assertEq "DISPATCH_BINDING_DIVERGENCE",c~divergenceReason,"outcome must bind to exact observed dispatch evidence"
call assertEq 1,c~dispatchBindingDeviationCount,"missing causal binding is machine-readable"
aFinal=mb~assessCFDHedgeBook("BOOK-D-ACT","T0","09:11")
v=mb~verifyHedgeRemediationPlanExecution("VER-D","PLAN-D","BOOK-D-ACT","09:11")
call assertEq "EXECUTION_DIVERGENCE",v~resultState,"final book cannot substitute for dispatch attribution"
call assertEq "DISPATCH_BINDING_DIVERGENCE",v~divergenceReason,"final verification retains dispatch mismatch"
call assertEq "DEVIATED",plan~state,"unbound outcome cannot verify approved plan"
call assertEq "OPEN",mb~hedgeRemediation("REM1")~state,"unbound execution cannot cure remediation"
say "PASS test_remediation_execution_dispatch_binding"
exit 0

::routine seed
  use strict arg mb
  mb~createPortfolio("PC","CLIENT","GBP"); mb~createPortfolio("PH1","MM1","GBP"); mb~createPortfolio("PU","MM1","GBP")
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
