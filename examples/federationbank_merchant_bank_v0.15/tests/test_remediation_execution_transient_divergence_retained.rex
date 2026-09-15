mb=.FederationBankMerchantBank~new
call seed mb
base=mb~assessCFDHedgeBook("BOOK-T-BASE","T0","09:04")
steps=.array~new
steps~append(.MBHedgeRemediationPlanStep~new("S1",1,"NEUTRALISE_EXISTING_HEDGE","H1",100,"","neutralise impaired short"))
steps~append(.MBHedgeRemediationPlanStep~new("S2",2,"ADD_REPLACEMENT_HEDGE","",-100,"RES-PLAN","replacement short"))
plan=.MBHedgeRemediationPlan~new("PLAN-T","REM1","T0","BOOK-T-BASE","MAKER","POL1","09:05",steps)
mb~proposeHedgeRemediationPlan(plan)
mb~approveHedgeRemediationPlan(.MBHedgeRemediationPlanApproval~new("APR-T","PLAN-T","CHECKER","AUTH-CHECKER","POL1","09:06"))
call assertEq 100,plan~peakAbsBaseExposure,"approved ordered plan explicitly bounds transient exposure"

-- Approved S1 really executes +100.
u=.MBDerivativeTrade~new("T-U","PU","MM1","CFD","LONG","GBP",100,0,0,"",1,"X","","EQ-X","09:10","MM1","INTERNAL_HEDGE")
mb~bookCFDOffset("I-U","H-U","T1",u,"","TRADING-AUTH","09:10")
-- An unrelated same-book long is also present at the checkpoint. It is not part of the approved plan.
rogueL=.MBDerivativeTrade~new("T-RL","PRL","MM3","CFD","LONG","GBP",100,0,0,"",1,"X","","EQ-X","09:10:10","MM3","INTERNAL_HEDGE")
mb~bookCFDOffset("I-RL","H-RL","T1",rogueL,"","OTHER-TRADING-AUTH","09:10:10")
e1=.MBHedgeRemediationPlanStepExecutionEvidence~new("EX-T1","PLAN-T","S1",1,"COMPLETED","MERCHANT_TRADING","FILL-T1","AUTH-T1","H-U",100,"09:10:20","POL1")
mb~recordHedgeRemediationPlanStepExecutionEvidence(e1)
a1=mb~assessCFDHedgeBookAsAt("BOOK-T-1","T0","09:10:20")
c1=mb~assessHedgeRemediationPlanExecutionCheckpoint("CHK-T1","PLAN-T","EX-T1","BOOK-T-1","09:10:31")
call assertEq 200,a1~netBaseExposure,"actual transient book exceeds approved +100 peak"
call assertEq "EXECUTION_DIVERGENCE",c1~resultState,"transient whole-book breach is detected immediately"
call assertEq "TRANSIENT_EXPOSURE_BREACH",c1~divergenceReason,"checkpoint names plan-envelope breach"
call assertEq 1,c1~transientExposureBreach,"peak breach is machine-readable"

