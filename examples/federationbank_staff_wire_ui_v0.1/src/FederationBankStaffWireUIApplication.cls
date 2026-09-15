/* FederationBank Staff Banking server-authoritative Wire UI v0.1. */
::class FederationBankStaffWireUIApplicationBuild public
::constant VERSION "0.1"
::constant API_VERSION "federationbank.staff.wire-ui/0.1"

::class FederationBankStaffWireApplication subclass WireUIApplication public
::method init
  expose readModel permissionPort actionPort staffId channelSessionId branchId deskId accessEntryRef windowRevision
  use strict arg applicationId,sessionId,accessPointId,view,projection,readModelArg,permissionPortArg,actionPortArg,staffIdArg,channelSessionIdArg,branchIdArg,deskIdArg,accessEntryRefArg
  self~init:super(applicationId,sessionId,accessPointId,view,projection)
  if readModelArg==.nil | permissionPortArg==.nil | actionPortArg==.nil then raise syntax 88.994 array("Staff Wire backend ports required")
  readModel=readModelArg; permissionPort=permissionPortArg; actionPort=actionPortArg
  staffId=staffIdArg~string; channelSessionId=channelSessionIdArg~string; branchId=branchIdArg~string~upper; deskId=deskIdArg~string~upper; accessEntryRef=accessEntryRefArg~string
  if staffId="" | channelSessionId="" | branchId="" | deskId="" | accessEntryRef="" then raise syntax 88.994 array("server-owned Staff Wire context required")
  windowRevision=0

::method installInitialView
  expose staffId channelSessionId branchId deskId accessEntryRef
  v=self~view; p=self~projection
  shell=.table~new; shell["visible"]=.true; shell["staffId"]=staffId; shell["sessionId"]=channelSessionId; shell["branchId"]=branchId; shell["deskId"]=deskId; shell["authorityScope"]="CUSTOMER"; shell["accessEntryRef"]=accessEntryRef; shell["methodPermissionMode"]="EXACT_OBJECT_METHOD_REQUIRED"
  call must v~createInstance("root","FB_STAFF_APP_SHELL@1",shell)

  summary=.table~new
  do k over .array~of("total","received","approvalRequired","readyForCore","completed","coreRejected","rejected","noBankAction"); summary[k]=0; end
  call must v~createInstance("summary","FB_STAFF_SUMMARY@1",summary,"root")

  query=.table~new; query["stateFilter"]="ALL"; query["sortRef"]="WORK_ID"; query["sortDirection"]="ASC"; query["actions"]=.array~of("WORK.FILTER","WORK.SORT","WORK.SELECT","WORK.REFRESH")
  call must v~createInstance("work-query","FB_STAFF_WORK_QUERY@1",query,"root")
  do a over query["actions"]; v~setActionAvailable("work-query",a,.true); end

  table=.table~new
  do k over .array~of("windowTotalCount","windowRevision","queryRevision","scopeRevision","orderRevision","selectionRevision","resultRevision"); table[k]=0; end
  call must v~createInstance("work-table","FB_STAFF_WORK_TABLE@1",table,"root")

  detail=.table~new; detail["visible"]=.false; detail["workspaceRef"]="FB.STAFF.WORK"; detail["authorityScope"]="CUSTOMER"
  call must v~createInstance("work-detail","FB_STAFF_WORK_DETAIL@1",detail,"root")

  action=.table~new; action["visible"]=.true; action["operation"]="TRANSFER"; action["customerId"]=""; action["sourceAccountId"]=""; action["targetAccountId"]=""; action["currency"]="GBP"; action["amountMinor"]=0; action["lastSubmissionCode"]=""; action["lastWorkId"]=""; action["lastSubmissionAt"]=""; action["authorityScope"]="CUSTOMER"; action["methodPermissionMode"]="EXACT_OBJECT_METHOD_REQUIRED"; action["actions"]=.array~of("CUSTOMER.TRANSFER.SUBMIT")
  call must v~createInstance("customer-transfer","FB_STAFF_CUSTOMER_ACTION@1",action,"root")
  v~setActionAvailable("customer-transfer","CUSTOMER.TRANSFER.SUBMIT",.true)

  call must self~registerWorkspace("FB.STAFF.WORK")
  p~bindSlots("summary.group","summary"); p~bindSlots("table.group","work-table"); p~bindSlots("detail.group","work-detail"); p~bindSlots("action.group","customer-transfer")
  r=self~refreshDashboard
  if \r~ok then return r
  return .WireUIResult~success(self,"FB_STAFF_WIRE_INITIAL_VIEW_INSTALLED")

