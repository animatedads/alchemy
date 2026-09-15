mb=.MBRiskServiceTestSupport~fixture
svc=.FederationBankMerchantRiskService~new(mb)
p=.MBRiskServiceTestSupport~payload("hedgeId","H-RS","policyRef","POL-RISK")
r=svc~handle(.MBRiskServiceEnvelope~new("C1","RISK.WATCH.REGISTER","TELLER-1","TELLER",p,"09:03"))
.MBRiskServiceTestSupport~assertEq("NOT_AUTHORISED",r~code,"retail/teller role cannot configure Merchant Risk")
notice=.MBRiskMarketStructureNotice~new("MSE-BAD","RESTRICTION","11:17","NL","AUTH","REF","LEGAL","RES-RS-B",.false,.false,.false,.false,.false,"BLOCKED")
p2=.directory~new; p2["notice"]=notice
r2=svc~handle(.MBRiskServiceEnvelope~new("C2","RISK.MARKET_STRUCTURE.INGEST","CLIENT","RETAIL_CUSTOMER",p2,"11:17"))
.MBRiskServiceTestSupport~assertEq("NOT_AUTHORISED",r2~code,"retail customer cannot inject market-structure events")
stored=mb~marketStructureEvent("MSE-BAD")
.MBRiskServiceTestSupport~assertTrue(stored==.nil,"rejected command creates no domain event")
say "PASS test_authority_boundary"
exit 0
::requires "TestSupport.cls"
::requires "FederationBankMerchantRiskService.cls"
