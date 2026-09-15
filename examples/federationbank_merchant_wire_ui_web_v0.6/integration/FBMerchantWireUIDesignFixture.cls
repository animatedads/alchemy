/* Wire UI Builder source-of-truth for the FederationBank Merchant operator workspace v0.6. */
::class FBMerchantWireUIDesignFixture public
::method build class
  w=.WireUIDesignWorkspace~new("FederationBank.Merchant.Operations")

  shellSlots=self~slots(.array~of("merchantEntity","perimeter","asOfRef"),"TEXT"); shellSlots["visible"]="BOOLEAN"
  summarySlots=self~slots(.array~of("totalBooks","riskAttention","executionDivergence","settlementOpen","accountingOpen","clientClosed"),"INTEGER")
  querySlots=self~slots(.array~of("workspaceRef","riskState","settlementState","accountingState","clientState","attention","sortRef","sortDirection"),"TEXT")
  tableSlots=self~slots(.array~of("windowOffset","windowLimit","windowTotalCount","visibleRowCount","windowRevision","queryRevision","scopeRevision","orderRevision","selectionRevision","resultRevision"),"INTEGER"); tableText=self~slots(.array~of("collectionRef","sortRef","filterRef","anchorRef"),"TEXT"); do k over tableText~allIndexes; tableSlots[k]=tableText[k]; end
  contextSlots=self~slots(.array~of("workspaceRef","selectedIdsJson"),"TEXT"); do k over .array~of("queryRevision","scopeRevision","orderRevision","selectionRevision","resultRevision","resultQueryRevision","resultScopeRevision","resultOrderRevision"); contextSlots[k]="INTEGER"; end; contextSlots["visible"]="BOOLEAN"
  openSlots=self~slots(.array~of("workspaceRef","semanticRowId","label"),"TEXT")
  rowSlots=self~slots(.array~of("workspaceRef","semanticRowId","rootTradeId","portfolioId","clientEntity","clientState","riskState","executionState","remediationState","settlementState","accountingState","attention","currency"),"TEXT")
  rowSlots["contractCount"]="INTEGER"; rowSlots["netBaseExposure"]="DECIMAL"
  detailSlots=self~slots(.array~of("rootTradeId","portfolioId","clientEntity","clientState","contractState","economicState","riskState","remediationId","remediationState","planId","planState","verificationState","settlementObligationId","settlementState","accountingState","accountingControlState","marketStructureState","hedgeEquivalenceEvidenceRef","bookAssessmentId","valuationRef","asOfRef"),"TEXT")
  detailSlots["contractCount"]="INTEGER"; detailSlots["netBaseExposure"]="DECIMAL"; detailSlots["visible"]="BOOLEAN"
  checkpointSlots=self~slots(.array~of("checkpointId","resultState","divergenceReason","executionState","evidenceId","bookAssessmentId","assessedAt"),"TEXT")
  checkpointSlots["actualNetBaseExposure"]="DECIMAL"; checkpointSlots["expectedPlanPeakAbsBaseExposure"]="DECIMAL"; checkpointSlots["transientExposureBreach"]="BOOLEAN"; checkpointSlots["visible"]="BOOLEAN"
  settlementSlots=self~slots(.array~of("obligationId","instructionId","instructionState","observationId","observationState","externalSettlementRef","sourceAuthority","currency","settlementState"),"TEXT")
  settlementSlots["obligationAmount"]="DECIMAL"; settlementSlots["instructionAmount"]="DECIMAL"; settlementSlots["observedAmount"]="DECIMAL"; settlementSlots["cumulativeObservedAmount"]="DECIMAL"; settlementSlots["visible"]="BOOLEAN"
  accountingSlots=self~slots(.array~of("journalId","journalStatus","policyRef","policyIdentity","accountingState","controlState","settlementDeterminationState","settlementRulesetRef"),"TEXT")
  accountingSlots["settlementReceivablePayable"]="DECIMAL"; accountingSlots["cashAtSettlementAgent"]="DECIMAL"; accountingSlots["derivativeSettlementControl"]="DECIMAL"; accountingSlots["determinedSettlementAmount"]="DECIMAL"; accountingSlots["roundingDifferenceMinor"]="DECIMAL"; accountingSlots["visible"]="BOOLEAN"
  marketSlots=self~slots(.array~of("marketStructureEventId","eventType","effectiveAt","instrumentEvidenceRef","hedgeClassification","hedgeEquivalenceEvidenceRef","riskState"),"TEXT"); marketSlots["visible"]="BOOLEAN"

  shell=.WireUIVisualComponent~new("FBM_APP_SHELL","1","PANEL",shellSlots,.array~of("surface"),.array~new)
  summary=.WireUIVisualComponent~new("FBM_TRUTH_SUMMARY","1","SEMANTIC_RECORD",summarySlots,.array~of("surface","status"),.array~new)
  query=.WireUIVisualComponent~new("FBM_BOOK_QUERY","1","FORM",querySlots,.array~of("surface","field","action"),.array~of("SEMANTIC_ACTION"))
  table=.WireUIVisualComponent~new("FBM_BOOK_TABLE","1","SEMANTIC_RECORD",tableSlots,.array~of("surface","collection"),.array~of("SEMANTIC_ACTION"))
  context=.WireUIVisualComponent~new("FBM_WORKSPACE_CONTEXT","1","SEMANTIC_RECORD",contextSlots,.array~new,.array~new)
  openButton=.WireUIVisualComponent~new("FBM_BOOK_OPEN","1","ACTION_BUTTON",openSlots,.array~of("action"),.array~of("SEMANTIC_ACTION"))
  row=.WireUIVisualComponent~new("FBM_BOOK_ROW","1","SEMANTIC_RECORD",rowSlots,.array~of("surface","status","action"),.array~of("SEMANTIC_ACTION"))
  detail=.WireUIVisualComponent~new("FBM_BOOK_DETAIL","1","SEMANTIC_RECORD",detailSlots,.array~of("surface","status","evidence"),.array~new)
  checkpoint=.WireUIVisualComponent~new("FBM_EXECUTION_CHECKPOINT","1","SEMANTIC_RECORD",checkpointSlots,.array~of("surface","status","evidence"),.array~new)
  settlement=.WireUIVisualComponent~new("FBM_SETTLEMENT_DETAIL","1","SEMANTIC_RECORD",settlementSlots,.array~of("surface","status","evidence"),.array~new)
  accounting=.WireUIVisualComponent~new("FBM_ACCOUNTING_DETAIL","1","SEMANTIC_RECORD",accountingSlots,.array~of("surface","status","evidence"),.array~new)
  market=.WireUIVisualComponent~new("FBM_MARKET_STRUCTURE_DETAIL","1","SEMANTIC_RECORD",marketSlots,.array~of("surface","status","evidence"),.array~new)
  do x over .array~of(shell,summary,query,table,context,openButton,row,detail,checkpoint,settlement,accounting,market); call must w~register(x); end

  eShell=.WireUISemanticElement~new("FBM_APP","1","APPLICATION",.array~of("merchantEntity","perimeter","asOfRef"),.array~new,"MERCHANT_OPERATOR")
  eSummary=.WireUISemanticElement~new("FBM_TRUTH_SUMMARY","1","INDEPENDENT_TRUTH_SUMMARY",summarySlots~allIndexes,.array~new,"MERCHANT_OPERATOR")
  eQuery=.WireUISemanticElement~new("FBM_BOOK_QUERY","1","WORKSPACE_QUERY",querySlots~allIndexes,.array~of("BOOKS.FILTER","BOOKS.SORT","BOOKS.WINDOW","BOOKS.SELECT","WORKSPACE.REFRESH"),"MERCHANT_OPERATOR")
  eTable=.WireUISemanticElement~new("FBM_BOOK_TABLE","1","WORKSPACE_COLLECTION",.array~new,.array~new,"MERCHANT_OPERATOR")
  eContext=.WireUISemanticElement~new("FBM_WORKSPACE_CONTEXT","1","WORKSPACE_COMMAND_CONTEXT",contextSlots~allIndexes,.array~new,"MERCHANT_OPERATOR")
  eOpen=.WireUISemanticElement~new("FBM_BOOK_OPEN","1","BOOK_ROW_OPEN_ACTION",.array~of("workspaceRef","semanticRowId"),.array~of("BOOK.OPEN"),"MERCHANT_OPERATOR")
  eRow=.WireUISemanticElement~new("FBM_BOOK_ROW","1","CUSTOMER_ROOTED_CFD_BOOK",rowSlots~allIndexes,.array~of("BOOK.OPEN"),"MERCHANT_OPERATOR")
  eDetail=.WireUISemanticElement~new("FBM_BOOK_DETAIL","1","MERCHANT_BOOK_DETAIL",detailSlots~allIndexes,.array~new,"MERCHANT_OPERATOR")
  eCheckpoint=.WireUISemanticElement~new("FBM_EXECUTION_CHECKPOINT","1","REMEDIATION_EXECUTION_CHECKPOINT",checkpointSlots~allIndexes,.array~new,"MERCHANT_OPERATOR")
  eSettlement=.WireUISemanticElement~new("FBM_SETTLEMENT_DETAIL","1","SETTLEMENT_EVIDENCE_CHAIN",settlementSlots~allIndexes,.array~new,"MERCHANT_OPERATOR")
  eAccounting=.WireUISemanticElement~new("FBM_ACCOUNTING_DETAIL","1","ACCOUNTING_CONTROL_DETAIL",accountingSlots~allIndexes,.array~new,"MERCHANT_OPERATOR")
  eMarket=.WireUISemanticElement~new("FBM_MARKET_STRUCTURE_DETAIL","1","MARKET_STRUCTURE_EVIDENCE",marketSlots~allIndexes,.array~new,"MERCHANT_OPERATOR")
  do x over .array~of(eShell,eSummary,eQuery,eTable,eContext,eOpen,eRow,eDetail,eCheckpoint,eSettlement,eAccounting,eMarket); call must w~register(x); end

  tokens=.table~new; tokens["brand.ink"]="#08285c"; tokens["brand.alert"]="#b42318"; tokens["surface"]="#ffffff"; tokens["density"]="compact"; tokens["space.unit"]="8"
  recipes=.table~new; recipes["workspace"]="merchant/workspace"; recipes["book.row"]="merchant/book.row"; recipes["evidence"]="merchant/evidence"; recipes["risk"]="merchant/risk"
  material=.WireUIMaterialSet~new("FBM_MATERIAL","1",tokens,recipes); call must w~register(material)

  pShell=self~projection("FBM_APP_SHELL",eShell,shell,"FBM_APP_SHELL","workspace",self~bindings(.array~of("merchantEntity","perimeter","asOfRef")))
  pSummary=self~projection("FBM_TRUTH_SUMMARY",eSummary,summary,"FBM_TRUTH_SUMMARY","workspace",self~bindings(.array~of("totalBooks","riskAttention","executionDivergence","settlementOpen","accountingOpen","clientClosed")))
  pQuery=self~projection("FBM_BOOK_QUERY",eQuery,query,"FBM_BOOK_QUERY","workspace",self~bindings(.array~of("workspaceRef","riskState","settlementState","accountingState","clientState","attention","sortRef","sortDirection")))
  pTable=self~projection("FBM_BOOK_TABLE",eTable,table,"FBM_BOOK_TABLE","workspace",self~bindings(.array~of("collectionRef","windowOffset","windowLimit","windowTotalCount","visibleRowCount","windowRevision","sortRef","filterRef","anchorRef","queryRevision","scopeRevision","orderRevision","selectionRevision","resultRevision")))
  pContext=self~projection("FBM_WORKSPACE_CONTEXT",eContext,context,"FBM_WORKSPACE_CONTEXT","workspace",self~bindings(.array~of("workspaceRef","selectedIdsJson","queryRevision","scopeRevision","orderRevision","selectionRevision","resultRevision","resultQueryRevision","resultScopeRevision","resultOrderRevision","visible")))
  pOpen=.WireUIProjectionDesign~new("FBM_BOOK_OPEN","1","HUMAN_VISUAL",eOpen~ref,openButton~ref,"FBM_BOOK_OPEN","BOOK.OPEN","book.row","book.row",self~bindings(.array~of("workspaceRef","semanticRowId","label")))
  pRow=self~projection("FBM_BOOK_ROW",eRow,row,"FBM_BOOK_ROW","book.row",self~bindings(.array~of("workspaceRef","semanticRowId","rootTradeId","portfolioId","clientEntity","clientState","contractCount","netBaseExposure","currency","riskState","executionState","remediationState","settlementState","accountingState","attention")))
  pDetail=self~projection("FBM_BOOK_DETAIL",eDetail,detail,"FBM_BOOK_DETAIL","workspace",self~bindings(.array~of("rootTradeId","portfolioId","clientEntity","clientState","contractState","contractCount","economicState","netBaseExposure","riskState","remediationId","remediationState","planId","planState","verificationState","settlementObligationId","settlementState","accountingState","accountingControlState","marketStructureState","hedgeEquivalenceEvidenceRef","bookAssessmentId","valuationRef","asOfRef")))
  pCheckpoint=self~projection("FBM_EXECUTION_CHECKPOINT",eCheckpoint,checkpoint,"FBM_EXECUTION_CHECKPOINT","risk",self~bindings(.array~of("checkpointId","resultState","divergenceReason","executionState","evidenceId","bookAssessmentId","assessedAt","actualNetBaseExposure","expectedPlanPeakAbsBaseExposure","transientExposureBreach")))
  pSettlement=self~projection("FBM_SETTLEMENT_DETAIL",eSettlement,settlement,"FBM_SETTLEMENT_DETAIL","evidence",self~bindings(.array~of("obligationId","obligationAmount","currency","instructionId","instructionState","instructionAmount","observationId","observationState","observedAmount","cumulativeObservedAmount","externalSettlementRef","sourceAuthority","settlementState")))
  pAccounting=self~projection("FBM_ACCOUNTING_DETAIL",eAccounting,accounting,"FBM_ACCOUNTING_DETAIL","evidence",self~bindings(.array~of("journalId","journalStatus","policyRef","policyIdentity","settlementReceivablePayable","cashAtSettlementAgent","derivativeSettlementControl","accountingState","controlState","settlementDeterminationState","determinedSettlementAmount","roundingDifferenceMinor","settlementRulesetRef")))
  pMarket=self~projection("FBM_MARKET_STRUCTURE_DETAIL",eMarket,market,"FBM_MARKET_STRUCTURE_DETAIL","evidence",self~bindings(.array~of("marketStructureEventId","eventType","effectiveAt","instrumentEvidenceRef","hedgeClassification","hedgeEquivalenceEvidenceRef","riskState")))
  do x over .array~of(pShell,pSummary,pQuery,pTable,pContext,pOpen,pRow,pDetail,pCheckpoint,pSettlement,pAccounting,pMarket); call must w~register(x); end

  j=.WireUIJourneyDesign~new("FBM_OPERATIONS_WORKSPACE","1","OPERATIONS")
  call must j~defineState("OPERATIONS",.array~of("FBM_APP","FBM_TRUTH_SUMMARY","FBM_BOOK_QUERY","FBM_BOOK_TABLE","FBM_WORKSPACE_CONTEXT","FBM_BOOK_OPEN","FBM_BOOK_ROW","FBM_BOOK_DETAIL","FBM_EXECUTION_CHECKPOINT","FBM_SETTLEMENT_DETAIL","FBM_ACCOUNTING_DETAIL","FBM_MARKET_STRUCTURE_DETAIL"),.array~new,.array~new)
  call must j~seal; call must w~register(j)

  release=.WireUISiteRelease~new("FEDERATIONBANK_MERCHANT_OPERATIONS","2026.09.01.1")
  do x over .array~of(shell,summary,query,table,context,openButton,row,detail,checkpoint,settlement,accounting,market,eShell,eSummary,eQuery,eTable,eContext,eOpen,eRow,eDetail,eCheckpoint,eSettlement,eAccounting,eMarket,material,pShell,pSummary,pQuery,pTable,pContext,pOpen,pRow,pDetail,pCheckpoint,pSettlement,pAccounting,pMarket,j); call must release~pin(x~ref); end
  call must release~seal; call must w~register(release)
  d=.directory~new; d["workspace"]=w; d["release"]=release; d["journey"]=j; return d

::method slots class private
  use arg names,type
  s=.table~new; do name over names; s[name]=type; end; return s
::method bindings class private
  use arg names
  b=.table~new; do name over names; b[name]=name; end; return b
::method projection class private
  use arg id,element,component,definitionId,role,bindings
  return .WireUIProjectionDesign~new(id,"1","HUMAN_VISUAL",element~ref,component~ref,definitionId,"",role,role,bindings)

::routine must
  use arg r
  if r~isA(.WireUIDesignResult) then if \r~ok then raise syntax 88.900 array(r~code,r~detail)
  return r
::requires "WireUIBuilderAll.cls"
