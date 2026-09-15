mb=.FederationBankMerchantBank~new
mb~createPortfolio("PF-C","CLIENT-C","GBP")
mb~createPortfolio("PF-H","MM-C","GBP")
mb~bookTrade(.MBDerivativeTrade~new("TR-C","PF-C","CLIENT-C","CFD","LONG","GBP",1000000,0,0,"",1,"EQ","","EQ-C","09:00"))
off=.MBDerivativeTrade~new("TR-H","PF-H","MM-C","CFD","SHORT","GBP",1000000,0,0,"",1,"EQ","","EQ-C","09:01","MM-C","EXTERNAL_HEDGE")
h=mb~bookCFDOffset("INT-C","H-C","TR-C",off,"","TRADE-AUTH","09:01")

bad=.MBHedgeEquivalenceEvidence~new("EQ-C-1","H-C",1,"","09:02","GB","SANCTIONS-AUTH","SANCTION-1","LEGAL-1","","",.true,.false,.false,.false,.false,"TRANSFER_BLOCKED")
mb~recordHedgeEquivalenceEvidence(bad)
a1=mb~reassessHedgeRiskFromLatestKnown("HRA-C-1","H-C","EQ-C-1","09:02")
call assertEq "HEDGE_IMPAIRED",a1~riskState,"impairment becomes risk fact"
r=mb~openHedgeRemediation("REM-C","H-C","HRA-C-1","POL-HEDGE-SURVEILLANCE-1","09:03","12:00")
call assertEq "OPEN",r~state,"impaired hedge creates explicit remediation obligation"
call assertEq "EQ-C-1",r~triggerEquivalenceEvidenceRef,"remediation binds impairment evidence"

ok=.MBHedgeEquivalenceEvidence~new("EQ-C-2","H-C",2,"EQ-C-1","10:10","GB","LEGAL-MARKET-AUTH","RELEASE-1","LEGAL-2","","",.true,.true,.true,.true,.true,"FUNGIBILITY_RESTORED")
mb~recordHedgeEquivalenceEvidence(ok)
a2=mb~reassessHedgeRiskFromLatestKnown("HRA-C-2","H-C","EQ-C-2","10:10")
call assertEq "NET_ZERO_MARKET_RISK_WITH_MONITORING",a2~riskState,"restored evidence must be reassessed"
act=.MBHedgeRemediationActionEvidence~new("ACT-C","REM-C","RESTORE_FUNGIBILITY","MB-RISK-AUTH","RELEASE-1","10:11","","LEGAL-2","POL-HEDGE-SURVEILLANCE-1")
mb~recordHedgeRemediationAction(act)
call assertEq "ACTION_RECORDED",r~state,"action evidence does not itself resolve remediation"
mb~resolveHedgeRemediation("REM-C","ACT-C","HRA-C-2","10:12")
call assertEq "RESOLVED",r~state,"current healthy proof resolves remediation"
call assertEq "ORIGINAL_HEDGE_RESTORED",r~disposition,"resolution disposition retained"
call assertEq 1,mb~hedgeRelationship("H-C")~monitoringRequired,"restored hedge remains monitored"
call assertEq "ACTIVE",mb~portfolio("PF-C")~trade("TR-C")~contractState,"client CFD contract remains live"
call assertEq "ACTIVE",mb~portfolio("PF-H")~trade("TR-H")~contractState,"external hedge contract remains live"
say "PASS test_hedge_remediation_restore"
exit 0
::routine assertEq
  use strict arg expected,actual,label
  if expected<>actual then raise syntax 88.900 array("ASSERT_EQ",label,"expected",expected,"actual",actual)
::requires "FederationBankMerchantBank.cls"
