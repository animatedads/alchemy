root=value("MB_RISK_TEST_ROOT",,"ENVIRONMENT"); if root="" then raise syntax 88.900 array("MB_RISK_TEST_ROOT required")
mb=.MBRiskServiceTestSupport~fixture; svc=.FederationBankMerchantRiskService~new(mb)
p=.MBRiskServiceTestSupport~payload("hedgeId","H-RS","policyRef","POL-RISK-SURV")
call mustOk svc~handle(.MBRiskServiceEnvelope~new("D1","RISK.WATCH.REGISTER","OPS","MERCHANT_RISK_ADMIN",p,"09:03")),"watch"
notice=.MBRiskMarketStructureNotice~new("MSE-QPLAN","JURISDICTIONAL_RESTRICTION","11:17","NL","SANCTIONS-AUTH","SANCTION-Q","LEGAL-Q","RES-RS-B",.true,.false,.false,.false,.false,"TRANSFER_RESTRICTED")
p2=.directory~new; p2["notice"]=notice
r=svc~handle(.MBRiskServiceEnvelope~new("D2","RISK.MARKET_STRUCTURE.INGEST","FEED","MARKET_STRUCTURE_FEED",p2,"11:17")); call mustOk r,"event"
row=r~value[1]; rem=mb~currentHedgeRemediation("H-RS")
steps=.array~new
s1=.directory~new; s1["stepId"]="S1"; s1["sequence"]=1; s1["actionType"]="NEUTRALISE_EXISTING_HEDGE"; s1["targetRef"]="H-RS"; s1["signedBaseExposureDelta"]=1000000; steps~append(s1)
s2=.directory~new; s2["stepId"]="S2"; s2["sequence"]=2; s2["actionType"]="ADD_REPLACEMENT_HEDGE"; s2["signedBaseExposureDelta"]=-1000000; s2["instrumentEvidenceRef"]="RES-RS-B"; steps~append(s2)
pp=.directory~new; pp["planId"]="PLAN-Q"; pp["remediationId"]=rem~remediationId; pp["rootTradeId"]=row["rootTradeId"]; pp["baselineBookAssessmentId"]=row["bookAssessmentId"]; pp["policyRef"]="POL-RISK-SURV"; pp["steps"]=steps
env=.MBRiskServiceEnvelope~new("QPLAN","RISK.REMEDIATION.PLAN.PROPOSE","RISK-MAKER","MERCHANT_RISK",pp,"11:18","CORR-QPLAN","RISK.REPLY")
mgr=.ObjectQueueManager~new(root||"/queue")
w=.FederationBankMerchantRiskQueueWorker~new(svc,mgr); call assert w~install~ok
ignore=mgr~grant("MERCHANT.RISK.COMMANDS","risk-client",.QueueAccess~PUT,"queue-admin")
ignore=mgr~createQueue("RISK.REPLY","TEMPORARY","CLIENT",0,"queue-admin"); ignore=mgr~grant("RISK.REPLY","merchant-risk-service",.QueueAccess~PUT,"queue-admin"); ignore=mgr~grant("RISK.REPLY","risk-client",.QueueAccess~GET,"queue-admin")
put=mgr~put("MERCHANT.RISK.COMMANDS",env,.nil,"risk-client"); call assert put~ok
worked=w~processOne; call assert worked~ok
claimed=mgr~claim("RISK.REPLY","risk-client"); call assert claimed~ok
reply=claimed~value~payload; call assert reply~ok
.MBRiskServiceTestSupport~assertEq("CORR-QPLAN",reply~correlationId,"correlation retained")
.MBRiskServiceTestSupport~assertEq("PLAN-Q",reply~value["planId"],"queue-safe plan projection returned")
.MBRiskServiceTestSupport~assertEq(0,reply~value["projectedNetBaseExposure"],"queue plan preserves net exposure")
.MBRiskServiceTestSupport~assertEq(2,reply~value["steps"]~items,"step projection survives queue boundary")
say "PASS test_queue_worker_remediation_plan"
exit 0
mustOk: procedure; use arg r,label; if \r~ok then raise syntax 88.900 array("ASSERT_OK",label,r~code,r~detail); return
assert: procedure; use arg v; if \v then raise syntax 88.900 array("ASSERT_TRUE","queue operation"); return
::requires "TestSupport.cls"
::requires "FederationBankMerchantRiskQueue.cls"