::method refreshDashboard
  expose readModel windowRevision
  q=self~workspaceQuery("FB.STAFF.WORK"); filters=q~filters; qw=q~asWire; sortRef="WORK_ID"; direction="ASC"
  if qw~hasIndex("sort") then do; sortRef=qw["sort"]["sortRef"]; direction=qw["sort"]["direction"]; end
  rows=readModel~rows(filters,sortRef,direction)
  wireRows=.array~new
  do r over rows
    row=.directory~new; row["instanceId"]=r["workId"]; row["definitionKey"]="FB_STAFF_WORK_ROW@1"; row["slots"]=self~rowSlots(r); wireRows~append(row)
  end
  windowRevision+=1
  window=.WireUICollectionWindow~new("work-table",0,100,rows~items,sortRef||":"||direction,self~filterRef(filters),windowRevision,"")
  rr=self~reconcileCollectionWindow("work-table",wireRows,window); if \rr~ok then return rr
  do r over rows; self~view~setActionAvailable(r["workId"],"WORK.OPEN",.true); end

  s=readModel~summary(filters)
  sumSlots=.table~new; sumSlots["total"]=s["TOTAL"]; sumSlots["received"]=s["RECEIVED"]; sumSlots["approvalRequired"]=s["APPROVAL_REQUIRED"]; sumSlots["readyForCore"]=s["READY_FOR_CORE"]; sumSlots["completed"]=s["COMPLETED"]; sumSlots["coreRejected"]=s["CORE_REJECTED"]; sumSlots["rejected"]=s["REJECTED"]; sumSlots["noBankAction"]=s["NO_BANK_ACTION"]
  mr=self~mutateState("summary.group",sumSlots); if \mr~ok then return mr

  ag=.table~new; ag["TOTAL"]=rows~items; ag["APPROVAL_REQUIRED"]=s["APPROVAL_REQUIRED"]; ag["READY_FOR_CORE"]=s["READY_FOR_CORE"]
  pr=self~publishWorkspaceResult("FB.STAFF.WORK",rows~items,ag,"FEDERATIONBANK_STAFF_CHANNEL_STATE","WINDOW:"||windowRevision); if \pr~ok then return pr
  sel=self~workspaceSelection("FB.STAFF.WORK")
  rs=self~workspaceResult("FB.STAFF.WORK")
  tableSlots=.table~new; tableSlots["windowTotalCount"]=rows~items; tableSlots["windowRevision"]=windowRevision; tableSlots["queryRevision"]=q~queryRevision; tableSlots["scopeRevision"]=q~scopeRevision; tableSlots["orderRevision"]=q~orderRevision; tableSlots["selectionRevision"]=sel~selectionRevision; tableSlots["resultRevision"]=rs~resultRevision
  mr=self~mutateState("table.group",tableSlots); if \mr~ok then return mr
  if sel~selectedIds~items=1 then do
    selected=sel~selectedIds[1]
    if readModel~containsWorkInScope(selected,filters) then return self~projectWork(selected)
  end
  hide=.table~new; hide["visible"]=.false; ignore=self~mutateState("detail.group",hide)
  return .WireUIResult~success(rows~items,"FB_STAFF_DASHBOARD_REFRESHED")

