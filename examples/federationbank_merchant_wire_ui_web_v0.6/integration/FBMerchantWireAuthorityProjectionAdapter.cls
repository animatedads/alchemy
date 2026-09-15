/*
 * FederationBank Merchant Banking authoritative read projection adapter v0.1.
 *
 * Reads already-authoritative Merchant Bank v0.15, Merchant Risk Service v0.5
 * and Merchant Accounting Adapter v0.5 state and emits the bounded scalar
 * projection consumed by FBMerchantWireApplication.  It never creates domain
 * assessments, risk work, settlement evidence, accounting journals or other
 * business mutations.
 */
::class FBMerchantWireAuthorityProjectionAdapter public
::constant VERSION "0.1"
::constant API_VERSION "federationbank.merchant.wire-authority-projection/0.1"

::method init
  expose bank risk accounting merchantEntity
  use strict arg bankArg,riskArg,accountingArg
  if bankArg==.nil | \bankArg~isA(.FederationBankMerchantBank) then raise syntax 88.900 array("FederationBankMerchantBank required")
  if riskArg==.nil | \riskArg~isA(.FederationBankMerchantRiskService) then raise syntax 88.900 array("FederationBankMerchantRiskService required")
  if accountingArg==.nil | \accountingArg~isA(.FederationBankMerchantAccountingAdapter) then raise syntax 88.900 array("FederationBankMerchantAccountingAdapter required")
  if riskArg~book \== bankArg then raise syntax 88.900 array("Merchant Risk Service must reference the projected Merchant Bank authority")
  if accountingArg~merchantEntity<>bankArg~merchantEntity then raise syntax 88.900 array("Merchant accounting legal entity mismatch")
  bank=bankArg; risk=riskArg; accounting=accountingArg; merchantEntity=bankArg~merchantEntity

::method api
  return self~API_VERSION

::method authorityRevision
  expose bank risk accounting
  return "bank:"||bank~journalPoint~string||"|risk:"||risk~state~sequence||"|accounting:"||accounting~book~entryCount

::method projectFeed
  feed=.FBMerchantWireProjectionFeed~new
  return self~refreshFeed(feed)

::method refreshFeed
  expose bank
  use strict arg feed
  if feed==.nil | \feed~isA(.FBMerchantWireProjectionFeed) then raise syntax 88.900 array("FBMerchantWireProjectionFeed required")
  feed~clear
  roots=self~assessedRootTradeIds
  do root over roots
    projected=self~projectRoot(root)
    if projected<>.nil then feed~putBook(projected["row"],projected["detail"])
  end
  return feed

::method assessedRootTradeIds private
  expose bank
  seen=.directory~new; roots=.array~new; journal=bank~journal
  do key over journal~allIndexes
    k=key~string
    if k~length<14 then iterate
    if k~substr(1,14)<>"hedgeBookRisk:" then iterate
    a=journal~at(k)
    if a==.nil | \a~isA(.MBCFDHedgeBookAssessment) then iterate
    root=a~rootTradeId~string~upper
    latest=bank~latestCFDHedgeBookAssessment(root)
    if latest==.nil then iterate
    if \seen~hasIndex(root) then do; seen[root]=.true; roots~append(root); end
  end
  roots~sort
  return roots

