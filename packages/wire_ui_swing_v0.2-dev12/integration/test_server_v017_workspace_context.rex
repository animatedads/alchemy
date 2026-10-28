/* Server v0.17 authoritative workspaceContext -> Swing event-time passthrough -> server validation. */
actionName="POSITION.BULK.CLOSE"
workspaceRef="POSITIONS"

def=.WireUIElementDefinition~new("WORKSPACE_CLOSE","1","BUTTON",actionName,"Close selected")
defs=.array~of(def)
manifest=.WireUIDefinitionManifest~new("server-v017-workspace","swing-large-fine",defs)

view=.WireUIView~new("workspace-v017-view","close")
slots=.table~new
slots["action"]=actionName
slots["workspaceRef"]=workspaceRef
call must view~createInstance("close",def~definitionKey,slots,"")

app=.WorkspaceTestApplication~new("workspace-app","workspace-session","swing-desktop",view,.nil)
call must app~registerWorkspace(workspaceRef)
query=app~workspaceQuery(workspaceRef)
call must app~setWorkspaceSelection(workspaceRef,query~scopeRevision,.array~of("P-100","P-200"))
call must app~publishWorkspaceResult(workspaceRef,2)

contextA=app~workspaceContext(workspaceRef)
contextA["futureServerToken"]="opaque-A"
r=view~setSlot("close","workspaceContext",contextA); call must r
view~setActionAvailable("close",actionName,.true)
if view~revision<>1 then call fail "initial workspace view revision" view~revision

bridge=.WireUISwingBridge~new
bridge~hello("workspace-app","workspace-session","swing-desktop")
ignore=bridge~drainOutbound
fields=manifest~asWire
bridge~accept(.WireUIProtocol~message(.WireUIProtocol~UI_RENDER_PROFILE,fields))
required=bridge~drainOutbound
if required~items<>1 then call fail "workspace definition request count" required~items
if required[1]["type"]<>.WireUIProtocol~UI_DEFINITION_REQUIRED then call fail "workspace definition request type" required[1]["type"]
wire=def~asWire; wire["profileId"]="swing-large-fine"
bridge~accept(.WireUIProtocol~message(.WireUIProtocol~UI_DEFINITION,wire))
bridge~accept(view~snapshot)
if bridge~revision<>1 then call fail "workspace snapshot revision" bridge~revision

/* Current event-time context is accepted by the authoritative server. */
bridge~rootComponent~doClick
first=bridge~pollAction
call assertContext first,contextA,"A current"
r=app~receive(first)
if \r~ok then call fail "current workspace action rejected" r~code
if r~code<>"WORKSPACE_COMMAND_ACCEPTED" then call fail "current workspace action dispatch" r~code

/* Queue another A action, then advance authoritative workspace + view before polling it. */
bridge~rootComponent~doClick
call must app~setWorkspaceSort(workspaceRef,"risk","DESC")
query=app~workspaceQuery(workspaceRef)
call must app~setWorkspaceSelection(workspaceRef,query~scopeRevision,.array~of("P-300"))
call must app~publishWorkspaceResult(workspaceRef,1)
contextB=app~workspaceContext(workspaceRef)
contextB["futureServerToken"]="opaque-B"
r=view~setSlot("close","workspaceContext",contextB); call must r
view~setActionAvailable("close",actionName,.true)
if r~value["newRevision"]<>2 then call fail "workspace B patch revision" r~value["newRevision"]
bridge~accept(r~value)
if bridge~revision<>2 then call fail "workspace B renderer revision" bridge~revision

queuedA=bridge~pollAction
call assertContext queuedA,contextA,"A queued across patch"
if queuedA["renderedRevision"]<>1 then call fail "queued A renderedRevision" queuedA["renderedRevision"]
stale=app~receive(queuedA)
if stale~ok | stale~code<>"STALE_UI_ACTION" then call fail "queued A server stale classification" stale~code

/* A later action captures the newly projected context B and is accepted. */
bridge~rootComponent~doClick
second=bridge~pollAction
call assertContext second,contextB,"B current"
if second["renderedRevision"]<>2 then call fail "B renderedRevision" second["renderedRevision"]
r=app~receive(second)
if \r~ok then call fail "B workspace action rejected" r~code
if r~code<>"WORKSPACE_COMMAND_ACCEPTED" then call fail "B workspace action dispatch" r~code

out=bridge~drainOutbound
if out~items<>0 then call fail "unexpected workspace renderer outbound" out~items
say "PASS Server v0.17 workspaceContext -> Swing event-time freeze/opaque echo -> server validation revisions=1,2"
exit 0

::routine assertContext
  use arg message,expected,label
  if message==.nil then call fail label" missing action"
  detail=message["detail"]
  if detail==.nil then call fail label" missing detail"
  actual=detail["workspaceContext"]
  if actual==.nil then call fail label" missing workspaceContext"
  do key over expected~allIndexes
    if \actual~hasIndex(key) then call fail label" missing context field" key
    if expected[key]~isA(.Array) then do
      if \sameArray(expected[key],actual[key]) then call fail label" array mismatch" key
    end
    else if actual[key]<>expected[key] then call fail label" context mismatch" key
  end
  if actual["futureServerToken"]<>expected["futureServerToken"] then call fail label" future field"
  if actual["resultRevision"]<>expected["resultRevision"] then call fail label" resultRevision"
  return

::routine sameArray
  use arg a,b
  if b==.nil | \b~isA(.Array) then return .false
  if a~items<>b~items then return .false
  do i=1 to a~items
    if a[i]<>b[i] then return .false
  end
  return .true

::routine must
  use arg r
  if \r~ok then call fail "server operation" r~code
  return r

::routine fail
  use arg what,detail=""
  say "FAIL" what detail
  exit 31

::class WorkspaceTestApplication subclass WireUIApplication
::method dispatchSemanticAction
  use arg action,message
  return .WireUIResult~success(action,"WORKSPACE_COMMAND_ACCEPTED")

::requires "WireUISwingBridge.cls"
::requires "WireUIElementDefinition.cls"
::requires "WireUIDefinitionManifest.cls"
::requires "WireUIView.cls"
::requires "WireUIApplication.cls"
