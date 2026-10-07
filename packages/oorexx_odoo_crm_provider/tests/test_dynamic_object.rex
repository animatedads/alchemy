transport=.DynamicMockTransport~new
cfg=.OdooCRMProviderConfig~new("https://oorexx-api-test.odoo.com")
provider=.OdooCRMProvider~new(cfg,transport)
data=.directory~new; data["id"]=10; data["name"]="Mr Test User"; data["phone"]="07342209126"
obj=provider~odooObject("res.partner",10,data,"discovery.operation")
listener=.UpdateSink~new
obj~onUpdate(listener)
call assertEq "Mr Test User",obj~name,"eager-discovered getter"
call assertEq "07342209126",obj~phone,"phone getter"
obj~phone="07340000000"
call assertEq "07340000000",obj~phone,"write-through setter"
call assertEq 1,listener~count,"local update event"
transport~remotePhone="07341111111"
r=obj~update
call assertTrue r~ok,"remote update"
call assertEq "07341111111",obj~phone,"remote refresh"
call assertEq 2,listener~count,"remote update event"
lead=.OdooObject~new(provider,"crm.lead",1,.directory~new,"discovery.operation")
call assertEq .false,lead~hasMethod("name"),"lazy starts undiscovered"
transport~leadName="test's opportunity"
/* UNKNOWN triggers discovery and installs field method. */
call assertEq "test's opportunity",lead~name,"lazy getter discovers and hydrates field"
call assertEq .true,lead~hasMethod("name"),"lazy method installed"
lead~update
call assertEq "test's opportunity",lead~name,"lazy object refresh"
say "PASS test_dynamic_object"
exit 0

::routine assertEq
  use arg e,a,l
  if e<>a then do; say "FAIL" l "expected="e "actual="a; exit 1; end
::routine assertTrue
  use arg a,l
  if \a then do; say "FAIL" l; exit 1; end

::class UpdateSink
::attribute count get
::method init; expose count; count=0
::method onOdooUpdate
  expose count
  use arg event
  count+=1

::class DynamicMockTransport subclass OdooJSON2Transport
::attribute remotePhone
::attribute leadName
::method init
  expose remotePhone leadName
  remotePhone="07342209126"; leadName="test's opportunity"
::method field
  use arg name,type="char",readonly=.false
  d=.directory~new; d["string"]=name; d["type"]=type; d["required"]=.false; d["readonly"]=readonly; return d
::method call
  expose remotePhone leadName
  use arg model,method,args
  if method="fields_get" then do
    d=.directory~new
    d["id"]=self~field("ID","integer",.true)
    d["name"]=self~field("Name")
    if model="res.partner" then do; d["phone"]=self~field("Phone"); d["email"]=self~field("Email"); end
    if model="crm.lead" then d["partner_id"]=self~field("Partner","many2one")
    return .OdooCRMProviderResult~success(d)
  end
  if method="write" then do
    if model="res.partner" & args["vals"]~hasIndex("phone") then remotePhone=args["vals"]["phone"]
    return .OdooCRMProviderResult~success(.true)
  end
  if method="read" then do
    row=.directory~new
    if model="res.partner" then do; row["id"]=10; row["name"]="Mr Test User"; row["phone"]=remotePhone; end
    else do; row["id"]=1; row["name"]=leadName; row["partner_id"]=.array~of(10,"Mr Test User"); end
    return .OdooCRMProviderResult~success(.array~of(row))
  end
  return .OdooCRMProviderResult~failure("MOCK_UNEXPECTED",model||"/"||method)

::requires "OdooCRMProvider.cls"
