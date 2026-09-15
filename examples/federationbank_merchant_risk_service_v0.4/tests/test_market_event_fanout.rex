mb=.MBRiskServiceTestSupport~fixture
svc=.FederationBankMerchantRiskService~new(mb)
p=.MBRiskServiceTestSupport~payload("hedgeId","H-RS","policyRef","POL-RISK-SURV")
r=svc~handle(.MBRiskServiceEnvelope~new("C1","RISK.WATCH.REGISTER","OPS-1","MERCHANT_RISK_ADMIN",p,"09:03"))
.MBRiskServiceTestSupport~assertTrue(r~ok,"watch registered")
notice=.MBRiskMarketStructureNotice~new("MSE-RS-SANC","JURISDICTIONAL_RESTRICTION","11:17","NL","SANCTIONS-AUTH","SANCTION-77","LEGAL-77","RES-RS-B",.true,.false,.false,.false,.false,"TRANSFER_RESTRICTED")
p2=.directory~new; p2["notice"]=notice
r2=svc~handle(.MBRiskServiceEnvelope~new("C2","RISK.MARKET_STRUCTURE.INGEST","FEED-1","MARKET_STRUCTURE_FEED",p2,"11:17"))
.MBRiskServiceTestSupport~assertTrue(r2~ok,"event ingested")
.MBRiskServiceTestSupport~assertEq(1,r2~value~items,"one watched hedge applied")
row=r2~value[1]
.MBRiskServiceTestSupport~assertEq("HEDGE_IMPAIRED",row["riskState"],"risk immediately impaired")
.MBRiskServiceTestSupport~assertEq("TR-RS-A",row["rootTradeId"],"client-rooted book resolved")
.MBRiskServiceTestSupport~assertEq("NET_ZERO_WITH_IMPAIRED_CONTRACTS",row["bookState"],"aggregate book retains impaired contracts")
.MBRiskServiceTestSupport~assertEq(0,row["netBaseExposure"],"aggregate directional exposure remains zero")
.MBRiskServiceTestSupport~assertEq(2,svc~openWork~items,"hedge and whole-book work created")
rem=mb~currentHedgeRemediation("H-RS")
.MBRiskServiceTestSupport~assertTrue(rem<>.nil,"domain remediation obligation opened")
.MBRiskServiceTestSupport~assertEq("POL-RISK-SURV",rem~policyRef,"watch policy retained by domain")
say "PASS test_market_event_fanout"
exit 0
::requires "TestSupport.cls"
::requires "FederationBankMerchantRiskService.cls"
