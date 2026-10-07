transport=.RelationMockTransport~new
cfg=.OdooCRMProviderConfig~new("https://oorexx-api-test.odoo.com")
provider=.OdooCRMProvider~new(cfg,transport)

leadData=.directory~new
leadData["id"]=1
leadData["name"]="test's opportunity"
leadData["partner_id"]=.array~of(10,"Mr Test User")
lead=provider~odooObject("crm.lead",1,leadData,"discovery.operation")
call assertEq .false,lead~discoveryComplete,"lead starts lazy"
partner=lead~partner_id
call assertEq .true,lead~discoveryComplete,"relation getter triggers discovery"
call assertEq "res.partner",partner~odooModel,"many2one relation model"
call assertEq 10,partner~odooId,"many2one relation id"
call assertEq "Mr Test User",partner~display_name,"many2one display seed"
call assertEq "07342209126",partner~phone,"related object read-through"

containerData=.directory~new
containerData["id"]=99
containerData["lead_ids"]=.array~of(1,2)
containerData["tag_ids"]=.array~of(7,8)
container=provider~odooObject("x.relation.container",99,containerData,"discovery.operation")
leads=container~lead_ids
call assertEq 2,leads~items,"one2many object count"
call assertEq "crm.lead",leads[1]~odooModel,"one2many model"
call assertEq 1,leads[1]~odooId,"one2many first id"
call assertEq "test's opportunity",leads[1]~name,"nested lazy discovery/read-through"
tags=container~tag_ids
call assertEq 2,tags~items,"many2many object count"
call assertEq "crm.tag",tags[1]~odooModel,"many2many model"
call assertEq "Priority",tags[1]~name,"many2many nested object"

/* Relation cache must be stable until backing identity changes. */
call assertTrue partner==lead~partner_id,"many2one relation identity cached"
listener=.RelationUpdateSink~new
lead~onUpdate(listener)
transport~leadPartnerId=11
transport~leadPartnerName="Replacement Customer"
r=lead~update
call assertTrue r~ok,"lead remote refresh"
replacement=lead~partner_id
call assertEq 11,replacement~odooId,"many2one cache invalidated after refresh"
call assertTrue \(partner==replacement),"changed relation produces new object"
call assertEq 1,listener~count,"relation refresh update event"

/* Safe many2one write-through accepts another OdooObject and serializes id. */
lead~partner_id=partner
call assertEq 10,transport~lastWrittenPartnerId,"many2one object normalized to id"
call assertEq 10,lead~partner_id~odooId,"many2one local cache after write"

/* Collection relations require explicit Odoo command semantics. */
ids=.array~of(1)
blocked=container~discoveredFieldSet("lead_ids",ids)
call assertEq .false,blocked~ok,"one2many direct assignment blocked"
call assertEq "ODOO_RELATION_WRITE_REQUIRES_COMMAND",blocked~code,"one2many fail-closed code"

say "PASS test_relation_graph"
exit 0

::routine assertEq
  use arg e,a,l
  if e<>a then do; say "FAIL" l "expected="e "actual="a; exit 1; end
::routine assertTrue
  use arg a,l
  if \a then do; say "FAIL" l; exit 1; end

::class RelationUpdateSink
::attribute count get
::method init; expose count; count=0
::method onOdooUpdate
  expose count
  use arg event
  count+=1

::class RelationMockTransport subclass OdooJSON2Transport
::attribute leadPartnerId
::attribute leadPartnerName
::attribute lastWrittenPartnerId
::method init
  expose leadPartnerId leadPartnerName lastWrittenPartnerId
  leadPartnerId=10; leadPartnerName="Mr Test User"; lastWrittenPartnerId=""
::method field
  use arg name,type="char",readonly=.false,relation=""
  d=.directory~new
  d["string"]=name; d["type"]=type; d["required"]=.false; d["readonly"]=readonly
  if relation<>"" then d["relation"]=relation
  return d
::method fieldsFor
  use arg model
  d=.directory~new
  d["id"]=self~field("ID","integer",.true)
  d["name"]=self~field("Name")
  if model="res.partner" then do
    d["display_name"]=self~field("Display Name","char",.true)
    d["phone"]=self~field("Phone")
    d["email"]=self~field("Email")
  end
  if model="crm.lead" then d["partner_id"]=self~field("Partner","many2one",.false,"res.partner")
  if model="x.relation.container" then do
    d["lead_ids"]=self~field("Leads","one2many",.false,"crm.lead")
    d["tag_ids"]=self~field("Tags","many2many",.false,"crm.tag")
  end
  return d
::method call
  expose leadPartnerId leadPartnerName lastWrittenPartnerId
  use arg model,method,args
  if method="fields_get" then return .OdooCRMProviderResult~success(self~fieldsFor(model))
  if method="write" then do
    if model="crm.lead" then if args["vals"]~hasIndex("partner_id") then lastWrittenPartnerId=args["vals"]["partner_id"]
    return .OdooCRMProviderResult~success(.true)
  end
  if method="read" then do
    id=args["ids"][1]
    row=.directory~new; row["id"]=id
    if model="res.partner" then do
      if id=10 then do; row["name"]="Mr Test User"; row["display_name"]="Mr Test User"; row["phone"]="07342209126"; end
      else do; row["name"]="Replacement Customer"; row["display_name"]="Replacement Customer"; row["phone"]="07000000011"; end
    end
    else if model="crm.lead" then do
      if id=1 then row["name"]="test's opportunity"; else row["name"]="second opportunity"
      row["partner_id"]=.array~of(leadPartnerId,leadPartnerName)
    end
    else if model="crm.tag" then do
      if id=7 then row["name"]="Priority"; else row["name"]="Follow-up"
    end
    else if model="x.relation.container" then do
      row["lead_ids"]=.array~of(1,2); row["tag_ids"]=.array~of(7,8)
    end
    return .OdooCRMProviderResult~success(.array~of(row))
  end
  return .OdooCRMProviderResult~failure("MOCK_UNEXPECTED",model||"/"||method)

::requires "OdooCRMProvider.cls"
