/* Persistent FlyLo public-shell runtime for ./flylo.
 * Browser HTTP requests enter here, are revalidated as Wire UI semantic
 * actions, and then reach Queue Fabric-backed FlyLo engines.  Workspace
 * selection/query/result mutations use Wire UI Server v0.17 authority directly.
 */
stage="BOOT"
signal on syntax name fatal

durableRoot=value("FLYLO_DURABLE_ROOT",,"ENVIRONMENT")~string~strip
accountingStore=value("FLYLO_ACCOUNTING_STORE",,"ENVIRONMENT")~string~strip
if durableRoot="" then do; call emitFailure "BOOT","FLYLO_DURABLE_ROOT_REQUIRED","./flylo must provide a durable Queue Fabric root",""; exit 2; end
if accountingStore="" then do; call emitFailure "BOOT","FLYLO_ACCOUNTING_STORE_REQUIRED","./flylo must provide an Accounting Core store path",""; exit 2; end
runtime=.FlyLoBackendFactory~fixture(durableRoot)
ops=.FlyLoQueueOperationsAdapter~new(runtime)
pay=.FlyLoDemoPaymentAdapter~new(.true)
accounting=.FlyLoAccountingAuthority~new(runtime~topology,.nil,accountingStore)
sales=.FlyLoSalesProcess~new(ops,pay,accounting,runtime~booking~highestSaleSequence)
controller=.FlyLoActionController~new(sales,ops,accounting)
built=.FlyLoWireRuntimeFactory~build("FLYLO-PUBLIC","PUBLIC-S1","WEB",controller)
if \built~ok then do; call emitFailure "BOOT",built~code,built~detail,""; exit 2; end
app=built~value
ignore=app~drainOutbound

ready=.directory~new; ready["ok"]=.JSON~true; ready["event"]="FLYLO_PUBLIC_RUNTIME_READY"; ready["wireUiServer"]="0.17"; ready["engine"]="QUEUE_FABRIC_DURABLE_FIXTURE"; ready["accounting"]="ACCOUNTING_CORE_0.7"; ready["storage"]="DURABLE"
say .JSON~toJSON(ready)

do forever
  line=linein()
  if line="" then leave
  call processRequest line,app
end
exit 0

processRequest: procedure
  use arg line,app
  stage="REQUEST_PARSE"
  id=""
  signal on syntax name requestFailed
  request=plainValue(.JSON~fromJSON(line))
  if request==.nil | \request~isA(.Directory) then do; call emitFailure "REQUEST_PARSE","REQUEST_INVALID","request must be JSON object",id; return; end
  id=field(request,"id","")
  op=field(request,"op","ACTION")~string~translate
  select
    when op="PING" then do
      out=.directory~new; out["ok"]=.JSON~true; out["id"]=id; out["result"]="PONG"; out["wireUiServer"]="0.17"; out["engine"]="QUEUE_FABRIC_DURABLE_FIXTURE"; out["accounting"]="ACCOUNTING_CORE_0.7"; out["storage"]="DURABLE"; say .JSON~toJSON(out)
    end
    when op="ACTION" then call handleAction request,id,app
    when op="WORKSPACE.SELECT" then call handleSelection request,id,app
    when op="WORKSPACE.SORT" then call handleSort request,id,app
    when op="WORKSPACE.CONTEXT" then call handleContext request,id,app
    otherwise call emitFailure "REQUEST","OP_UNSUPPORTED",op,id
  end
  signal off syntax
  return
requestFailed:
  signal off syntax
  c=condition("O"); code="UNKNOWN"; pos=""; additional=.nil
  if c<>.nil then if c~isA(.Directory) then do
    if c["CODE"]<>.nil then code=c["CODE"]~string
    if c["POSITION"]<>.nil then pos=c["POSITION"]~string
    if c["ADDITIONAL"]<>.nil then additional=c["ADDITIONAL"]
  end
  /* Queue adapters raise 88.900 to cross the legacy operations boundary, but
     an engine rejection is a domain result, not an ooRexx runtime failure.
     Preserve the authoritative engine code for the HTTP boundary. */
  if code="88.900" & additional<>.nil then if additional~isA(.Array) then if additional~items>=2 then do
    if additional[1]~string="FLYLO_BACKEND_REJECTED" then do
      domainCode=additional[2]~string; domainDetail=""
      if additional~items>=3 then domainDetail=additional[3]~string
      call emitFailure "DOMAIN",domainCode,domainDetail,id
      return
    end
  end
  call emitFailure "RUNTIME","RUNTIME_CONDITION_"||code,"position="||pos,id
  return


