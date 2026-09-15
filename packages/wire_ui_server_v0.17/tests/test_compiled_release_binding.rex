/* Builder -> immutable compiled release -> Wire UI Server acceptance. */
b=.WireUIServerBuilderFixture~build
compiler=.WireUICompiler~new
cr=compiler~compile(b["workspace"],b["release"])
call mustDesign cr,"compile neutral Builder release"
pkg=cr~value
/* Detach Builder authoring objects at the deployment boundary: server consumes a plain compiled wire/table contract. */
wirePackage=.table~new
wirePackage["releaseRef"]=pkg~releaseRef~asWire
wirePackage["contentAddress"]=pkg~contentAddress
wirePackage["definitions"]=pkg~definitions
wirePackage["journeyPlans"]=pkg~journeyPlans
wirePackage["materials"]=pkg~materials
wirePackage["experiments"]=pkg~experiments
catalogue=.WireUICompiledCatalogue~new(wirePackage)

view=.WireUIView~new("OLA.RUNTIME","root")
projection=.WireUIProjection~new
app=.WireUIApplication~new("ola-release-app","sess-release","ap-release",view,projection)
r=app~bindCompiledRelease(catalogue,.WireUIProtocol~PROFILE_HUMAN_VISUAL)
call must r,"bind compiled release"

binding=app~siteReleaseBinding
call expect binding \== .nil,"release binding installed"
call expect binding~releaseId="WIRE_UI_SERVER_NEUTRAL","release id exact"
call expect binding~version="1","release version exact"
call expect binding~contentAddress=b["release"]~contentAddress,"sealed release address preserved"
call expect binding~packageContentAddress=pkg~contentAddress,"compiled package address preserved"

/* Definitions retain Builder identities and content addresses exactly. */
call expect app~definition("WUI_TEST_QUERY_FORM@1") \== .nil,"human search exact definition loaded"
call expect app~definition("WUI_TEST_QUERY_STATE@1") \== .nil,"agent search exact definition loaded ahead of profile switch"
sourceAddress=""
do d over pkg~definitions
  if d["definitionKey"]="WUI_TEST_QUERY_FORM@1" then sourceAddress=d["contentAddress"]
end
call expect app~definition("WUI_TEST_QUERY_FORM@1")~contentAddress=sourceAddress,"builder definition content address preserved"
call expect app~definition("WUI_TEST_QUERY_FORM") == .nil,"no implicit latest resolution after release load"

jr=app~journeyPlanMessage
call must jr,"compiled journey message"
wire=jr~value
call expect wire["siteRelease"]["contentAddress"]=binding~contentAddress,"journey wire carries exact site release"
call expect wire["active"]~items=1,"compiled SEARCH active subscription installed"
call expect wire["prefetch"]~items=1,"compiled SEARCH prefetch subscription installed"
call expect app~view~viewRef="OLA.RUNTIME","binding does not replace authoritative live view"

/* Snapshot/resync provenance is server-side and independent of DOM preservation. */
snap=app~snapshot
call expect snap["siteRelease"]["packageContentAddress"]=pkg~contentAddress,"snapshot carries compiled package provenance"

/* Machine profile is selected through the normal semantic action and reuses the same compiled release. */
modeSlots=.table~new; modeSlots["action"]=.WireUIProtocol~INTERACTION_PROFILE_SELECT; modeSlots["visible"]=.false
ignore=view~createInstance("agentOffer","SERVER_MODE_SWITCH@1",modeSlots)
r=app~offerInteractionProfile("agentOffer")
call must r,"offer compiled agent profile"
offer=r~value
action=.table~new
action["type"]=.WireUIProtocol~UI_ACTION; action["messageId"]="compiled-agent-profile"
action["applicationId"]=app~applicationId; action["sessionId"]=app~sessionId; action["accessPointId"]=app~accessPointId
action["viewRef"]=view~viewRef; action["elementInstance"]="agentOffer"; action["action"]=.WireUIProtocol~INTERACTION_PROFILE_SELECT
action["renderedRevision"]=view~revision; detail=.table~new; detail["offerId"]=offer["offerId"]; detail["profileId"]=.WireUIProtocol~PROFILE_AI_AGENT_OPTIMISED; action["detail"]=detail
r=app~receive(action)
call must r,"select compiled agent profile"
call expect app~interactionProfile=.WireUIProtocol~PROFILE_AI_AGENT_OPTIMISED,"application profile switched explicitly"
call expect app~journeyPlanMessage~value["active"]~items=1,"agent profile has active semantic search definition"
agentActive=.false
do sub over app~activeSubscriptions
  do key over sub~definitionKeys
    if key="WUI_TEST_QUERY_STATE@1" then agentActive=.true
  end
end
call expect agentActive,"AI_AGENT_OPTIMISED activates semantic-record definition"

/* A supplied wrong release address is rejected on an otherwise valid action context. */
slots=.table~new; slots["action"]="TEST.ACTION"
ignore=view~createInstance("action1","WUI_TEST_QUERY_FORM@1",slots)
view~setActionAvailable("action1","TEST.ACTION",.true)
msg=.table~new
msg["type"]=.WireUIProtocol~UI_ACTION; msg["messageId"]="wrong-release-action"
msg["applicationId"]=app~applicationId; msg["sessionId"]=app~sessionId; msg["accessPointId"]=app~accessPointId
msg["viewRef"]=view~viewRef; msg["elementInstance"]="action1"; msg["action"]="TEST.ACTION"; msg["renderedRevision"]=view~revision
msg["siteReleaseContentAddress"]="sha512-NOT-THE-BOUND-RELEASE"
r=app~receive(msg)
call expect \r~ok & r~code="SITE_RELEASE_MISMATCH","mismatched release provenance rejected"

say "PASS compiled release binding Builder -> Server"
exit 0

mustDesign: procedure
  use arg r,l
  if \r~ok then do; say "FAIL" l r~code r~detail; exit 1; end
  return
must: procedure
  use arg r,l
  if \r~ok then do; say "FAIL" l r~code r~detail; exit 1; end
  return
expect: procedure
  use arg c,l
  if \c then do; say "FAIL" l; exit 1; end
  say "ok" l
  return
::requires "WireUIServerBuilderFixture.cls"
::requires "WireUICompiler.cls"
::requires "WireUIAll.cls"
