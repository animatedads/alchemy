bridge=.WireUISwingBridge~new
bridge~hello("bsf-desktop","session","swing")

def=.table~new; def["definitionId"]="ROOT"; def["definitionVersion"]=1; def["definitionKey"]="ROOT@1"; def["primitive"]="PANEL"; def["contentAddress"]="root"
bridge~accept(message("UI_DEFINITION",def))
def=.table~new; def["definitionId"]="TITLE"; def["definitionVersion"]=1; def["definitionKey"]="TITLE@1"; def["primitive"]="TEXT"; def["contentAddress"]="title"
bridge~accept(message("UI_DEFINITION",def))
slots=.table~new; slots["text"]="ooRexx -> BSF -> real JFrame"
instances=.array~of(instance("root","ROOT@1","",.table~new),instance("title","TITLE@1","root",slots))
snap=.table~new; snap["viewRef"]="desktop"; snap["revision"]=0; snap["rootInstanceId"]="root"; snap["instances"]=instances
bridge~accept(message("UI_VIEW_SNAPSHOT",snap))
bridge~openDesktopWindow("Wire UI BSF Desktop",800,520)
if \bridge~desktopWindowVisible then call fail "desktop window not visible"
bridge~closeDesktopWindow
if bridge~desktopWindowVisible then call fail "desktop window remained visible"
say "PASS ooRexx -> BSF -> WireSwingDesktopWindow real JFrame show/dispose"
exit 0

instance:
  use arg id,key,parent,slots
  x=.table~new; x["instanceId"]=id; x["definitionKey"]=key; x["parentId"]=parent; x["slots"]=slots; return x
message:
  use arg type,fields
  m=.table~new; m["type"]=type; m["protocolVersion"]="WIRE-UI/0.1"; do k over fields; m[k]=fields[k]; end; return m
fail:
  use arg detail
  say "FAIL" detail
  exit 30
::requires "WireUISwingBridge.cls"