::method dispatchSemanticAction
  expose readModel permissionPort actionPort staffId channelSessionId branchId deskId
  use arg action,message
  detail=self~detailOf(message)
  select
    when action="WORK.REFRESH" then return self~refreshDashboard
    when action="WORK.FILTER" then do
      value=self~fieldOf(detail,"state","ALL")~string~upper
      allowed=.set~of("ALL","RECEIVED","APPROVAL_REQUIRED","READY_FOR_CORE","COMPLETED","CORE_REJECTED","REJECTED","NO_BANK_ACTION")
      if \allowed~hasIndex(value) then return .WireUIResult~failure("FB_STAFF_FILTER_NOT_ALLOWED",value)
      if value="ALL" then r=self~removeWorkspaceFilter("FB.STAFF.WORK","state")
      else r=self~setWorkspaceFilter("FB.STAFF.WORK","state",value)
      if \r~ok then return r
      return self~refreshDashboard
    end
    when action="WORK.SORT" then do
      ref=self~fieldOf(detail,"sortRef","WORK_ID")~string~upper; direction=self~fieldOf(detail,"direction","ASC")~string~upper
      if ref<>"WORK_ID" & ref<>"STATE" then return .WireUIResult~failure("FB_STAFF_SORT_NOT_ALLOWED",ref)
      r=self~setWorkspaceSort("FB.STAFF.WORK",ref,direction); if \r~ok then return r
      return self~refreshDashboard
    end
    when action="WORK.SELECT" then do
      ids=self~fieldOf(detail,"selectedIds",.nil); scope=self~fieldOf(detail,"scopeRevision",-1)
      if ids==.nil | \ids~isA(.Array) then return .WireUIResult~failure("FB_STAFF_SELECTION_REQUIRED")
      q=self~workspaceQuery("FB.STAFF.WORK"); if scope<>q~scopeRevision then return .WireUIResult~failure("FB_STAFF_SELECTION_SCOPE_STALE")
      filters=q~filters
      do id over ids; if \readModel~containsWorkInScope(id,filters) then return .WireUIResult~failure("FB_STAFF_SELECTION_OUT_OF_SCOPE",id); end
      r=self~setWorkspaceSelection("FB.STAFF.WORK",scope,ids); if \r~ok then return r
      return self~refreshDashboard
    end
    when action="WORK.OPEN" then do
      workId=self~fieldOf(detail,"workId","")
      sr=self~selectedWork(workId); if \sr~ok then return sr
      return self~projectWork(workId)
    end
    when action="CUSTOMER.TRANSFER.SUBMIT" then return self~submitTransfer(message,detail)
    otherwise return .WireUIResult~failure("FB_STAFF_ACTION_NOT_IMPLEMENTED",action)
  end

::method submitTransfer private
  expose permissionPort actionPort staffId channelSessionId branchId deskId
  use arg message,detail
  messageId=self~fieldOf(message,"messageId","")~string
  if messageId="" then return .WireUIResult~failure("FB_STAFF_MUTATION_MESSAGE_ID_REQUIRED")
  fields=.directory~new
  fields["customerId"]=self~fieldOf(detail,"customerId","")~string~strip
  fields["sourceAccountId"]=self~fieldOf(detail,"sourceAccountId","")~string~strip
  fields["targetAccountId"]=self~fieldOf(detail,"targetAccountId","")~string~strip
  fields["currency"]=self~fieldOf(detail,"currency","")~string~strip~upper
  amountText=self~fieldOf(detail,"amountMinor","")~string~strip
  if fields["customerId"]="" | fields["sourceAccountId"]="" | fields["targetAccountId"]="" | fields["currency"]="" | amountText="" then return .WireUIResult~failure("FB_STAFF_TRANSFER_FIELDS_REQUIRED")
  if \datatype(amountText,"W") then return .WireUIResult~failure("FB_STAFF_TRANSFER_AMOUNT_INVALID")
  fields["amountMinor"]=amountText+0
  if fields["amountMinor"]<=0 then return .WireUIResult~failure("FB_STAFF_TRANSFER_AMOUNT_INVALID")
  if fields["sourceAccountId"]=fields["targetAccountId"] then return .WireUIResult~failure("FB_STAFF_TRANSFER_ACCOUNTS_SAME")
  if fields["currency"]~length<>3 then return .WireUIResult~failure("FB_STAFF_TRANSFER_CURRENCY_INVALID")
  payload=self~transferPayloadIdentity(messageId,fields)
  admitted=permissionPort~admit(payload)
  if \admitted~ok then return .WireUIResult~failure("FB_STAFF_METHOD_PERMISSION_REQUIRED",admitted~code||":"||admitted~detail)
  submitted=actionPort~submitTransfer(messageId,fields,admitted~value)
  status=.table~new; status["lastSubmissionCode"]=submitted~code; status["lastSubmissionAt"]=.DateTime~new~utcIsoDate
  if submitted~value<>.nil then if submitted~value~hasMethod("WORKID") then status["lastWorkId"]=submitted~value~workId
  ignore=self~mutateState("action.group",status)
  if \submitted~ok then return .WireUIResult~failure(submitted~code,submitted~detail,submitted~value)
  refreshed=self~refreshDashboard; if \refreshed~ok then return refreshed
  return .WireUIResult~success(submitted~value,submitted~code)

