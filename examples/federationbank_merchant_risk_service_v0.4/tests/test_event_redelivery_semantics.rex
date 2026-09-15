mb=.MBRiskServiceTestSupport~fixture
svc=.FederationBankMerchantRiskService~new(mb)
p=.MBRiskServiceTestSupport~payload("hedgeId","H-RS","policyRef","POL-RISK-SURV")
ignore=svc~handle(.MBRiskServiceEnvelope~new("C1","RISK.WATCH.REGISTER","OPS","MERCHANT_RISK_ADMIN",p,"09:03"))
notice=.MBRiskMarketStructureNotice~new("MSE-RED","JURISDICTIONAL_RESTRICTION","11:17","NL","SANCTIONS-AUTH","SANCTION-RED","LEGAL-RED","RES-RS-B",.true,.false,.false,.false,.false,"TRANSFER_RESTRICTED")
p2=.directory~new; p2["notice"]=notice
r1=svc~handle(.MBRiskServiceEnvelope~new("C2","RISK.MARKET_STRUCTURE.INGEST","FEED","MARKET_STRUCTURE_FEED",p2,"11:17"))
.MBRiskServiceTestSupport~assertTrue(r1~ok,"first delivery accepted")
eq1=mb~latestHedgeEquivalenceEvidence("H-RS")
book1=mb~latestCFDHedgeBookAssessment("TR-RS-A")
workCount=svc~openWork~items
-- Same evidence, new transport command id: event-level replay must not create new domain facts.
r2=svc~handle(.MBRiskServiceEnvelope~new("C3","RISK.MARKET_STRUCTURE.INGEST","FEED","MARKET_STRUCTURE_FEED",p2,"11:18"))
.MBRiskServiceTestSupport~assertTrue(r2~ok,"redelivery accepted")
eq2=mb~latestHedgeEquivalenceEvidence("H-RS")
book2=mb~latestCFDHedgeBookAssessment("TR-RS-A")
.MBRiskServiceTestSupport~assertEq(eq1~evidenceId,eq2~evidenceId,"redelivery does not advance equivalence evidence")
.MBRiskServiceTestSupport~assertEq(book1~assessmentId,book2~assessmentId,"redelivery reuses whole-book assessment")
.MBRiskServiceTestSupport~assertEq(workCount,svc~openWork~items,"redelivery does not duplicate work")
-- Same event id with changed evidence is a semantic conflict.
conflict=.MBRiskMarketStructureNotice~new("MSE-RED","JURISDICTIONAL_RESTRICTION","11:17","NL","SANCTIONS-AUTH","DIFFERENT-SOURCE","LEGAL-RED","RES-RS-B",.true,.false,.false,.false,.false,"TRANSFER_RESTRICTED")
p3=.directory~new; p3["notice"]=conflict
r3=svc~handle(.MBRiskServiceEnvelope~new("C4","RISK.MARKET_STRUCTURE.INGEST","FEED","MARKET_STRUCTURE_FEED",p3,"11:19"))
.MBRiskServiceTestSupport~assertTrue(\r3~ok,"conflicting event id rejected")
.MBRiskServiceTestSupport~assertEq("EVENT_ID_CONFLICT",r3~code,"conflicting evidence detected")
say "PASS test_event_redelivery_semantics"
exit 0
::requires "TestSupport.cls"
::requires "FederationBankMerchantRiskService.cls"
