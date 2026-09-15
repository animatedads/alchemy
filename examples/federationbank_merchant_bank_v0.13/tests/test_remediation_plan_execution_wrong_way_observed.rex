mb=.FederationBankMerchantBank~new
call seed mb
baseline=mb~assessCFDHedgeBook("BOOK-W-BASE","T0","09:04")
steps=.array~new
steps~append(.MBHedgeRemediationPlanStep~new("S1",1,"NEUTRALISE_EXISTING_HEDGE","H1",100,"","neutralise impaired short"))
steps~append(.MBHedgeRemediationPlanStep~new("S2",2,"ADD_REPLACEMENT_HEDGE","",-100,"RES-PLAN","replacement short"))
plan=.MBHedgeRemediationPlan~new("PLAN-W","REM1","T0","BOOK-W-BASE","MAKER","POL1","09:05",steps)
mb~proposeHedgeRemediationPlan(plan)
mb~approveHedgeRemediationPlan(.MBHedgeRemediationPlanApproval~new("APR-W","PLAN-W","CHECKER","AUTH-CHECKER","POL1","09:06"))

-- Execution goes wrong: instead of reversing T1, another short is booked against the client root.
wrong=.MBDerivativeTrade~new("T-WRONG","PH2","MM2","CFD","SHORT","GBP",100,0,0,"",1,"X","CFD-PLAN","EQ-X","09:10","MM2","EXTERNAL_HEDGE")
mb~bookCFDOffset("I-WRONG","H-WRONG","T0",wrong,"","TRADING-AUTH","09:10")
-- The planned replacement short is then booked too. Each pair looks individually plausible; aggregate book is now doubled short.
replacement=.MBDerivativeTrade~new("T2","PH3","MM3","CFD","SHORT","GBP",100,0,0,"",1,"X","CFD-PLAN","EQ-X","09:11","MM3","EXTERNAL_HEDGE")
mb~bookCFDOffset("I2","H2","T0",replacement,"","TRADING-AUTH","09:11")

-- Record what actually happened. Evidence is not discarded merely because execution was wrong-way.
mb~recordHedgeRemediationPlanStepExecutionEvidence(.MBHedgeRemediationPlanStepExecutionEvidence~new("EX-W1","PLAN-W","S1",1,"COMPLETED","MERCHANT_TRADING","FILL-W","AUTH-W","H-WRONG",-100,"09:10","POL1","wrong-way fill observed"))
mb~recordHedgeRemediationPlanStepExecutionEvidence(.MBHedgeRemediationPlanStepExecutionEvidence~new("EX-W2","PLAN-W","S2",2,"COMPLETED","MERCHANT_TRADING","FILL-R","AUTH-R","H2",-100,"09:11","POL1"))
actual=mb~assessCFDHedgeBook("BOOK-W-ACTUAL","T0","09:12")
call assertEq -200,actual~netBaseExposure,"wrong neutralisation plus replacement doubles short aggregate exposure"
verification=mb~verifyHedgeRemediationPlanExecution("VER-W","PLAN-W","BOOK-W-ACTUAL","09:13")
call assertEq "STEP_OBJECT_DEVIATION",verification~resultState,"wrong-way actual object is retained and classified as execution deviation"
call assertEq 1,verification~objectSemanticDeviationCount,"neutralisation step actually targeted wrong contractual leg"
call assertEq 1,verification~stepDeltaDeviationCount,"neutralisation signed delta was opposite to approved plan"
call assertEq -200,verification~actualNetBaseExposure,"verification binds real aggregate book"
call assertEq "DEVIATED",plan~state,"plan cannot claim successful execution"
call assertEq "OPEN",mb~hedgeRemediation("REM1")~state,"wrong-way execution cannot cure remediation"
say "PASS test_remediation_plan_execution_wrong_way_observed"
exit 0

::routine seed
  use strict arg mb
  mb~createPortfolio("PC","CLIENT","GBP"); mb~createPortfolio("PH1","MM1","GBP"); mb~createPortfolio("PH2","MM2","GBP"); mb~createPortfolio("PH3","MM3","GBP")
  mb~bookTrade(.MBDerivativeTrade~new("T0","PC","CLIENT","CFD","LONG","GBP",100,0,0,"",1,"X","","EQ-X","09:00"))
  old=.MBDerivativeTrade~new("T1","PH1","MM1","CFD","SHORT","GBP",100,0,0,"",1,"X","","EQ-X","09:01","MM1","EXTERNAL_HEDGE")
  mb~bookCFDOffset("I1","H1","T0",old,"","AUTH","09:01")
  mb~recordHedgeEquivalenceEvidence(.MBHedgeEquivalenceEvidence~new("E1","H1",1,"","09:02","GB","AUTH","BLOCK","LEGAL1","","",.true,.false,.false,.false,.false,"BLOCKED"))
  mb~reassessHedgeRiskFromLatestKnown("R1","H1","E1","09:02")
  mb~openHedgeRemediation("REM1","H1","R1","POL1","09:03")
  doc=.MBReferenceDocumentEvidence~new("DOC-PLAN","REF-AUTH","urn:test:wrong-exec","Wrong execution fixture","1","09:00","","SOURCE_OBSERVED")
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
