package=.json~fromJsonFile("compiled/vector_meridian_markets_operations_v0.2.json")
catalogue=.WireUICompiledCatalogue~new(package)
view=.WireUIView~new("VMM.OPERATOR","root")
rootSlots=.table~new; rootSlots["visible"]=.true
call must view~createInstance("root","VMM_FIRM_RISK_SUMMARY@2",rootSlots),"create root"
app=.VMMOperatorAuthorityFixtureApp~new("VMM-OPS-APP","VMM-OPS-SESSION","VMM-OPS-AP",view,.WireUIProjection~new)
call must app~bindCompiledRelease(catalogue,.WireUIProtocol~PROFILE_HUMAN_VISUAL),"bind compiled VMM release"

call expect app~definition("VMM_ORDER_CANCEL@2") \== .nil,"cancel definition installed from compiled release"
call expect app~definition("VMM_ALGO_KILL@2") \== .nil,"kill definition installed from compiled release"
call expect app~siteReleaseBinding~releaseId="VECTOR_MERIDIAN_MARKETS_OPERATIONS","exact VMM release bound"

slots=.table~new; slots["action"]="VMM.ORDER.CANCEL.REQUEST"; slots["label"]="Request cancel"; slots["enabled"]=.true
call must view~createInstance("cancel-order","VMM_ORDER_CANCEL@2",slots,"root"),"create cancel control"

/* Merely rendering a bound control is insufficient; server action availability is mandatory. */
r=send(app,"VMM-OPS-AP","VMM.ORDER.CANCEL.REQUEST",view~revision,"","m1")
call expect \r~ok & r~code="ACTION_NOT_AVAILABLE_AT_REVISION","rendered action unavailable until server projects availability"

view~setActionAvailable("cancel-order","VMM.ORDER.CANCEL.REQUEST",.true)
r=send(app,"VMM-OPS-AP","VMM.ORDER.CANCEL.REQUEST",view~revision,"","m2")
call must r,"available operator intent reaches server dispatch"
call expect app~lastAction="VMM.ORDER.CANCEL.REQUEST","dispatch receives semantic intent only"

r=send(app,"VMM-OPS-AP","VMM.ORDER.EXECUTE",view~revision,"","m3")
call expect \r~ok & r~code="ACTION_NOT_BOUND_TO_ELEMENT","browser cannot invent execution verb"

r=send(app,"FEDERATION-MERCHANT-AP","VMM.ORDER.CANCEL.REQUEST",view~revision,"","m4")
call expect \r~ok & r~code="ACCESS_POINT_OWNERSHIP_MISMATCH","Federation access point cannot inject VMM operator action"

r=send(app,"VMM-OPS-AP","VMM.ORDER.CANCEL.REQUEST",view~revision,"sha512-not-vmm-release","m5")
call expect \r~ok & r~code="SITE_RELEASE_MISMATCH","wrong release provenance rejected"

say "PASS VMM server-authoritative operator action boundary"
exit 0

send: procedure
  use arg app,accessPoint,action,revision,releaseAddress="",messageId="test-action"
  m=.table~new
  m["type"]=.WireUIProtocol~UI_ACTION; m["messageId"]=messageId
  m["applicationId"]="VMM-OPS-APP"; m["sessionId"]="VMM-OPS-SESSION"; m["accessPointId"]=accessPoint
  m["viewRef"]="VMM.OPERATOR"; m["elementInstance"]="cancel-order"; m["action"]=action; m["renderedRevision"]=revision
  if releaseAddress<>"" then m["siteReleaseContentAddress"]=releaseAddress
  m["detail"]=.table~new
  return app~receive(m)

must: procedure
  use arg r,label
  if \r~ok then do; say "FAIL" label r~code r~detail; exit 1; end
  return
expect: procedure
  use arg condition,label
  if \condition then do; say "FAIL" label; exit 1; end
  say "ok" label
  return

::class VMMOperatorAuthorityFixtureApp subclass WireUIApplication
::attribute lastAction get
::method init
  expose lastAction
  use arg applicationId,sessionId,accessPointId,view,projection
  self~init:super(applicationId,sessionId,accessPointId,view,projection)
  lastAction=""
::method dispatchSemanticAction
  expose lastAction
  use arg action,message
  /* Fixture proves delivery only. No VMM business action is implemented here. */
  lastAction=action
  return .WireUIResult~success(action,"VMM_OPERATOR_INTENT_DELIVERED")

::requires "WireUIAll.cls"
::requires "json.cls"