::method projectRoot private
  expose bank
  use strict arg root
  a=bank~latestCFDHedgeBookAssessment(root)
  if a==.nil then return .nil
  t=bank~journal~at("trade:"||root)
  if t==.nil | \t~isA(.MBDerivativeTrade) then return .nil
  if t~productType<>"CFD" then return .nil
  p=bank~portfolio(t~portfolioId)
  if p==.nil then return .nil

  remInfo=self~remediationInfo(a)
  settleInfo=self~settlementInfo(p~portfolioId)
  acctInfo=self~accountingInfo(settleInfo)
  marketInfo=self~marketInfo(a)
  riskInfo=self~riskInfo(a,remInfo,settleInfo,acctInfo)

  row=.directory~new
  row["schema"]="federationbank.merchant.wire-book-row/1"
  row["rootTradeId"]=root
  row["portfolioId"]=p~portfolioId
  row["clientEntity"]=p~clientEntity
  row["clientState"]=t~clientViewState
  row["contractCount"]=a~contractCount
  row["netBaseExposure"]=a~netBaseExposure
  row["currency"]=a~baseCurrency
  row["riskState"]=a~state
  row["executionState"]=remInfo["executionState"]
  row["remediationState"]=remInfo["remediationState"]
  row["settlementState"]=settleInfo["wireState"]
  row["accountingState"]=acctInfo["accountingState"]
  row["attention"]=riskInfo["attention"]

  d=.directory~new
  d["schema"]="federationbank.merchant.wire-book-detail/1"
  d["rootTradeId"]=root
  d["portfolioId"]=p~portfolioId
  d["clientEntity"]=p~clientEntity
  d["clientState"]=t~clientViewState
  d["contractState"]=self~contractState(a)
  d["contractCount"]=a~contractCount
  if a~netBaseExposure=0 then d["economicState"]="NET_ZERO"; else d["economicState"]="DIRECTIONAL_RESIDUAL"
  d["netBaseExposure"]=a~netBaseExposure
  d["riskState"]=a~state
  d["remediationId"]=remInfo["remediationId"]
  d["remediationState"]=remInfo["remediationState"]
  d["planId"]=remInfo["planId"]
  d["planState"]=remInfo["planState"]
  d["verificationState"]=remInfo["verificationState"]
  d["settlementObligationId"]=settleInfo["obligationId"]
  d["settlementState"]=settleInfo["wireState"]
  d["accountingState"]=acctInfo["accountingState"]
  d["accountingControlState"]=acctInfo["controlState"]
  d["marketStructureState"]=marketInfo["marketState"]
  d["hedgeEquivalenceEvidenceRef"]=marketInfo["equivalenceRef"]
  d["bookAssessmentId"]=a~assessmentId
  d["valuationRef"]=self~latestValuationRef(p~portfolioId)
  d["asOfRef"]=a~asAt

  ignore=self~copyPrefixed(remInfo,d,"checkpoint",.array~of("checkpointId","resultState","divergenceReason","executionState","evidenceId","bookAssessmentId","assessedAt","actualNetBaseExposure","expectedPlanPeakAbsBaseExposure","transientExposureBreach"))
  ignore=self~copyPrefixed(settleInfo,d,"settlement",.array~of("obligationId","obligationAmount","currency","instructionId","instructionState","instructionAmount","observationId","observationState","observedAmount","cumulativeObservedAmount","externalSettlementRef","sourceAuthority","settlementState"))
  ignore=self~copyPrefixed(acctInfo,d,"accounting",.array~of("journalId","journalStatus","policyRef","policyIdentity","settlementReceivablePayable","cashAtSettlementAgent","derivativeSettlementControl","accountingState","controlState","settlementDeterminationState","determinedSettlementAmount","roundingDifferenceMinor","settlementRulesetRef"))
  ignore=self~copyPrefixed(marketInfo,d,"marketStructure",.array~of("marketStructureEventId","eventType","effectiveAt","instrumentEvidenceRef","hedgeClassification","hedgeEquivalenceEvidenceRef","riskState"))

  out=.directory~new; out["row"]=row; out["detail"]=d; return out

::method remediationInfo private
  expose bank
  use strict arg assessment
  out=.directory~new
  out["remediationId"]=""; out["remediationState"]="NONE"; out["planId"]=""; out["planState"]="NONE"; out["verificationState"]=""; out["executionState"]="NONE"
  out["checkpointId"]=""; out["resultState"]=""; out["divergenceReason"]=""; out["evidenceId"]=""; out["bookAssessmentId"]=""; out["assessedAt"]=""; out["actualNetBaseExposure"]=0; out["expectedPlanPeakAbsBaseExposure"]=0; out["transientExposureBreach"]=.false
  best=.nil; bestRank=-1
  hedgeIds=self~sortedCopy(assessment~hedgeIds)
  do hid over hedgeIds
    r=bank~currentHedgeRemediation(hid)
    if r==.nil then iterate
    rank=self~remediationRank(r~state)
    if rank>bestRank then do; best=r; bestRank=rank; end
  end
  if best==.nil then return out
  out["remediationId"]=best~remediationId; out["remediationState"]=best~state
  p=bank~currentHedgeRemediationPlan(best~remediationId)
  if p==.nil then return out
  out["planId"]=p~planId; out["planState"]=p~state; out["executionState"]=p~state
  c=bank~latestHedgeRemediationPlanExecutionCheckpoint(p~planId)
  if c<>.nil then do
    out["checkpointId"]=c~checkpointId; out["resultState"]=c~resultState; out["divergenceReason"]=c~divergenceReason; out["executionState"]=c~executionState; out["evidenceId"]=c~evidenceId; out["bookAssessmentId"]=c~bookAssessmentId; out["assessedAt"]=c~assessedAt; out["actualNetBaseExposure"]=c~actualNetBaseExposure; out["expectedPlanPeakAbsBaseExposure"]=c~expectedPlanPeakAbsBaseExposure; out["transientExposureBreach"]=c~transientExposureBreach
    if c~resultState="EXECUTION_DIVERGENCE" then out["executionState"]="EXECUTION_DIVERGENCE"
  end
  v=bank~latestHedgeRemediationPlanExecutionVerification(p~planId)
  if v<>.nil then do
    out["verificationState"]=v~resultState
    if v~resultState="EXECUTION_DIVERGENCE" then out["executionState"]="EXECUTION_DIVERGENCE"
  end
  return out

