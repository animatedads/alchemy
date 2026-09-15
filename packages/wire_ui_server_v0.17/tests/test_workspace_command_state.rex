/* Dense workspace command/query state: filter scope, order, selection and stale-command rejection. */
view=.WireUIView~new("MB.WORKSPACE","root")
root=.table~new; root["visible"]=.true
call must view~createInstance("root","WORKSPACE@1",root)
button=.table~new
button["action"]="POSITION.BULK.CLOSE"
button["workspaceRef"]="POSITIONS"
button["enabled"]=.true
call must view~createInstance("bulk-close","BULK_ACTION@1",button,"root")
view~setActionAvailable("bulk-close","POSITION.BULK.CLOSE",.true)

app=.WorkspaceTestApp~new("APP","SESSION","AP",view,.WireUIProjection~new)
r=app~registerWorkspace("POSITIONS"); call must r
call assert r~value["queryRevision"]=0 & r~value["scopeRevision"]=0 & r~value["selectionRevision"]=0,"initial workspace revisions"

/* Selection is semantic identity, independent of current visual row order. */
r=app~setWorkspaceSelection("POSITIONS",0,.array~of("P-100","P-200")); call must r
call assert app~workspaceSelection("POSITIONS")~selectedIds~items=2,"semantic selection registered"
selectionRevision=app~workspaceSelection("POSITIONS")~selectionRevision
r=app~setWorkspaceSelection("POSITIONS",0,.array~of("P-200","P-100")); call must r
call assert r~code="NO_CHANGE" & app~workspaceSelection("POSITIONS")~selectionRevision=selectionRevision,"selection order is not semantic authority"

/* A sort changes order/query revisions, but not membership scope or selection. */
r=app~setWorkspaceSort("POSITIONS","NOTIONAL","DESC"); call must r
q=app~workspaceQuery("POSITIONS")
call assert q~queryRevision=1 & q~orderRevision=1 & q~scopeRevision=0,"sort revisions are independent"
call assert app~workspaceSelection("POSITIONS")~selectionRevision=selectionRevision,"sort preserves selection revision"
call assert app~workspaceSelection("POSITIONS")~contains("P-100"),"sort preserves semantic selection"

current=app~workspaceContext("POSITIONS")
r=send(app,"m-1",current); call assert r~ok & r~value=2,"bulk command accepts exact workspace context"

/* A stale query context is rejected even when the UI view revision itself is current. */
stale=selfCopy(current); stale["queryRevision"]=0
r=send(app,"m-2",stale)
call assert \r~ok & r~code="WORKSPACE_QUERY_REVISION_MISMATCH","stale query revision rejected"

/* Selection identity is part of authority, not a browser hint. */
forged=selfCopy(current); forged["selectedIds"]=.array~of("P-999")
r=send(app,"m-3",forged)
call assert \r~ok & r~code="WORKSPACE_SELECTION_MISMATCH","forged selected identity rejected"

/* Filter changes alter membership scope and invalidate the previous selection. */
r=app~setWorkspaceFilter("POSITIONS","jurisdiction","GB"); call must r
q=app~workspaceQuery("POSITIONS"); s=app~workspaceSelection("POSITIONS")
call assert q~scopeRevision=1 & q~queryRevision=2,"filter advances membership scope"
call assert s~scopeRevision=1 & s~selectedIds~items=0,"filter invalidates prior selection"

/* A browser cannot reapply an old selection against the new scope. */
r=app~setWorkspaceSelection("POSITIONS",0,.array~of("P-100"))
call assert \r~ok & r~code="WORKSPACE_SELECTION_SCOPE_STALE","old-scope selection rejected"
r=app~setWorkspaceSelection("POSITIONS",1,.array~of("P-300","P-400")); call must r
current2=app~workspaceContext("POSITIONS")
r=send(app,"m-4",current2)
call assert r~ok & r~value=2,"new-scope selection accepted"

/* Context is required for an element explicitly bound to a workspace. */
r=sendNoContext(app,"m-5")
call assert \r~ok & r~code="WORKSPACE_CONTEXT_REQUIRED","workspace command cannot omit context"

say "PASS workspace command/query state"
exit 0

send:
  use arg app,id,context
  f=.table~new
  f["applicationId"]="APP"; f["sessionId"]="SESSION"; f["accessPointId"]="AP"; f["viewRef"]="MB.WORKSPACE"
  f["elementInstance"]="bulk-close"; f["action"]="POSITION.BULK.CLOSE"; f["renderedRevision"]=app~view~revision
  d=.table~new; d["workspaceContext"]=context; f["detail"]=d
  return app~receive(.WireUIProtocol~message(.WireUIProtocol~UI_ACTION,f))

sendNoContext:
  use arg app,id
  f=.table~new
  f["applicationId"]="APP"; f["sessionId"]="SESSION"; f["accessPointId"]="AP"; f["viewRef"]="MB.WORKSPACE"
  f["elementInstance"]="bulk-close"; f["action"]="POSITION.BULK.CLOSE"; f["renderedRevision"]=app~view~revision; f["detail"]=.table~new
  return app~receive(.WireUIProtocol~message(.WireUIProtocol~UI_ACTION,f))

selfCopy:
  use arg source
  d=.table~new
  do k over source~allIndexes
    v=source[k]
    if v~isA(.Array) then do
      a=.array~new; do x over v; a~append(x); end; d[k]=a
    end
    else d[k]=v
  end
  return d

must: use arg r; if \r~ok then raise syntax 88.900 array(r~code,r~detail); return r
assert: use arg ok,msg; if \ok then raise syntax 88.900 array("ASSERT",msg); return

::class WorkspaceTestApp subclass WireUIApplication
::method dispatchSemanticAction
  use arg action,message
  if action="POSITION.BULK.CLOSE" then do
    detail=message["detail"]; ctx=detail["workspaceContext"]
    return .WireUIResult~success(ctx["selectedIds"]~items,"BULK_COMMAND_ACCEPTED")
  end
  return .WireUIResult~failure("UNKNOWN_ACTION",action)

::requires "WireUIAll.cls"
