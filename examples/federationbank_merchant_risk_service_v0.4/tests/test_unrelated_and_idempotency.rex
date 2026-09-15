mb=.MBRiskServiceTestSupport~fixture
svc=.FederationBankMerchantRiskService~new(mb)
p=.MBRiskServiceTestSupport~payload("hedgeId","H-RS","policyRef","POL-RISK-SURV")
ignore=svc~handle(.MBRiskServiceEnvelope~new("C1","RISK.WATCH.REGISTER","OPS-1","MERCHANT_RISK_ADMIN",p,"09:03"))
notice=.MBRiskMarketStructureNotice~new("MSE-RS-X","OTHER_LINE_RESTRICTION","11:18","SE","AUTH","REF-X","LEGAL-X","RES-RS-X",.false,.false,.false,.false,.false,"OTHER")
p2=.directory~new; p2["notice"]=notice
env=.MBRiskServiceEnvelope~new("C2","RISK.MARKET_STRUCTURE.INGEST","FEED-1","MARKET_STRUCTURE_FEED",p2,"11:18")
r=svc~handle(env)
.MBRiskServiceTestSupport~assertTrue(r~ok,"unrelated event accepted as evidence")
.MBRiskServiceTestSupport~assertEq(0,r~value~items,"unrelated settlement line not applied to hedge")
h=mb~hedgeRelationship("H-RS")
.MBRiskServiceTestSupport~assertEq("EQUIVALENT",h~equivalenceState,"hedge unchanged")
r2=svc~handle(env)
.MBRiskServiceTestSupport~assertEq("REPLAY",r2~code,"same command id replayed")
eq=mb~latestHedgeEquivalenceEvidence("H-RS")
.MBRiskServiceTestSupport~assertEq(1,eq~version,"idempotent replay did not advance evidence")
say "PASS test_unrelated_and_idempotency"
exit 0
::requires "TestSupport.cls"
::requires "FederationBankMerchantRiskService.cls"
