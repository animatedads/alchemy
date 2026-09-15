mb=.FederationBankMerchantBank~new
call seedRiskRoot mb
svc=.FederationBankMerchantRiskService~new(mb)
call buildWrongWayRisk mb,svc
acct=.FederationBankMerchantAccountingAdapter~new
acct~addPeriod("2026-08","2026-08-01","2026-08-31","OPEN")
call buildSettledAccountingRoot mb,acct

adapter=.FBMerchantWireAuthorityProjectionAdapter~new(mb,svc,acct)
feed=adapter~projectFeed
call assertEq 2,feed~rows~items,"only already-assessed CFD roots are projected"
call assertTrue adapter~authorityRevision~pos("bank:")=1,"authority revision binds bank"
call assertTrue adapter~authorityRevision~pos("|risk:")>0,"authority revision binds risk service"
call assertTrue adapter~authorityRevision~pos("|accounting:")>0,"authority revision binds accounting"

riskRow=feed~row("TR-RS-A")
call assertTrue riskRow<>.nil,"risk root projected"
call assertEq "CLIENT-RS",riskRow["clientEntity"],"root client comes from Merchant portfolio"
call assertEq "DIRECTIONAL_RESIDUAL",riskRow["riskState"],"fresh whole-book risk is projected"
call assertEq "EXECUTION_DIVERGENCE",riskRow["executionState"],"wrong-way execution is not collapsed"
call assertEq "URGENT",riskRow["attention"],"Risk Service deviation work escalates attention"
riskDetail=feed~detail("TR-RS-A")
call assertEq "WRONG_WAY_EXECUTION",riskDetail["checkpoint.divergenceReason"],"checkpoint diagnostic comes from Merchant domain evidence"
call assertEq -2000000,riskDetail["checkpoint.actualNetBaseExposure"],"actual doubled-short exposure is projected"
call assertEq "MSE-W",riskDetail["marketStructure.marketStructureEventId"],"market event is followed through exact equivalence evidence source"
call assertEq "HEDGE_IMPAIRED",riskDetail["marketStructure.riskState"],"impaired hedge state remains separate from book state"

settleRow=feed~row("TR-UI-SET")
call assertTrue settleRow<>.nil,"settlement root projected"
call assertEq "CLOSED",settleRow["clientState"],"customer close view comes from actual original CFD"
call assertEq 2,settleRow["contractCount"],"original and reversing CFDs remain monitored"
call assertEq 0,settleRow["netBaseExposure"],"actual book is net zero"
call assertEq "COMPLETE",settleRow["settlementState"],"exact external completion normalises to wire COMPLETE"
call assertEq "CONTROL_OPEN",settleRow["accountingState"],"cash settlement does not close derivative accounting control"
settleDetail=feed~detail("TR-UI-SET")
call assertEq "ACTIVE",settleDetail["contractState"],"client CLOSED does not destroy either CFD"
call assertEq "SETTLED",settleDetail["settlement.settlementState"],"raw Merchant settlement state is retained in evidence section"
call assertEq "SETTLE-UI-C",settleDetail["settlement.observationId"],"exact external observation evidence is projected"
call assertEq "SETTLEMENT-AGENT-UI",settleDetail["settlement.sourceAuthority"],"settlement source authority is attributable"
call assertEq 0,settleDetail["accounting.settlementReceivablePayable"],"settlement receivable is fully cleared"
call assertEq 30000000,settleDetail["accounting.cashAtSettlementAgent"],"cash-at-settlement-agent comes from Accounting Core journal lines"
call assertEq 30000000,settleDetail["accounting.derivativeSettlementControl"],"derivative control remains open after cash settlement"
call assertEq "DERIVATIVE_CONTROL_OPEN",settleDetail["accounting.controlState"],"accounting control state is independently projected"
call assertEq "NOT_RETAINED_BY_ACCOUNTING_AUTHORITY",settleDetail["accounting.settlementDeterminationState"],"UI does not invent a persisted settlement-rounding determination"

