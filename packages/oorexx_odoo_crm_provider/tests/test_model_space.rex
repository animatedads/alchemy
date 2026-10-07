transport=.ModelMockTransport~new
cfg=.OdooCRMProviderConfig~new("https://oorexx-api-test.odoo.com")
provider=.OdooCRMProvider~new(cfg,transport)

partnerModel=provider~model("res.partner","discovery.operation")
call assertEq .false,partnerModel~discoveryComplete,"model begins undiscovered"
r=partnerModel~browse(10)
call assertTrue r~ok,"browse result"
partner=r~value
call assertEq .true,partnerModel~discoveryComplete,"UNKNOWN discovers model operations"
call assertEq "res.partner",partner~odooModel,"browse live model"
call assertEq 10,partner~odooId,"browse id"
call assertEq "Mr Test User",partner~name,"browse live field"

domain=.array~of(.array~of("phone","=","07342209126"))
r=partnerModel~searchRead(domain,.array~of("id","name","phone"),10,"id")
call assertTrue r~ok,"searchRead result"
call assertEq 1,r~value~items,"searchRead object count"
call assertEq "Mr Test User",r~value[1]~name,"searchRead object seeded"

r=partnerModel~search(domain,10,"id")
call assertTrue r~ok,"search result"
call assertEq 1,r~value~items,"search object count"
call assertEq 10,r~value[1]~odooId,"search object id"
call assertEq "Mr Test User",r~value[1]~name,"search object lazy hydration"

vals=.directory~new; vals["name"]="New Remote Contact"; vals["phone"]="07111111111"
r=partnerModel~create(vals)
call assertTrue r~ok,"create object"
call assertEq 42,r~value~odooId,"create returned id"
call assertEq "New Remote Contact",r~value~name,"create seeded live object"

odoo=provider~modelSpace("discovery.operation")
leadModel=odoo~crm~lead
call assertEq "crm.lead",leadModel~odooModel,"namespace model path"
r=leadModel~browse(1)
call assertTrue r~ok,"namespace browse"
call assertEq "test's opportunity",r~value~name,"namespace returned live record"

callModel=provider~model("discuss.call.history","discovery.operation")
r=callModel~searchRead(.array~new,.array~of("id","start_dt"),10,"id desc")
call assertTrue r~ok,"phone history read-only model discovery"
call assertEq 0,r~value~items,"empty native phone history remains natural"
call assertEq .false,callModel~hasMethod("create"),"undeclared native phone create absent"

say "PASS test_model_space"
exit 0

::routine assertEq
  use arg e,a,l
  if e<>a then do; say "FAIL" l "expected="e "actual="a; exit 1; end
::routine assertTrue
  use arg a,l
  if \a then do; say "FAIL" l; exit 1; end

::class ModelMockTransport subclass OdooJSON2Transport
::method field
  use arg name,type="char",readonly=.false,relation=""
  d=.directory~new; d["string"]=name; d["type"]=type; d["required"]=.false; d["readonly"]=readonly
  if relation<>"" then d["relation"]=relation
  return d
::method fieldsFor
  use arg model
  d=.directory~new; d["id"]=self~field("ID","integer",.true); d["name"]=self~field("Name")
  if model="res.partner" then d["phone"]=self~field("Phone")
  if model="crm.lead" then d["partner_id"]=self~field("Partner","many2one",.false,"res.partner")
  if model="discuss.call.history" then d["start_dt"]=self~field("Start","datetime")
  return d
::method partnerRow
  use arg id=10,name="Mr Test User",phone="07342209126"
  d=.directory~new; d["id"]=id; d["name"]=name; d["phone"]=phone; return d
::method call
  use arg model,method,args
  if method="fields_get" then return .OdooCRMProviderResult~success(self~fieldsFor(model))
  if model="res.partner" then do
    if method="read" then return .OdooCRMProviderResult~success(.array~of(self~partnerRow(args["ids"][1])))
    if method="search_read" then return .OdooCRMProviderResult~success(.array~of(self~partnerRow))
    if method="search" then return .OdooCRMProviderResult~success(.array~of(10))
    if method="create" then return .OdooCRMProviderResult~success(.array~of(42))
  end
  if model="crm.lead" then do
    if method="read" then do
      d=.directory~new; d["id"]=1; d["name"]="test's opportunity"; d["partner_id"]=.array~of(10,"Mr Test User")
      return .OdooCRMProviderResult~success(.array~of(d))
    end
  end
  if model="discuss.call.history" & method="search_read" then return .OdooCRMProviderResult~success(.array~new)
  return .OdooCRMProviderResult~failure("MOCK_UNEXPECTED",model||"/"||method)

::requires "OdooCRMProvider.cls"
