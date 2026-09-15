/* Authoritative workspace result revision binds commands to the business result, not merely the query. */
view=.WireUIView~new("MB.RESULTS","root")
rootSlots=.table~new; rootSlots["visible"]=.true
call must view~createInstance("root","WORKSPACE@1",rootSlots)
button=.table~new
button["action"]="POSITION.BULK.CLOSE"
button["workspaceRef"]="POSITIONS"
button["enabled"]=.true
call must view~createInstance("bulk-close","BULK_ACTION@1",button,"root")
view~setActionAvailable("bulk-close","POSITION.BULK.CLOSE",.true)

app=.ResultTestApp~new("APP","SESSION","AP",view,.WireUIProjection~new)
call must app~registerWorkspace("POSITIONS")

aggregates=.table~new
aggregates["grossNotional"]=12500000
aggregates["netDirectionalExposure"]=2300000
aggregates["marginShortfall"]=500000
r=app~publishWorkspaceResult("POSITIONS",50000,aggregates,"RISK-SNAPSHOT-41","2026-08-28T13:00:00Z"); call must r
resultState=app~workspaceResult("POSITIONS")
call assert resultState~resultRevision=1 & resultState~totalCount=50000,"first authoritative result published"
wire=resultState~asWire
call assert wire["aggregates"]["marginShortfall"]=500000 & wire["provenanceRef"]="RISK-SNAPSHOT-41","result aggregate/provenance preserved"

call must app~setWorkspaceSelection("POSITIONS",0,.array~of("P-100","P-200"))
ctx1=app~workspaceContext("POSITIONS")
call assert ctx1["resultRevision"]=1 & ctx1["resultCurrent"]=.true,"command context binds current result"
r=send(app,"m-1",ctx1); call assert r~ok & r~value=2,"current result context accepted"

/* Same query/selection, but new authoritative result: old command authority is stale. */
aggregates2=.table~new
aggregates2["grossNotional"]=12500000
aggregates2["netDirectionalExposure"]=2700000
aggregates2["marginShortfall"]=750000
r=app~publishWorkspaceResult("POSITIONS",50000,aggregates2,"RISK-SNAPSHOT-42","2026-08-28T13:00:05Z"); call must r
call assert app~workspaceQuery("POSITIONS")~queryRevision=0,"business result refresh does not invent a query change"
call assert app~workspaceSelection("POSITIONS")~selectedIds~items=2,"result refresh preserves semantic selection"
r=send(app,"m-2",ctx1)
call assert \r~ok & r~code="WORKSPACE_RESULT_REVISION_MISMATCH","old result revision rejected"
ctx2=app~workspaceContext("POSITIONS")
call assert ctx2["resultRevision"]=2,"new context carries refreshed result revision"
r=send(app,"m-3",ctx2); call assert r~ok & r~value=2,"refreshed result context accepted"

/* Query movement makes the prior result explicitly non-current until republished. */
call must app~setWorkspaceFilter("POSITIONS","jurisdiction","GB")
staleCurrent=app~workspaceContext("POSITIONS")
call assert staleCurrent["resultRevision"]=2 & staleCurrent["resultCurrent"]=.false,"query movement marks existing result stale"
r=send(app,"m-4",staleCurrent)
call assert \r~ok & r~code="WORKSPACE_RESULT_NOT_CURRENT","command blocked while result is stale"

call must app~publishWorkspaceResult("POSITIONS",12000,.table~new,"RISK-SNAPSHOT-43","2026-08-28T13:00:10Z")
q=app~workspaceQuery("POSITIONS")
call must app~setWorkspaceSelection("POSITIONS",q~scopeRevision,.array~of("P-300"))
ctx3=app~workspaceContext("POSITIONS")
call assert ctx3["resultRevision"]=3 & ctx3["resultCurrent"]=.true,"republished filtered result current"
r=send(app,"m-5",ctx3); call assert r~ok & r~value=1,"filtered result command accepted"

/* Sort-only change preserves selection but still requires a result ordering refresh. */
call must app~setWorkspaceSort("POSITIONS","NOTIONAL","DESC")
call assert app~workspaceSelection("POSITIONS")~contains("P-300"),"sort preserves semantic selection"
sortStale=app~workspaceContext("POSITIONS")
r=send(app,"m-6",sortStale)
call assert \r~ok & r~code="WORKSPACE_RESULT_NOT_CURRENT","sort requires refreshed authoritative result ordering"
call must app~publishWorkspaceResult("POSITIONS",12000,.table~new,"RISK-SNAPSHOT-44","2026-08-28T13:00:12Z")
ctx4=app~workspaceContext("POSITIONS")
r=send(app,"m-7",ctx4); call assert r~ok & r~value=1,"sorted refreshed result accepted"

say "PASS authoritative workspace result revision"
exit 0

send:
  use arg app,id,context
  f=.table~new
  f["type"]=.WireUIProtocol~UI_ACTION; f["messageId"]=id
  f["applicationId"]="APP"; f["sessionId"]="SESSION"; f["accessPointId"]="AP"; f["viewRef"]="MB.RESULTS"
  f["elementInstance"]="bulk-close"; f["action"]="POSITION.BULK.CLOSE"; f["renderedRevision"]=app~view~revision
  d=.table~new; d["workspaceContext"]=context; f["detail"]=d
  return app~receive(f)

must: use arg r; if \r~ok then raise syntax 88.900 array(r~code,r~detail); return r
assert: use arg ok,msg; if \ok then raise syntax 88.900 array("ASSERT",msg); return

::class ResultTestApp subclass WireUIApplication
::method dispatchSemanticAction
  use arg action,message
  ctx=message["detail"]["workspaceContext"]
  return .WireUIResult~success(ctx["selectedIds"]~items,"BULK_COMMAND_ACCEPTED")

::requires "WireUIAll.cls"
