transport=.IdentityMockTransport~new
cfg=.OdooCRMProviderConfig~new("https://oorexx-api-test.odoo.com")
provider=.OdooCRMProvider~new(cfg,transport)

seed=.directory~new; seed["id"]=10; seed["name"]="Mr Test User"
a=provider~odooObject("res.partner",10,seed,"discovery.operation")
call assertEq 1,provider~identityObjectCount,"one canonical object"

seed2=.directory~new; seed2["id"]=10; seed2["name"]="Mr Test User Updated"
b=provider~odooObject("res.partner",10,seed2,"discovery.operation")
call assertTrue a==b,"same model/id returns same object"
snap=a~snapshot
call assertEq "Mr Test User Updated",snap["name"],"fresh seed merged into canonical object"

model=provider~model("res.partner","discovery.operation")
r=model~browse(10,.array~of("id","name","phone"))
call assertTrue r~ok,"browse succeeds"
call assertTrue a==r~value,"browse reuses canonical object"

r=model~searchRead(.array~new,.array~of("id","name","phone"),10,"id")
call assertTrue r~ok,"searchRead succeeds"
call assertTrue a==r~value[1],"searchRead reuses canonical object"

q1r=model~liveQuery(.array~new,.array~of("id","name","phone"),10,"id")
call assertTrue q1r~ok,"first live query"
q2r=model~liveQuery(.array~new,.array~of("id","name","phone"),10,"id")
call assertTrue q2r~ok,"second live query"
call assertTrue q1r~value~at(1)==q2r~value~at(1),"queries share canonical member object"
call assertTrue a==q1r~value~at(1),"query shares browse/object identity"

call assertTrue provider~evictIdentityObject("res.partner",10),"explicit eviction"
call assertEq 0,provider~identityObjectCount,"identity map empty after eviction"
c=provider~odooObject("res.partner",10,seed,"discovery.operation")
call assertTrue c\==a,"eviction permits fresh wrapper"
call assertEq 1,provider~identityObjectCount,"fresh canonical object registered"

say "PASS test_identity_map"
exit 0

::routine assertEq
  use arg e,a,l
  if e<>a then do; say "FAIL" l "expected="e "actual="a; exit 1; end
::routine assertTrue
  use arg a,l
  if \a then do; say "FAIL" l; exit 1; end

::class IdentityMockTransport subclass OdooJSON2Transport
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
  d=.directory~new; d["id"]=10; d["name"]="Mr Test User Remote"; d["phone"]="07342209126"; return d
::method call
  use arg model,method,args
  if model="res.partner" & method="fields_get" then return .OdooCRMProviderResult~success(self~fieldsFor)
  if model="res.partner" & method="read" then return .OdooCRMProviderResult~success(.array~of(self~row))
  if model="res.partner" & method="search_read" then return .OdooCRMProviderResult~success(.array~of(self~row))
  return .OdooCRMProviderResult~failure("MOCK_UNEXPECTED",model||"/"||method)

::requires "OdooCRMProvider.cls"