-- Refreshing replaces the projection rather than retaining stale rows.
feed~putBook(dummyRow("STALE"),dummyDetail("STALE"))
call assertEq 3,feed~rows~items,"test stale row inserted"
adapter~refreshFeed(feed)
call assertEq 2,feed~rows~items,"authority refresh removes stale projection rows"
call assertTrue feed~row("STALE")==.nil,"stale row cannot survive authority refresh"

-- The exact authority-derived feed binds unchanged to the sealed precompiled Wire UI release.
pkg=.json~fromJsonFile(directory()||"/semantic/federationbank_merchant_operations_v0.6.json")
runtime=.FBMerchantWireAuthorityRuntimeFactory~buildFromAuthorities("FBM-AUTH-APP","S-AUTH","WEB",mb,svc,acct,pkg)
call assertTrue runtime~ok,"authority feed binds to precompiled Server release"
app=runtime~value
call assertEq 2,app~workspaceResult("FBM.BOOKS")~totalCount,"server sees exactly authority-derived books"
call assertTrue app~view~instance("TR-RS-A") \== .nil,"server renders real risk root"
call assertTrue app~view~instance("TR-UI-SET") \== .nil,"server renders real settlement/accounting root"

fd=.directory~new; fd["filterRef"]="attention"; fd["value"]="URGENT"
r=app~receive(uiAction(app,"book-query","BOOKS.FILTER",fd)); call assertTrue r~ok,"server-side urgent filter accepts authority feed"
call assertEq 1,app~workspaceResult("FBM.BOOKS")~totalCount,"server-side filter narrows actual authority rows"
sel=.directory~new; sel["selectedIds"]=.array~of("TR-RS-A"); sel["scopeRevision"]=app~workspaceQuery("FBM.BOOKS")~scopeRevision
r=app~receive(uiAction(app,"book-query","BOOKS.SELECT",sel)); call assertTrue r~ok,"real risk root selection accepted"
wireDetail=app~view~instance("book-detail")
call assertEq "DIRECTIONAL_RESIDUAL",wireDetail["slots"]["economicState"],"server projects actual whole-book economic state"
call assertEq "DIRECTIONAL_RESIDUAL",wireDetail["slots"]["riskState"],"server projects whole-book risk state without collapsing hedge evidence"
wireCp=app~view~instance("execution-checkpoint")
call assertEq "WRONG_WAY_EXECUTION",wireCp["slots"]["divergenceReason"],"server projects actual wrong-way checkpoint"
call assertEq -2000000,wireCp["slots"]["actualNetBaseExposure"],"server projects actual transaction-time exposure"
wireMarket=app~view~instance("market-detail")
call assertEq "HEDGE_IMPAIRED",wireMarket["slots"]["riskState"],"server separately projects impaired hedge evidence"

-- Explicit refresh re-reads authority state; navigation actions do not own domain truth.
mb~createPortfolio("PF-LIVE-NEW","CLIENT-LIVE-NEW","GBP")
mb~bookTrade(.MBDerivativeTrade~new("TR-LIVE-NEW","PF-LIVE-NEW","CLIENT-LIVE-NEW","CFD","LONG","GBP",250000,0,0,"",1,"IDX-LIVE","","IDX-LIVE","2026-08-28T11:30:00Z"))
mb~assessCFDHedgeBook("HBA-LIVE-NEW","TR-LIVE-NEW","2026-08-28T11:31:00Z")
empty=.directory~new
r=app~receive(uiAction(app,"book-query","WORKSPACE.REFRESH",empty)); call assertTrue r~ok,"explicit workspace refresh re-reads authorities"
call assertEq 2,app~workspaceResult("FBM.BOOKS")~totalCount,"urgent-filtered workspace includes newly assessed live root after refresh"
call assertTrue app~view~instance("TR-LIVE-NEW") \== .nil,"new Merchant authority root appears only after refresh"

say "PASS Merchant authoritative multi-service projection adapter"
exit 0

