mb=.FederationBankMerchantBank~new
call seed mb
baseline=mb~assessCFDHedgeBook("BOOK-P-BASE","T0","09:04")
steps=.array~new
steps~append(.MBHedgeRemediationPlanStep~new("S1",1,"NEUTRALISE_EXISTING_HEDGE","H1",100,"","neutralise impaired short"))
steps~append(.MBHedgeRemediationPlanStep~new("S2",2,"ADD_REPLACEMENT_HEDGE","",-100,"RES-PLAN","replacement short"))
plan=.MBHedgeRemediationPlan~new("PLAN-P","REM1","T0","BOOK-P-BASE","MAKER","POL1","09:05",steps)
mb~proposeHedgeRemediationPlan(plan)
mb~approveHedgeRemediationPlan(.MBHedgeRemediationPlanApproval~new("APR-P","PLAN-P","CHECKER","AUTH-CHECKER","POL1","09:06"))

-- First fill is genuinely partial: +40 of the approved +100 neutralisation.
u1=.MBDerivativeTrade~new("T-U1","PU1","MM1","CFD","LONG","GBP",40,0,0,"",1,"X","","EQ-X","09:10","MM1","INTERNAL_HEDGE")
mb~bookCFDOffset("I-U1","H-U1","T1",u1,"","TRADING-AUTH","09:10")
e1=.MBHedgeRemediationPlanStepExecutionEvidence~new("EX-P1","PLAN-P","S1",1,"PARTIAL","MERCHANT_TRADING","FILL-P1","AUTH-P1","H-U1",40,"09:10","POL1")
mb~recordHedgeRemediationPlanStepExecutionEvidence(e1)
call assertEq "EXECUTING",plan~state,"partial observation is not terminal execution evidence"
a1=mb~assessCFDHedgeBookAsAt("BOOK-P-1","T0","09:10")
c1=mb~assessHedgeRemediationPlanExecutionCheckpoint("CHK-P1","PLAN-P","EX-P1","BOOK-P-1","09:10:31")
call assertEq 40,a1~netBaseExposure,"partial fill changes the real whole book immediately"
call assertEq "PARTIAL_WITHIN_APPROVED_ENVELOPE",c1~resultState,"correct partial fill remains inside approved transient envelope"
call assertEq 40,c1~stepCumulativeObservedBaseExposureDelta,"checkpoint accumulates observed fill amount"

-- The same approved step later receives the remaining +60 and becomes terminal.
u2=.MBDerivativeTrade~new("T-U2","PU2","MM1","CFD","LONG","GBP",60,0,0,"",1,"X","","EQ-X","09:11","MM1","INTERNAL_HEDGE")
mb~bookCFDOffset("I-U2","H-U2","T1",u2,"","TRADING-AUTH","09:11")
e2=.MBHedgeRemediationPlanStepExecutionEvidence~new("EX-P2","PLAN-P","S1",2,"COMPLETED","MERCHANT_TRADING","FILL-P2","AUTH-P2","H-U2",60,"09:11","POL1")
mb~recordHedgeRemediationPlanStepExecutionEvidence(e2)
a2=mb~assessCFDHedgeBookAsAt("BOOK-P-2","T0","09:11")
c2=mb~assessHedgeRemediationPlanExecutionCheckpoint("CHK-P2","PLAN-P","EX-P2","BOOK-P-2","09:11:31")
call assertEq 100,a2~netBaseExposure,"partial plus completion fills accumulate to approved step quantity"
call assertEq "MATCHED_APPROVED_CHECKPOINT",c2~resultState,"completed step reconciles to approved checkpoint"
call assertEq 100,c2~stepCumulativeObservedBaseExposureDelta,"step result is cumulative across multiple fill observations"
call assertEq 2,mb~hedgeRemediationPlanStepExecutionEvidenceFor("PLAN-P","S1")~items,"both fill observations remain immutable evidence"
call assertEq "EXECUTING",plan~state,"plan still waits for later approved step"

rep=.MBDerivativeTrade~new("T-R","PR","MM2","CFD","SHORT","GBP",100,0,0,"",1,"X","CFD-PLAN","EQ-X","09:12","MM2","EXTERNAL_HEDGE")
mb~bookCFDOffset("I-R","H-R","T0",rep,"","TRADING-AUTH","09:12")
e3=.MBHedgeRemediationPlanStepExecutionEvidence~new("EX-P3","PLAN-P","S2",3,"COMPLETED","MERCHANT_TRADING","FILL-P3","AUTH-P3","H-R",-100,"09:12","POL1")
mb~recordHedgeRemediationPlanStepExecutionEvidence(e3)
call assertEq "EVIDENCE_COMPLETE",plan~state,"all plan steps become terminal only after final outcome"
a3=mb~assessCFDHedgeBookAsAt("BOOK-P-3-CHK","T0","09:12")
c3=mb~assessHedgeRemediationPlanExecutionCheckpoint("CHK-P3","PLAN-P","EX-P3","BOOK-P-3-CHK","09:12:31")
call assertEq "MATCHED_APPROVED_CHECKPOINT",c3~resultState,"final execution checkpoint matches approved book"
aFinal=mb~assessCFDHedgeBook("BOOK-P-3","T0","09:13")
v=mb~verifyHedgeRemediationPlanExecution("VER-P","PLAN-P","BOOK-P-3","09:13")
call assertEq "MATCHED_PROJECTED_BOOK",v~resultState,"normal partial-fill progression can verify successfully"
call assertEq "VERIFIED",plan~state,"verified state follows independently proved actual final book"
call assertEq 3,mb~hedgeRemediationPlanExecutionEvidenceFor("PLAN-P")~items,"plan retains all partial/full evidence observations"
call assertEq "OPEN",mb~hedgeRemediation("REM1")~state,"execution verification still cannot cure contractual remediation"
say "PASS test_remediation_execution_partial_checkpoint"
exit 0

::routine seed
  use strict arg mb
  mb~createPortfolio("PC","CLIENT","GBP"); mb~createPortfolio("PH1","MM1","GBP"); mb~createPortfolio("PU1","MM1","GBP"); mb~createPortfolio("PU2","MM1","GBP"); mb~createPortfolio("PR","MM2","GBP")
  mb~bookTrade(.MBDerivativeTrade~new("T0","PC","CLIENT","CFD","LONG","GBP",100,0,0,"",1,"X","","EQ-X","09:00"))
  old=.MBDerivativeTrade~new("T1","PH1","MM1","CFD","SHORT","GBP",100,0,0,"",1,"X","","EQ-X","09:01","MM1","EXTERNAL_HEDGE")
  mb~bookCFDOffset("I1","H1","T0",old,"","AUTH","09:01")
  mb~recordHedgeEquivalenceEvidence(.MBHedgeEquivalenceEvidence~new("E1","H1",1,"","09:02","GB","AUTH","BLOCK","LEGAL1","","",.true,.false,.false,.false,.false,"BLOCKED"))
  mb~reassessHedgeRiskFromLatestKnown("R1","H1","E1","09:02")
  mb~openHedgeRemediation("REM1","H1","R1","POL1","09:03")
  doc=.MBReferenceDocumentEvidence~new("DOC-PLAN","REF-AUTH","urn:test:partial-checkpoint","Partial execution fixture","1","09:00","","SOURCE_OBSERVED")
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