handleAction: procedure
  use arg request,id,app
  action=field(request,"action","")~translate
  detail=request["detail"]; if detail==.nil then detail=.directory~new
  instance=""
  select
    when action="FLIGHT.SEARCH" then instance="search"
    when action="FLIGHT.SELECT" then instance="offers"
    when action="PASSENGER.SAVE" then instance="passengers"
    when action="ANCILLARY.SAVE" then instance="extras"
    when action="SALE.REVIEW" then instance="review"
    when action="PAYMENT.AUTHORIZE" then instance="payment"
    when action="BOOKING.LOOKUP" then instance="booking-lookup"
    when action="BOOKING.ADD_CHECKED_BAG" then instance="manage-passengers"
    when action="FLIGHT.STATUS" then instance="flight-status"
    otherwise do; call emitFailure "ACTION","ACTION_UNSUPPORTED",action,id; return; end
  end
  if action="FLIGHT.SELECT" then do
    if \detail~hasIndex("offerId") & detail~hasIndex("offer") then detail["offerId"]=field(detail["offer"],"offerId","")
  end
  m=.directory~new
  m["type"]="UI_ACTION"; m["applicationId"]="FLYLO-PUBLIC"; m["sessionId"]="PUBLIC-S1"; m["accessPointId"]="WEB"; m["viewRef"]=app~view~viewRef; m["renderedRevision"]=app~view~revision; m["elementInstance"]=instance; m["action"]=action; m["detail"]=detail
  r=app~receive(m)
  if \r~ok then do; call emitFailure "WIRE_ACTION",r~code,r~detail,id; return; end
  ignore=app~drainOutbound
  value=r~value
  select
    when action="FLIGHT.SEARCH" then value=app~offerById(r~value)
    when action="FLIGHT.SELECT" then value=app~saleSnapshot(r~value)
    otherwise nop
  end
  call emitSuccess id,value,r~code
  return

handleSelection: procedure
  use arg request,id,app
  workspaceRef=field(request,"workspaceRef","")
  scopeRevision=request["scopeRevision"]; if scopeRevision==.nil then scopeRevision=-1
  selected=request["selectedIds"]; if selected==.nil then selected=.array~new
  r=app~setBookingWorkspaceSelection(workspaceRef,scopeRevision,selected)
  if \r~ok then do; call emitFailure "WORKSPACE_SELECT",r~code,r~detail,id; return; end
  call emitSuccess id,r~value,r~code
  return

handleSort: procedure
  use arg request,id,app
  r=app~setBookingWorkspaceSort(field(request,"workspaceRef",""),field(request,"sortRef","familyName"),field(request,"direction","ASC"))
  if \r~ok then do; call emitFailure "WORKSPACE_SORT",r~code,r~detail,id; return; end
  call emitSuccess id,r~value,r~code
  return

handleContext: procedure
  use arg request,id,app
  context=app~workspaceContext(field(request,"workspaceRef",""))
  if context==.nil then do; call emitFailure "WORKSPACE_CONTEXT","WORKSPACE_NOT_FOUND",field(request,"workspaceRef",""),id; return; end
  call emitSuccess id,context,"WORKSPACE_CONTEXT"
  return

emitSuccess: procedure
  use arg id,value,code="OK"
  out=.directory~new; out["ok"]=.JSON~true; out["id"]=id; out["code"]=code; out["result"]=value
  say .JSON~toJSON(out)
  return

emitFailure: procedure
  use arg stage,code,detail,id=""
  out=.directory~new; out["ok"]=.JSON~false; out["id"]=id; out["stage"]=stage; out["code"]=code; out["detail"]=detail~string
  say .JSON~toJSON(out)
  return

plainValue: procedure
  use arg value
  if value==.nil then return .nil
  if value~isA(.JsonString) | value~isA(.JsonBoolean) then return value~string
  if value~isA(.Array) then do
    out=.array~new
    do item over value; out~append(plainValue(item)); end
    return out
  end
  if value~isA(.Directory) then do
    out=.directory~new
    supplier=value~supplier
    do while supplier~available
      key=supplier~index~string
      out[key]=plainValue(supplier~item)
      supplier~next
    end
    return out
  end
  if value~isA(.Table) then do
    out=.table~new
    supplier=value~supplier
    do while supplier~available
      key=supplier~index
      if key~isA(.JsonString) | key~isA(.JsonBoolean) then key=key~string
      out[key]=plainValue(supplier~item)
      supplier~next
    end
    return out
  end
  return value

field: procedure
  use arg d,key,defaultValue=.nil
  if d==.nil | \d~hasMethod("HASINDEX") then return defaultValue
  if d~hasIndex(key) then do; v=d[key]; if v<>.nil then return v; end
  return defaultValue

fatal:
  signal off syntax
  c=condition("O"); code="UNKNOWN"; pos=""
  if c<>.nil then if c~isA(.Directory) then do; if c["CODE"]<>.nil then code=c["CODE"]~string; if c["POSITION"]<>.nil then pos=c["POSITION"]~string; end
  call emitFailure stage,"BOOT_CONDITION_"||code,"position="||pos,""
  exit 3

::requires "FlyLoAccounting.cls"
::requires "FlyLoWireApplication.cls"
::requires "FlyLoQueueOperationsAdapter.cls"
::requires "json.cls"