-- Later unrelated action offsets the rogue transient exposure, and planned S2 executes correctly.
rogueS=.MBDerivativeTrade~new("T-RS","PRS","MM4","CFD","SHORT","GBP",100,0,0,"",1,"X","","EQ-X","09:11","MM4","EXTERNAL_HEDGE")
mb~bookCFDOffset("I-RS","H-RS","T0",rogueS,"","OTHER-TRADING-AUTH","09:11")
rep=.MBDerivativeTrade~new("T-R","PR","MM2","CFD","SHORT","GBP",100,0,0,"",1,"X","CFD-PLAN","EQ-X","09:12","MM2","EXTERNAL_HEDGE")
mb~bookCFDOffset("I-R","H-R","T0",rep,"","TRADING-AUTH","09:12")
e2=.MBHedgeRemediationPlanStepExecutionEvidence~new("EX-T2","PLAN-T","S2",2,"COMPLETED","MERCHANT_TRADING","FILL-T2","AUTH-T2","H-R",-100,"09:12","POL1")
mb~recordHedgeRemediationPlanStepExecutionEvidence(e2)
a2=mb~assessCFDHedgeBookAsAt("BOOK-T-2-CHK","T0","09:12")
c2=mb~assessHedgeRemediationPlanExecutionCheckpoint("CHK-T2","PLAN-T","EX-T2","BOOK-T-2-CHK","09:12:31")
call assertEq 0,a2~netBaseExposure,"later actual book can return to the approved final net exposure"
call assertEq "MATCHED_APPROVED_CHECKPOINT",c2~resultState,"current checkpoint can be good after the transient has passed"
aFinal=mb~assessCFDHedgeBook("BOOK-T-2","T0","09:13")
v=mb~verifyHedgeRemediationPlanExecution("VER-T","PLAN-T","BOOK-T-2","09:13")
call assertEq "EXECUTION_DIVERGENCE",v~resultState,"good final net cannot erase historical execution divergence"
call assertEq "PRIOR_EXECUTION_CHECKPOINT_DIVERGENCE",v~divergenceReason,"historical transient breach remains part of verification"
call assertEq 1,v~checkpointDivergenceCount,"final verification retains divergent checkpoint count"
call assertEq "DEVIATED",plan~state,"plan remains deviated despite repaired final book"
call assertEq "OPEN",mb~hedgeRemediation("REM1")~state,"transient breach cannot be laundered into remediation success"
say "PASS test_remediation_execution_transient_divergence_retained"
exit 0

::routine seed
  use strict arg mb
  mb~createPortfolio("PC","CLIENT","GBP"); mb~createPortfolio("PH1","MM1","GBP"); mb~createPortfolio("PU","MM1","GBP"); mb~createPortfolio("PR","MM2","GBP"); mb~createPortfolio("PRL","MM3","GBP"); mb~createPortfolio("PRS","MM4","GBP")
  mb~bookTrade(.MBDerivativeTrade~new("T0","PC","CLIENT","CFD","LONG","GBP",100,0,0,"",1,"X","","EQ-X","09:00"))
  old=.MBDerivativeTrade~new("T1","PH1","MM1","CFD","SHORT","GBP",100,0,0,"",1,"X","","EQ-X","09:01","MM1","EXTERNAL_HEDGE")
  mb~bookCFDOffset("I1","H1","T0",old,"","AUTH","09:01")
  mb~recordHedgeEquivalenceEvidence(.MBHedgeEquivalenceEvidence~new("E1","H1",1,"","09:02","GB","AUTH","BLOCK","LEGAL1","","",.true,.false,.false,.false,.false,"BLOCKED"))
  mb~reassessHedgeRiskFromLatestKnown("R1","H1","E1","09:02")
  mb~openHedgeRemediation("REM1","H1","R1","POL1","09:03")
  doc=.MBReferenceDocumentEvidence~new("DOC-PLAN","REF-AUTH","urn:test:transient-checkpoint","Transient execution fixture","1","09:00","","SOURCE_OBSERVED")
  mb~recordReferenceDocumentEvidence(doc)
  res=.MBInstrumentResolutionEvidence~new("RES-PLAN","DOC-PLAN","EQ-X","ISIN-X","XLON","GBP","LINE-X","CRSTGB22","ORDINARY","GBP","GBP","line=X","09:00")
  mb~recordInstrumentResolutionEvidence(res)
  ident=mb~instrumentIdentityFromEvidence("RES-PLAN","GBP",1,"ISSUER-X")
  permit=.MBDecisionEvidence~new("PERMITTED","PERMITTED","LEGAL-P","POL-P")
  mb~registerProduct(.MBDerivativeProductDefinition~new("CFD-PLAN","1","CFD","EQ-X","GBP","CASH",permit,"","",1,ident))
  return
::routine assertEq
  use strict arg expected,actual,label
  if expected<>actual then raise syntax 88.900 array("ASSERT_EQ",label,"expected",expected,"actual",actual)
::requires "FederationBankMerchantBank.cls"