::method settlementInfo private
  expose bank
  use strict arg portfolioId
  out=.directory~new
  out["obligationId"]=""; out["obligationAmount"]=0; out["currency"]=""; out["instructionId"]=""; out["instructionState"]=""; out["instructionAmount"]=0; out["observationId"]=""; out["observationState"]=""; out["observedAmount"]=0; out["cumulativeObservedAmount"]=0; out["externalSettlementRef"]=""; out["sourceAuthority"]=""; out["settlementState"]="NONE"; out["wireState"]="NONE"; out["obligation"] = .nil
  chosen=.nil; chosenAt=""; chosenRank=-1
  j=bank~journal
  do key over j~allIndexes
    k=key~string
    if k~length<11 then iterate
    if k~substr(1,11)<>"obligation:" then iterate
    o=j~at(k)
    if o==.nil | \o~isA(.MBSettlementObligation) then iterate
    x=j~at("riskNeutralisation:"||o~sourceRef)
    if x==.nil then x=j~at("closeOutExecution:"||o~sourceRef)
    if x==.nil then iterate
    if x~portfolioId<>portfolioId then iterate
    a=bank~settlementStatusAssessment(o~obligationId); at=""
    if a<>.nil then at=a~asAt
    rank=self~settlementRank(o~status)
    if chosen==.nil | rank>chosenRank | (rank=chosenRank & at>chosenAt) then do; chosen=o; chosenAt=at; chosenRank=rank; end
  end
  if chosen==.nil then return out
  o=chosen; out["obligation"]=o; out["obligationId"]=o~obligationId; out["obligationAmount"]=o~amount; out["currency"]=o~currency; out["cumulativeObservedAmount"]=o~settledAmount; out["settlementState"]=o~status; out["wireState"]=self~settlementWireState(o~status)
  instructions=bank~settlementInstructionsForObligation(o~obligationId)
  i=.nil
  if o~currentInstructionRef<>"" then i=bank~settlementInstruction(o~currentInstructionRef)
  else if instructions~items>0 then i=instructions[instructions~items]
  if i<>.nil then do
    out["instructionId"]=i~instructionId; out["instructionAmount"]=i~amount
    if o~currentInstructionRef=i~instructionId then out["instructionState"]="OPEN"
    else out["instructionState"]="CLOSED_OR_SUPERSEDED"
  end
  observations=bank~settlementObservationsForObligation(o~obligationId)
  if observations~items>0 then do
    e=observations[observations~items]
    out["observationId"]=e~evidenceId; out["observationState"]=e~outcome; out["observedAmount"]=e~amount; out["externalSettlementRef"]=e~externalSettlementRef; out["sourceAuthority"]=e~sourceAuthority
    if i<>.nil & e~instructionId=i~instructionId then do
      if e~outcome="COMPLETE" then out["instructionState"]="COMPLETE"
      else if e~outcome="FAILED" then out["instructionState"]="FAILED"
      else if e~outcome="PARTIAL" then out["instructionState"]="OPEN"
    end
  end
  return out

