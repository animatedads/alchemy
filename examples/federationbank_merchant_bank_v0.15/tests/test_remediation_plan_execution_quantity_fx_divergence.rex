call caseQuantity
call caseFx
say "PASS test_remediation_plan_execution_quantity_fx_divergence"
exit 0

::routine caseQuantity
  mb=.FederationBankMerchantBank~new
  call seed mb
  call buildPlan mb,"PLAN-Q","APR-Q",""
  unwind=.MBDerivativeTrade~new("T1R","PU","MM1","CFD","LONG","GBP",50,0,0,"",1,"X","","EQ-X","09:10","MM1","INTERNAL_HEDGE")
  mb~bookCFDOffset("IU","HU","T1",unwind,"","TRADING-AUTH","09:10")
  replacement=.MBDerivativeTrade~new("T2","PH2","MM2","CFD","SHORT","GBP",100,0,0,"",1,"X","CFD-PLAN","EQ-X","09:11","MM2","EXTERNAL_HEDGE")
  mb~bookCFDOffset("I2","H2","T0",replacement,"","TRADING-AUTH","09:11")
  mb~recordHedgeRemediationPlanStepExecutionEvidence(.MBHedgeRemediationPlanStepExecutionEvidence~new("EX-Q1","PLAN-Q","S1",1,"COMPLETED","MERCHANT_TRADING","FILL-Q1","AUTH-Q1","HU",50,"09:10","POL1"))
  mb~recordHedgeRemediationPlanStepExecutionEvidence(.MBHedgeRemediationPlanStepExecutionEvidence~new("EX-Q2","PLAN-Q","S2",2,"COMPLETED","MERCHANT_TRADING","FILL-Q2","AUTH-Q2","H2",-100,"09:11","POL1"))
  actual=mb~assessCFDHedgeBook("BOOK-Q-ACTUAL","T0","09:12")
  v=mb~verifyHedgeRemediationPlanExecution("VER-Q","PLAN-Q","BOOK-Q-ACTUAL","09:13")
  call assertEq -50,actual~netBaseExposure,"partial neutralisation leaves actual directional residual"
  call assertEq "EXECUTION_DIVERGENCE",v~resultState,"quantity mismatch is top-level divergence"
  call assertEq "UNEXPECTED_QUANTITY",v~divergenceReason,"same-direction magnitude mismatch is quantity divergence"
  call assertEq 1,v~quantityDeviationCount,"quantity deviation is counted"
  call assertEq 0,v~wrongWayStepCount,"smaller correct-direction fill is not wrong-way"
  call assertEq "OPEN",mb~hedgeRemediation("REM1")~state,"quantity divergence cannot cure remediation"
  return