::routine seedRiskRoot
  use strict arg mb
  src=.MBReferenceDocumentEvidence~new("DOC-RS","REF-AUTH","urn:test:risk-service","Risk service fixture","1","09:00","","SOURCE_OBSERVED")
  mb~recordReferenceDocumentEvidence(src)
  a=.MBInstrumentResolutionEvidence~new("RES-RS-A",src~documentEvidenceId,"RS-EQ","ISIN-RS","XLON","GBP","LINE-GBP","CRSTGB22","ORDINARY","GBP","GBP","line=A","09:00")
  b=.MBInstrumentResolutionEvidence~new("RES-RS-B",src~documentEvidenceId,"RS-EQ","ISIN-RS","XAMS","EUR","LINE-EUR","CUSTNL2A","ORDINARY","EUR","EUR","line=B","09:00")
  mb~recordInstrumentResolutionEvidence(a); mb~recordInstrumentResolutionEvidence(b)
  ia=mb~instrumentIdentityFromEvidence("RES-RS-A","GBP",1,"ISSUER-RS"); ib=mb~instrumentIdentityFromEvidence("RES-RS-B","EUR",1,"ISSUER-RS")
  permit=.MBDecisionEvidence~new("PERMITTED","PERMITTED","LEGAL-RS","POL-RS")
  mb~registerProduct(.MBDerivativeProductDefinition~new("CFD-RS-A","1","CFD","RS-EQ","GBP","CASH",permit,"","",1,ia)); mb~registerProduct(.MBDerivativeProductDefinition~new("CFD-RS-B","1","CFD","RS-EQ","EUR","CASH",permit,"","",1,ib))
  mb~createPortfolio("PF-RS-A","CLIENT-RS","GBP"); mb~createPortfolio("PF-RS-B","MM-RS","EUR")
  mb~bookTrade(.MBDerivativeTrade~new("TR-RS-A","PF-RS-A","CLIENT-RS","CFD","LONG","GBP",1000000,0,0,"",1,"RS","CFD-RS-A","RS-EQ","09:00"))
  mb~recordFXEvidence(.MBFXEvidence~new("FX-RS","FX-AUTH","GBP","EUR",1.20,"09:01","CURRENT"))
  off=.MBDerivativeTrade~new("TR-RS-B","PF-RS-B","MM-RS","CFD","SHORT","EUR",1200000,0,0,"",1,"RS","CFD-RS-B","RS-EQ","09:01","MM-RS","EXTERNAL_HEDGE")
  mb~bookCFDOffset("INT-RS","H-RS","TR-RS-A",off,"FX-RS","TRADE-AUTH","09:01")
  baseline=.MBMarketStructureEvent~new("MSE-RS-BASE","BASELINE","09:02","GB/NL","MARKET-AUTH","BASE","LEGAL-BASE","RES-RS-B",.true,.true,.true,.true,.true,"AVAILABLE")
  mb~applyMarketStructureEventToHedge(baseline,"H-RS","EQE-RS-BASE")
  mb~reassessHedgeRiskFromLatestKnown("HRA-RS-BASE","H-RS","EQE-RS-BASE","09:02")
  return

