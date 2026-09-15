mb=.MBRiskServiceTestSupport~fixture
svc=.FederationBankMerchantRiskService~new(mb)
p=.MBRiskServiceTestSupport~payload("hedgeId","H-RS","policyRef","POL-RISK-SURV")
call mustOk svc~handle(.MBRiskServiceEnvelope~new("C1","RISK.WATCH.REGISTER","OPS-1","MERCHANT_RISK_ADMIN",p,"09:03")),"watch"
notice=.MBRiskMarketStructureNotice~new("MSE-PLAN","JURISDICTIONAL_RESTRICTION","11:17","NL","SANCTIONS-AUTH","SANCTION-PLAN","LEGAL-PLAN","RES-RS-B",.true,.false,.false,.false,.false,"TRANSFER_RESTRICTED")
p2=.directory~new; p2["notice"]=notice
r=svc~handle(.MBRiskServiceEnvelope~new("C2","RISK.MARKET_STRUCTURE.INGEST","FEED-1","MARKET_STRUCTURE_FEED",p2,"11:17"))
call mustOk r,"market event"
row=r~value[1]
rem=mb~currentHedgeRemediation("H-RS")
.MBRiskServiceTestSupport~assertTrue(rem<>.nil,"remediation exists")
steps=.array~new
s1=.directory~new; s1["stepId"]="S1"; s1["sequence"]=1; s1["actionType"]="NEUTRALISE_EXISTING_HEDGE"; s1["targetRef"]="H-RS"; s1["signedBaseExposureDelta"]=1000000; s1["detail"]="neutralise old EUR hedge in GBP base"; steps~append(s1)
s2=.directory~new; s2["stepId"]="S2"; s2["sequence"]=2; s2["actionType"]="ADD_REPLACEMENT_HEDGE"; s2["signedBaseExposureDelta"]=-1000000; s2["instrumentEvidenceRef"]="RES-RS-B"; s2["detail"]="stage replacement"; steps~append(s2)
pp=.directory~new; pp["planId"]="PLAN-RS-1"; pp["remediationId"]=rem~remediationId; pp["rootTradeId"]=row["rootTradeId"]; pp["baselineBookAssessmentId"]=row["bookAssessmentId"]; pp["policyRef"]="POL-RISK-SURV"; pp["steps"]=steps
pr=svc~handle(.MBRiskServiceEnvelope~new("C3","RISK.REMEDIATION.PLAN.PROPOSE","RISK-MAKER","MERCHANT_RISK",pp,"11:18"))
call mustOk pr,"plan proposed"
.MBRiskServiceTestSupport~assertEq("PROPOSED",pr~value["state"],"plan awaits checker")
.MBRiskServiceTestSupport~assertEq(0,pr~value["projectedNetBaseExposure"],"plan preserves whole-book net zero")
.MBRiskServiceTestSupport~assertEq(1000000,pr~value["peakAbsBaseExposure"],"transient execution exposure visible")
-- Same human wearing approver role still fails domain maker/checker.
pa=.directory~new; pa["approvalId"]="APR-RS-BAD"; pa["planId"]="PLAN-RS-1"; pa["approvalAuthorityRef"]="AUTH-SELF"; pa["policyRef"]="POL-RISK-SURV"
br=svc~handle(.MBRiskServiceEnvelope~new("C4","RISK.REMEDIATION.PLAN.APPROVE","RISK-MAKER","MERCHANT_RISK_APPROVER",pa,"11:19"))
.MBRiskServiceTestSupport~assertEq("DOMAIN_REJECTED",br~code,"maker/checker enforced in Merchant domain")
pa2=.directory~new; pa2["approvalId"]="APR-RS-GOOD"; pa2["planId"]="PLAN-RS-1"; pa2["approvalAuthorityRef"]="AUTH-CHECKER"; pa2["policyRef"]="POL-RISK-SURV"
ar=svc~handle(.MBRiskServiceEnvelope~new("C5","RISK.REMEDIATION.PLAN.APPROVE","RISK-CHECKER","MERCHANT_RISK_APPROVER",pa2,"11:20"))
call mustOk ar,"independent approval"
.MBRiskServiceTestSupport~assertEq("APPROVED",ar~value["state"],"plan approved")
lp=.directory~new; lp["remediationId"]=rem~remediationId
lr=svc~handle(.MBRiskServiceEnvelope~new("C6","RISK.REMEDIATION.PLAN.LIST","RISK-READ","MERCHANT_RISK_READ",lp,"11:21"))
call mustOk lr,"plan list"
.MBRiskServiceTestSupport~assertEq(1,lr~value~items,"approved plan discoverable")
er=svc~handle(.MBRiskServiceEnvelope~new("C7","RISK.REMEDIATION.EXECUTE","RISK-CHECKER","MERCHANT_RISK_APPROVER",.directory~new,"11:22"))
.MBRiskServiceTestSupport~assertEq("NOT_AUTHORISED",er~code,"service cannot execute remediation")
say "PASS test_remediation_plan_maker_checker"
exit 0
::routine mustOk
  use strict arg r,label
  if \r~ok then raise syntax 88.900 array("ASSERT_OK",label,r~code,r~detail)
::requires "TestSupport.cls"
::requires "FederationBankMerchantRiskService.cls"
