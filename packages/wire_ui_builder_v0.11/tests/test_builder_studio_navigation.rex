call test
say "PASS test_builder_studio_navigation"
exit 0

test:
  parse source . . script
  root=filespec("P",script); if root~right(6)="tests/" then root=root~left(root~length-6)
  target=.WireUIBuilderProject~new("NAV_TARGET","Neutral navigation target")
  br=.WireUIBuilderRuntimeFactory~build(target,.nil,"BUILDER-APP","NAV","BUILDER-WEB",root"/studio/wire_ui_builder_studio_v0.11.json")
  call assert br~ok,"Builder app"
  app=br~value
  call assert app~journeyPlanMessage~value["planId"]~pos(":DESIGN:")>0,"starts in DESIGN"

  d=.directory~new; d["value"]="COMPONENTS"; call must send(app,"tool-nav","STUDIO.NAVIGATE",d)
  call assert app~journeyPlanMessage~value["planId"]~pos(":COMPONENTS:")>0,"nav enters COMPONENTS"

  d=.directory~new; d["value"]="PUBLISH"; call must send(app,"tool-nav","STUDIO.NAVIGATE",d)
  call assert app~journeyPlanMessage~value["planId"]~pos(":PUBLISH:")>0,"nav enters PUBLISH"

  d=.directory~new; d["value"]="BOGUS"; r=send(app,"tool-nav","STUDIO.NAVIGATE",d)
  call assert \r~ok & r~code="JOURNEY_STATE_NOT_FOUND","unknown Studio state rejected by server journey"
  return

send:
  use arg app,instanceId,action,detail
  f=.directory~new; f["applicationId"]=app~applicationId; f["sessionId"]=app~sessionId; f["accessPointId"]=app~accessPointId; f["viewRef"]=app~view~viewRef; f["elementInstance"]=instanceId; f["action"]=action; f["renderedRevision"]=app~view~revision; f["detail"]=detail
  return app~receive(.WireUIProtocol~message(.WireUIProtocol~UI_ACTION,f))
must: use arg r; if \r~ok then raise syntax 88.900 array(r~code,r~detail); return r
assert: use arg ok,msg; if \ok then raise syntax 88.900 array("ASSERT",msg); return
::requires "WireUIBuilderApplication.cls"
