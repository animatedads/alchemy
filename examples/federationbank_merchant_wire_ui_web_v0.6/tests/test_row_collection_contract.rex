msgSeq=0
feed=.FBMerchantWireProjectionFeed~new
call put feed,row("ROOT-A","P-A","CLIENT-A","CLOSED",2,-200,"GBP","DIRECTIONAL_RESIDUAL","EXECUTION_DIVERGENCE","OPEN","COMPLETE","CONTROL_OPEN","URGENT"),detail("ROOT-A","P-A","CLIENT-A")
call put feed,row("ROOT-B","P-B","CLIENT-B","OPEN",2,0,"GBP","NET_ZERO_WITH_IMPAIRED_CONTRACTS","EXECUTING","OPEN","OPEN","SETTLEMENT_OPEN","ACTION_REQUIRED"),detail("ROOT-B","P-B","CLIENT-B")
call put feed,row("ROOT-C","P-C","CLIENT-C","OPEN",2,0,"GBP","NET_ZERO_WITH_COUNTERPARTY_RISK","NOT_STARTED","OPEN","NONE","NONE","MONITOR"),detail("ROOT-C","P-C","CLIENT-C")
call put feed,row("ROOT-D","P-D","CLIENT-D","OPEN",1,50,"GBP","DIRECTIONAL_RESIDUAL","NONE","NONE","OPEN","NONE","WAITING_EXTERNAL"),detail("ROOT-D","P-D","CLIENT-D")
call put feed,row("ROOT-E","P-E","CLIENT-E","OPEN",2,0,"GBP","CLEAR","NONE","NONE","NONE","COMPLETE","CLEAR"),detail("ROOT-E","P-E","CLIENT-E")
call put feed,row("ROOT-F","P-F","CLIENT-F","OPEN",2,0,"GBP","CLEAR","NONE","NONE","NONE","COMPLETE","CLEAR"),detail("ROOT-F","P-F","CLIENT-F")

pkg=.json~fromJsonFile(directory()||"/semantic/federationbank_merchant_operations_v0.6.json")
r=.FBMerchantWireRuntimeFactory~buildFromPackage("FBM-ROWS","S-ROWS","WEB",feed,pkg)
call assert r~ok,"runtime factory"
app=r~value

table=app~view~instance("book-table")
call assert table["slots"]["collectionRef"]="book-table","explicit collection identity"
call assert table["slots"]["windowTotalCount"]=6,"total count is separate scalar"
call assert table["slots"]["visibleRowCount"]=6,"visible count is separate scalar"
call assert table["children"]~items=6,"collection is represented by child rows, not a count field"
initialCtx=app~workspaceContext("FBM.BOOKS")
initialResult=initialCtx["resultRevision"]
initialSelection=initialCtx["selectionRevision"]

/* Windowing is first-class and does not mutate query/result/selection semantics. */
d=.directory~new; d["offset"]=0; d["limit"]=2
r=app~receive(action(app,"book-query","BOOKS.WINDOW",d)); call assert r~ok,"window request accepted"
table=app~view~instance("book-table")
call assert table["slots"]["windowOffset"]=0 & table["slots"]["windowLimit"]=2,"authoritative window metadata"
call assert table["slots"]["windowTotalCount"]=6 & table["slots"]["visibleRowCount"]=2,"total and visible counts not overloaded"
call assert table["children"]~items=2,"only requested window materialised"
call assert table["children"][1]="ROOT-A" & table["children"][2]="ROOT-B","default ordered window"
ra=app~view~instance("ROOT-A")
call assert ra["slots"]["semanticRowId"]="ROOT-A","semantic row identity explicit"
call assert ra["slots"]["rootTradeId"]="ROOT-A","semantic identity is domain identity, not position"
ctx=app~workspaceContext("FBM.BOOKS")
call assert ctx["queryRevision"]=initialCtx["queryRevision"],"window does not change query revision"
call assert ctx["scopeRevision"]=initialCtx["scopeRevision"],"window does not change scope revision"
call assert ctx["orderRevision"]=initialCtx["orderRevision"],"window does not change order revision"
call assert ctx["selectionRevision"]=initialSelection,"window does not change selection revision"
call assert ctx["resultRevision"]=initialResult,"window does not manufacture result revision"

