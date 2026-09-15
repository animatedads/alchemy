call test
say "PASS test_source_workspace_v016"
exit 0

test:
  parse source . . script
  root=filespec("P",script); if root~right(6)="tests/" then root=root~left(root~length-6)
  sources=.WireUISourceCatalogue~new("BUILDER_V010_SOURCE_WORKSPACE")
  call assert sources~addTree(root,"*.cls",.true,"builder")~ok,"scan Builder source"
  call assert sources~seal~ok,"seal source catalogue"
  target=.WireUIBuilderProject~new("SOURCE_WORKSPACE_TARGET","Source workspace target")
  br=.WireUIBuilderRuntimeFactory~build(target,sources,"BUILDER-APP","SOURCE-WORKSPACE","BUILDER-WEB",root"/studio/wire_ui_builder_studio_v0.11.json")
  call assert br~ok,"Builder application factory"
  app=br~value

  q=app~workspaceQuery("BUILDER_SOURCE"); s=app~workspaceSelection("BUILDER_SOURCE")
  call assert q<>.nil & s<>.nil,"Server v0.16 source workspace registered"
  initialQuery=q~queryRevision; initialScope=q~scopeRevision; initialOrder=q~orderRevision
  parent=app~view~instance("source-files")
  call assert parent<>.nil,"source window parent exists"
  call assert parent["slots"]["windowTotalCount"]=sources~fileCount,"window total count is authoritative"
  call assert parent["children"]~items<=25,"browser receives bounded source window"
  call assert parent["children"]~items>0,"source window has visible rows"

  firstId=parent["children"][1]; first=app~view~instance(firstId); firstPath=first["slots"]["label"]
  r=send(app,firstId,"SOURCE.OPEN",.directory~new); call assert r~ok,"row semantic action selects source"
  s=app~workspaceSelection("BUILDER_SOURCE")
  call assert s~selectedIds~items=1 & s~contains(firstPath),"source selection is semantic identity"
  selectedRevision=s~selectionRevision
  detail=app~view~instance("source-detail")
  call assert detail["slots"]["visible"],"selected source detail visible"
  call assert detail["slots"]["selectionRevision"]=selectedRevision,"detail exposes authoritative selection revision"

  d=.directory~new; d["filter"]=""; d["sortRef"]="PATH"; d["direction"]="DESC"; d["offset"]=0; d["limit"]=10
  r=send(app,"source-window-control","SOURCE.WINDOW",d); call assert r~ok,"source order changed through semantic action"
  q2=app~workspaceQuery("BUILDER_SOURCE"); s2=app~workspaceSelection("BUILDER_SOURCE")
  call assert q2~scopeRevision=initialScope,"sorting does not change membership scope"
  call assert q2~orderRevision>initialOrder & q2~queryRevision>initialQuery,"sorting advances order/query revisions"
  call assert s2~selectionRevision=selectedRevision & s2~contains(firstPath),"sorting preserves semantic selection"
  sortedScope=q2~scopeRevision
  parent=app~view~instance("source-files")
  call assert parent["slots"]["windowLimit"]=10 & parent["children"]~items<=10,"requested source window limit applied"

  d=.directory~new; d["filter"]="WireUIBuilderApplication.cls"; d["sortRef"]="PATH"; d["direction"]="DESC"; d["offset"]=50; d["limit"]=10
  r=send(app,"source-window-control","SOURCE.WINDOW",d); call assert r~ok,"source membership filter changed through semantic action"
  q3=app~workspaceQuery("BUILDER_SOURCE"); s3=app~workspaceSelection("BUILDER_SOURCE")
  call assert q3~scopeRevision=sortedScope+1,"filter advances membership scope revision"
  call assert s3~scopeRevision=q3~scopeRevision & s3~selectedIds~items=0,"filter invalidates old semantic selection"
  detail=app~view~instance("source-detail"); call assert \detail["slots"]["visible"],"scope change hides stale source detail"
  parent=app~view~instance("source-files")
  call assert parent["slots"]["windowOffset"]=0,"scope change resets stale requested offset"
  call assert parent["slots"]["filterRef"]="WireUIBuilderApplication.cls","window carries current filter identity"
  call assert parent["children"]~items=1,"narrow filter materialises only matching row"
  only=app~view~instance(parent["children"][1]); call assert only["slots"]["label"]="builder/integration/WireUIBuilderApplication.cls","filtered row has stable source path"
  return

send:
  use arg app,instanceId,action,detail
  f=.directory~new; f["applicationId"]=app~applicationId; f["sessionId"]=app~sessionId; f["accessPointId"]=app~accessPointId; f["viewRef"]=app~view~viewRef; f["elementInstance"]=instanceId; f["action"]=action; f["renderedRevision"]=app~view~revision; f["detail"]=detail
  return app~receive(.WireUIProtocol~message(.WireUIProtocol~UI_ACTION,f))
assert: use arg ok,msg; if \ok then raise syntax 88.900 array("ASSERT",msg); return
::requires "WireUIBuilderApplication.cls"
::requires "WireUISourceCatalogue.cls"
