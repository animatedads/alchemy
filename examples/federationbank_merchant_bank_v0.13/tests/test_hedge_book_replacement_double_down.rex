mb=.FederationBankMerchantBank~new
mb~createPortfolio("PC","CLIENT","GBP"); mb~createPortfolio("PH1","MM1","GBP"); mb~createPortfolio("PH2","MM2","GBP")
mb~bookTrade(.MBDerivativeTrade~new("T0","PC","CLIENT","CFD","LONG","GBP",100,0,0,"",1,"X","","EQ-X","09:00"))
old=.MBDerivativeTrade~new("T1","PH1","MM1","CFD","SHORT","GBP",100,0,0,"",1,"X","","EQ-X","09:01","MM1","EXTERNAL_HEDGE")
mb~bookCFDOffset("I1","H1","T0",old,"","AUTH","09:01")
mb~recordHedgeEquivalenceEvidence(.MBHedgeEquivalenceEvidence~new("E1","H1",1,"","09:02","GB","AUTH","BLOCK","LEGAL1","","",.true,.false,.false,.false,.false,"BLOCKED"))
mb~reassessHedgeRiskFromLatestKnown("R1","H1","E1","09:02")
rem=mb~openHedgeRemediation("REM1","H1","R1","POL1","09:03")

replacement=.MBDerivativeTrade~new("T2","PH2","MM2","CFD","SHORT","GBP",100,0,0,"",1,"X","","EQ-X","09:10","MM2","EXTERNAL_HEDGE")
mb~bookCFDOffset("I2","H2","T0",replacement,"","AUTH","09:10")
mb~recordHedgeEquivalenceEvidence(.MBHedgeEquivalenceEvidence~new("E2","H2",1,"","09:11","GB","AUTH","HEALTHY","LEGAL2","","",.true,.true,.true,.true,.true,"HEALTHY"))
mb~reassessHedgeRiskFromLatestKnown("R2","H2","E2","09:11")
act=.MBHedgeRemediationActionEvidence~new("ACT2","REM1","REPLACE_HEDGE","MB-RISK-AUTH","REPLACEMENT-ORDER","09:12","H2")
mb~recordHedgeRemediationAction(act)
book=mb~assessCFDHedgeBook("BOOK1","T0","09:13")
call assertEq 3,book~contractCount,"aggregate book contains original plus both shorts"
call assertEq -100,book~netBaseExposure,"naive replacement doubled short exposure"
call assertEq "DIRECTIONAL_RESIDUAL",book~state,"aggregate assessment detects double-down"
call expectMitigationFail mb,"REM1","ACT2","BOOK1","09:14","directionally doubled replacement cannot mitigate"
call assertEq "ACTION_RECORDED",rem~state,"failed aggregate proof leaves remediation open"
say "PASS test_hedge_book_replacement_double_down"
exit 0
::routine expectMitigationFail
  use strict arg mb,rem,action,assessment,at,label
  caught=.false
  signal on syntax name got
  mb~mitigateHedgeRemediation(rem,action,assessment,at)
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