::method accountingInfo private
  expose accounting
  use strict arg settlementInfo
  out=.directory~new
  out["journalId"]=""; out["journalStatus"]=""; out["policyRef"]=""; out["policyIdentity"]=""; out["settlementReceivablePayable"]=0; out["cashAtSettlementAgent"]=0; out["derivativeSettlementControl"]=0; out["accountingState"]="NONE"; out["controlState"]="NONE"; out["settlementDeterminationState"]="NONE"; out["determinedSettlementAmount"]=0; out["roundingDifferenceMinor"]=0; out["settlementRulesetRef"]=""
  o=settlementInfo["obligation"]
  if o==.nil then return out
  entries=accounting~book~entriesByCorrelation(o~obligationId)
  if entries~items=0 then do; out["accountingState"]="UNACCOUNTED_OBLIGATION"; out["controlState"]="NOT_ACCOUNTED"; return out; end
  rp=0; cash=0; control=0; latest=entries[entries~items]
  do e over entries
    do line over e~lines
      select
        when line~accountId="1315" then rp=rp+line~debitMinor-line~creditMinor
        when line~accountId="2315" then rp=rp+line~creditMinor-line~debitMinor
        when line~accountId="1105" then cash=cash+abs(line~debitMinor-line~creditMinor)
        when line~accountId="1395" then control=control+line~debitMinor-line~creditMinor
        when line~accountId="2395" then control=control+line~creditMinor-line~debitMinor
        otherwise nop
      end
    end
  end
  if rp<0 then rp=abs(rp)
  if control<0 then control=abs(control)
  out["journalId"]=latest~entryId; out["journalStatus"]="POSTED"; out["policyRef"]=latest~policyRef; out["policyIdentity"]=latest~policyIdentity; out["settlementReceivablePayable"]=rp; out["cashAtSettlementAgent"]=cash; out["derivativeSettlementControl"]=control
  if rp>0 then out["accountingState"]="SETTLEMENT_OPEN"
  else if control>0 then out["accountingState"]="CONTROL_OPEN"
  else out["accountingState"]="COMPLETE"
  if control>0 then out["controlState"]="DERIVATIVE_CONTROL_OPEN"; else out["controlState"]="CLEAR"
  if accounting~settlementAmountApi<>"" then out["settlementDeterminationState"]="NOT_RETAINED_BY_ACCOUNTING_AUTHORITY"
  return out

::method marketInfo private
  expose bank
  use strict arg assessment
  out=.directory~new
  out["marketStructureEventId"]=""; out["eventType"]=""; out["effectiveAt"]=""; out["instrumentEvidenceRef"]=""; out["hedgeClassification"]=""; out["hedgeEquivalenceEvidenceRef"]=""; out["riskState"]=""; out["marketState"]="NONE"; out["equivalenceRef"]=""
  chosenEq=.nil; chosenH=.nil
  hedgeIds=self~sortedCopy(assessment~hedgeIds)
  do hid over hedgeIds
    h=bank~hedgeRelationship(hid); if h==.nil then iterate
    eq=bank~latestHedgeEquivalenceEvidence(hid)
    if eq==.nil then iterate
    if chosenEq==.nil then do; chosenEq=eq; chosenH=h; end
    else if eq~equivalenceState="IMPAIRED" & chosenEq~equivalenceState<>"IMPAIRED" then do; chosenEq=eq; chosenH=h; end
    else if eq~equivalenceState=chosenEq~equivalenceState & eq~effectiveAt>chosenEq~effectiveAt then do; chosenEq=eq; chosenH=h; end
  end
  if chosenEq==.nil then return out
  eq=chosenEq; h=chosenH
  out["hedgeClassification"]=h~relationshipType; out["hedgeEquivalenceEvidenceRef"]=eq~evidenceId; out["equivalenceRef"]=eq~evidenceId; out["effectiveAt"]=eq~effectiveAt; out["riskState"]=h~economicState; out["marketState"]=h~economicState
  if eq~originalInstrumentEvidenceRef<>"" then out["instrumentEvidenceRef"]=eq~originalInstrumentEvidenceRef; else out["instrumentEvidenceRef"]=eq~offsetInstrumentEvidenceRef
  ev=bank~marketStructureEvent(eq~sourceRef)
  if ev<>.nil then do
    out["marketStructureEventId"]=ev~eventId; out["eventType"]=ev~eventType; out["effectiveAt"]=ev~effectiveAt; out["instrumentEvidenceRef"]=ev~affectedInstrumentEvidenceRef
  end
  else do
    out["eventType"]="HEDGE_EQUIVALENCE_EVIDENCE"
    out["marketStructureEventId"]=""
  end
  return out

