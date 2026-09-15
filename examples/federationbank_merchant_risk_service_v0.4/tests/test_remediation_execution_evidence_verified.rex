mb=.MBRiskServiceTestSupport~fixture
svc=.FederationBankMerchantRiskService~new(mb)
call setupPlan mb,svc,"GOOD"

-- These are actual Merchant-domain trading results, not Risk Service execution commands.
mb~createPortfolio("PF-RS-U","MM-RS","EUR")
unwind=.MBDerivativeTrade~new("TR-RS-U","PF-RS-U","MM-RS","CFD","LONG","EUR",1200000,0,0,"",1,"RS","CFD-RS-B","RS-EQ","11:21","MM-RS","INTERNAL_HEDGE")
mb~bookCFDOffset("INT-RS-U","H-RS-U","TR-RS-B",unwind,"","MERCHANT-TRADING-AUTH","11:21")
mb~createPortfolio("PF-RS-R","MM-RS2","EUR")
replacement=.MBDerivativeTrade~new("TR-RS-R","PF-RS-R","MM-RS2","CFD","SHORT","EUR",1200000,0,0,"",1,"RS","CFD-RS-B","RS-EQ","11:22","MM-RS2","EXTERNAL_HEDGE")
mb~bookCFDOffset("INT-RS-R","H-RS-R","TR-RS-A",replacement,"FX-RS","MERCHANT-TRADING-AUTH","11:22")

p1=.directory~new; p1["evidenceId"]="EXEC-G-1"; p1["planId"]="PLAN-GOOD"; p1["stepId"]="S1"; p1["executionSequence"]=1; p1["executionState"]="COMPLETED"; p1["sourceRef"]="FILL-U"; p1["authorityRef"]="AUTH-TRD-U"; p1["actualObjectRef"]="H-RS-U"; p1["observedSignedBaseExposureDelta"]=1000000; p1["policyRef"]="POL-RISK-SURV"
r1=svc~handle(.MBRiskServiceEnvelope~new("E1","RISK.REMEDIATION.PLAN.EXECUTION.INGEST","MERCHANT-TRADING-AUTH","MERCHANT_EXECUTION_EVIDENCE",p1,"11:21"))
call mustOk r1,"first execution evidence"
.MBRiskServiceTestSupport~assertEq("EXECUTING",r1~value["plan"]["state"],"plan waits for remaining attributable outcome")

p2=.directory~new; p2["evidenceId"]="EXEC-G-2"; p2["planId"]="PLAN-GOOD"; p2["stepId"]="S2"; p2["executionSequence"]=2; p2["executionState"]="COMPLETED"; p2["sourceRef"]="FILL-R"; p2["authorityRef"]="AUTH-TRD-R"; p2["actualObjectRef"]="H-RS-R"; p2["observedSignedBaseExposureDelta"]=-1000000; p2["policyRef"]="POL-RISK-SURV"
r2=svc~handle(.MBRiskServiceEnvelope~new("E2","RISK.REMEDIATION.PLAN.EXECUTION.INGEST","MERCHANT-TRADING-AUTH","MERCHANT_EXECUTION_EVIDENCE",p2,"11:22"))
call mustOk r2,"second execution evidence"
v=r2~value["verification"]
.MBRiskServiceTestSupport~assertEq("MATCHED_PROJECTED_BOOK",v["resultState"],"service verifies real current whole book against approved projection")
.MBRiskServiceTestSupport~assertEq(0,v["actualNetBaseExposure"],"actual aggregate exposure remains net zero")
.MBRiskServiceTestSupport~assertEq("VERIFIED",mb~hedgeRemediationPlan("PLAN-GOOD")~state,"domain records successful execution proof")
.MBRiskServiceTestSupport~assertEq("OPEN",mb~currentHedgeRemediation("H-RS")~state,"execution verification cannot cure impaired contractual relationship")

