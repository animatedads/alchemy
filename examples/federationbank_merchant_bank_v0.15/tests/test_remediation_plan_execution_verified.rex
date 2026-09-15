mb=.FederationBankMerchantBank~new
call seed mb
baseline=mb~assessCFDHedgeBook("BOOK-PLAN-BASE","T0","09:04")
steps=.array~new
steps~append(.MBHedgeRemediationPlanStep~new("S1",1,"NEUTRALISE_EXISTING_HEDGE","H1",100,"","neutralise impaired short"))
steps~append(.MBHedgeRemediationPlanStep~new("S2",2,"ADD_REPLACEMENT_HEDGE","",-100,"RES-PLAN","replacement short"))
plan=.MBHedgeRemediationPlan~new("PLAN-EXEC","REM1","T0","BOOK-PLAN-BASE","MAKER","POL1","09:05",steps)
mb~proposeHedgeRemediationPlan(plan)
mb~approveHedgeRemediationPlan(.MBHedgeRemediationPlanApproval~new("APR-EXEC","PLAN-EXEC","CHECKER","AUTH-CHECKER","POL1","09:06"))

-- Actual Merchant Trading authority neutralises the impaired short.
unwind=.MBDerivativeTrade~new("T1R","PU","MM1","CFD","LONG","GBP",100,0,0,"",1,"X","","EQ-X","09:10","MM1","INTERNAL_HEDGE")
mb~bookCFDOffset("IU","HU","T1",unwind,"","TRADING-AUTH","09:10")
-- Actual Merchant Trading authority then adds the replacement hedge using the planned instrument evidence.
replacement=.MBDerivativeTrade~new("T2","PH2","MM2","CFD","SHORT","GBP",100,0,0,"",1,"X","CFD-PLAN","EQ-X","09:11","MM2","EXTERNAL_HEDGE")
mb~bookCFDOffset("I2","H2","T0",replacement,"","TRADING-AUTH","09:11")

mb~recordHedgeRemediationPlanStepExecutionEvidence(.MBHedgeRemediationPlanStepExecutionEvidence~new("EX1","PLAN-EXEC","S1",1,"COMPLETED","MERCHANT_TRADING","FILL-U","AUTH-U","HU",100,"09:10","POL1"))
mb~recordHedgeRemediationPlanStepExecutionEvidence(.MBHedgeRemediationPlanStepExecutionEvidence~new("EX2","PLAN-EXEC","S2",2,"COMPLETED","MERCHANT_TRADING","FILL-R","AUTH-R","H2",-100,"09:11","POL1"))
call assertEq "EVIDENCE_COMPLETE",plan~state,"all attributable step outcomes complete plan evidence"
actual=mb~assessCFDHedgeBook("BOOK-PLAN-ACTUAL","T0","09:12")
verification=mb~verifyHedgeRemediationPlanExecution("VER-EXEC","PLAN-EXEC","BOOK-PLAN-ACTUAL","09:13")
call assertEq "MATCHED_PROJECTED_BOOK",verification~resultState,"actual book matches approved projection"
call assertEq 0,verification~actualNetBaseExposure,"actual whole book net"
call assertEq 0,verification~projectionDeviation,"no projection deviation"
call assertEq 0,verification~stepDeltaDeviationCount,"all actual step deltas match plan"
call assertEq 0,verification~objectSemanticDeviationCount,"actual objects have planned semantics"
call assertEq "VERIFIED",plan~state,"plan records verified execution rather than assuming it"
call assertEq "OPEN",mb~hedgeRemediation("REM1")~state,"verified execution does not itself cure impaired contract"
say "PASS test_remediation_plan_execution_verified"
exit 0

::routine seed
  use strict arg mb
  mb~createPortfolio("PC","CLIENT","GBP"); mb~createPortfolio("PH1","MM1","GBP"); mb~createPortfolio("PU","MM1","GBP"); mb~createPortfolio("PH2","MM2","GBP")
  mb~bookTrade(.MBDerivativeTrade~new("T0","PC","CLIENT","CFD","LONG","GBP",100,0,0,"",1,"X","","EQ-X","09:00"))
  old=.MBDerivativeTrade~new("T1","PH1","MM1","CFD","SHORT","GBP",100,0,0,"",1,"X","","EQ-X","09:01","MM1","EXTERNAL_HEDGE")
  mb~bookCFDOffset("I1","H1","T0",old,"","AUTH","09:01")
  mb~recordHedgeEquivalenceEvidence(.MBHedgeEquivalenceEvidence~new("E1","H1",1,"","09:02","GB","AUTH","BLOCK","LEGAL1","","",.true,.false,.false,.false,.false,"BLOCKED"))
  mb~reassessHedgeRiskFromLatestKnown("R1","H1","E1","09:02")
  mb~openHedgeRemediation("REM1","H1","R1","POL1","09:03")
  doc=.MBReferenceDocumentEvidence~new("DOC-PLAN","REF-AUTH","urn:test:plan-exec","Plan execution fixture","1","09:00","","SOURCE_OBSERVED")
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
