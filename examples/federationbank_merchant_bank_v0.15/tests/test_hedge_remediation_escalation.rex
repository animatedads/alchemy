mb=.FederationBankMerchantBank~new
mb~createPortfolio("A","C","GBP"); mb~createPortfolio("B","M","GBP")
mb~bookTrade(.MBDerivativeTrade~new("T1","A","C","CFD","LONG","GBP",100,0,0,"",1,"X","","EQ-X","09:00"))
mb~bookCFDOffset("I1","H1","T1",.MBDerivativeTrade~new("T2","B","M","CFD","SHORT","GBP",100,0,0,"",1,"X","","EQ-X","09:01","M","EXTERNAL_HEDGE"),"","AUTH","09:01")
mb~recordHedgeEquivalenceEvidence(.MBHedgeEquivalenceEvidence~new("E1","H1",1,"","09:02","GB","AUTH","BLOCK","LEGAL1","","",.true,.false,.false,.false,.false,"BLOCKED"))
mb~reassessHedgeRiskFromLatestKnown("R1","H1","E1","09:02")
rem=mb~openHedgeRemediation("REM1","H1","R1","POL-SURV","09:03","10:00")
mb~escalateHedgeRemediation("REM1","10:01","MB-RISK-POLICY-AUTH","REMEDIATION_DEADLINE_EXPIRED")
call assertEq "ESCALATED",rem~state,"deadline/policy authority explicitly escalates remediation"
call assertEq "MB-RISK-POLICY-AUTH",rem~escalationAuthority,"escalation authority retained"
call assertEq "REMEDIATION_DEADLINE_EXPIRED",rem~escalationReason,"escalation reason retained"
call assertEq "10:00",rem~dueBy,"policy deadline remains evidence"
say "PASS test_hedge_remediation_escalation"
exit 0
::routine assertEq
  use strict arg expected,actual,label
  if expected<>actual then raise syntax 88.900 array("ASSERT_EQ",label,"expected",expected,"actual",actual)
::requires "FederationBankMerchantBank.cls"
