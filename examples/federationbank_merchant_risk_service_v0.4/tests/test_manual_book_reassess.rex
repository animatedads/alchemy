mb=.MBRiskServiceTestSupport~fixture
svc=.FederationBankMerchantRiskService~new(mb)
p=.MBRiskServiceTestSupport~payload("rootTradeId","TR-RS-A")
r=svc~handle(.MBRiskServiceEnvelope~new("B1","RISK.BOOK.REASSESS","RISK-OPS","MERCHANT_RISK",p,"09:04"))
.MBRiskServiceTestSupport~assertTrue(r~ok,"risk role may request domain book reassessment")
.MBRiskServiceTestSupport~assertEq("NET_ZERO_WITH_MONITORING",r~value~state,"baseline whole book is net zero monitored")
.MBRiskServiceTestSupport~assertEq("TR-RS-A",r~value~rootTradeId,"assessment rooted at client contract")
say "PASS test_manual_book_reassess"
exit 0
::requires "TestSupport.cls"
::requires "FederationBankMerchantRiskService.cls"
