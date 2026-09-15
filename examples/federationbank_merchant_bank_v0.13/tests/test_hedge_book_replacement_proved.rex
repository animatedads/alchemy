mb=.FederationBankMerchantBank~new
mb~createPortfolio("PC","CLIENT","GBP"); mb~createPortfolio("PH1","MM1","GBP"); mb~createPortfolio("PU","MM1","GBP"); mb~createPortfolio("PH2","MM2","GBP")
mb~bookTrade(.MBDerivativeTrade~new("T0","PC","CLIENT","CFD","LONG","GBP",100,0,0,"",1,"X","","EQ-X","09:00"))
old=.MBDerivativeTrade~new("T1","PH1","MM1","CFD","SHORT","GBP",100,0,0,"",1,"X","","EQ-X","09:01","MM1","EXTERNAL_HEDGE")
mb~bookCFDOffset("I1","H1","T0",old,"","AUTH","09:01")
mb~recordHedgeEquivalenceEvidence(.MBHedgeEquivalenceEvidence~new("E1","H1",1,"","09:02","GB","AUTH","BLOCK","LEGAL1","","",.true,.false,.false,.false,.false,"BLOCKED"))
mb~reassessHedgeRiskFromLatestKnown("R1","H1","E1","09:02")
rem=mb~openHedgeRemediation("REM1","H1","R1","POL1","09:03")

-- Neutralise the impaired external short with its own reversing long.
unwind=.MBDerivativeTrade~new("T1R","PU","MM1","CFD","LONG","GBP",100,0,0,"",1,"X","","EQ-X","09:10","MM1","INTERNAL_HEDGE")
mb~bookCFDOffset("IU","HU","T1",unwind,"","AUTH","09:10")
mb~recordHedgeEquivalenceEvidence(.MBHedgeEquivalenceEvidence~new("EU","HU",1,"","09:11","GB","AUTH","UNWIND-HEALTHY","LEGAL-U","","",.true,.true,.true,.true,.true,"HEALTHY"))
mb~reassessHedgeRiskFromLatestKnown("RU","HU","EU","09:11")

-- Then put on the replacement short against the client leg.
replacement=.MBDerivativeTrade~new("T2","PH2","MM2","CFD","SHORT","GBP",100,0,0,"",1,"X","","EQ-X","09:12","MM2","EXTERNAL_HEDGE")
mb~bookCFDOffset("I2","H2","T0",replacement,"","AUTH","09:12")
mb~recordHedgeEquivalenceEvidence(.MBHedgeEquivalenceEvidence~new("E2","H2",1,"","09:13","GB","AUTH","REPLACEMENT-HEALTHY","LEGAL2","","",.true,.true,.true,.true,.true,"HEALTHY"))
mb~reassessHedgeRiskFromLatestKnown("R2","H2","E2","09:13")
act=.MBHedgeRemediationActionEvidence~new("ACT2","REM1","REPLACE_HEDGE","MB-RISK-AUTH","REPLACEMENT-ORDER","09:14","H2")
mb~recordHedgeRemediationAction(act)
book=mb~assessCFDHedgeBook("BOOK2","T0","09:15")
call assertEq 4,book~contractCount,"whole book follows reversals of reversing legs"
call assertEq 0,book~netBaseExposure,"old hedge unwind plus replacement leaves aggregate direction net zero"
call assertEq 1,book~impairedHedgeCount,"only original impaired relationship remains"
call assertEq 0,book~unprovedHedgeCount,"all remediation hedges have proved equivalence"
call assertEq "NET_ZERO_WITH_IMPAIRED_CONTRACTS",book~state,"direction fixed while impaired contracts remain monitored"
mb~mitigateHedgeRemediation("REM1","ACT2","BOOK2","09:16")
call assertEq "MITIGATED_MONITORING",rem~state,"whole-book proof mitigates but does not erase impaired contract"
call assertEq "REPLACEMENT_BOOK_NETTED_WITH_CONTINUING_CONTRACT_MONITORING",rem~disposition,"mitigation disposition is explicit"
call assertEq "ACTIVE",mb~portfolio("PH1")~trade("T1")~contractState,"old external hedge promise remains active"
call assertEq "IMPAIRED",mb~hedgeRelationship("H1")~equivalenceState,"old hedge impairment remains historical/current truth"
say "PASS test_hedge_book_replacement_proved"
exit 0
::routine assertEq
  use strict arg expected,actual,label
  if expected<>actual then raise syntax 88.900 array("ASSERT_EQ",label,"expected",expected,"actual",actual)
::requires "FederationBankMerchantBank.cls"
