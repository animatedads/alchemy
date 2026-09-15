msgSeq=0
feed=.FBMerchantWireProjectionFeed~new
call put feed,row("ROOT-A","P-A","CLIENT-A","CLOSED",2,0,"GBP","HEDGE_IMPAIRED","EXECUTION_DIVERGENCE","OPEN","COMPLETE","CONTROL_OPEN","URGENT"), detail("ROOT-A","P-A","CLIENT-A","CLOSED","ACTIVE",2,"NET_ZERO",0,"HEDGE_IMPAIRED","REM-A","OPEN","PLAN-A","DEVIATED","EXECUTION_DIVERGENCE","SET-A","COMPLETE","CONTROL_OPEN","DERIVATIVE_CONTROL_OPEN","HEDGE_IMPAIRED","EQ-A","HBA-A","VAL-A","2026-08-28T20:00:00Z",.true)
call put feed,row("ROOT-B","P-B","CLIENT-B","OPEN",1,125,"GBP","NET_ZERO_WITH_MONITORING","NOT_STARTED","NONE","NONE","COMPLETE","CLEAR"), detail("ROOT-B","P-B","CLIENT-B","OPEN","ACTIVE",1,"DIRECTIONAL",125,"NET_ZERO_WITH_MONITORING","","NONE","","NONE","","","NONE","COMPLETE","COMPLETE","CLEAR","","HBA-B","VAL-B","2026-08-28T20:01:00Z",.false)
pkg=.json~fromJsonFile(directory()||"/semantic/federationbank_merchant_operations_v0.6.json")
r=.FBMerchantWireRuntimeFactory~buildFromPackage("FBM-APP","S1","WEB",feed,pkg)
call assert r~ok,"runtime factory"
app=r~value
call assert app~workspaceResult("FBM.BOOKS")~totalCount=2,"initial two-book result"
call assert app~view~instance("ROOT-A") \== .nil,"urgent row projected"
call assert app~view~instance("ROOT-B") \== .nil,"clear row projected"

/* server-side filter invalidates selection scope and bounded collection */
d=.directory~new; d["filterRef"]="attention"; d["value"]="URGENT"
r=app~receive(action(app,"book-query","BOOKS.FILTER",d)); call assert r~ok,"filter accepted"
call assert app~workspaceResult("FBM.BOOKS")~totalCount=1,"filter is server-side"
call assert app~view~instance("ROOT-A") \== .nil,"urgent remains"
call assert app~view~instance("ROOT-B") == .nil,"out-of-scope row removed"

/* stale scope cannot select */
d=.directory~new; d["selectedIds"]=.array~of("ROOT-A"); d["scopeRevision"]=0
r=app~receive(action(app,"book-query","BOOKS.SELECT",d)); call assert \r~ok & r~code="FBM_SELECTION_SCOPE_STALE","stale selection rejected"

/* current selection projects independent truths without collapsing them */
d=.directory~new; d["selectedIds"]=.array~of("ROOT-A"); d["scopeRevision"]=app~workspaceQuery("FBM.BOOKS")~scopeRevision
r=app~receive(action(app,"book-query","BOOKS.SELECT",d)); call assert r~ok,"current selection"
detail=app~view~instance("book-detail")
call assert detail["slots"]["clientState"]="CLOSED","client closed projected"
call assert detail["slots"]["contractState"]="ACTIVE","contract remains active"
call assert detail["slots"]["riskState"]="HEDGE_IMPAIRED","risk remains impaired"
call assert detail["slots"]["settlementState"]="COMPLETE","settlement can be complete"
call assert detail["slots"]["accountingControlState"]="DERIVATIVE_CONTROL_OPEN","accounting control remains open"
cp=app~view~instance("execution-checkpoint")
call assert cp["slots"]["divergenceReason"]="WRONG_WAY_EXECUTION","wrong-way checkpoint projected"
call assert cp["slots"]["actualNetBaseExposure"]=-200,"actual checkpoint exposure projected"

/* sort/filter action surface is navigation only */
d=.directory~new; d["sortRef"]="BOGUS"; d["direction"]="ASC"
r=app~receive(action(app,"book-query","BOOKS.SORT",d)); call assert \r~ok & r~code="FBM_SORT_NOT_ALLOWED","unlisted sort rejected"
say "PASS Merchant Wire UI server-authoritative workspace"
exit 0

put: procedure
  use arg feed,row,detail
  feed~putBook(row,detail); return

action: procedure expose msgSeq
  use arg app,instance,semantic,detail
  msgSeq+=1
  if detail==.nil then detail=.directory~new
  detail["workspaceContext"]=app~workspaceContext("FBM.BOOKS")
  m=.directory~new; m["type"]="UI_ACTION"; m["messageId"]="M-"||msgSeq||"-"||app~view~revision||"-"||semantic; m["applicationId"]="FBM-APP"; m["sessionId"]="S1"; m["accessPointId"]="WEB"; m["viewRef"]=app~view~viewRef; m["renderedRevision"]=app~view~revision; m["elementInstance"]=instance; m["action"]=semantic; m["detail"]=detail; return m

