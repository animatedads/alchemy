transport=.LiveQueryMockTransport~new
cfg=.OdooCRMProviderConfig~new("https://oorexx-api-test.odoo.com")
provider=.OdooCRMProvider~new(cfg,transport)
model=provider~model("res.partner","discovery.operation")
listener=.QueryListener~new

r=model~liveQuery(.array~new,.array~of("id","name","phone"),100,"id")
call assertTrue r~ok,"initial live query"
q=r~value
q~onUpdate(listener)
call assertEq 2,q~items,"initial member count"
first=q~at(1)
second=q~at(2)
call assertEq 10,first~odooId,"first member id"
call assertEq 11,second~odooId,"second member id"
call assertEq 0,listener~events~items,"initial load is quiet"

transport~advance
r=q~update
call assertTrue r~ok,"changed refresh"
call assertEq 2,q~items,"changed member count"
call assertTrue first==q~at(1),"surviving object identity retained"
call assertEq "Mr Test User Updated",first~name,"surviving object merged"
call assertEq 12,q~at(2)~odooId,"new member materialized"
call assertEq 3,listener~events~items,"one updated one added one removed"
call assertEq "UPDATED",listener~events[1]~kind,"updated event first"
call assertEq 10,listener~events[1]~recordId,"updated event id"
call assertEq 1,listener~events[1]~changedFields~items,"updated field count"
call assertEq "name",listener~events[1]~changedFields[1],"updated field name"
call assertEq "ADDED",listener~events[2]~kind,"added event"
call assertEq 12,listener~events[2]~recordId,"added id"
call assertEq "REMOVED",listener~events[3]~kind,"removed event"
call assertEq 11,listener~events[3]~recordId,"removed id"

transport~advance
before=listener~events~items
r=q~refresh
call assertTrue r~ok,"stable refresh"
call assertEq before,listener~events~items,"stable refresh is quiet"
call assertTrue first==q~at(1),"identity remains stable after quiet refresh"

say "PASS test_live_query"
exit 0

::routine assertEq
  use arg e,a,l
  if e<>a then do; say "FAIL" l "expected="e "actual="a; exit 1; end
::routine assertTrue
  use arg a,l
  if \a then do; say "FAIL" l; exit 1; end

::class QueryListener public
::attribute events get
::method init
  expose events
  events=.array~new
::method onOdooQueryEvent
  expose events
  use arg event
  events~append(event)

::class LiveQueryMockTransport subclass OdooJSON2Transport
::attribute phase get
::method init
  expose phase
  phase=1
::method advance
  expose phase
  phase+=1
::method field
  use arg name,type="char",readonly=.false,relation=""
  d=.directory~new; d["string"]=name; d["type"]=type; d["required"]=.false; d["readonly"]=readonly
  if relation<>"" then d["relation"]=relation
  return d
::method fieldsFor
  d=.directory~new
  d["id"]=self~field("ID","integer",.true)
  d["name"]=self~field("Name")
  d["phone"]=self~field("Phone")
  return d
::method row
  use arg id,name,phone
  d=.directory~new; d["id"]=id; d["name"]=name; d["phone"]=phone; return d
::method rows
  expose phase
  if phase=1 then return .array~of(self~row(10,"Mr Test User","07342209126"),self~row(11,"Departing User","07000000011"))
  return .array~of(self~row(10,"Mr Test User Updated","07342209126"),self~row(12,"New User","07000000012"))
::method call
  use arg model,method,args
  if model="res.partner" & method="fields_get" then return .OdooCRMProviderResult~success(self~fieldsFor)
  if model="res.partner" & method="search_read" then return .OdooCRMProviderResult~success(self~rows)
  return .OdooCRMProviderResult~failure("MOCK_UNEXPECTED",model||"/"||method)

::requires "OdooCRMProvider.cls"
