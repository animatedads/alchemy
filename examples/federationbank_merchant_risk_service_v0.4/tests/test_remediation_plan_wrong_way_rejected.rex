mb=.MBRiskServiceTestSupport~fixture
svc=.FederationBankMerchantRiskService~new(mb)
p=.MBRiskServiceTestSupport~payload("hedgeId","H-RS","policyRef","POL-RISK-SURV")
call mustOk svc~handle(.MBRiskServiceEnvelope~new("C1","RISK.WATCH.REGISTER","OPS-1","MERCHANT_RISK_ADMIN",p,"09:03")),"watch"
notice=.MBRiskMarketStructureNotice~new("MSE-PLAN-BAD","JURISDICTIONAL_RESTRICTION","11:17","NL","SANCTIONS-AUTH","SANCTION-BAD","LEGAL-BAD","RES-RS-B",.true,.false,.false,.false,.false,"TRANSFER_RESTRICTED")
p2=.directory~new; p2["notice"]=notice
r=svc~handle(.MBRiskServiceEnvelope~new("C2","RISK.MARKET_STRUCTURE.INGEST","FEED-1","MARKET_STRUCTURE_FEED",p2,"11:17"))
call mustOk r,"market event"
row=r~value[1]; rem=mb~currentHedgeRemediation("H-RS")
steps=.array~new
s1=.directory~new; s1["stepId"]="S1"; s1["sequence"]=1; s1["actionType"]="ADD_REPLACEMENT_HEDGE"; s1["signedBaseExposureDelta"]=-1000000; s1["instrumentEvidenceRef"]="RES-RS-B"; s1["detail"]="blind second short"; steps~append(s1)
pp=.directory~new; pp["planId"]="PLAN-RS-BAD"; pp["remediationId"]=rem~remediationId; pp["rootTradeId"]=row["rootTradeId"]; pp["baselineBookAssessmentId"]=row["bookAssessmentId"]; pp["policyRef"]="POL-RISK-SURV"; pp["steps"]=steps
pr=svc~handle(.MBRiskServiceEnvelope~new("C3","RISK.REMEDIATION.PLAN.PROPOSE","RISK-MAKER","MERCHANT_RISK",pp,"11:18"))
.MBRiskServiceTestSupport~assertEq("DOMAIN_REJECTED",pr~code,"single replacement that doubles short exposure rejected")
.MBRiskServiceTestSupport~assertTrue(mb~hedgeRemediationPlan("PLAN-RS-BAD")==.nil,"bad plan never enters Merchant journal")
say "PASS test_remediation_plan_wrong_way_rejected"
exit 0
::routine mustOk
  use strict arg r,label
  if \r~ok then raise syntax 88.900 array("ASSERT_OK",label,r~code,r~detail)
::requires "TestSupport.cls"
::requires "FederationBankMerchantRiskService.cls"