row: procedure
  use arg root,portfolio,client,clientState,contracts,net,currency,risk,execution,remediation,settlement,accounting,attention
  d=.directory~new; d["schema"]="federationbank.merchant.wire-book-row/1"; d["rootTradeId"]=root; d["portfolioId"]=portfolio; d["clientEntity"]=client; d["clientState"]=clientState; d["contractCount"]=contracts; d["netBaseExposure"]=net; d["currency"]=currency; d["riskState"]=risk; d["executionState"]=execution; d["remediationState"]=remediation; d["settlementState"]=settlement; d["accountingState"]=accounting; d["attention"]=attention; return d

detail: procedure
  use arg root,portfolio,client,clientState,contractState,contractCount,economicState,net,risk,remId,remState,planId,planState,verification,settlementId,settlementState,accountingState,accountingControl,marketState,eqRef,assessmentId,valuationRef,asOf,includeEvidence
  d=.directory~new; d["schema"]="federationbank.merchant.wire-book-detail/1"; d["rootTradeId"]=root; d["portfolioId"]=portfolio; d["clientEntity"]=client; d["clientState"]=clientState; d["contractState"]=contractState; d["contractCount"]=contractCount; d["economicState"]=economicState; d["netBaseExposure"]=net; d["riskState"]=risk; d["remediationId"]=remId; d["remediationState"]=remState; d["planId"]=planId; d["planState"]=planState; d["verificationState"]=verification; d["settlementObligationId"]=settlementId; d["settlementState"]=settlementState; d["accountingState"]=accountingState; d["accountingControlState"]=accountingControl; d["marketStructureState"]=marketState; d["hedgeEquivalenceEvidenceRef"]=eqRef; d["bookAssessmentId"]=assessmentId; d["valuationRef"]=valuationRef; d["asOfRef"]=asOf
  if includeEvidence then do
    d["checkpoint.checkpointId"]="CP-A"; d["checkpoint.resultState"]="EXECUTION_DIVERGENCE"; d["checkpoint.divergenceReason"]="WRONG_WAY_EXECUTION"; d["checkpoint.executionState"]="PARTIAL"; d["checkpoint.evidenceId"]="E-A"; d["checkpoint.bookAssessmentId"]="HBA-CP-A"; d["checkpoint.assessedAt"]="2026-08-28T19:58:00Z"; d["checkpoint.actualNetBaseExposure"]=-200; d["checkpoint.expectedPlanPeakAbsBaseExposure"]=100; d["checkpoint.transientExposureBreach"]=.true
    d["settlement.obligationId"]="SET-A"; d["settlement.obligationAmount"]=123469; d["settlement.currency"]="GBP"; d["settlement.instructionId"]="SI-A"; d["settlement.instructionState"]="DISPATCHED"; d["settlement.instructionAmount"]=123469; d["settlement.observationId"]="SO-A"; d["settlement.observationState"]="COMPLETE"; d["settlement.observedAmount"]=123469; d["settlement.cumulativeObservedAmount"]=123469; d["settlement.externalSettlementRef"]="AGENT-RCPT-A"; d["settlement.sourceAuthority"]="SETTLEMENT_AGENT"; d["settlement.settlementState"]="COMPLETE"
    d["accounting.journalId"]="J-A"; d["accounting.journalStatus"]="POSTED"; d["accounting.policyRef"]="merchant.settlement/0.5"; d["accounting.policyIdentity"]="sha512:POLICY-A"; d["accounting.settlementReceivablePayable"]=0; d["accounting.cashAtSettlementAgent"]=123469; d["accounting.derivativeSettlementControl"]=123469; d["accounting.accountingState"]="CONTROL_OPEN"; d["accounting.controlState"]="DERIVATIVE_CONTROL_OPEN"; d["accounting.settlementDeterminationState"]="MERCHANT_SETTLEMENT_AMOUNT_AUTHORITY_REQUIRED"; d["accounting.determinedSettlementAmount"]=123470; d["accounting.roundingDifferenceMinor"]=1; d["accounting.settlementRulesetRef"]="RULESET-A"
    d["marketStructure.marketStructureEventId"]="MSE-A"; d["marketStructure.eventType"]="CUSTODY_RESTRICTION"; d["marketStructure.effectiveAt"]="2026-08-28T18:00:00Z"; d["marketStructure.instrumentEvidenceRef"]="INST-A"; d["marketStructure.hedgeClassification"]="CROSS_LISTED_HEDGE"; d["marketStructure.hedgeEquivalenceEvidenceRef"]="EQ-A"; d["marketStructure.riskState"]="HEDGE_IMPAIRED"
  end
  return d

assert: procedure
  use arg ok,msg
  if \ok then raise syntax 88.900 array("ASSERT",msg)
  return
::requires "json.cls"
::requires "FBMerchantWireUIApplication.cls"
