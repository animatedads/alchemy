bridge=.WireUISwingBridge~new

hello=bridge~hello("bsf-app", "bsf-session", "swing-desktop")
if hello["type"]<>"UI_HELLO" then call fail "hello type"
if hello["protocolVersion"]<>"WIRE-UI/0.1" then call fail "hello protocol"
caps=hello["renderCapabilities"]
if caps["uiToolkit"]<>"JAVA_SWING" then call fail "hello toolkit"

profile=.table~new
profile["type"]="UI_RENDER_PROFILE"
profile["protocolVersion"]="WIRE-UI/0.1"
profile["profileId"]="swing-large-fine"
bridge~accept(profile)

refs=.array~new
refs~append(ref("ROOT",1,"addr-root"))
refs~append(ref("TITLE",1,"addr-title"))
manifest=.table~new
manifest["type"]="UI_DEFINITION_MANIFEST"
manifest["protocolVersion"]="WIRE-UI/0.1"
manifest["manifestId"]="m-bsf"
manifest["profileId"]="swing-large-fine"
manifest["definitions"]=refs
bridge~accept(manifest)

required=bridge~drainOutbound
if required~items<>1 then call fail "manifest cold request count"
if required[1]["type"]<>"UI_DEFINITION_REQUIRED" then call fail "manifest cold request type"
if required[1]["definitions"]~items<>2 then call fail "manifest cold request definitions"

bridge~accept(definition("ROOT",1,"PANEL","","addr-root"))
bridge~accept(definition("TITLE",1,"TEXT","","addr-title"))

instances=.array~new
instances~append(instance("root","ROOT@1","",.table~new))
titleSlots=.table~new; titleSlots["text"]="From ooRexx"
instances~append(instance("title","TITLE@1","root",titleSlots))

snapshot=.table~new
snapshot["type"]="UI_VIEW_SNAPSHOT"
snapshot["protocolVersion"]="WIRE-UI/0.1"
snapshot["viewRef"]="view-bsf"
snapshot["revision"]=1
snapshot["rootInstanceId"]="root"
snapshot["instances"]=instances
bridge~accept(snapshot)
if bridge~revision<>1 then call fail "snapshot did not commit"

slot=.table~new
slot["op"]="SET_SLOT"
slot["instanceId"]="title"
slot["slot"]="text"
slot["value"]="Patched from ooRexx"
ops=.array~new; ops~append(slot)
patch=.table~new
patch["type"]="UI_VIEW_PATCH"
patch["protocolVersion"]="WIRE-UI/0.1"
patch["viewRef"]="view-bsf"
patch["previousRevision"]=1
patch["newRevision"]=2
patch["operations"]=ops
bridge~accept(patch)
if bridge~revision<>2 then call fail "patch did not commit"

errors=bridge~drainOutbound
if errors~items<>0 then do
  say "unexpected outbound count="errors~items
  exit 21
end

say "PASS ooRexx -> BSF -> WireSwingRuntime snapshot/patch roundtrip revision="bridge~revision
exit 0

::routine definition
  use arg id,version,primitive,action,address
  d=.table~new
  d["type"]="UI_DEFINITION"; d["protocolVersion"]="WIRE-UI/0.1"
  d["definitionId"]=id; d["definitionVersion"]=version; d["definitionKey"]=id"@"version
  d["primitive"]=primitive; d["action"]=action; d["label"]=""; d["styleRole"]=""
  d["contentAddress"]=address; d["profileId"]="swing-large-fine"; d["metadata"]=.table~new
  return d

::routine ref
  use arg id,version,address
  d=.table~new; d["id"]=id; d["version"]=version; d["contentAddress"]=address
  return d

::routine instance
  use arg id,key,parent,slots
  d=.table~new; d["instanceId"]=id; d["definitionKey"]=key; d["parentId"]=parent; d["slots"]=slots
  return d

::routine fail
  use arg what
  say "FAIL" what
  exit 20

::requires "WireUISwingBridge.cls"
