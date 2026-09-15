root=value("MB_RISK_TEST_ROOT",,"ENVIRONMENT")
if root="" then raise syntax 88.900 array("MB_RISK_TEST_ROOT required")
mb=.MBRiskServiceTestSupport~fixture
svc=.FederationBankMerchantRiskService~new(mb)
p=.MBRiskServiceTestSupport~payload("hedgeId","H-RS","policyRef","POL-RISK-SURV")
ignore=svc~handle(.MBRiskServiceEnvelope~new("C1","RISK.WATCH.REGISTER","OPS","MERCHANT_RISK_ADMIN",p,"09:03"))
store=.FederationBankMerchantRiskStateStore~new(root)
ignore=store~save(svc~state)
restored=store~load
.MBRiskServiceTestSupport~assertEq(1,restored~watches~items,"watch survives restart")
receipt=restored~receipts["C1"]
.MBRiskServiceTestSupport~assertTrue(receipt<>.nil,"idempotency receipt survives restart")
svc2=.FederationBankMerchantRiskService~new(mb,restored)
r=svc2~handle(.MBRiskServiceEnvelope~new("C1","RISK.WATCH.REGISTER","OPS","MERCHANT_RISK_ADMIN",p,"09:03"))
.MBRiskServiceTestSupport~assertEq("REPLAY",r~code,"recovered receipt prevents duplicate mutation")
say "PASS test_persistence_restart"
exit 0
::requires "TestSupport.cls"
::requires "FederationBankMerchantRiskPersistence.cls"
