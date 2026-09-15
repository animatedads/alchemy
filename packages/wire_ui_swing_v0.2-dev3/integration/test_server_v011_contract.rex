bridge=.WireUISwingBridge~new

rootDef=.WireUIElementDefinition~new("SERVER_ROOT","1","PANEL")
titleDef=.WireUIElementDefinition~new("SERVER_TITLE","1","TEXT")
defs=.array~of(rootDef,titleDef)
manifest=.WireUIDefinitionManifest~new("server-contract","swing-large-fine",defs)

fields=manifest~asWire
bridge~accept(.WireUIProtocol~message(.WireUIProtocol~UI_RENDER_PROFILE,fields))
bridge~accept(.WireUIProtocol~message(.WireUIProtocol~UI_DEFINITION_MANIFEST,fields))

do definition over defs
  wire=definition~asWire
  wire["profileId"]="swing-large-fine"
  bridge~accept(.WireUIProtocol~message(.WireUIProtocol~UI_DEFINITION,wire))
end

view=.WireUIView~new("server-view","root")
r=view~createInstance("root",rootDef~definitionKey,.table~new,"")
if \r~ok then call fail "server root create" r~code
slots=.table~new; slots["text"]="Server v0.11 snapshot"
r=view~createInstance("title",titleDef~definitionKey,slots,"root")
if \r~ok then call fail "server title create" r~code

bridge~accept(view~snapshot)
if bridge~revision<>0 then call fail "server snapshot revision" bridge~revision

patchResult=view~setSlot("title","text","Server v0.11 patch")
if \patchResult~ok then call fail "server setSlot" patchResult~code
bridge~accept(patchResult~value)
if bridge~revision<>1 then call fail "server patch revision" bridge~revision

out=bridge~drainOutbound
if out~items<>0 then call fail "unexpected renderer outbound" out~items

say "PASS Wire UI Server v0.11 objects -> ooRexx bridge -> Swing revision="bridge~revision
exit 0

::routine fail
  use arg what,detail=""
  say "FAIL" what detail
  exit 30

::requires "WireUISwingBridge.cls"
::requires "WireUIElementDefinition.cls"
::requires "WireUIDefinitionManifest.cls"
::requires "WireUIView.cls"
