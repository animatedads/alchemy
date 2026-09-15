/* Wire UI Builder source-of-truth for FederationBank Staff Banking. */
::class FederationBankStaffWireUIDesignFixture public
::method build class
  w=.WireUIDesignWorkspace~new("FederationBank.StaffBanking")

  shellSlots=.table~new
  do k over .array~of("staffId","sessionId","branchId","deskId","authorityScope","accessEntryRef","methodPermissionMode"); shellSlots[k]="TEXT"; end
  shellSlots["visible"]="BOOLEAN"

  summarySlots=.table~new
  do k over .array~of("total","received","approvalRequired","readyForCore","completed","coreRejected","rejected","noBankAction"); summarySlots[k]="INTEGER"; end

  querySlots=.table~new
  querySlots["stateFilter"]="TEXT"; querySlots["sortRef"]="TEXT"; querySlots["sortDirection"]="TEXT"

  tableSlots=.table~new
  do k over .array~of("windowTotalCount","windowRevision","queryRevision","scopeRevision","orderRevision","selectionRevision","resultRevision"); tableSlots[k]="INTEGER"; end

  rowSlots=.table~new
  do k over .array~of("workId","customerId","operation","state","outcomeCode","route","staffId","branchId","currency","updatedAt","coreCode"); rowSlots[k]="TEXT"; end
  rowSlots["amountMinor"]="INTEGER"; rowSlots["revision"]="INTEGER"; rowSlots["checkerRequired"]="BOOLEAN"

  detailSlots=.table~new
  do k over .array~of("workId","customerId","operation","state","outcomeCode","detail","route","staffId","branchId","deskId","sessionId","sourceAccountId","targetAccountId","currency","updatedAt","coreCode","ruleId","authorityScope"); detailSlots[k]="TEXT"; end
  detailSlots["amountMinor"]="INTEGER"; detailSlots["revision"]="INTEGER"; detailSlots["checkerRequired"]="BOOLEAN"; detailSlots["visible"]="BOOLEAN"

  actionSlots=.table~new
  do k over .array~of("operation","customerId","sourceAccountId","targetAccountId","currency","lastSubmissionCode","lastWorkId","lastSubmissionAt","authorityScope","methodPermissionMode"); actionSlots[k]="TEXT"; end
  actionSlots["amountMinor"]="INTEGER"; actionSlots["visible"]="BOOLEAN"

  shell=.WireUIVisualComponent~new("FB_STAFF_APP_SHELL","1","PANEL",shellSlots,.array~of("surface","status"),.array~new)
  summary=.WireUIVisualComponent~new("FB_STAFF_SUMMARY","1","SEMANTIC_RECORD",summarySlots,.array~of("surface","status"),.array~new)
  query=.WireUIVisualComponent~new("FB_STAFF_WORK_QUERY","1","FORM",querySlots,.array~of("surface","field","action"),.array~of("SEMANTIC_ACTION"))
  table=.WireUIVisualComponent~new("FB_STAFF_WORK_TABLE","1","SEMANTIC_RECORD",tableSlots,.array~of("surface","collection"),.array~new)
  row=.WireUIVisualComponent~new("FB_STAFF_WORK_ROW","1","SEMANTIC_RECORD",rowSlots,.array~of("surface","status","action"),.array~of("SEMANTIC_ACTION"))
  detail=.WireUIVisualComponent~new("FB_STAFF_WORK_DETAIL","1","SEMANTIC_RECORD",detailSlots,.array~of("surface","status"),.array~new)
  actionPanel=.WireUIVisualComponent~new("FB_STAFF_CUSTOMER_ACTION","1","FORM",actionSlots,.array~of("surface","field","action","evidence"),.array~of("SEMANTIC_ACTION"))
  do x over .array~of(shell,summary,query,table,row,detail,actionPanel); call must w~register(x); end

  eShell=.WireUISemanticElement~new("FB_STAFF_APP","1","APPLICATION",.array~of("staffId","sessionId","branchId","deskId","authorityScope"),.array~new,"STAFF_BANKING")
  eSummary=.WireUISemanticElement~new("FB_STAFF_WORK_SUMMARY","1","OPERATIONAL_SUMMARY",.array~of("total","approvalRequired","readyForCore","completed","rejected"),.array~new,"STAFF_BANKING")
  eQuery=.WireUISemanticElement~new("FB_STAFF_WORK_QUERY","1","WORKSPACE_QUERY",.array~of("stateFilter","sortRef","sortDirection"),.array~of("WORK.FILTER","WORK.SORT","WORK.SELECT","WORK.REFRESH"),"STAFF_BANKING")
  eTable=.WireUISemanticElement~new("FB_STAFF_WORK_TABLE","1","WORKSPACE_COLLECTION",.array~new,.array~new,"STAFF_BANKING")
  eRow=.WireUISemanticElement~new("FB_STAFF_WORK_ROW","1","STAFF_WORK",.array~of("workId","customerId","operation","state","outcomeCode","amountMinor","currency"),.array~of("WORK.OPEN"),"STAFF_BANKING")
  eDetail=.WireUISemanticElement~new("FB_STAFF_WORK_DETAIL","1","STAFF_WORK_DETAIL",.array~of("workId","state","outcomeCode","route","coreCode","checkerRequired"),.array~new,"STAFF_BANKING")
  eAction=.WireUISemanticElement~new("FB_STAFF_CUSTOMER_TRANSFER","1","CUSTOMER_INSTRUCTION",.array~of("customerId","sourceAccountId","targetAccountId","currency","amountMinor"),.array~of("CUSTOMER.TRANSFER.SUBMIT"),"STAFF_BANKING")
  do x over .array~of(eShell,eSummary,eQuery,eTable,eRow,eDetail,eAction); call must w~register(x); end

  tokens=.table~new; tokens["brand.ink"]="#14213d"; tokens["surface"]="#ffffff"; tokens["density"]="compact"; tokens["space.unit"]="8"
  recipes=.table~new; recipes["workspace"]="staff/workspace"; recipes["work.row"]="staff/work.row"; recipes["action"]="staff/customer.action"
  material=.WireUIMaterialSet~new("FB_STAFF_MATERIAL","1",tokens,recipes); call must w~register(material)

  pShell=.WireUIProjectionDesign~new("FB_STAFF_APP_SHELL","1","HUMAN_VISUAL",eShell~ref,shell~ref,"FB_STAFF_APP_SHELL","","workspace","workspace",self~bindings(.array~of("staffId","sessionId","branchId","deskId","authorityScope","accessEntryRef","methodPermissionMode")))
  pSummary=.WireUIProjectionDesign~new("FB_STAFF_SUMMARY","1","HUMAN_VISUAL",eSummary~ref,summary~ref,"FB_STAFF_SUMMARY","","workspace","workspace",self~bindings(.array~of("total","received","approvalRequired","readyForCore","completed","coreRejected","rejected","noBankAction")))
  pQuery=.WireUIProjectionDesign~new("FB_STAFF_WORK_QUERY","1","HUMAN_VISUAL",eQuery~ref,query~ref,"FB_STAFF_WORK_QUERY","","workspace","workspace",self~bindings(.array~of("stateFilter","sortRef","sortDirection")))
  pTable=.WireUIProjectionDesign~new("FB_STAFF_WORK_TABLE","1","HUMAN_VISUAL",eTable~ref,table~ref,"FB_STAFF_WORK_TABLE","","workspace","workspace",self~bindings(.array~of("windowTotalCount","windowRevision","queryRevision","scopeRevision","orderRevision","selectionRevision","resultRevision")))
  pRow=.WireUIProjectionDesign~new("FB_STAFF_WORK_ROW","1","HUMAN_VISUAL",eRow~ref,row~ref,"FB_STAFF_WORK_ROW","","work.row","work.row",self~bindings(.array~of("workId","customerId","operation","state","outcomeCode","route","staffId","branchId","currency","updatedAt","coreCode","amountMinor","revision","checkerRequired")))
  pDetail=.WireUIProjectionDesign~new("FB_STAFF_WORK_DETAIL","1","HUMAN_VISUAL",eDetail~ref,detail~ref,"FB_STAFF_WORK_DETAIL","","workspace","workspace",self~bindings(.array~of("workId","customerId","operation","state","outcomeCode","detail","route","staffId","branchId","deskId","sessionId","sourceAccountId","targetAccountId","currency","updatedAt","coreCode","ruleId","authorityScope","amountMinor","revision","checkerRequired")))
  pAction=.WireUIProjectionDesign~new("FB_STAFF_CUSTOMER_ACTION","1","HUMAN_VISUAL",eAction~ref,actionPanel~ref,"FB_STAFF_CUSTOMER_ACTION","","action","action",self~bindings(.array~of("operation","customerId","sourceAccountId","targetAccountId","currency","amountMinor","lastSubmissionCode","lastWorkId","lastSubmissionAt","authorityScope","methodPermissionMode")))
  do x over .array~of(pShell,pSummary,pQuery,pTable,pRow,pDetail,pAction); call must w~register(x); end

  j=.WireUIJourneyDesign~new("FB_STAFF_BANKING_WORKSPACE","1","WORKSPACE")
  call must j~defineState("WORKSPACE",.array~of("FB_STAFF_APP","FB_STAFF_WORK_SUMMARY","FB_STAFF_WORK_QUERY","FB_STAFF_WORK_TABLE","FB_STAFF_WORK_ROW","FB_STAFF_WORK_DETAIL","FB_STAFF_CUSTOMER_TRANSFER"),.array~new,.array~new)
  call must j~seal; call must w~register(j)

  release=.WireUISiteRelease~new("FEDERATIONBANK_STAFF_BANKING","2026.08.28.1")
  do x over .array~of(shell,summary,query,table,row,detail,actionPanel,eShell,eSummary,eQuery,eTable,eRow,eDetail,eAction,material,pShell,pSummary,pQuery,pTable,pRow,pDetail,pAction,j); call must release~pin(x~ref); end
  call must release~seal; call must w~register(release)
  d=.directory~new; d["workspace"]=w; d["release"]=release; d["journey"]=j; return d

::method bindings class private
  use arg names
  b=.table~new
  do name over names; b[name]=name; end
  return b

::routine must
  use arg r
  if r~isA(.WireUIDesignResult) then if \r~ok then raise syntax 88.994 array(r~code,r~detail)
  return r

::requires "WireUIBuilderAll.cls"