::routine caseFx
  mb=.FederationBankMerchantBank~new
  call seed mb
  mb~recordFXEvidence(.MBFXEvidence~new("FX-EXPECTED","PLAN-FX","EUR","GBP",0.85,"09:04"))
  mb~recordFXEvidence(.MBFXEvidence~new("FX-ACTUAL","EXEC-FX","EUR","GBP",0.84,"09:09"))
  call buildPlan mb,"PLAN-FX","APR-FX","FX-EXPECTED"
  unwind=.MBDerivativeTrade~new("T1R","PU","MM1","CFD","LONG","GBP",100,0,0,"",1,"X","","EQ-X","09:10","MM1","INTERNAL_HEDGE")
  mb~bookCFDOffset("IU","HU","T1",unwind,"","TRADING-AUTH","09:10")
  replacement=.MBDerivativeTrade~new("T2","PH2","MM2","CFD","SHORT","GBP",100,0,0,"",1,"X","CFD-PLAN","EQ-X","09:11","MM2","EXTERNAL_HEDGE")
  mb~bookCFDOffset("I2","H2","T0",replacement,"","TRADING-AUTH","09:11")
  mb~recordHedgeRemediationPlanStepExecutionEvidence(.MBHedgeRemediationPlanStepExecutionEvidence~new("EX-F1","PLAN-FX","S1",1,"COMPLETED","MERCHANT_TRADING","FILL-F1","AUTH-F1","HU",100,"09:10","POL1","","FX-ACTUAL"))
  mb~recordHedgeRemediationPlanStepExecutionEvidence(.MBHedgeRemediationPlanStepExecutionEvidence~new("EX-F2","PLAN-FX","S2",2,"COMPLETED","MERCHANT_TRADING","FILL-F2","AUTH-F2","H2",-100,"09:11","POL1"))
  actual=mb~assessCFDHedgeBook("BOOK-FX-ACTUAL","T0","09:12")
  v=mb~verifyHedgeRemediationPlanExecution("VER-FX","PLAN-FX","BOOK-FX-ACTUAL","09:13")
  call assertEq 0,actual~netBaseExposure,"aggregate book can coincidentally match despite different FX evidence"
  call assertEq "EXECUTION_DIVERGENCE",v~resultState,"unexpected FX evidence prevents plan-match assumption"
  call assertEq "UNEXPECTED_FX_RESULT",v~divergenceReason,"FX divergence is independently classified"
  call assertEq 1,v~fxDeviationCount,"FX deviation is counted"
  call assertEq 0,v~quantityDeviationCount,"matching signed delta is not quantity divergence"
  call assertEq "OPEN",mb~hedgeRemediation("REM1")~state,"FX divergence cannot cure remediation"
  return

::routine buildPlan
  use strict arg mb,planId,approvalId,expectedFxRef
  baseline=mb~assessCFDHedgeBook("BOOK-PLAN-BASE","T0","09:04")
  steps=.array~new
  steps~append(.MBHedgeRemediationPlanStep~new("S1",1,"NEUTRALISE_EXISTING_HEDGE","H1",100,"","neutralise impaired short",expectedFxRef))
  steps~append(.MBHedgeRemediationPlanStep~new("S2",2,"ADD_REPLACEMENT_HEDGE","",-100,"RES-PLAN","replacement short"))
  plan=.MBHedgeRemediationPlan~new(planId,"REM1","T0","BOOK-PLAN-BASE","MAKER","POL1","09:05",steps)
  mb~proposeHedgeRemediationPlan(plan)
  mb~approveHedgeRemediationPlan(.MBHedgeRemediationPlanApproval~new(approvalId,planId,"CHECKER","AUTH-CHECKER","POL1","09:06"))
  return

::routine seed
  use strict arg mb
  mb~createPortfolio("PC","CLIENT","GBP"); mb~createPortfolio("PH1","MM1","GBP"); mb~createPortfolio("PU","MM1","GBP"); mb~createPortfolio("PH2","MM2","GBP")
  mb~bookTrade(.MBDerivativeTrade~new("T0","PC","CLIENT","CFD","LONG","GBP",100,0,0,"",1,"X","","EQ-X","09:00"))
  old=.MBDerivativeTrade~new("T1","PH1","MM1","CFD","SHORT","GBP",100,0,0,"",1,"X","","EQ-X","09:01","MM1","EXTERNAL_HEDGE")
  mb~bookCFDOffset("I1","H1","T0",old,"","AUTH","09:01")
  mb~recordHedgeEquivalenceEvidence(.MBHedgeEquivalenceEvidence~new("E1","H1",1,"","09:02","GB","AUTH","BLOCK","LEGAL1","","",.true,.false,.false,.false,.false,"BLOCKED"))
  mb~reassessHedgeRiskFromLatestKnown("R1","H1","E1","09:02")
  mb~openHedgeRemediation("REM1","H1","R1","POL1","09:03")
  doc=.MBReferenceDocumentEvidence~new("DOC-PLAN","REF-AUTH","urn:test:qty-fx","Quantity and FX fixture","1","09:00","","SOURCE_OBSERVED")
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