/* Selection binds to semantic identity. */
d=.directory~new; d["selectedIds"]=.array~of("ROOT-A"); d["scopeRevision"]=ctx["scopeRevision"]
r=app~receive(action(app,"book-query","BOOKS.SELECT",d)); call assert r~ok,"semantic row selected"
selectedCtx=app~workspaceContext("FBM.BOOKS")
call assert selectedCtx["selectedIds"]~items=1 & selectedCtx["selectedIds"][1]="ROOT-A","selection stores semantic id"
call assert selectedCtx["selectionRevision"]=initialSelection+1,"selection revision advances"
call assert selectedCtx["resultRevision"]=initialResult,"selection does not change result revision"

/* Sorting changes order but preserves selection identity even if selected row leaves visible window. */
d=.directory~new; d["sortRef"]="ROOT_TRADE_ID"; d["direction"]="DESC"
r=app~receive(action(app,"book-query","BOOKS.SORT",d)); call assert r~ok,"sort accepted"
sortedCtx=app~workspaceContext("FBM.BOOKS")
call assert sortedCtx["orderRevision"]=selectedCtx["orderRevision"]+1,"order revision advances"
call assert sortedCtx["selectionRevision"]=selectedCtx["selectionRevision"],"sort preserves selection revision"
call assert sortedCtx["selectedIds"][1]="ROOT-A","sort preserves semantic selection"
call assert sortedCtx["resultRevision"]=selectedCtx["resultRevision"]+1,"new ordering has independent result revision"
table=app~view~instance("book-table")
call assert table["children"][1]="ROOT-F" & table["children"][2]="ROOT-E","sort reorders visible rows"
call assert app~view~instance("ROOT-A")==.nil,"selected row can be outside visible window"
call assert app~view~instance("book-detail")["slots"]["rootTradeId"]="ROOT-A","selected semantic detail survives window membership"

/* Paging/window movement preserves semantic selection and result identity. */
d=.directory~new; d["offset"]=2; d["limit"]=2
r=app~receive(action(app,"book-query","BOOKS.WINDOW",d)); call assert r~ok,"second window accepted"
windowCtx=app~workspaceContext("FBM.BOOKS")
call assert windowCtx["selectedIds"][1]="ROOT-A","paging preserves semantic selection"
call assert windowCtx["selectionRevision"]=sortedCtx["selectionRevision"],"paging does not alter selection revision"
call assert windowCtx["resultRevision"]=sortedCtx["resultRevision"],"paging does not alter whole-result revision"
table=app~view~instance("book-table")
call assert table["slots"]["windowOffset"]=2 & table["children"]~items=2,"second window materialised"

/* Filtering changes membership scope and invalidates selection, even if the selected ID still matches. */
d=.directory~new; d["filterRef"]="attention"; d["value"]="URGENT"
r=app~receive(action(app,"book-query","BOOKS.FILTER",d)); call assert r~ok,"membership filter accepted"
filteredCtx=app~workspaceContext("FBM.BOOKS")
call assert filteredCtx["scopeRevision"]=windowCtx["scopeRevision"]+1,"scope revision advances"
call assert filteredCtx["selectionRevision"]=windowCtx["selectionRevision"]+1,"scope change invalidates selection"
call assert filteredCtx["selectedIds"]~items=0,"selection cleared on membership scope change"
table=app~view~instance("book-table")
call assert table["slots"]["windowOffset"]=0,"filter resets window to first page"
call assert table["slots"]["windowTotalCount"]=1 & table["children"][1]="ROOT-A","filtered membership authoritative"
call assert app~view~instance("book-detail")["slots"]["visible"]=.false,"detail hidden after scope invalidation"

