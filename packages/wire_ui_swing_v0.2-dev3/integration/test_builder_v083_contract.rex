/* Actual Wire UI Builder v0.8.3 compiled package -> Swing composition acceptance. */
project=.WireUIBuilderProject~new("SWING.BUILDER.TEST","Swing Builder Test")

call draft project,"DESIGN.COMPONENT.DRAFT","PANEL_COMPONENT",componentSpec("PANEL")
call draft project,"DESIGN.COMPONENT.DRAFT","TEXT_COMPONENT",componentSpec("TEXT")

do id over .array~of("ROOT","HEADER","NAVIGATION","SEARCH_PANEL","DETAIL_PANEL","NOTICES")
  call draft project,"DESIGN.ELEMENT.DRAFT",id,elementSpec(id)
end
call projection project,"ROOT","PANEL_COMPONENT","ROOT_DEF"
call projection project,"HEADER","TEXT_COMPONENT","HEADER_DEF"
call projection project,"NAVIGATION","PANEL_COMPONENT","NAVIGATION_DEF"
call projection project,"SEARCH_PANEL","PANEL_COMPONENT","SEARCH_PANEL_DEF"
call projection project,"DETAIL_PANEL","PANEL_COMPONENT","DETAIL_PANEL_DEF"
call projection project,"NOTICES","TEXT_COMPONENT","NOTICES_DEF"
call draft project,"DESIGN.JOURNEY.DRAFT","MAIN",journeySpec()
call draft project,"DESIGN.COMPOSITION.DRAFT","SEARCH_LAYOUT",compositionSpec()

published=project~publish("SWING_BUILDER_SITE","1")
if \published~ok then call fail "Builder publish" published~code
pkg=published~value["package"]
defs=pkg~definitions
if defs~items<>6 then call fail "compiled definitions" defs~items

bridge=.WireUISwingBridge~new
bridge~hello("builder-test","session","swing")

profile=.table~new; profile["profileId"]="swing-large-fine"
bridge~accept(message("UI_RENDER_PROFILE",profile))

refs=.array~new
do d over defs
  ref=.table~new; ref["id"]=d["definitionId"]; ref["version"]=d["definitionVersion"]; ref["contentAddress"]=d["contentAddress"]
  refs~append(ref)
end
mf=.table~new; mf["manifestId"]="builder-v083"; mf["profileId"]="swing-large-fine"; mf["definitions"]=refs
bridge~accept(message("UI_DEFINITION_MANIFEST",mf))

do d over defs
  d["profileId"]="swing-large-fine"
  bridge~accept(message("UI_DEFINITION",d))
end

instances=.array~new
instances~append(instance("root","ROOT_DEF@1","",.table~new))
slots=.table~new; slots["text"]="App Header"; instances~append(instance("header","HEADER_DEF@1","root",slots))
instances~append(instance("nav","NAVIGATION_DEF@1","root",.table~new))
instances~append(instance("search","SEARCH_PANEL_DEF@1","root",.table~new))
instances~append(instance("detail","DETAIL_PANEL_DEF@1","root",.table~new))
slots=.table~new; slots["text"]="Notices"; instances~append(instance("notices","NOTICES_DEF@1","root",slots))
snap=.table~new; snap["viewRef"]="builder-search"; snap["revision"]=0; snap["rootInstanceId"]="root"; snap["instances"]=instances
bridge~accept(message("UI_VIEW_SNAPSHOT",snap))
if bridge~revision<>0 then call fail "snapshot revision" bridge~revision

root=bridge~rootComponent
if root~getComponentCount<5 then call fail "root child count" root~getComponentCount
layout=root~getLayout
expectedWidth=.array~of(12,3,5,4,12)
expectedX=.array~of(0,0,3,8,0)
expectedY=.array~of(0,1,1,1,2)
do i=1 to 5
  c=layout~getConstraints(root~getComponent(i-1))
  if c~gridwidth<>expectedWidth[i] then call fail "gridwidth" i"="c~gridwidth
  if c~gridx<>expectedX[i] then call fail "gridx" i"="c~gridx
  if c~gridy<>expectedY[i] then call fail "gridy" i"="c~gridy
end

out=bridge~drainOutbound
if out~items<>0 then call fail "unexpected renderer outbound" out~items
say "PASS Builder v0.8.3 compiled GRID12 -> ooRexx/BSF -> Swing widths=12,3,5,4,12"
exit 0

projection:
  use arg p,elementId,componentId,definitionId
  s=.table~new; s["publishVersion"]="1"; s["profile"]="HUMAN_VISUAL"; s["elementId"]=elementId; s["componentId"]=componentId; s["definitionId"]=definitionId; s["styleRole"]=elementId~lower
  call draft p,"DESIGN.PROJECTION.DRAFT",elementId"_VIEW",s
  return

draft:
  use arg p,verb,id,spec
  payload=.table~new; payload["artifactId"]=id; payload["spec"]=spec
  op=.WireUIDesignOperation~new("op-"p~revision"-"id,verb,p~revision,.nil,payload,"TEST")
  r=p~applyOperation(op); if \r~ok then call fail verb" "id,r~code" "r~detail
  return

componentSpec:
  use arg primitive
  s=.table~new; s["publishVersion"]="1"; s["primitive"]=primitive; return s

elementSpec:
  use arg semanticType
  s=.table~new; s["publishVersion"]="1"; s["semanticType"]=semanticType; s["fields"]=.array~of("text"); s["actions"]=.array~new; s["audiencePolicyRef"]="PUBLIC"; return s

journeySpec:
  s=.table~new; s["publishVersion"]="1"; s["initialState"]="SEARCH"
  row=.table~new; row["stateId"]="SEARCH"; row["ACTIVE"]=.array~of("ROOT","HEADER","NAVIGATION","SEARCH_PANEL","DETAIL_PANEL","NOTICES"); row["PREFETCH"]=.array~new; row["ON_DEMAND"]=.array~new
  s["states"]=.array~of(row); return s

compositionSpec:
  s=.table~new; s["publishVersion"]="1"; s["journeyId"]="MAIN"; s["profile"]="HUMAN_VISUAL"; s["stateId"]="SEARCH"; s["layoutModel"]="GRID12"
  rows=.array~new
  rows~append(place("ROOT",0,12))
  rows~append(place("HEADER",10,12))
  rows~append(place("NAVIGATION",20,3))
  rows~append(place("SEARCH_PANEL",30,5))
  rows~append(place("DETAIL_PANEL",40,4))
  rows~append(place("NOTICES",50,12))
  s["placements"]=rows; return s

place:
  use arg elementId,order,span
  p=.table~new; p["elementId"]=elementId; p["projectionId"]=""; p["region"]="main"; p["order"]=order; p["span"]=span; p["rowSpan"]=1; p["align"]="STRETCH"; p["viewportClass"]="DEFAULT"; return p

instance:
  use arg id,key,parent,slots
  x=.table~new; x["instanceId"]=id; x["definitionKey"]=key; x["parentId"]=parent; x["slots"]=slots; return x

message:
  use arg type,fields
  m=.table~new; m["type"]=type; m["protocolVersion"]="WIRE-UI/0.1"
  do k over fields; m[k]=fields[k]; end
  return m

fail:
  use arg what,detail=""
  say "FAIL" what detail
  exit 30

::requires "WireUISwingBridge.cls"
::requires "WireUIBuilderAll.cls"