::routine buildWrongWayRisk
  use strict arg mb,svc
  p=.directory~new; p["hedgeId"]="H-RS"; p["policyRef"]="POL-RISK-SURV"
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
  mb~createPortfolio("PF-W1","MM-W1","EUR")
  wrong=.MBDerivativeTrade~new("TR-W1","PF-W1","MM-W1","CFD","SHORT","EUR",1200000,0,0,"",1,"RS","CFD-RS-B","RS-EQ","11:21","MM-W1","EXTERNAL_HEDGE")
  mb~bookCFDOffset("INT-W1","H-W1","TR-RS-A",wrong,"FX-RS","MERCHANT-TRADING-AUTH","11:21")
  mb~createPortfolio("PF-W2","MM-W2","EUR")
  replacement=.MBDerivativeTrade~new("TR-W2","PF-W2","MM-W2","CFD","SHORT","EUR",1200000,0,0,"",1,"RS","CFD-RS-B","RS-EQ","11:22","MM-W2","EXTERNAL_HEDGE")
  mb~bookCFDOffset("INT-W2","H-W2","TR-RS-A",replacement,"FX-RS","MERCHANT-TRADING-AUTH","11:22")
  p1=.directory~new; p1["evidenceId"]="EXEC-W-1"; p1["planId"]="PLAN-W"; p1["stepId"]="S1"; p1["executionSequence"]=1; p1["executionState"]="COMPLETED"; p1["sourceRef"]="FILL-W1"; p1["authorityRef"]="AUTH-W1"; p1["actualObjectRef"]="H-W1"; p1["observedSignedBaseExposureDelta"]=-1000000; p1["policyRef"]="POL-RISK-SURV"
  call mustOk svc~handle(.MBRiskServiceEnvelope~new("EW1","RISK.REMEDIATION.PLAN.EXECUTION.INGEST","MERCHANT-TRADING-AUTH","MERCHANT_EXECUTION_EVIDENCE",p1,"11:21")),"wrong-way evidence"
  p2=.directory~new; p2["evidenceId"]="EXEC-W-2"; p2["planId"]="PLAN-W"; p2["stepId"]="S2"; p2["executionSequence"]=2; p2["executionState"]="COMPLETED"; p2["sourceRef"]="FILL-W2"; p2["authorityRef"]="AUTH-W2"; p2["actualObjectRef"]="H-W2"; p2["observedSignedBaseExposureDelta"]=-1000000; p2["policyRef"]="POL-RISK-SURV"
  call mustOk svc~handle(.MBRiskServiceEnvelope~new("EW2","RISK.REMEDIATION.PLAN.EXECUTION.INGEST","MERCHANT-TRADING-AUTH","MERCHANT_EXECUTION_EVIDENCE",p2,"11:22")),"second wrong-way evidence"
  return

::routine buildSettledAccountingRoot
  use strict arg mb,acct
  p=mb~createPortfolio("PF-UI-SET","CLIENT-UI-SET","GBP")
  hp=mb~createPortfolio("PF-UI-H","MM-UI","GBP")
  mb~bookTrade(.MBDerivativeTrade~new("TR-UI-SET","PF-UI-SET","CLIENT-UI-SET","CFD","LONG","GBP",6000000,0,0,"",1,"IDX-UI","","IDX-UI","2026-08-28T08:00:00Z"))
  v=.MBValuationSnapshot~new("VAL-UI-SET","PF-UI-SET","2026-08-28T09:00:00Z","GBP",0,0,6000000,"MKTSET-UI")
  mb~recordValuation(v)
  policy=.MBRiskPolicy~new("POL-UI",6,0,3600)
  a=mb~assessMargin("ASS-UI","PF-UI-SET",v,policy,0,"2026-08-28T09:01:00Z")
  c=mb~issueMarginCall("CALL-UI",a~assessmentId,"2026-08-28T09:02:00Z","2026-08-28T10:02:00Z")
  i=mb~defaultMarginCall(c~callId,"NEUT-REQ-UI","MB-RISK-AUTH","2026-08-28T10:03:00Z")
  mb~recordMarketEvidence(.MBMarketEvidence~new("MKT-UI","EXCHANGE-A","IDX-UI","2026-08-28T10:04:00Z","GBP",100,"CURRENT"))
  results=.directory~new
  off=.MBDerivativeTrade~new("TR-UI-OFF","PF-UI-H","MM-UI","CFD","SHORT","GBP",6000000,0,0,"",1,"IDX-UI","","IDX-UI","2026-08-28T10:04:00Z","MM-UI","EXTERNAL_HEDGE")
  results["TR-UI-SET"]=.MBCFDNeutralisationResult~new("NR-UI","TR-UI-SET",off,"",250000,300000,"MKT-UI","MB-CLOSEOUT-AUTH")
  x=mb~executeRiskNeutralisation(i~instructionId,"NEUT-EXEC-UI",results,"2026-08-28T10:05:00Z","MB-CLOSEOUT-AUTH")
  h="NEUT-EXEC-UI:TR-UI-SET:HEDGE"
  mb~recordHedgeEquivalenceEvidence(.MBHedgeEquivalenceEvidence~new("EQE-UI",h,1,"","2026-08-28T10:05:01Z","GB","MB-HEDGE-AUTH","BASE-UI","LEGAL-UI","","",.true,.true,.true,.true,.true,"AVAILABLE"))
  mb~reassessHedgeRiskFromLatestKnown("HRA-UI",h,"EQE-UI","2026-08-28T10:05:02Z")
  o=mb~createNeutralisationSettlementObligation("OBL-UI","NEUT-EXEC-UI")
  scale=.MBAccountingCurrencyScaleEvidence~new("GBP-2DP-UI","GBP",100,"ACCOUNTING-POLICY","ISO4217:GBP")
  proj=.FederationBankMerchantAccountingProjectionV1~new
  oe=proj~projectSettlementObligation(mb,o,scale,"2026-08-28","2026-08")
  call acctOk acct~postSettlementObligation(oe),"account settlement obligation"
  ins=.MBSettlementInstructionEvidence~new("INS-UI","OBL-UI","CLIENT-UI-SET","FEDERATIONBANK_MERCHANT_BANK","GBP",300000,"SETTLEMENT-CHANNEL-UI","MB-SETTLEMENT-AUTH","2026-08-28T10:06:00Z")
  mb~recordSettlementInstruction(ins)
  obs=.MBSettlementObservationEvidence~new("SETTLE-UI-C","OBL-UI","INS-UI","AGENT-UI-RCPT-1","CLIENT-UI-SET","FEDERATIONBANK_MERCHANT_BANK","GBP",300000,"COMPLETE","2026-08-28T10:07:00Z","SETTLEMENT-AGENT-UI",.array~of("AGENT-RECEIPT:UI-1"))
  mb~recordSettlementObservation(obs)
  ae=proj~projectSettlementObservation(mb,obs,scale,"2026-08-28","2026-08")
  call acctOk acct~postSettlementObservation(ae),"account settlement observation"
  mb~assessCFDHedgeBook("HBA-UI-SET","TR-UI-SET","2026-08-28T10:08:00Z")
  return

