mb=.MBRiskServiceTestSupport~fixture
svc=.FederationBankMerchantRiskService~new(mb)
call setupPlan mb,svc

-- Actual execution is wrong: step 1 adds another short to the root instead of reversing the old short.
mb~createPortfolio("PF-W1","MM-W1","EUR")
wrong=.MBDerivativeTrade~new("TR-W1","PF-W1","MM-W1","CFD","SHORT","EUR",1200000,0,0,"",1,"RS","CFD-RS-B","RS-EQ","11:21","MM-W1","EXTERNAL_HEDGE")
mb~bookCFDOffset("INT-W1","H-W1","TR-RS-A",wrong,"FX-RS","MERCHANT-TRADING-AUTH","11:21")
mb~createPortfolio("PF-W2","MM-W2","EUR")
replacement=.MBDerivativeTrade~new("TR-W2","PF-W2","MM-W2","CFD","SHORT","EUR",1200000,0,0,"",1,"RS","CFD-RS-B","RS-EQ","11:22","MM-W2","EXTERNAL_HEDGE")
mb~bookCFDOffset("INT-W2","H-W2","TR-RS-A",replacement,"FX-RS","MERCHANT-TRADING-AUTH","11:22")

p1=.directory~new; p1["evidenceId"]="EXEC-W-1"; p1["planId"]="PLAN-W"; p1["stepId"]="S1"; p1["executionSequence"]=1; p1["executionState"]="COMPLETED"; p1["sourceRef"]="FILL-W1"; p1["authorityRef"]="AUTH-W1"; p1["actualObjectRef"]="H-W1"; p1["observedSignedBaseExposureDelta"]=-1000000; p1["policyRef"]="POL-RISK-SURV"
call mustOk svc~handle(.MBRiskServiceEnvelope~new("EW1","RISK.REMEDIATION.PLAN.EXECUTION.INGEST","MERCHANT-TRADING-AUTH","MERCHANT_EXECUTION_EVIDENCE",p1,"11:21")),"wrong-way evidence retained"
p2=.directory~new; p2["evidenceId"]="EXEC-W-2"; p2["planId"]="PLAN-W"; p2["stepId"]="S2"; p2["executionSequence"]=2; p2["executionState"]="COMPLETED"; p2["sourceRef"]="FILL-W2"; p2["authorityRef"]="AUTH-W2"; p2["actualObjectRef"]="H-W2"; p2["observedSignedBaseExposureDelta"]=-1000000; p2["policyRef"]="POL-RISK-SURV"
r=svc~handle(.MBRiskServiceEnvelope~new("EW2","RISK.REMEDIATION.PLAN.EXECUTION.INGEST","MERCHANT-TRADING-AUTH","MERCHANT_EXECUTION_EVIDENCE",p2,"11:22")); call mustOk r,"second evidence"
v=r~value["verification"]
.MBRiskServiceTestSupport~assertEq("STEP_OBJECT_DEVIATION",v["resultState"],"service sees wrong contractual leg rather than trusting close intent")
.MBRiskServiceTestSupport~assertEq(-2000000,v["actualNetBaseExposure"],"whole book is doubled short in base currency")
.MBRiskServiceTestSupport~assertEq("DEVIATED",mb~hedgeRemediationPlan("PLAN-W")~state,"bad execution never becomes successful plan")
work=svc~openWork; found=.false
do w over work
  if w~workType="REMEDIATION_PLAN_EXECUTION_DEVIATION" then do
    found=.true
    .MBRiskServiceTestSupport~assertEq(-2000000,w~netBaseExposure,"deviation work carries actual book exposure")
  end
end
.MBRiskServiceTestSupport~assertTrue(found,"wrong-way execution creates durable operational work")
-- A risk user may not impersonate the evidence-producing authority.
spoof=.directory~new; spoof["evidenceId"]="SPOOF"; spoof["planId"]="PLAN-W"; spoof["stepId"]="S1"; spoof["executionSequence"]=9; spoof["executionState"]="FAILED"; spoof["sourceRef"]="X"; spoof["authorityRef"]="X"; spoof["policyRef"]="POL-RISK-SURV"
denied=svc~handle(.MBRiskServiceEnvelope~new("EW3","RISK.REMEDIATION.PLAN.EXECUTION.INGEST","RISK-MAKER","MERCHANT_RISK",spoof,"11:23"))
.MBRiskServiceTestSupport~assertEq("NOT_AUTHORISED",denied~code,"risk role cannot manufacture execution evidence")
say "PASS test_remediation_execution_wrong_way_work"
exit 0

::routine setupPlan
  use strict arg mb,svc
  p=.MBRiskServiceTestSupport~payload("hedgeId","H-RS","policyRef","POL-RISK-SURV")
  call mustOk svc~handle(.MBRiskServiceEnvelope~new("W-W","RISK.WATCH.REGISTER","OPS-1","MERCHANT_RISK_ADMIN",p,"09:03")),"watch"
  notice=.MBRiskMarketStructureNotice~new("MSE-W","JURISDICTIONAL_RESTRICTION","11:17","NL","SANCTIONS-AUTH","SANCTION-W","LEGAL-W","RES-RS-B",.true,.false,.false,.false,.false,"TRANSFER_RESTRICTED")
  pn=.directory~new; pn["notice"]=notice
  r=svc~handle(.MBRiskServiceEnvelope~new("M-W","RISK.MARKET_STRUCTURE.INGEST","FEED-1","MARKET_STRUCTURE_FEED",pn,"11:17")); call mustOk r,"market event"
  row=r~value[1]; rem=mb~currentHedgeRemediation("H-RS")
  steps=.array~new
  s1=.directory~new; s1["stepId"]="S1"; s1["sequence"]=1; s1["actionType"]="NEUTRALISE_EXISTING_HEDGE"; s1["targetRef"]="H-RS"; s1["signedBaseExposureDelta"]=1000000; steps~append(s1)
  s2=.directory~new; s2["stepId"]="S2"; s2["sequence"]=2; s2["actionType"]="ADD_REPLACEMENT_HEDGE"; s2["signedBaseExposureDelta"]=-1000000; s2["instrumentEvidenceRef"]="RES-RS-B"; steps~append(s2)
  pp=.directory~new; pp["planId"]="PLAN-W"; pp["remediationId"]=rem~remediationId; pp["rootTradeId"]=row["rootTradeId"]; pp["baselineBookAssessmentId"]=row["bookAssessmentId"]; pp["policyRef"]="POL-RISK-SURV"; pp["steps"]=steps
  call mustOk svc~handle(.MBRiskServiceEnvelope~new("P-W","RISK.REMEDIATION.PLAN.PROPOSE","RISK-MAKER","MERCHANT_RISK",pp,"11:18")),"plan"
  pa=.directory~new; pa["approvalId"]="APR-W"; pa["planId"]="PLAN-W"; pa["approvalAuthorityRef"]="AUTH-C"; pa["policyRef"]="POL-RISK-SURV"
  call mustOk svc~handle(.MBRiskServiceEnvelope~new("A-W","RISK.REMEDIATION.PLAN.APPROVE","CHECKER","MERCHANT_RISK_APPROVER",pa,"11:20")),"approval"
  return
::routine mustOk
  use strict arg r,label
  if \r~ok then raise syntax 88.900 array("ASSERT_OK",label,r~code,r~detail)
::requires "TestSupport.cls"
::requires "FederationBankMerchantRiskService.cls"