::method transferPayloadIdentity private
  expose staffId channelSessionId branchId deskId
  use arg messageId,fields
  text="FB-STAFF-WIRE-TRANSFER/1"
  text||=self~canon("MESSAGE",messageId); text||=self~canon("STAFF",staffId); text||=self~canon("SESSION",channelSessionId); text||=self~canon("BRANCH",branchId); text||=self~canon("DESK",deskId); text||=self~canon("SCOPE","CUSTOMER"); text||=self~canon("OPERATION","TRANSFER")
  do k over .array~of("customerId","sourceAccountId","targetAccountId","currency","amountMinor"); text||=self~canon(k~upper,fields[k]); end
  return text

::method canon private
  use arg tag,value
  s=value~string
  return tag~string||":"||s~length||":"||s

::method rowSlots private
  use arg r
  d=.table~new
  do k over r~allIndexes; d[k]=r[k]; end
  d["action"]="WORK.OPEN"; d["workspaceRef"]="FB.STAFF.WORK"
  return d

::method selectedWork private
  use arg requested
  requested=requested~string; sel=self~workspaceSelection("FB.STAFF.WORK")~selectedIds
  if sel~items<>1 then return .WireUIResult~failure("FB_STAFF_SINGLE_WORK_SELECTION_REQUIRED")
  if sel[1]<>requested then return .WireUIResult~failure("FB_STAFF_SELECTED_WORK_MISMATCH",requested)
  return .WireUIResult~success(requested)

::method projectWork private
  expose readModel
  use arg workId
  w=readModel~work(workId); if w==.nil then return .WireUIResult~failure("FB_STAFF_WORK_NOT_FOUND",workId)
  r=readModel~rowFor(w)
  u=.table~new
  do k over r~allIndexes; u[k]=r[k]; end
  u["detail"]=w~detail; u["visible"]=.true; u["authorityScope"]="CUSTOMER"
  return self~mutateState("detail.group",u)

::method filterRef private
  use arg filters
  keys=filters~allIndexes; keys~sort; text=""
  do k over keys; if text<>"" then text||=";"; text||=k||"="||filters[k]; end
  return text

::method detailOf private
  use arg message
  if message==.nil then return .directory~new
  if message~hasIndex("detail") & message["detail"]<>.nil then return message["detail"]
  return .directory~new

::method fieldOf private
  use arg object,key,default=.nil
  if object==.nil then return default
  if object~hasIndex(key) then return object[key]
  return default

::class FederationBankStaffWireRuntimeFactory public
::method compileCatalogue class
  design=.FederationBankStaffWireUIDesignFixture~build
  compiled=.WireUICompiler~new~compile(design["workspace"],design["release"]); if \compiled~ok then return compiled
  return .WireUIResult~success(.WireUICompiledCatalogue~new(compiled~value),"FB_STAFF_WIRE_CATALOGUE_READY")

::method build class
  use strict arg applicationId,sessionId,accessPointId,readModel,permissionPort,actionPort,staffId,channelSessionId,branchId,deskId,accessEntryRef
  cat=self~compileCatalogue; if \cat~ok then return cat
  return self~buildFromCatalogue(applicationId,sessionId,accessPointId,readModel,permissionPort,actionPort,staffId,channelSessionId,branchId,deskId,accessEntryRef,cat~value)

::method buildFromCatalogue class
  use strict arg applicationId,sessionId,accessPointId,readModel,permissionPort,actionPort,staffId,channelSessionId,branchId,deskId,accessEntryRef,catalogue
  view=.WireUIView~new("FederationBank.StaffBanking","root"); projection=.WireUIProjection~new
  app=.FederationBankStaffWireApplication~new(applicationId,sessionId,accessPointId,view,projection,readModel,permissionPort,actionPort,staffId,channelSessionId,branchId,deskId,accessEntryRef)
  bound=app~bindCompiledRelease(catalogue,.WireUIProtocol~PROFILE_HUMAN_VISUAL,"WORKSPACE"); if \bound~ok then return bound
  installed=app~installInitialView; if \installed~ok then return installed
  return .WireUIResult~success(app,"FB_STAFF_WIRE_APPLICATION_READY")

::routine must
  use arg r
  if \r~ok then raise syntax 88.994 array(r~code,r~detail)
  return r

::requires "WireUIAll.cls"
::requires "WireUICompiledCatalogue.cls"
::requires "WireUICollectionWindow.cls"
::requires "FederationBankStaffWireUIDesignFixture.cls"
::requires "FederationBankStaffWireReadModel.cls"
::requires "FederationBankStaffWireActionPorts.cls"
