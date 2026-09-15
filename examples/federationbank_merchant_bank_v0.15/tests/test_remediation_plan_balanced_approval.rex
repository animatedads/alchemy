mb=.FederationBankMerchantBank~new
call seed mb
baseline=mb~assessCFDHedgeBook("BOOK-P2","T0","09:04")
steps=.array~new
steps~append(.MBHedgeRemediationPlanStep~new("S1",1,"NEUTRALISE_EXISTING_HEDGE","H1",100,"","neutralise impaired short"))
steps~append(.MBHedgeRemediationPlanStep~new("S2",2,"ADD_REPLACEMENT_HEDGE","",-100,"RES-PLAN","replacement short"))
plan=.MBHedgeRemediationPlan~new("PLAN-GOOD","REM1","T0","BOOK-P2","MAKER-A","POL1","09:05",steps)
mb~proposeHedgeRemediationPlan(plan)
call assertEq 0,plan~startingNetBaseExposure,"plan starts from whole-book net"
call assertEq 0,plan~projectedNetBaseExposure,"balanced replacement projects net zero"
call assertEq 100,plan~peakAbsBaseExposure,"transition exposure is visible rather than hidden"
call assertEq "PROPOSED",plan~state,"plan awaiting independent approval"
call expectApproveFail mb,.MBHedgeRemediationPlanApproval~new("APR-BAD","PLAN-GOOD","MAKER-A","AUTH-SELF","POL1","09:06"),"maker cannot approve own plan"
apr=.MBHedgeRemediationPlanApproval~new("APR-GOOD","PLAN-GOOD","CHECKER-B","AUTH-CHECKER","POL1","09:07")
mb~approveHedgeRemediationPlan(apr)
call assertEq "APPROVED",plan~state,"independent checker approves current plan"
call assertEq "CHECKER-B",plan~approvedBy,"checker identity retained"
call assertEq "AUTH-CHECKER",plan~approvalAuthorityRef,"approval evidence retained"
call assertEq "PLAN-GOOD",mb~currentHedgeRemediationPlan("REM1")~planId,"plan remains tied to remediation"
say "PASS test_remediation_plan_balanced_approval"
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