::method riskInfo private
  expose risk
  use strict arg assessment,remediationInfo,settlementInfo,accountingInfo
  out=.directory~new; attention="CLEAR"
  select
    when assessment~state="DIRECTIONAL_RESIDUAL" then attention="URGENT"
    when assessment~state="NET_ZERO_WITH_IMPAIRED_CONTRACTS" then attention="ACTION_REQUIRED"
    when assessment~state="NET_ZERO_WITH_UNPROVED_EQUIVALENCE" then attention="ACTION_REQUIRED"
    when assessment~state="NET_ZERO_WITH_COUNTERPARTY_RISK" then attention="MONITOR"
    otherwise attention="CLEAR"
  end
  do w over risk~openWork
    bound=(w~rootTradeId=assessment~rootTradeId)
    if \bound & w~hedgeId<>"" then bound=assessment~hasHedge(w~hedgeId)
    if \bound then iterate
    if w~workType="REMEDIATION_PLAN_EXECUTION_DEVIATION" | w~reasonCode="WRONG_WAY_EXECUTION" | w~reasonCode="TRANSIENT_EXPOSURE_BREACH" then attention="URGENT"
    else if attention<>"URGENT" then attention="ACTION_REQUIRED"
  end
  if remediationInfo["executionState"]="EXECUTION_DIVERGENCE" then attention="URGENT"
  if attention="CLEAR" & settlementInfo["wireState"]<>"NONE" & settlementInfo["wireState"]<>"COMPLETE" then attention="WAITING_EXTERNAL"
  if attention="CLEAR" & accountingInfo["accountingState"]<>"NONE" & accountingInfo["accountingState"]<>"COMPLETE" then attention="MONITOR"
  out["attention"]=attention; return out

::method contractState private
  expose bank
  use strict arg assessment
  active=0; inactive=0
  do tid over assessment~tradeIds
    t=bank~journal~at("trade:"||tid)
    if t==.nil then do; inactive+=1; iterate; end
    if t~contractState="ACTIVE" then active+=1; else inactive+=1
  end
  if active>0 & inactive=0 then return "ACTIVE"
  if active=0 & inactive>0 then return "INACTIVE"
  return "MIXED"

::method latestValuationRef private
  expose bank
  use strict arg portfolioId
  best=""; bestAt=""; j=bank~journal
  do key over j~allIndexes
    k=key~string
    if k~length<10 then iterate
    if k~substr(1,10)<>"valuation:" then iterate
    v=j~at(k)
    if v==.nil | \v~isA(.MBValuationSnapshot) then iterate
    if v~portfolioId<>portfolioId then iterate
    if best="" | v~asAt>bestAt then do; best=v~valuationId; bestAt=v~asAt; end
  end
  return best

::method remediationRank private
  use strict arg state
  select
    when state="ESCALATED" then return 5
    when state="OPEN" then return 4
    when state="ACTION_RECORDED" then return 4
    when state="MITIGATED_MONITORING" then return 3
    when state="RESOLVED" then return 1
    otherwise return 0
  end

::method settlementRank private
  use strict arg state
  select
    when state="PARTIALLY_SETTLED" then return 5
    when state="INSTRUCTED" then return 4
    when state="UNSETTLED" then return 3
    when state="SETTLED" then return 1
    otherwise return 0
  end

::method settlementWireState private
  use strict arg state
  select
    when state="SETTLED" then return "COMPLETE"
    when state="PARTIALLY_SETTLED" then return "PARTIAL"
    when state="INSTRUCTED" then return "INSTRUCTED"
    when state="UNSETTLED" then return "OPEN"
    otherwise return "NONE"
  end

::method sortedCopy private
  use strict arg source
  a=.array~new; do x over source; a~append(x); end; a~sort; return a

::method copyPrefixed private
  use strict arg source,target,prefix,names
  do k over names
    if source~hasIndex(k) then target[prefix||"."||k]=source[k]
  end
  return .true

::requires "FBMerchantWireProjectionFeed.cls"
::requires "FederationBankMerchantRiskService.cls"
::requires "FederationBankMerchantAccountingAdapter.cls"
