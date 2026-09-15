mb=.FederationBankMerchantBank~new
call seed mb
baseline=mb~assessCFDHedgeBook("BOOK-P1","T0","09:04")
call assertEq 0,baseline~netBaseExposure,"fixture starts directionally netted"
steps=.array~new
steps~append(.MBHedgeRemediationPlanStep~new("S1",1,"ADD_REPLACEMENT_HEDGE","",-100,"RES-PLAN","blind replacement"))
plan=.MBHedgeRemediationPlan~new("PLAN-BAD","REM1","T0","BOOK-P1","MAKER-A","POL1","09:05",steps)
call expectPlanFail mb,plan,"single replacement would double short exposure"
call assertTrue mb~hedgeRemediationPlan("PLAN-BAD")==.nil,"rejected plan not recorded"
say "PASS test_remediation_plan_wrong_way_rejected"
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
  doc=.MBReferenceDocumentEvidence~new("DOC-PLAN","REF-AUTH","urn:test:plan","Plan fixture","1","09:00","","SOURCE_OBSERVED")
  mb~recordReferenceDocumentEvidence(doc)
  mb~recordInstrumentResolutionEvidence(.MBInstrumentResolutionEvidence~new("RES-PLAN","DOC-PLAN","EQ-X","ISIN-X","XLON","GBP","LINE-X","CRSTGB22","ORDINARY","GBP","GBP","line=X","09:00"))
  return
::routine expectPlanFail
  use strict arg mb,plan,label
  caught=.false
  signal on syntax name got
  mb~proposeHedgeRemediationPlan(plan)
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
::routine assertTrue
  use strict arg value,label
  if \value then raise syntax 88.900 array("ASSERT_TRUE",label)
::requires "FederationBankMerchantBank.cls"