lp=.directory~new; lp["planId"]="PLAN-GOOD"
lr=svc~handle(.MBRiskServiceEnvelope~new("E3","RISK.REMEDIATION.PLAN.EXECUTION.LIST","RISK-READ","MERCHANT_RISK_READ",lp,"11:23"))
call mustOk lr,"execution list"
.MBRiskServiceTestSupport~assertEq(2,lr~value["evidence"]~items,"both external execution outcomes are inspectable")
.MBRiskServiceTestSupport~assertEq("MATCHED_PROJECTED_BOOK",lr~value["verification"]["resultState"],"verification projection is read-only discoverable")

-- Risk roles still cannot execute trades through this service.
er=svc~handle(.MBRiskServiceEnvelope~new("E4","RISK.REMEDIATION.EXECUTE","RISK-MAKER","MERCHANT_RISK",.directory~new,"11:24"))
.MBRiskServiceTestSupport~assertEq("NOT_AUTHORISED",er~code,"evidence ingestion did not create execution authority")
say "PASS test_remediation_execution_evidence_verified"
exit 0

::routine setupPlan
  use strict arg mb,svc,suffix
  p=.MBRiskServiceTestSupport~payload("hedgeId","H-RS","policyRef","POL-RISK-SURV")
  call mustOk svc~handle(.MBRiskServiceEnvelope~new("W-"||suffix,"RISK.WATCH.REGISTER","OPS-1","MERCHANT_RISK_ADMIN",p,"09:03")),"watch"
  notice=.MBRiskMarketStructureNotice~new("MSE-"||suffix,"JURISDICTIONAL_RESTRICTION","11:17","NL","SANCTIONS-AUTH","SANCTION-"||suffix,"LEGAL-"||suffix,"RES-RS-B",.true,.false,.false,.false,.false,"TRANSFER_RESTRICTED")
  p2=.directory~new; p2["notice"]=notice
  r=svc~handle(.MBRiskServiceEnvelope~new("M-"||suffix,"RISK.MARKET_STRUCTURE.INGEST","FEED-1","MARKET_STRUCTURE_FEED",p2,"11:17")); call mustOk r,"market event"
  row=r~value[1]; rem=mb~currentHedgeRemediation("H-RS")
  steps=.array~new
  s1=.directory~new; s1["stepId"]="S1"; s1["sequence"]=1; s1["actionType"]="NEUTRALISE_EXISTING_HEDGE"; s1["targetRef"]="H-RS"; s1["signedBaseExposureDelta"]=1000000; steps~append(s1)
  s2=.directory~new; s2["stepId"]="S2"; s2["sequence"]=2; s2["actionType"]="ADD_REPLACEMENT_HEDGE"; s2["signedBaseExposureDelta"]=-1000000; s2["instrumentEvidenceRef"]="RES-RS-B"; steps~append(s2)
  pp=.directory~new; pp["planId"]="PLAN-GOOD"; pp["remediationId"]=rem~remediationId; pp["rootTradeId"]=row["rootTradeId"]; pp["baselineBookAssessmentId"]=row["bookAssessmentId"]; pp["policyRef"]="POL-RISK-SURV"; pp["steps"]=steps
  call mustOk svc~handle(.MBRiskServiceEnvelope~new("P-"||suffix,"RISK.REMEDIATION.PLAN.PROPOSE","RISK-MAKER","MERCHANT_RISK",pp,"11:18")),"plan proposed"
  pa=.directory~new; pa["approvalId"]="APR-GOOD"; pa["planId"]="PLAN-GOOD"; pa["approvalAuthorityRef"]="AUTH-CHECKER"; pa["policyRef"]="POL-RISK-SURV"
  call mustOk svc~handle(.MBRiskServiceEnvelope~new("A-"||suffix,"RISK.REMEDIATION.PLAN.APPROVE","RISK-CHECKER","MERCHANT_RISK_APPROVER",pa,"11:20")),"plan approved"
  return
::routine mustOk
  use strict arg r,label
  if \r~ok then raise syntax 88.900 array("ASSERT_OK",label,r~code,r~detail)
::requires "TestSupport.cls"
::requires "FederationBankMerchantRiskService.cls"
