call test
say "PASS multi-action element binding"
exit 0

test:
  view=.WireUIView~new("MULTI","root")
  slots=.table~new; slots["action"]="ITEM.SELECT"; slots["actions"]=.array~of("ITEM.SELECT","ITEM.MOVE")
  call must view~createInstance("canvas","CANVAS@1",slots,"root")
  view~setActionAvailable("canvas","ITEM.SELECT",.true)
  view~setActionAvailable("canvas","ITEM.MOVE",.true)
  app=.MultiActionTestApp~new("APP","SESSION","AP",view,.WireUIProjection~new)
  r=send(app,"ITEM.SELECT"); call assert r~ok,"legacy primary action remains bound"
  r=send(app,"ITEM.MOVE"); call assert r~ok,"additional bound action accepted"
  r=send(app,"ITEM.DELETE"); call assert \r~ok & r~code="ACTION_NOT_BOUND_TO_ELEMENT","unbound action rejected"
  return

send:
  use arg app,action
  f=.table~new; f["applicationId"]="APP"; f["sessionId"]="SESSION"; f["accessPointId"]="AP"; f["viewRef"]="MULTI"; f["elementInstance"]="canvas"; f["action"]=action; f["renderedRevision"]=app~view~revision; f["detail"]=.table~new
  return app~receive(.WireUIProtocol~message(.WireUIProtocol~UI_ACTION,f))
must: use arg r; if \r~ok then raise syntax 88.900 array(r~code,r~detail); return r
assert: use arg ok,msg; if \ok then raise syntax 88.900 array("ASSERT",msg); return

::class MultiActionTestApp subclass WireUIApplication
::method dispatchSemanticAction
  use arg action,message
  return .WireUIResult~success(action,"DISPATCHED")
::requires "WireUIAll.cls"
