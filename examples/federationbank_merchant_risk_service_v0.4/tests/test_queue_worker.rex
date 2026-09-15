root=value("MB_RISK_TEST_ROOT",,"ENVIRONMENT"); if root="" then raise syntax 88.900 array("MB_RISK_TEST_ROOT required")
mb=.MBRiskServiceTestSupport~fixture; svc=.FederationBankMerchantRiskService~new(mb); mgr=.ObjectQueueManager~new(root||"/queue")
w=.FederationBankMerchantRiskQueueWorker~new(svc,mgr); call assert w~install~ok
ignore=mgr~grant("MERCHANT.RISK.COMMANDS","risk-client",.QueueAccess~PUT,"queue-admin")
ignore=mgr~createQueue("RISK.REPLY","TEMPORARY","CLIENT",0,"queue-admin"); ignore=mgr~grant("RISK.REPLY","merchant-risk-service",.QueueAccess~PUT,"queue-admin"); ignore=mgr~grant("RISK.REPLY","risk-client",.QueueAccess~GET,"queue-admin")
p=.MBRiskServiceTestSupport~payload("hedgeId","H-RS","policyRef","POL-RISK")
env=.MBRiskServiceEnvelope~new("Q1","RISK.WATCH.REGISTER","OPS","MERCHANT_RISK_ADMIN",p,"09:03","CORR-Q","RISK.REPLY")
put=mgr~put("MERCHANT.RISK.COMMANDS",env,.nil,"risk-client"); call assert put~ok; worked=w~processOne; call assert worked~ok
claimed=mgr~claim("RISK.REPLY","risk-client"); call assert claimed~ok; reply=claimed~value~payload; .MBRiskServiceTestSupport~assertTrue(reply~ok,"reply delivered"); .MBRiskServiceTestSupport~assertEq("CORR-Q",reply~correlationId,"correlation retained")
say "PASS test_queue_worker"
exit 0
assert: procedure; use arg v; if \v then raise syntax 88.900 array("ASSERT_TRUE","queue operation"); return
::requires "TestSupport.cls"
::requires "FederationBankMerchantRiskQueue.cls"
