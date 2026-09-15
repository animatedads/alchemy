say "FLYLO WIRE APPLICATION START"
provider=.CapturingProvider~new
assistant=.FlyLoGrokAssistant~new(provider,"fixture-model",128)
r=.FlyLoWireRuntimeFactory~buildDemo("FLYLO-APP","S1","WEB",assistant)
call must r
app=r~value

hello=.table~new; hello["type"]="UI_HELLO"; hello["applicationId"]="FLYLO-APP"; hello["sessionId"]="S1"; hello["accessPointId"]="WEB"
caps=.table~new; caps["viewportClass"]="large"; caps["pointer"]="fine"; hello["renderCapabilities"]=caps
call must app~receive(hello)
out=app~drainOutbound
call hasType out,"UI_RENDER_PROFILE","hello profile"
call hasType out,"UI_JOURNEY_PLAN","hello journey"
call hasType out,"UI_VIEW_SNAPSHOT","hello snapshot"

/* Search: browser supplies criteria, server owns returned offer truth. */
d=.directory~new; d["origin"]="PIK"; d["destination"]="EWR"; d["date"]="2026-09-01"; d["passengers"]="1"
r=app~receive(action(app,"search","FLIGHT.SEARCH",d)); call must r
out=app~drainOutbound
call hasType out,"UI_DEFINITION_MANIFEST","search manifest"
call hasType out,"UI_JOURNEY_PLAN","search journey"
if app~view~instance("offers")["slots"]["offers"]~items<>1 then do; say "FAIL offers not projected"; exit 41; end

/* Selection sends only offer identity; the server resolves the authoritative offer. */
d=.directory~new; d["offerId"]="DEMO-FL101-2026-09-01"; d["index"]=0
r=app~receive(action(app,"offers","FLIGHT.SELECT",d)); call must r
saleId=r~value
if saleId="" then do; say "FAIL sale id"; exit 42; end
ignore=app~drainOutbound
if app~view~instance("passengers")==.nil then do; say "FAIL passenger form not created"; exit 43; end

/* Passenger email is transactional state but must not leak into assistant context. */
d=.directory~new; d["saleId"]="BROWSER-LIE"; d["givenName"]="Walter"; d["familyName"]="White"; d["email"]="walter@example.invalid"
r=app~receive(action(app,"passengers","PASSENGER.SAVE",d)); call must r
ignore=app~drainOutbound
if app~view~instance("extras")==.nil then do; say "FAIL extras not created"; exit 44; end

r=app~receive(action(app,"assistant-trigger","ASSISTANT.OPEN",.directory~new)); call must r
ignore=app~drainOutbound
q=.directory~new; q["message"]="What extras might be useful?"
r=app~receive(action(app,"assistant","ASSISTANT.ASK",q)); call must r
ignore=app~drainOutbound
if provider~request~prompt~pos("Walter White")=0 then do; say "FAIL assistant lacks permitted passenger name"; exit 45; end
if provider~request~prompt~pos("walter@example.invalid")>0 then do; say "FAIL assistant leaked passenger email"; exit 46; end
if app~view~instance("assistant")["slots"]["answer"]<>"fixture sales explanation; nothing has been added" then do; say "FAIL assistant projection"; exit 47; end

/* Explicit ancillary choices only; no assistant transaction side effect. */
d=.directory~new; d["saleId"]="BROWSER-LIE"; d["CABIN_BAG"]=.true; d["CHECKED_BAG"]=.false; d["SEAT_SELECTION"]=.true; d["PRIORITY_BOARDING"]=.false
r=app~receive(action(app,"extras","ANCILLARY.SAVE",d)); call must r
state=r~value
if state["totalMinor"]<>24200 then do; say "FAIL authoritative extras total" state["totalMinor"]; exit 48; end
ignore=app~drainOutbound

r=app~receive(action(app,"review","SALE.REVIEW",.directory~new)); call must r
ignore=app~drainOutbound
pd=.directory~new; pd["saleId"]="BROWSER-LIE"; pd["paymentMethodToken"]="tok_fixture"; pd["totalMinor"]=1; pd["currency"]="XXX"
r=app~receive(action(app,"payment","PAYMENT.AUTHORIZE",pd)); call must r
state=r~value
if state["state"]<>"CONFIRMED" then do; say "FAIL booking state"; exit 49; end
if state["totalMinor"]<>24200 then do; say "FAIL browser altered price"; exit 50; end
if app~view~instance("confirmation")==.nil then do; say "FAIL confirmation not projected"; exit 51; end
say "FLYLO WIRE APPLICATION: OK"
exit 0

action: procedure
  use arg app,instance,semantic,detail
  m=.directory~new; m["type"]="UI_ACTION"; m["applicationId"]="FLYLO-APP"; m["sessionId"]="S1"; m["accessPointId"]="WEB"; m["viewRef"]=app~view~viewRef; m["renderedRevision"]=app~view~revision; m["elementInstance"]=instance; m["action"]=semantic; m["detail"]=detail
  return m
hasType: procedure
  use arg messages,t,label
  do m over messages; if m["type"]=t then return; end
  say "FAIL missing" t label; exit 60
must: procedure
  use arg r
  if \r~ok then do; say "FAIL" r~code r~detail; exit 61; end
  return r

::class CapturingProvider
::attribute request get
::method complete
  expose request
  use arg requestArg
  request=requestArg
  return .AIProviderReply~success("fixture sales explanation; nothing has been added",request~model,"stop",.AIProviderUsage~new(5,7))

::requires "FlyLoWireApplication.cls"
