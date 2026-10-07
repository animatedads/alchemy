transport=.MockOdooTransport~new
cfg=.OdooCRMProviderConfig~new("https://oorexx-api-test.odoo.com")
provider=.OdooCRMProvider~new(cfg,transport)
bridge=.OdooSipCRMBridge~new(provider)

/* Live Odoo 20 shape: res.partner has phone but no mobile. */
r=bridge~resolveInbound("sip-call-123","07342209126")
.Test~assert(r~ok,"inbound resolve")
c=r~value
.Test~assert(c~matched & c~partnerId="10" & c~leads~items=1,"inbound CRM context")
.Test~assert(c~partner~hasMethod("odooModel") & c~partner~odooModel="res.partner","inbound partner is live OdooObject")
.Test~assert(c~leads[1]~hasMethod("odooModel") & c~leads[1]~odooModel="crm.lead","inbound leads are live OdooObjects")
.Test~assert(transport~partnerSearchHadMobile=.false,"missing mobile omitted from live-shaped query")

w=provider~recordCallNote("10","sip-call-123","INBOUND","07342209126","2026-10-03T19:25:00+01:00","2026-10-03T19:29:00+01:00","ANSWERED","qualification")
.Test~assert(w~ok,"call note")
.Test~assert(transport~lastModel="res.partner" & transport~lastMethod="message_post","call note route")
.Test~assert(pos("OOReXX-SIP-CALL",transport~lastArgs["body"])>0,"call note marker")

messages=provider~interactionMessagesForPartner("10",5)
.Test~assert(messages~ok & messages~value~items=1,"read interaction messages")

out=bridge~prepareOutbound("10","sip-out-9")
.Test~assert(out~ok,"outbound preparation")
.Test~assert(out~value~remoteNumber="07342209126","outbound number")

channels=provider~findPartnerChannels("10")
.Test~assert(channels~ok & channels~value~items=0,"no fabricated discuss channel")
history=provider~readNativeCallHistory
.Test~assert(history~ok & history~value~items=0,"empty native history is valid")

native=provider~recordNativeCall(.directory~new)
.Test~assert(\native~ok & native~code="ODOO_NATIVE_PHONE_WRITE_UNSUPPORTED","native Phone write fail closed")

say "PASS test_provider"
exit 0

::class Test
::method assert class
  use arg truth,label
  if \truth then do
    say "FAIL" label
    exit 1
  end
  return

::class MockOdooTransport subclass OdooJSON2Transport
::attribute lastModel
::attribute lastMethod
::attribute lastArgs
::attribute partnerSearchHadMobile
::method init
  expose partnerSearchHadMobile
  partnerSearchHadMobile=.false
::method schema private
  use arg names
  d=.directory~new
  do name over names
    meta=.directory~new; meta["string"]=name; meta["type"]="char"; meta["required"]=.false; meta["readonly"]=.false
    d[name]=meta
  end
  return d
::method contains private
  use arg collection,value
  do item over collection
    if item=value then return .true
  end
  return .false
::method call
  expose lastModel lastMethod lastArgs partnerSearchHadMobile
  use arg model,method,args
  lastModel=model; lastMethod=method; lastArgs=args
  if model="res.partner" & method="fields_get" then return .OdooCRMProviderResult~success(self~schema(.array~of("id","name","phone","email")))
  if model="crm.lead" & method="fields_get" then return .OdooCRMProviderResult~success(self~schema(.array~of("id","name","partner_id","type","stage_id")))
  if model="res.partner" & method="search_read" then do
    partnerSearchHadMobile=self~contains(args["fields"],"mobile")
    p=.directory~new; p["id"]="10"; p["name"]="Mr Test User"; p["phone"]="07342209126"; p["email"]=.false
    return .OdooCRMProviderResult~success(.array~of(p))
  end
  if model="res.partner" & method="read" then do
    p=.directory~new; p["id"]="10"; p["name"]="Mr Test User"; p["phone"]="07342209126"
    return .OdooCRMProviderResult~success(.array~of(p))
  end
  if model="crm.lead" & method="search_read" then do
    l=.directory~new; l["id"]="1"; l["name"]="test's opportunity"; l["partner_id"]=.array~of("10","Mr Test User"); l["type"]="opportunity"; l["stage_id"]=.array~of("1","New")
    return .OdooCRMProviderResult~success(.array~of(l))
  end
  if model="res.partner" & method="message_post" then return .OdooCRMProviderResult~success(.array~of("863"))
  if model="mail.message" & method="search_read" then do
    m=.directory~new; m["id"]="863"; m["message_type"]="comment"; m["body"]="<p>ooRexx SIP/CRM integration test</p>"
    return .OdooCRMProviderResult~success(.array~of(m))
  end
  if model="discuss.channel" & method="search_read" then return .OdooCRMProviderResult~success(.array~new)
  if model="discuss.call.history" & method="search_read" then return .OdooCRMProviderResult~success(.array~new)
  return .OdooCRMProviderResult~failure("MOCK_UNEXPECTED",model||"/"||method)

::requires "OdooCRMProvider.cls"
