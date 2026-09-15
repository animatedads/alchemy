/* Server-authored workspace context and returned JS semantic action acceptance. */
parse arg mode rest
if mode="" then mode="emit"
view=.WireUIView~new("MB.WORKSPACE","root")
root=.table~new; root["visible"]=.true
call must view~createInstance("root","WORKSPACE@1",root)
button=.table~new; button["action"]="POSITION.BULK.CLOSE"; button["workspaceRef"]="POSITIONS"; button["enabled"]=.true
call must view~createInstance("bulk-close","BULK_ACTION@1",button,"root")
view~setActionAvailable("bulk-close","POSITION.BULK.CLOSE",.true)
app=.CrossWorkspaceApp~new("APP","SESSION","AP",view,.WireUIProjection~new)
call must app~registerWorkspace("POSITIONS")
call must app~setWorkspaceSelection("POSITIONS",0,.array~of("P-100","P-200"))
call must app~setWorkspaceSort("POSITIONS","NOTIONAL","DESC")
aggregates=.table~new; aggregates["grossNotional"]=12500000; aggregates["marginShortfall"]=500000
call must app~publishWorkspaceResult("POSITIONS",50000,aggregates,"RISK-SNAPSHOT-41","2026-08-28T13:00:00Z")
ctx=app~workspaceContext("POSITIONS")

select
  when mode="emit" then do
    say "CONTEXT" json(ctx)
    say "REVISION" view~revision
    exit 0
  end
  when mode="accept" then do
    parse var rest qrev srev orev selv rrev rqrev rsrev rorev ids
    supplied=.table~new
    supplied["workspaceRef"]="POSITIONS"; supplied["queryRevision"]=qrev; supplied["scopeRevision"]=srev; supplied["orderRevision"]=orev; supplied["selectionRevision"]=selv
    supplied["resultRevision"]=rrev; supplied["resultQueryRevision"]=rqrev; supplied["resultScopeRevision"]=rsrev; supplied["resultOrderRevision"]=rorev; supplied["resultCurrent"]=.true
    selected=.array~new
    do while ids<>""
      parse var ids one ',' ids
      if one<>"" then selected~append(one)
    end
    supplied["selectedIds"]=selected
    m=.table~new; m["type"]=.WireUIProtocol~UI_ACTION; m["messageId"]="cross-workspace"
    m["applicationId"]="APP"; m["sessionId"]="SESSION"; m["accessPointId"]="AP"; m["viewRef"]="MB.WORKSPACE"
    m["elementInstance"]="bulk-close"; m["action"]="POSITION.BULK.CLOSE"; m["renderedRevision"]=view~revision
    detail=.table~new; detail["workspaceContext"]=supplied; m["detail"]=detail
    r=app~receive(m); call must r
    say "RESULT" r~code r~value
    exit 0
  end
  otherwise do; say "FAIL unknown mode" mode; exit 2; end
end

::routine must
 use arg r
 if \r~ok then do; say "FAIL" r~code r~detail; exit 4; end
 return

::routine json
  use arg value
  if value==.nil then return "null"
  if value~isA(.string) then do
    s=value~string
    if datatype(s,"N") then return s
  end
  if value==.true then return "true"
  if value==.false then return "false"
  if value~isA(.table) | value~isA(.directory) then do
    keys=value~allIndexes; keys~sort; out="{"; first=.true
    do k over keys
      if \first then out ||= ","
      out ||= quote(k)":"json(value[k]); first=.false
    end
    return out"}"
  end
  if value~isA(.array) then do
    out="["; do i=1 to value~items; if i>1 then out ||= ","; out ||= json(value[i]); end; return out"]"
  end
  s=value~string; if datatype(s,"N") then return s
  return quote(s)
::routine quote
  use arg s
  s=changestr('\\',s,'\\\\'); s=changestr('"',s,'\\"'); s=changestr('0a'x,s,'\\n'); s=changestr('0d'x,s,'\\r')
  return '"'s'"'

::class CrossWorkspaceApp subclass WireUIApplication
::method dispatchSemanticAction
  use arg action,message
  detail=message["detail"]; ctx=detail["workspaceContext"]
  return .WireUIResult~success(ctx["selectedIds"]~items,"WORKSPACE_COMMAND_ACCEPTED")

::requires "WireUIAll.cls"
