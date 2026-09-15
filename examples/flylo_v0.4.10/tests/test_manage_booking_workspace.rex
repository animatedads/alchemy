say "FLYLO MANAGE BOOKING WORKSPACE START"
runtime=.FlyLoBackendFactory~fixture
ops=.FlyLoQueueOperationsAdapter~new(runtime)
pay=.FlyLoDemoPaymentAdapter~new(.true)
sales=.FlyLoSalesProcess~new(ops,pay)
controller=.FlyLoActionController~new(sales,ops)
r=.FlyLoWireRuntimeFactory~build("FLYLO-APP","S1","WEB",controller); call must r
app=r~value

/* Book two passengers through the Wire application and Queue Fabric engines. */
d=.directory~new; d["origin"]="PIK"; d["destination"]="EWR"; d["date"]="2026-09-12"; d["passengers"]=2
r=app~receive(action(app,"search","FLIGHT.SEARCH",d)); call must r
offerId=r~value; ignore=app~drainOutbound

d=.directory~new; d["offerId"]=offerId
r=app~receive(action(app,"offers","FLIGHT.SELECT",d)); call must r; saleId=r~value; ignore=app~drainOutbound
p1=.directory~new; p1["givenName"]="Tom"; p1["familyName"]="Dyer"; p1["email"]="tom@example.invalid"
p2=.directory~new; p2["givenName"]="Mia"; p2["familyName"]="Dyer"
d=.directory~new; d["passengers"]=.array~of(p1,p2)
r=app~receive(action(app,"passengers","PASSENGER.SAVE",d)); call must r; ignore=app~drainOutbound

d=.directory~new; d["CABIN_BAG"]=.false; d["CHECKED_BAG"]=.false; d["SEAT_SELECTION"]=.false; d["PRIORITY_BOARDING"]=.false
r=app~receive(action(app,"extras","ANCILLARY.SAVE",d)); call must r; ignore=app~drainOutbound
r=app~receive(action(app,"review","SALE.REVIEW",.directory~new)); call must r; ignore=app~drainOutbound
pd=.directory~new; pd["paymentMethodToken"]="tok_fixture"
r=app~receive(action(app,"payment","PAYMENT.AUTHORIZE",pd)); call must r
state=r~value; bookingRef=state["booking"]["bookingRef"]; ignore=app~drainOutbound
call assert bookingRef<>"","booking ref created"
call assert state["booking"]["passengers"][1]["passengerId"]="PAX-001","first stable passenger identity"
call assert state["booking"]["passengers"][2]["passengerId"]="PAX-002","second stable passenger identity"

/* Lookup creates a v0.17 workspace with an authoritative result snapshot. */
ld=.directory~new; ld["bookingRef"]=bookingRef; ld["familyName"]="Dyer"
r=app~receive(action(app,"booking-lookup","BOOKING.LOOKUP",ld)); call must r
workspace=r~value; ignore=app~drainOutbound
workspaceRef=workspace["workspaceContext"]["workspaceRef"]
call assert workspaceRef="BOOKING."||bookingRef||".PASSENGERS","workspace identity"
call assert workspace["passengers"]~items=2,"workspace passenger count"
call assert workspace["workspaceContext"]["resultRevision"]>=1,"workspace result revision published"
call assert workspace["workspaceContext"]["resultCurrent"],"workspace result current"

/* Select daughter by semantic identity, then sort. Selection must survive. */
ctx0=workspace["workspaceContext"]
r=app~setBookingWorkspaceSelection(workspaceRef,ctx0["scopeRevision"],.array~of("PAX-002")); call must r
selectedContext=r~value
call assert selectedContext["selectedIds"]~items=1 & selectedContext["selectedIds"][1]="PAX-002","daughter selected"
r=app~setBookingWorkspaceSort(workspaceRef,"familyName","DESC"); call must r
sortedContext=r~value
call assert sortedContext["selectedIds"][1]="PAX-002","sort preserves semantic selection"
call assert sortedContext["resultRevision"]>selectedContext["resultRevision"],"sort republishes authoritative result"
call assert sortedContext["resultCurrent"],"sorted workspace result current"

/* A stale pre-sort context must be rejected before semantic dispatch. */
bag=.directory~new; bag["workspaceContext"]=selectedContext; bag["quantity"]=1; bag["paymentMethodToken"]="tok_service"
r=app~receive(action(app,"manage-passengers","BOOKING.ADD_CHECKED_BAG",bag))
call assert \r~ok & r~code="WORKSPACE_QUERY_REVISION_MISMATCH","stale workspace command rejected"

/* Browser cannot forge a different passenger identity into current context. */
forged=copyContext(sortedContext); forged["selectedIds"]=.array~of("PAX-999")
bag["workspaceContext"]=forged
r=app~receive(action(app,"manage-passengers","BOOKING.ADD_CHECKED_BAG",bag))
call assert \r~ok & r~code="WORKSPACE_SELECTION_MISMATCH","forged passenger identity rejected"

/* Exact current context adds exactly one bag to the daughter. */
bag["workspaceContext"]=sortedContext
r=app~receive(action(app,"manage-passengers","BOOKING.ADD_CHECKED_BAG",bag)); call must r
managed=r~value
call assert managed["passengers"][1]["checkedBagCount"]=0,"parent bag count unchanged"
call assert managed["passengers"][2]["checkedBagCount"]=1,"selected daughter bag count changed"
call assert managed["lastAncillaryService"]["amountMinor"]=4900,"authoritative ancillary amount"
call assert managed["lastAncillaryService"]["passengerIds"][1]="PAX-002","service evidence exact passenger"

/* The business result changed after servicing, so the old exact context is now stale even though the same passenger remains selected. */
r=app~receive(action(app,"manage-passengers","BOOKING.ADD_CHECKED_BAG",bag))
call assert \r~ok & r~code="WORKSPACE_RESULT_REVISION_MISMATCH","stale business-result command rejected"
ld2=.directory~new; ld2["bookingRef"]=bookingRef; ld2["familyName"]="Dyer"
r=app~receive(action(app,"booking-lookup","BOOKING.LOOKUP",ld2)); call must r
managed2=r~value
call assert managed2["passengers"][2]["checkedBagCount"]=1,"stale result command does not duplicate bag"

say "FLYLO MANAGE BOOKING WORKSPACE: OK"
exit 0

action: procedure
  use arg app,instance,semantic,detail
  m=.directory~new; m["type"]="UI_ACTION"; m["applicationId"]="FLYLO-APP"; m["sessionId"]="S1"; m["accessPointId"]="WEB"; m["viewRef"]=app~view~viewRef; m["renderedRevision"]=app~view~revision; m["elementInstance"]=instance; m["action"]=semantic; m["detail"]=detail
  return m
copyContext: procedure
  use arg source
  d=.table~new
  do k over source~allIndexes
    v=source[k]
    if v~isA(.Array) then do; a=.array~new; do x over v; a~append(x); end; d[k]=a; end
    else d[k]=v
  end
  return d
must: procedure
  use arg r
  if \r~ok then do; say "FAIL" r~code r~detail; exit 61; end
  return r
assert: procedure
  use arg ok,msg
  if \ok then do; say "FAIL ASSERT" msg; exit 62; end
  return

::requires "FlyLoWireApplication.cls"
::requires "FlyLoQueueOperationsAdapter.cls"