::routine uiAction
  use strict arg app,instance,semantic,detail
  if detail==.nil then detail=.directory~new
  detail["workspaceContext"]=app~workspaceContext("FBM.BOOKS")
  m=.directory~new; m["type"]="UI_ACTION"; m["messageId"]="AUTH-M-"||app~view~revision||"-"||semantic; m["applicationId"]="FBM-AUTH-APP"; m["sessionId"]="S-AUTH"; m["accessPointId"]="WEB"; m["viewRef"]=app~view~viewRef; m["renderedRevision"]=app~view~revision; m["elementInstance"]=instance; m["action"]=semantic; m["detail"]=detail
  return m

::routine dummyRow
  use strict arg root
  d=.directory~new; d["schema"]="federationbank.merchant.wire-book-row/1"; d["rootTradeId"]=root; d["portfolioId"]="STALE-P"; d["clientEntity"]="STALE-C"; d["clientState"]="OPEN"; d["contractCount"]=1; d["netBaseExposure"]=0; d["currency"]="GBP"; d["riskState"]="CLEAR"; d["executionState"]="NONE"; d["remediationState"]="NONE"; d["settlementState"]="NONE"; d["accountingState"]="NONE"; d["attention"]="CLEAR"; return d
::routine dummyDetail
  use strict arg root
  d=.directory~new; d["schema"]="federationbank.merchant.wire-book-detail/1"; d["rootTradeId"]=root; return d
::routine mustOk
  use strict arg r,label
  if \r~ok then raise syntax 88.900 array("ASSERT_OK",label,r~code,r~detail)
  return
::routine acctOk
  use strict arg r,label
  if \r~ok then raise syntax 88.900 array("ASSERT_ACCOUNTING_OK",label,r~errorCode,r~message)
  return
::routine assertEq
  use strict arg expected,actual,label
  if expected<>actual then raise syntax 88.900 array("ASSERT_EQ",label,"expected",expected,"actual",actual)
  return
::routine assertTrue
  use strict arg value,label
  if \value then raise syntax 88.900 array("ASSERT_TRUE",label)
  return

::requires "json.cls"
::requires "FBMerchantWireAuthorityRuntimeFactory.cls"
::requires "FBMerchantWireUIApplication.cls"
::requires "FBMerchantWireAuthorityProjectionAdapter.cls"
::requires "FederationBankMerchantAccountingProjection.cls"