/* Business/result revision advances independently from selection revision. */
staleCtx=app~workspaceContext("FBM.BOOKS")
call put feed,row("ROOT-A","P-A","CLIENT-A","CLOSED",2,-250,"GBP","DIRECTIONAL_RESIDUAL","EXECUTION_DIVERGENCE","OPEN","COMPLETE","CONTROL_OPEN","URGENT"),detail("ROOT-A","P-A","CLIENT-A")
r=app~receive(actionWithContext(app,"book-query","WORKSPACE.REFRESH",.directory~new,staleCtx)); call assert r~ok,"refresh after authority-feed change"
newCtx=app~workspaceContext("FBM.BOOKS")
call assert newCtx["selectionRevision"]=staleCtx["selectionRevision"],"business refresh leaves selection revision independent"
call assert newCtx["resultRevision"]=staleCtx["resultRevision"]+1,"business refresh advances result revision"
call assert app~view~instance("ROOT-A")["slots"]["netBaseExposure"]=-250,"changed row data projected under same semantic id"

/* Current UI revision with stale result context still fails closed. */
d=.directory~new; d["sortRef"]="ROOT_TRADE_ID"; d["direction"]="ASC"
r=app~receive(actionWithContext(app,"book-query","BOOKS.SORT",d,staleCtx))
call assert \r~ok & r~code="WORKSPACE_RESULT_REVISION_MISMATCH","stale result context rejected independently"

say "PASS Merchant first-class row/list/window/revision contract"
exit 0

put: procedure
  use arg feed,r,d
  feed~putBook(r,d); return

action: procedure expose msgSeq
  use arg app,instance,semantic,detail
  return actionWithContext(app,instance,semantic,detail,app~workspaceContext("FBM.BOOKS"))

actionWithContext: procedure expose msgSeq
  use arg app,instance,semantic,detail,ctx
  msgSeq+=1
  if detail==.nil then detail=.directory~new
  detail["workspaceContext"]=ctx
  m=.directory~new; m["type"]="UI_ACTION"; m["messageId"]="ROW-M-"||msgSeq||"-"||app~view~revision||"-"||semantic; m["applicationId"]="FBM-ROWS"; m["sessionId"]="S-ROWS"; m["accessPointId"]="WEB"; m["viewRef"]=app~view~viewRef; m["renderedRevision"]=app~view~revision; m["elementInstance"]=instance; m["action"]=semantic; m["detail"]=detail; return m

row: procedure
  use arg root,portfolio,client,clientState,contracts,net,currency,risk,execution,remediation,settlement,accounting,attention
  d=.directory~new; d["schema"]="federationbank.merchant.wire-book-row/1"; d["rootTradeId"]=root; d["portfolioId"]=portfolio; d["clientEntity"]=client; d["clientState"]=clientState; d["contractCount"]=contracts; d["netBaseExposure"]=net; d["currency"]=currency; d["riskState"]=risk; d["executionState"]=execution; d["remediationState"]=remediation; d["settlementState"]=settlement; d["accountingState"]=accounting; d["attention"]=attention; return d

detail: procedure
  use arg root,portfolio,client
  d=.directory~new; d["schema"]="federationbank.merchant.wire-book-detail/1"; d["rootTradeId"]=root; d["portfolioId"]=portfolio; d["clientEntity"]=client; d["clientState"]="OPEN"; d["contractState"]="ACTIVE"; d["contractCount"]=1; d["economicState"]="DIRECTIONAL"; d["netBaseExposure"]=0; d["riskState"]="CLEAR"; d["remediationId"]=""; d["remediationState"]="NONE"; d["planId"]=""; d["planState"]="NONE"; d["verificationState"]=""; d["settlementObligationId"]=""; d["settlementState"]="NONE"; d["accountingState"]="NONE"; d["accountingControlState"]="NONE"; d["marketStructureState"]=""; d["hedgeEquivalenceEvidenceRef"]=""; d["bookAssessmentId"]="HBA-"||root; d["valuationRef"]=""; d["asOfRef"]="2026-08-29T10:00:00Z"; return d

assert: procedure
  use arg ok,msg
  if \ok then raise syntax 88.900 array("ASSERT",msg)
  return
::requires "json.cls"
::requires "FBMerchantWireUIApplication.cls"
