root=value("MB_RISK_TEST_ROOT",,"ENVIRONMENT"); if root="" then raise syntax 88.900 array("MB_RISK_TEST_ROOT required")
mb=.MBRiskServiceTestSupport~fixture; svc=.FederationBankMerchantRiskService~new(mb)
p=.MBRiskServiceTestSupport~payload("hedgeId","H-RS","policyRef","POL-RISK-SURV"); call mustOk svc~handle(.MBRiskServiceEnvelope~new("WQ","RISK.WATCH.REGISTER","OPS","MERCHANT_RISK_ADMIN",p,"09:03")),"watch"
notice=.MBRiskMarketStructureNotice~new("MSE-QEXEC","JURISDICTIONAL_RESTRICTION","11:17","NL","SANCTIONS-AUTH","SANCTION-QE","LEGAL-QE","RES-RS-B",.true,.false,.false,.false,.false,"TRANSFER_RESTRICTED")
pn=.directory~new; pn["notice"]=notice
r=svc~handle(.MBRiskServiceEnvelope~new("MQ","RISK.MARKET_STRUCTURE.INGEST","FEED","MARKET_STRUCTURE_FEED",pn,"11:17")); call mustOk r,"event"
row=r~value[1]; rem=mb~currentHedgeRemediation("H-RS")
steps=.array~new; st=.directory~new; st["stepId"]="S1"; st["sequence"]=1; st["actionType"]="RESTORE_FUNGIBILITY"; st["targetRef"]="H-RS"; st["signedBaseExposureDelta"]=0; steps~append(st)
pp=.directory~new; pp["planId"]="PLAN-QEXEC"; pp["remediationId"]=rem~remediationId; pp["rootTradeId"]=row["rootTradeId"]; pp["baselineBookAssessmentId"]=row["bookAssessmentId"]; pp["policyRef"]="POL-RISK-SURV"; pp["steps"]=steps
call mustOk svc~handle(.MBRiskServiceEnvelope~new("PQ","RISK.REMEDIATION.PLAN.PROPOSE","RISK-MAKER","MERCHANT_RISK",pp,"11:18")),"plan"
pa=.directory~new; pa["approvalId"]="APR-QEXEC"; pa["planId"]="PLAN-QEXEC"; pa["approvalAuthorityRef"]="AUTH-C"; pa["policyRef"]="POL-RISK-SURV"
call mustOk svc~handle(.MBRiskServiceEnvelope~new("AQ","RISK.REMEDIATION.PLAN.APPROVE","CHECKER","MERCHANT_RISK_APPROVER",pa,"11:19")),"approve"

ep=.directory~new; ep["evidenceId"]="EXEC-Q"; ep["planId"]="PLAN-QEXEC"; ep["stepId"]="S1"; ep["executionSequence"]=1; ep["executionState"]="COMPLETED"; ep["sourceRef"]="LEGAL-RESTORE-RESULT"; ep["authorityRef"]="AUTH-RESTORE"; ep["actualObjectRef"]="RESTORE-EVIDENCE-1"; ep["observedSignedBaseExposureDelta"]=0; ep["policyRef"]="POL-RISK-SURV"
env=.MBRiskServiceEnvelope~new("QEXEC","RISK.REMEDIATION.PLAN.EXECUTION.INGEST","MERCHANT-LEGAL-OPS","MERCHANT_EXECUTION_EVIDENCE",ep,"11:20","CORR-QEXEC","RISK.REPLY")
mgr=.ObjectQueueManager~new(root||"/queue")
w=.FederationBankMerchantRiskQueueWorker~new(svc,mgr); call assert w~install~ok
ignore=mgr~grant("MERCHANT.RISK.COMMANDS","risk-client",.QueueAccess~PUT,"queue-admin")
ignore=mgr~createQueue("RISK.REPLY","TEMPORARY","CLIENT",0,"queue-admin"); ignore=mgr~grant("RISK.REPLY","merchant-risk-service",.QueueAccess~PUT,"queue-admin"); ignore=mgr~grant("RISK.REPLY","risk-client",.QueueAccess~GET,"queue-admin")
put=mgr~put("MERCHANT.RISK.COMMANDS",env,.nil,"risk-client"); call assert put~ok
worked=w~processOne; call assert worked~ok
claimed=mgr~claim("RISK.REPLY","risk-client"); call assert claimed~ok
reply=claimed~value~payload; call assert reply~ok
.MBRiskServiceTestSupport~assertEq("CORR-QEXEC",reply~correlationId,"correlation retained")
.MBRiskServiceTestSupport~assertEq("EXEC-Q",reply~value["evidence"]["evidenceId"],"scalar execution evidence crosses Queue Fabric")
.MBRiskServiceTestSupport~assertEq("MERCHANT-LEGAL-OPS",reply~value["evidence"]["sourceAuthority"],"source authority comes from authenticated command actor")
.MBRiskServiceTestSupport~assertEq("MATCHED_PROJECTED_BOOK",reply~value["verification"]["resultState"],"completed plan is verified after queue-delivered evidence")
.MBRiskServiceTestSupport~assertEq("OPEN",rem~state,"verified plan remains separate from remediation cure")
say "PASS test_queue_worker_remediation_execution_evidence"
exit 0
mustOk: procedure; use arg r,label; if \r~ok then raise syntax 88.900 array("ASSERT_OK",label,r~code,r~detail); return
assert: procedure; use arg v; if \v then raise syntax 88.900 array("ASSERT_TRUE","queue operation"); return
::requires "TestSupport.cls"
::requires "FederationBankMerchantRiskQueue.cls"
