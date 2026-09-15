call test
say "PASS test_builder_application_self_source"
exit 0

test:
  parse source . . script
  root=filespec("P",script); if root~right(6)="tests/" then root=root~left(root~length-6)
  sources=.WireUISourceCatalogue~new("BUILDER_SELF_SOURCE")
  call assert sources~addTree(root,"*.cls",.true,"builder")~ok,"scan Builder source"
  call assert sources~seal~ok,"seal Builder source catalogue"
  target=.WireUIBuilderProject~new("SELF_SOURCE_SITE","Builder Source Site")
  br=.WireUIBuilderRuntimeFactory~build(target,sources,"BUILDER-APP","SELF-SOURCE","BUILDER-WEB",root"/studio/wire_ui_builder_studio_v0.11.json")
  call assert br~ok,"Builder application factory"
  app=br~value
  sourceInstance=app~view~instance("source-files")
  call assert sourceInstance<>.nil,"Builder source window is rendered in its own Studio"
  call assert sourceInstance["slots"]["windowTotalCount"]=sources~fileCount,"source window carries authoritative total count"
  call assert sourceInstance["children"]~items=min(25,sources~fileCount),"source window materialises only its initial bounded rows"
  do rowId over sourceInstance["children"]
    row=app~view~instance(rowId); call assert row<>.nil,"window row is a real semantic instance"
    call assert row["slots"]["label"]~isA(.String),"SOURCE row carries only a stable path label"
    call assert row["slots"]["label"]~pos("source-hc-")=0,"SOURCE navigator does not dump content addresses"
  end
  selected=sources~file("builder/src/WireUISourceCatalogue.cls"); call assert selected<>.nil,"catalogue source located by stable path"
  rowId=findSourceRow(app,selected~path)
  if rowId="" then do
    d=.directory~new; d["filter"]="WireUISourceCatalogue.cls"; d["sortRef"]="PATH"; d["direction"]="ASC"; d["offset"]=0; d["limit"]=25
    sr=send(app,"source-window-control","SOURCE.WINDOW",d); call assert sr~ok,"source window filtered to requested path"
    rowId=findSourceRow(app,selected~path)
  end
  call assert rowId<>"","catalogue source is present in an authoritative source window"
  sr=send(app,rowId,"SOURCE.OPEN",.directory~new); call assert sr~ok,"source opened through real window-row UI_ACTION"
  sourceDetail=app~view~instance("source-detail")
  call assert sourceDetail<>.nil,"source detail instance exists"
  call assert sourceDetail["slots"]["visible"],"source detail becomes visible"
  call assert sourceDetail["slots"]["path"]=selected~path,"source detail path projected"
  call assert sourceDetail["slots"]["attributes"]~pos("catalogueId")>0,"source detail attributes are readable"
  selected=sources~file("builder/src/WireUIDesignSupport.cls"); call assert selected<>.nil,"support source located by stable path"
  d=.directory~new; d["filter"]="WireUIDesignSupport.cls"; d["sortRef"]="PATH"; d["direction"]="ASC"; d["offset"]=0; d["limit"]=25
  sr=send(app,"source-window-control","SOURCE.WINDOW",d); call assert sr~ok,"source window can change authoritative membership scope"
  rowId=findSourceRow(app,selected~path); call assert rowId<>"","support source window row materialised"
  sr=send(app,rowId,"SOURCE.OPEN",.directory~new); call assert sr~ok,"second source opened through same semantic row action"
  sourceDetail=app~view~instance("source-detail")
  call assert sourceDetail["slots"]["path"]=selected~path,"source detail switches deterministically"
  call assert sourceDetail["slots"]["constants"]~pos("PACKAGE_VERSION")>0,"source constants are visible in Studio state"

  d=.directory~new; d["artifactId"]="SOURCE_RECORD"; d["publishVersion"]="1"; d["primitive"]="SEMANTIC_RECORD"
  call must send(app,"component-editor","DESIGN.COMPONENT.DRAFT",d)
  d=.directory~new; d["artifactId"]="SOURCE_INFO"; d["publishVersion"]="1"; d["semanticType"]="SOURCE_INFO"; d["fields"]="path,classes,methods"; d["actions"]=""; d["audiencePolicyRef"]="PUBLIC"
  call must send(app,"element-editor","DESIGN.ELEMENT.DRAFT",d)
  d=.directory~new; d["artifactId"]="SOURCE_MATERIAL"; d["publishVersion"]="1"; d["tokenName"]="space.unit"; d["tokenValue"]="8"
  call must send(app,"material-editor","DESIGN.MATERIAL.DRAFT",d)
  d=.directory~new; d["artifactId"]="SOURCE_INFO_VIEW"; d["publishVersion"]="1"; d["profile"]="HUMAN_VISUAL"; d["elementId"]="SOURCE_INFO"; d["componentId"]="SOURCE_RECORD"; d["definitionId"]="SELF_SOURCE_INFO"; d["action"]=""; d["styleRole"]="source.detail"; d["materialRole"]="source.detail"
  call must send(app,"projection-editor","DESIGN.PROJECTION.DRAFT",d)
  d=.directory~new; d["artifactId"]="SOURCE_JOURNEY"; d["publishVersion"]="1"; d["initialState"]="SOURCE"; d["stateId"]="SOURCE"; d["active"]="SOURCE_INFO"; d["prefetch"]=""; d["onDemand"]=""
  call must send(app,"journey-editor","DESIGN.JOURNEY.DRAFT",d)
  call assert target~revision=5,"five browser-authoring operations hit target project only"
  call assert target~workspace~allArtifacts~items=0,"target remains draft before publish"

  d=.directory~new; d["releaseId"]="SELF_SOURCE_SITE"; d["releaseVersion"]="1"
  rr=send(app,"publish","DESIGN.PUBLISH",d); call assert rr~ok,"target project published from Builder Studio action"
  call assert target~workspace~artifact("COMPONENT","SOURCE_RECORD","1")<>.nil,"component published"
  call assert target~workspace~artifact("ELEMENT","SOURCE_INFO","1")<>.nil,"element published"
  call assert target~workspace~artifact("PROJECTION","SOURCE_INFO_VIEW","1")<>.nil,"projection published"
  release=target~workspace~artifact("SITE_RELEASE","SELF_SOURCE_SITE","1"); call assert release<>.nil,"release published"
  call assert release~ref~contentAddress~left(7)="sha512-","published release strongly sealed"
  return

findSourceRow:
  use arg app,path
  parent=app~view~instance("source-files"); if parent==.nil then return ""
  do id over parent["children"]
    row=app~view~instance(id)
    if row<>.nil then if row["slots"]["label"]=path then return id
  end
  return ""

send:
  use arg app,instanceId,action,detail
  f=.directory~new; f["applicationId"]=app~applicationId; f["sessionId"]=app~sessionId; f["accessPointId"]=app~accessPointId; f["viewRef"]=app~view~viewRef; f["elementInstance"]=instanceId; f["action"]=action; f["renderedRevision"]=app~view~revision; f["detail"]=detail
  m=.WireUIProtocol~message(.WireUIProtocol~UI_ACTION,f)
  return app~receive(m)
must: use arg r; if \r~ok then raise syntax 88.900 array(r~code,r~detail); return r
assert: use arg ok,msg; if \ok then raise syntax 88.900 array("ASSERT",msg); return
::requires "WireUIBuilderApplication.cls"
::requires "WireUISourceCatalogue.cls"
