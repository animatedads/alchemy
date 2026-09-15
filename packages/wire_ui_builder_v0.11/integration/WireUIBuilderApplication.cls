/*
  Standalone Builder Studio Wire UI application.
  Studio design and target design are intentionally different projects.
*/
::class WireUIBuilderApplication subclass WireUIApplication public
::attribute targetProject get
::attribute sourceCatalogue get
::method init
  expose targetProject sourceCatalogue lastPublished studioState sourceWorkspaceRef sourceWindowRevision sourceWindowOffset sourceWindowLimit sourceFilter sourceSortRef sourceSortDirection
  use arg applicationId, sessionId, accessPointId, view, projection, targetProject, sourceCatalogue=.nil
  self~init:super(applicationId,sessionId,accessPointId,view,projection)
  if targetProject==.nil | \targetProject~isA(.WireUIBuilderProject) then raise syntax 88.900 array("BUILDER_TARGET_PROJECT_REQUIRED")
  lastPublished=.nil
  studioState="DESIGN"
  sourceWorkspaceRef="BUILDER_SOURCE"; sourceWindowRevision=0; sourceWindowOffset=0; sourceWindowLimit=25
  sourceFilter=""; sourceSortRef="PATH"; sourceSortDirection="ASC"

::method installInitialView
  expose targetProject sourceCatalogue sourceWorkspaceRef sourceWindowOffset sourceWindowLimit sourceFilter sourceSortRef sourceSortDirection
  v=self~view
  shell=.table~new; shell["visible"]=.true
  call must v~createInstance("root","WUIB_SHELL@1",shell)

  project=.table~new; project["projectId"]=targetProject~projectId; project["title"]=targetProject~title; project["revision"]=targetProject~revision; project["draftCount"]=targetProject~drafts~items; project["visible"]=.true
  call must v~createInstance("project","WUIB_PROJECT@1",project,"root")

  toolNav=.table~new; toolNav["items"]=.array~of("DESIGN","SOURCE","COMPONENTS","MATERIALS","FLOW","PUBLISH"); toolNav["visible"]=.true; toolNav["action"]="STUDIO.NAVIGATE"
  call must v~createInstance("tool-nav","WUIB_TOOL_NAV@1",toolNav,"root"); v~setActionAvailable("tool-nav","STUDIO.NAVIGATE",.true)

  library=.table~new; library["items"]=self~artifactLibraryItems; library["visible"]=.true; library["action"]="ARTIFACT.SELECT"
  call must v~createInstance("artifact-library","WUIB_ARTIFACT_LIBRARY@1",library,"root"); v~setActionAvailable("artifact-library","ARTIFACT.SELECT",.true)

  inspector=.table~new; inspector["kind"]="NONE"; inspector["artifactId"]=""; inspector["draftRevision"]=""; inspector["publishVersion"]=""; inspector["detail"]="Select an artifact or canvas placement"; inspector["visible"]=.true
  call must v~createInstance("selection-inspector","WUIB_SELECTION_INSPECTOR@1",inspector,"root")

  flow=.table~new; flow["items"]=self~flowMapItems; flow["visible"]=.true; flow["action"]="FLOW.SELECT"
  call must v~createInstance("flow-map","WUIB_FLOW_MAP@1",flow,"root"); v~setActionAvailable("flow-map","FLOW.SELECT",.true)

  /* SOURCE is a first-class authoritative workspace.  The browser receives only
     the current source window; filtering changes membership scope while sorting
     changes order only.  Stable source identity remains the catalogue path. */
  call must self~registerWorkspace(sourceWorkspaceRef)
  call must self~setWorkspaceSort(sourceWorkspaceRef,sourceSortRef,sourceSortDirection)
  source=.table~new
  source["collectionRef"]=sourceWorkspaceRef; source["windowOffset"]=0; source["windowLimit"]=sourceWindowLimit
  source["windowTotalCount"]=0; source["windowRevision"]=0; source["sortRef"]=sourceSortRef; source["filterRef"]=sourceFilter; source["anchorRef"]=""; source["visible"]=.true
  call must v~createInstance("source-files","WUIB_SOURCE_FILES@1",source,"root")
  sourceControl=.table~new; sourceControl["filter"]=""; sourceControl["sortRef"]="PATH"; sourceControl["direction"]="ASC"; sourceControl["offset"]=0; sourceControl["limit"]=sourceWindowLimit; sourceControl["visible"]=.true; sourceControl["action"]="SOURCE.WINDOW"
  call must v~createInstance("source-window-control","WUIB_SOURCE_WINDOW_CONTROL@1",sourceControl,"root"); v~setActionAvailable("source-window-control","SOURCE.WINDOW",.true)

  sourceDetail=.table~new
  sourceDetail["path"]=""; sourceDetail["classes"]=""; sourceDetail["methods"]=""
  sourceDetail["attributes"]=""; sourceDetail["constants"]=""
  sourceDetail["requires"]=""; sourceDetail["packageOptions"]=""
  sourceDetail["queryRevision"]=0; sourceDetail["scopeRevision"]=0; sourceDetail["selectionRevision"]=0; sourceDetail["visible"]=.false
  call must v~createInstance("source-detail","WUIB_SOURCE_DETAIL@1",sourceDetail,"root")
  call must self~refreshSourceWindow(sourceWindowOffset,sourceWindowLimit,.false)

  defaultState=self~defaultTargetJourneyState
  canvas=.table~new; canvas["items"]=self~compositionCanvasItems("HUMAN_VISUAL",defaultState,"DEFAULT"); canvas["visible"]=.true; canvas["action"]="COMPOSITION.SELECT"; canvas["actions"]=.array~of("COMPOSITION.SELECT","DESIGN.COMPOSITION.MOVE","DESIGN.COMPOSITION.RESIZE","DESIGN.COMPOSITION.RELOCATE","DESIGN.COMPOSITION.ALIGN")
  call must v~createInstance("composition-canvas","WUIB_COMPOSITION_CANVAS@1",canvas,"root")
  do canvasAction over canvas["actions"]; v~setActionAvailable("composition-canvas",canvasAction,.true); end
  ignore=self~installEditor(v,"composition-editor","WUIB_COMPOSITION_EDITOR@1","DESIGN.COMPOSITION.DRAFT",.array~of("artifactId","publishVersion","journeyId","profile","stateId","layoutModel","presentationPolicyId","presentationPolicyVersion","elementId","projectionId","region","order","span","rowSpan","align","viewportClass","whenMode","whenConditionIds","suppressConditionIds","presentationClass"))
  ignore=self~installEditor(v,"preview-control","WUIB_PREVIEW_CONTROL@1","PREVIEW.CONFIGURE",.array~of("profile","journeyState","viewportClass","experimentId","variantId"))
  summary=.table~new; summary["mode"]="DRAFT"; summary["profile"]="HUMAN_VISUAL"; summary["journeyState"]=defaultState; summary["viewportClass"]="DEFAULT"; summary["variant"]=""; summary["compositionCount"]=canvas["items"]~items; summary["activeDefinitions"]=""; summary["visible"]=.true
  call must v~createInstance("preview-summary","WUIB_PREVIEW_SUMMARY@1",summary,"root")

  ignore=self~installEditor(v,"component-editor","WUIB_COMPONENT_EDITOR@1","DESIGN.COMPONENT.DRAFT",.array~of("artifactId","publishVersion","primitive"))
  ignore=self~installEditor(v,"element-editor","WUIB_ELEMENT_EDITOR@1","DESIGN.ELEMENT.DRAFT",.array~of("artifactId","publishVersion","semanticType","fields","actions","audiencePolicyRef"))
  ignore=self~installEditor(v,"projection-editor","WUIB_PROJECTION_EDITOR@1","DESIGN.PROJECTION.DRAFT",.array~of("artifactId","publishVersion","profile","elementId","componentId","definitionId","action","styleRole","materialRole","resourceRole","resourceId","resourceVersion","resourceContentAddress","resourceClass","resourceLocale"))
  ignore=self~installEditor(v,"material-editor","WUIB_MATERIAL_EDITOR@1","DESIGN.MATERIAL.DRAFT",.array~of("artifactId","publishVersion","tokenName","tokenValue"))
  ignore=self~installEditor(v,"journey-editor","WUIB_JOURNEY_EDITOR@1","DESIGN.JOURNEY.DRAFT",.array~of("artifactId","publishVersion","initialState","initialFlowId","flowId","flowInitialState","stateId","active","prefetch","onDemand","fromState","toState","trigger","purpose","transitionWhenMode","transitionWhenConditionIds","transitionSuppressConditionIds"))
  ignore=self~installEditor(v,"condition-editor","WUIB_CONDITION_EDITOR@1","DESIGN.CONDITION.DRAFT",.array~of("artifactId","publishVersion","sourceKind","sourceRef","operator","expectedValue","authorityRef"))
  ignore=self~installEditor(v,"presentation-policy-editor","WUIB_PRESENTATION_POLICY_EDITOR@1","DESIGN.PRESENTATION_POLICY.DRAFT",.array~of("artifactId","publishVersion","precedence","region","capacity"))
  ignore=self~installEditor(v,"experiment-editor","WUIB_EXPERIMENT_EDITOR@1","DESIGN.EXPERIMENT.DRAFT",.array~of("artifactId","publishVersion","targetElementId","variantAProjectionId","variantBProjectionId"))
  ignore=self~installEditor(v,"publish","WUIB_PUBLISH@1","DESIGN.PUBLISH",.array~of("releaseId","releaseVersion"))

  p=self~projection; p~bind("projectRevision","project","revision"); p~bind("projectDraftCount","project","draftCount")
  p~bind("artifactLibraryItems","artifact-library","items")
  p~bind("flowMapItems","flow-map","items")
  p~bind("selectionKind","selection-inspector","kind"); p~bind("selectionArtifactId","selection-inspector","artifactId")
  p~bind("selectionDraftRevision","selection-inspector","draftRevision"); p~bind("selectionPublishVersion","selection-inspector","publishVersion"); p~bind("selectionDetail","selection-inspector","detail")
  p~bind("sourceDetailPath","source-detail","path")
  p~bind("sourceDetailClasses","source-detail","classes")
  p~bind("sourceDetailMethods","source-detail","methods")
  p~bind("sourceDetailAttributes","source-detail","attributes")
  p~bind("sourceDetailConstants","source-detail","constants")
  p~bind("sourceDetailRequires","source-detail","requires")
  p~bind("sourceDetailPackageOptions","source-detail","packageOptions")
  p~bind("sourceDetailQueryRevision","source-detail","queryRevision")
  p~bind("sourceDetailScopeRevision","source-detail","scopeRevision")
  p~bind("sourceDetailSelectionRevision","source-detail","selectionRevision")
  p~bind("sourceDetailVisible","source-detail","visible")
  do name over .array~of("filter","sortRef","direction","offset","limit"); p~bind("sourceControl."name,"source-window-control",name); end
  p~bind("compositionCanvasItems","composition-canvas","items")
  do name over .array~of("artifactId","publishVersion","journeyId","profile","stateId","layoutModel","presentationPolicyId","presentationPolicyVersion","elementId","projectionId","region","order","span","rowSpan","align","viewportClass","whenMode","whenConditionIds","suppressConditionIds","presentationClass")
    p~bind("compositionEdit."name,"composition-editor",name)
  end
  ignore=self~bindEditorProjection(p,"componentEdit","component-editor",.array~of("artifactId","publishVersion","primitive"))
  ignore=self~bindEditorProjection(p,"elementEdit","element-editor",.array~of("artifactId","publishVersion","semanticType","fields","actions","audiencePolicyRef"))
  ignore=self~bindEditorProjection(p,"projectionEdit","projection-editor",.array~of("artifactId","publishVersion","profile","elementId","componentId","definitionId","action","styleRole","materialRole","resourceRole","resourceId","resourceVersion","resourceContentAddress","resourceClass","resourceLocale"))
  ignore=self~bindEditorProjection(p,"materialEdit","material-editor",.array~of("artifactId","publishVersion","tokenName","tokenValue"))
  ignore=self~bindEditorProjection(p,"journeyEdit","journey-editor",.array~of("artifactId","publishVersion","initialState","initialFlowId","flowId","flowInitialState","stateId","active","prefetch","onDemand","fromState","toState","trigger","purpose","transitionWhenMode","transitionWhenConditionIds","transitionSuppressConditionIds"))
  ignore=self~bindEditorProjection(p,"conditionEdit","condition-editor",.array~of("artifactId","publishVersion","sourceKind","sourceRef","operator","expectedValue","authorityRef"))
  ignore=self~bindEditorProjection(p,"policyEdit","presentation-policy-editor",.array~of("artifactId","publishVersion","precedence","region","capacity"))
  ignore=self~bindEditorProjection(p,"experimentEdit","experiment-editor",.array~of("artifactId","publishVersion","targetElementId","variantAProjectionId","variantBProjectionId"))
  p~bind("previewMode","preview-summary","mode"); p~bind("previewProfile","preview-summary","profile"); p~bind("previewJourneyState","preview-summary","journeyState")
  p~bind("previewViewportClass","preview-summary","viewportClass"); p~bind("previewVariant","preview-summary","variant"); p~bind("previewCompositionCount","preview-summary","compositionCount"); p~bind("previewActiveDefinitions","preview-summary","activeDefinitions")

  /* Server v0.16 state-group projection lets one semantic Builder action change
     several related facts without exposing transient half-updated UI revisions.
     Keep the ordinary one-key bindings above for simple mutations; grouped
     actions use this derived projector over the same semantic slots. */
  groupKeys=.array~new
  do key over .array~of("projectRevision","projectDraftCount","artifactLibraryItems","flowMapItems","selectionKind","selectionArtifactId","selectionDraftRevision","selectionPublishVersion","selectionDetail","sourceDetailPath","sourceDetailClasses","sourceDetailMethods","sourceDetailAttributes","sourceDetailConstants","sourceDetailRequires","sourceDetailPackageOptions","sourceDetailQueryRevision","sourceDetailScopeRevision","sourceDetailSelectionRevision","sourceDetailVisible","compositionCanvasItems","previewMode","previewProfile","previewJourneyState","previewViewportClass","previewVariant","previewCompositionCount","previewActiveDefinitions")
    groupKeys~append(key)
  end
  do prefix over .array~of("sourceControl","compositionEdit","componentEdit","elementEdit","projectionEdit","materialEdit","journeyEdit","conditionEdit","policyEdit","experimentEdit")
    select
      when prefix="sourceControl" then fields=.array~of("filter","sortRef","direction","offset","limit")
      when prefix="compositionEdit" then fields=.array~of("artifactId","publishVersion","journeyId","profile","stateId","layoutModel","presentationPolicyId","presentationPolicyVersion","elementId","projectionId","region","order","span","rowSpan","align","viewportClass","whenMode","whenConditionIds","suppressConditionIds","presentationClass")
      when prefix="componentEdit" then fields=.array~of("artifactId","publishVersion","primitive")
      when prefix="elementEdit" then fields=.array~of("artifactId","publishVersion","semanticType","fields","actions","audiencePolicyRef")
      when prefix="projectionEdit" then fields=.array~of("artifactId","publishVersion","profile","elementId","componentId","definitionId","action","styleRole","materialRole","resourceRole","resourceId","resourceVersion","resourceContentAddress","resourceClass","resourceLocale")
      when prefix="materialEdit" then fields=.array~of("artifactId","publishVersion","tokenName","tokenValue")
      when prefix="journeyEdit" then fields=.array~of("artifactId","publishVersion","initialState","initialFlowId","flowId","flowInitialState","stateId","active","prefetch","onDemand","fromState","toState","trigger","purpose","transitionWhenMode","transitionWhenConditionIds","transitionSuppressConditionIds")
      when prefix="conditionEdit" then fields=.array~of("artifactId","publishVersion","sourceKind","sourceRef","operator","expectedValue","authorityRef")
      when prefix="policyEdit" then fields=.array~of("artifactId","publishVersion","precedence","region","capacity")
      when prefix="experimentEdit" then fields=.array~of("artifactId","publishVersion","targetElementId","variantAProjectionId","variantBProjectionId")
      otherwise fields=.array~new
    end
    do fieldName over fields; groupKeys~append(prefix"."fieldName); end
  end
  call must p~bindDerived(groupKeys,.WireUIBuilderStateGroupProjector~new)
  return .WireUIResult~success(.true,"BUILDER_STUDIO_INITIAL_VIEW_INSTALLED")

::method installEditor private
  use arg v,instanceId,definitionKey,action,fieldNames
  slots=.table~new; do name over fieldNames; slots[name]=""; end
  slots["visible"]=.true; slots["action"]=action
  call must v~createInstance(instanceId,definitionKey,slots,"root")
  v~setActionAvailable(instanceId,action,.true)
  return .true

::method bindEditorProjection private
  use arg projection,prefix,instanceId,fieldNames
  do name over fieldNames; projection~bind(prefix"."name,instanceId,name); end
  return .true

::method dispatchSemanticAction
  expose targetProject sourceCatalogue lastPublished studioState sourceWorkspaceRef sourceWindowOffset sourceWindowLimit sourceFilter sourceSortRef sourceSortDirection
  use arg action,message
  detail=self~detailOf(message)
  if action="STUDIO.NAVIGATE" then do
    targetState=self~field(detail,"value",self~field(detail,"id",self~field(detail,"key","")))~string~strip~translate
    if targetState="" then return .WireUIResult~failure("BUILDER_STUDIO_STATE_REQUIRED")
    r=self~advanceJourney(targetState,"STUDIO.NAVIGATE",detail)
    if \r~ok then return r
    studioState=targetState
    call must self~mutateState("artifactLibraryItems",self~artifactLibraryItems(targetState))
    if targetState="SOURCE" then call must self~refreshSourceWindow(sourceWindowOffset,sourceWindowLimit,.true)
    return .WireUIResult~success(targetState,"BUILDER_STUDIO_NAVIGATED")
  end
  if action="SOURCE.WINDOW" then do
    if sourceCatalogue==.nil then return .WireUIResult~failure("BUILDER_SOURCE_CATALOGUE_UNAVAILABLE")
    requestedFilter=self~field(detail,"filter","")~string~strip
    requestedSort=self~field(detail,"sortRef","PATH")~string~strip~translate
    requestedDirection=self~field(detail,"direction","ASC")~string~strip~translate
    if requestedSort<>"PATH" then return .WireUIResult~failure("BUILDER_SOURCE_SORT_UNSUPPORTED",requestedSort)
    if requestedDirection<>"ASC" & requestedDirection<>"DESC" then return .WireUIResult~failure("BUILDER_SOURCE_SORT_DIRECTION_INVALID",requestedDirection)
    requestedLimit=self~numberOr(self~field(detail,"limit",sourceWindowLimit),sourceWindowLimit)
    if requestedLimit<5 then requestedLimit=5
    if requestedLimit>100 then requestedLimit=100
    requestedOffset=self~numberOr(self~field(detail,"offset",sourceWindowOffset),sourceWindowOffset)
    if requestedOffset<0 then requestedOffset=0
    scopeChanged=requestedFilter<>sourceFilter
    if scopeChanged then do
      if requestedFilter="" then wr=self~removeWorkspaceFilter(sourceWorkspaceRef,"PATH_CONTAINS")
      else wr=self~setWorkspaceFilter(sourceWorkspaceRef,"PATH_CONTAINS",requestedFilter)
      if \wr~ok then return wr
      requestedOffset=0
      sourceFilter=requestedFilter
    end
    if requestedSort<>sourceSortRef | requestedDirection<>sourceSortDirection then do
      wr=self~setWorkspaceSort(sourceWorkspaceRef,requestedSort,requestedDirection); if \wr~ok then return wr
      sourceSortRef=requestedSort; sourceSortDirection=requestedDirection
    end
    sourceWindowLimit=requestedLimit; sourceWindowOffset=requestedOffset
    updates=.table~new
    if scopeChanged then updates["sourceDetailVisible"]=.false
    updates["sourceControl.filter"]=sourceFilter
    updates["sourceControl.sortRef"]=sourceSortRef
    updates["sourceControl.direction"]=sourceSortDirection
    updates["sourceControl.offset"]=sourceWindowOffset
    updates["sourceControl.limit"]=sourceWindowLimit
    ur=self~mutateStateGroup(updates); if \ur~ok then return ur
    /* Publish the new row window last.  Once a newly-visible row can be acted on,
       the client has necessarily consumed every state patch produced by this
       SOURCE.WINDOW action and therefore holds the current view revision. */
    r=self~refreshSourceWindow(sourceWindowOffset,sourceWindowLimit,.true); if \r~ok then return r
    return .WireUIResult~success(self~workspaceContext(sourceWorkspaceRef),"BUILDER_SOURCE_WINDOW_UPDATED")
  end
  if action="SOURCE.OPEN" then do
    if sourceCatalogue==.nil then return .WireUIResult~failure("BUILDER_SOURCE_CATALOGUE_UNAVAILABLE")
    sourceKey=self~field(detail,"id",self~field(detail,"key",self~field(detail,"ref",self~field(detail,"value",""))))
    if sourceKey="" then do
      instanceId=self~field(message,"elementInstance","")
      row=self~view~instance(instanceId)
      if row<>.nil then sourceKey=self~field(row["slots"],"label","")
    end
    sourceFile=sourceCatalogue~file(sourceKey)
    if sourceFile==.nil then return .WireUIResult~failure("BUILDER_SOURCE_NOT_FOUND",sourceKey)
    q=self~workspaceQuery(sourceWorkspaceRef)
    sr=self~setWorkspaceSelection(sourceWorkspaceRef,q~scopeRevision,.array~of(sourceKey)); if \sr~ok then return sr
    sourceWire=sourceFile~asWire
    ctx=self~workspaceContext(sourceWorkspaceRef)
    updates=.table~new
    updates["sourceDetailPath"]=sourceWire["path"]
    updates["sourceDetailClasses"]=self~sourceSymbolText(sourceWire["classes"])
    updates["sourceDetailMethods"]=self~sourceSymbolText(sourceWire["methods"])
    updates["sourceDetailAttributes"]=self~sourceSymbolText(sourceWire["attributes"])
    updates["sourceDetailConstants"]=self~sourceSymbolText(sourceWire["constants"])
    updates["sourceDetailRequires"]=self~sourceValueText(sourceWire["requires"])
    updates["sourceDetailPackageOptions"]=self~sourceValueText(sourceWire["packageOptions"])
    updates["sourceDetailQueryRevision"]=ctx["queryRevision"]
    updates["sourceDetailScopeRevision"]=ctx["scopeRevision"]
    updates["sourceDetailSelectionRevision"]=ctx["selectionRevision"]
    updates["sourceDetailVisible"]=.true
    call must self~mutateStateGroup(updates)
    if studioState<>"SOURCE" then do
      nav=self~advanceJourney("SOURCE","SOURCE.OPEN",sourceWire["path"]); if \nav~ok then return nav
      studioState="SOURCE"
    end
    return .WireUIResult~success(sourceWire,"BUILDER_SOURCE_SELECTED")
  end
  if action="ARTIFACT.SELECT" then do
    itemId=self~field(detail,"id",self~field(detail,"key",""))
    item=self~artifactLibraryItem(itemId)
    if item==.nil then return .WireUIResult~failure("BUILDER_ARTIFACT_NOT_FOUND",itemId)
    ignore=self~mutateState("selectionKind",item["kind"]); ignore=self~mutateState("selectionArtifactId",item["artifactId"])
    ignore=self~mutateState("selectionDraftRevision",item["draftRevision"]); ignore=self~mutateState("selectionPublishVersion",item["publishVersion"])
    ignore=self~mutateState("selectionDetail",item["kind"]" draft · revision "item["draftRevision"])
    ignore=self~populateArtifactEditor(item)
    return .WireUIResult~success(item,"BUILDER_ARTIFACT_SELECTED")
  end
  if action="FLOW.SELECT" then do
    itemId=self~field(detail,"id",self~field(detail,"key",""))
    item=self~flowMapItem(itemId)
    if item==.nil then return .WireUIResult~failure("BUILDER_FLOW_STATE_NOT_FOUND",itemId)
    updates=.table~new
    updates["selectionKind"]="JOURNEY_STATE"; updates["selectionArtifactId"]=item["journeyId"]":"item["stateId"]
    updates["selectionDraftRevision"]=""; updates["selectionPublishVersion"]=""
    updates["selectionDetail"]="active "item["activeCount"]" · next "item["nextStates"]
    preview=self~previewStateUpdates("HUMAN_VISUAL",item["stateId"],"DEFAULT","","")
    do key over preview~allIndexes; updates[key]=preview[key]; end
    call must self~mutateStateGroup(updates)
    return .WireUIResult~success(item,"BUILDER_FLOW_STATE_SELECTED")
  end
  if action="COMPOSITION.SELECT" then do
    itemId=self~field(detail,"id",self~field(detail,"key",""))
    item=self~compositionCanvasItem(itemId)
    if item==.nil then return .WireUIResult~failure("BUILDER_COMPOSITION_ITEM_NOT_FOUND",itemId)
    updates=.table~new
    do name over .array~of("artifactId","publishVersion","journeyId","profile","stateId","layoutModel","presentationPolicyId","presentationPolicyVersion","elementId","projectionId","region","order","span","rowSpan","align","viewportClass","whenMode","whenConditionIds","suppressConditionIds","presentationClass")
      updates["compositionEdit."name]=self~field(item,name,"")
    end
    updates["selectionKind"]="COMPOSITION_PLACEMENT"; updates["selectionArtifactId"]=item["elementId"]
    updates["selectionDraftRevision"]=targetProject~revision; updates["selectionPublishVersion"]=item["publishVersion"]
    updates["selectionDetail"]="region "item["region"]" · span "item["span"]"/12 · order "item["order"]
    call must self~mutateStateGroup(updates)
    return .WireUIResult~success(item,"BUILDER_COMPOSITION_SELECTED")
  end
  if action="PREVIEW.CONFIGURE" then do
    r=self~refreshPreview(self~field(detail,"profile","HUMAN_VISUAL"),self~field(detail,"journeyState",""),self~field(detail,"viewportClass","DEFAULT"),self~field(detail,"experimentId",""),self~field(detail,"variantId",""))
    return r
  end
  if action="DESIGN.COMPOSITION.MOVE" then do
    source=self~compositionCanvasItem(self~field(detail,"sourceId","")); target=self~compositionCanvasItem(self~field(detail,"targetId",""))
    if source==.nil | target==.nil then return .WireUIResult~failure("BUILDER_COMPOSITION_MOVE_ITEM_NOT_FOUND")
    if source["artifactId"]<>target["artifactId"] then return .WireUIResult~failure("BUILDER_COMPOSITION_MOVE_CROSS_ARTIFACT")
    payload=.table~new; payload["artifactId"]=source["artifactId"]
    payload["sourcePlacementKey"]=self~placementKey(source); payload["targetPlacementKey"]=self~placementKey(target)
    op=.WireUIDesignOperation~new("browser-move-"targetProject~revision"-".WireUIDesignUtil~token(payload["sourcePlacementKey"]"|"payload["targetPlacementKey"]),"DESIGN.COMPOSITION.MOVE",targetProject~revision,.nil,payload,"WIRE_UI:BUILDER","direct visual composition move")
    r=targetProject~applyOperation(op); if \r~ok then return .WireUIResult~failure(r~code,r~detail)
    ignore=self~refreshDesignCollections
    return .WireUIResult~success(r~value~asWire,"BUILDER_COMPOSITION_MOVED")
  end
  if action="DESIGN.COMPOSITION.RESIZE" then do
    item=self~compositionCanvasItem(self~field(detail,"id","")); if item==.nil then return .WireUIResult~failure("BUILDER_COMPOSITION_RESIZE_ITEM_NOT_FOUND")
    span=self~field(detail,"span","")
    if span="" then span=(item["span"]+0)+self~numberOr(self~field(detail,"deltaSpan",""),0)
    if span<1 then span=1
    if span>12 then span=12
    payload=.table~new; payload["artifactId"]=item["artifactId"]; payload["placementKey"]=self~placementKey(item); payload["span"]=span; payload["rowSpan"]=self~numberOr(self~field(detail,"rowSpan",""),item["rowSpan"])
    op=.WireUIDesignOperation~new("browser-resize-"targetProject~revision"-".WireUIDesignUtil~token(payload["placementKey"]"|"span),"DESIGN.COMPOSITION.RESIZE",targetProject~revision,.nil,payload,"WIRE_UI:BUILDER","direct visual composition resize")
    r=targetProject~applyOperation(op); if \r~ok then return .WireUIResult~failure(r~code,r~detail)
    ignore=self~refreshDesignCollections
    return .WireUIResult~success(r~value~asWire,"BUILDER_COMPOSITION_RESIZED")
  end
  if action="DESIGN.COMPOSITION.RELOCATE" then do
    item=self~compositionCanvasItem(self~field(detail,"id","")); if item==.nil then return .WireUIResult~failure("BUILDER_COMPOSITION_RELOCATE_ITEM_NOT_FOUND")
    region=self~field(detail,"region","")~string~strip; if region="" then return .WireUIResult~failure("BUILDER_COMPOSITION_REGION_REQUIRED")
    payload=.table~new; payload["artifactId"]=item["artifactId"]; payload["placementKey"]=self~placementKey(item); payload["region"]=region
    op=.WireUIDesignOperation~new("browser-relocate-"targetProject~revision"-".WireUIDesignUtil~token(payload["placementKey"]"|"region),"DESIGN.COMPOSITION.RELOCATE",targetProject~revision,.nil,payload,"WIRE_UI:BUILDER","direct visual composition region relocation")
    r=targetProject~applyOperation(op); if \r~ok then return .WireUIResult~failure(r~code,r~detail)
    ignore=self~refreshDesignCollections
    return .WireUIResult~success(r~value~asWire,"BUILDER_COMPOSITION_RELOCATED")
  end
  if action="DESIGN.COMPOSITION.ALIGN" then do
    item=self~compositionCanvasItem(self~field(detail,"id","")); if item==.nil then return .WireUIResult~failure("BUILDER_COMPOSITION_ALIGN_ITEM_NOT_FOUND")
    align=self~field(detail,"align","")~string~strip~translate; if align="" then return .WireUIResult~failure("BUILDER_COMPOSITION_ALIGN_REQUIRED")
    payload=.table~new; payload["artifactId"]=item["artifactId"]; payload["placementKey"]=self~placementKey(item); payload["align"]=align
    op=.WireUIDesignOperation~new("browser-align-"targetProject~revision"-".WireUIDesignUtil~token(payload["placementKey"]"|"align),"DESIGN.COMPOSITION.ALIGN",targetProject~revision,.nil,payload,"WIRE_UI:BUILDER","direct visual composition alignment")
    r=targetProject~applyOperation(op); if \r~ok then return .WireUIResult~failure(r~code,r~detail)
    ignore=self~refreshDesignCollections
    return .WireUIResult~success(r~value~asWire,"BUILDER_COMPOSITION_ALIGNED")
  end
  if action="DESIGN.PUBLISH" then do
    releaseId=self~field(detail,"releaseId",""); releaseVersion=self~field(detail,"releaseVersion","")
    r=targetProject~publish(releaseId,releaseVersion); if \r~ok then return .WireUIResult~failure(r~code,r~detail)
    lastPublished=r~value
    ignore=self~refreshPreview("HUMAN_VISUAL","","DEFAULT","","")
    return .WireUIResult~success(r~value["release"]~ref~asWire,"BUILDER_TARGET_PUBLISHED")
  end
  if action~left(7)<>"DESIGN." | action~right(6)<>".DRAFT" then return .WireUIResult~failure("BUILDER_ACTION_UNSUPPORTED",action)
  payload=self~draftPayload(action,detail); if payload==.nil then return .WireUIResult~failure("BUILDER_DRAFT_INPUT_INVALID",action)
  op=.WireUIDesignOperation~new("browser-"targetProject~revision"-".WireUIDesignUtil~token(action"|".WireUIDesignUtil~canonicalTable(payload)),action,targetProject~revision,.nil,payload,"WIRE_UI:BUILDER","Builder Studio semantic action")
  r=targetProject~applyOperation(op); if \r~ok then return .WireUIResult~failure(r~code,r~detail)
  updates=.table~new
  updates["projectRevision"]=targetProject~revision
  updates["projectDraftCount"]=targetProject~drafts~items
  updates["artifactLibraryItems"]=self~artifactLibraryItems(studioState)
  updates["flowMapItems"]=self~flowMapItems
  if action="DESIGN.COMPOSITION.DRAFT" then do
    preview=self~previewStateUpdates("HUMAN_VISUAL","","DEFAULT","","")
    do key over preview~allIndexes; updates[key]=preview[key]; end
  end
  call must self~mutateStateGroup(updates)
  return .WireUIResult~success(r~value~asWire,"BUILDER_DRAFT_UPDATED")

::method sourceSymbolText private
  use arg items
  text=""
  if items==.nil then return text
  do item over items
    name=""
    if item~isA(.Table) | item~isA(.Directory) then do
      if item~hasIndex("name") then name=item["name"]
      if item~hasIndex("line") & item["line"]<>"" then name ||= " @"item["line"]
    end
    else name=item~string
    if name="" then iterate
    if text<>"" then text ||= .endOfLine
    text ||= name
  end
  return text

::method sourceValueText private
  use arg items
  text=""
  if items==.nil then return text
  do item over items
    if text<>"" then text ||= .endOfLine
    text ||= item~string
  end
  return text

::method draftPayload private
  expose targetProject
  use arg action,detail
  id=self~field(detail,"artifactId","")~string~strip; pv=self~field(detail,"publishVersion","")~string~strip
  if id="" | pv="" then return .nil
  spec=.table~new; spec["publishVersion"]=pv
  select
    when action="DESIGN.COMPONENT.DRAFT" then spec["primitive"]=self~field(detail,"primitive","")
    when action="DESIGN.ELEMENT.DRAFT" then do
      spec["semanticType"]=self~field(detail,"semanticType",""); spec["fields"]=self~csv(self~field(detail,"fields","")); spec["actions"]=self~csv(self~field(detail,"actions","")); spec["audiencePolicyRef"]=self~field(detail,"audiencePolicyRef","PUBLIC")
    end
    when action="DESIGN.PROJECTION.DRAFT" then do
      do k over .array~of("profile","elementId","componentId","definitionId","action","styleRole","materialRole"); spec[k]=self~field(detail,k,""); end
      bindings=.table~new; elementDraft=targetProject~draft("ELEMENT",spec["elementId"])
      if elementDraft<>.nil then do
        elementFields=self~field(elementDraft~spec,"fields",.array~new)
        do fieldName over elementFields; bindings[fieldName]=fieldName; end
      end
      spec["bindings"]=bindings
      resources=.array~new
      priorProjection=targetProject~draft("PROJECTION",id)
      if priorProjection<>.nil then resources=.WireUIDesignUtil~copyArray(self~field(priorProjection~spec,"resourceBindings",.array~new))
      rid=self~field(detail,"resourceId","")~string~strip
      if rid<>"" then do
        rr=.table~new; rr["resourceId"]=rid; rr["version"]=self~field(detail,"resourceVersion",""); rr["contentAddress"]=self~field(detail,"resourceContentAddress",""); rr["resourceClass"]=self~field(detail,"resourceClass","STRUCTURED"); rr["locale"]=self~field(detail,"resourceLocale","")
        rb=.table~new; rb["role"]=self~field(detail,"resourceRole","PRIMARY_CONTENT"); rb["resourceRef"]=rr; rb["required"]=.true
        next=.array~new; replaced=.false
        do oldrb over resources
          if self~field(oldrb,"role","")=rb["role"] then do; next~append(rb); replaced=.true; end; else next~append(oldrb)
        end
        if \replaced then next~append(rb); resources=next
      end
      spec["resourceBindings"]=resources
    end
    when action="DESIGN.MATERIAL.DRAFT" then do
      tokens=.table~new; recipes=.table~new
      prior=targetProject~draft("MATERIAL",id)
      if prior<>.nil then do; old=prior~spec; tokens=.WireUIDesignUtil~copyTable(old["tokens"]); recipes=.WireUIDesignUtil~copyTable(old["recipes"]); end
      name=self~field(detail,"tokenName",""); if name="" then return .nil
      tokens[name]=self~field(detail,"tokenValue",""); spec["tokens"]=tokens; spec["recipes"]=recipes
    end
    when action="DESIGN.JOURNEY.DRAFT" then do
      spec["initialState"]=self~field(detail,"initialState",""); spec["initialFlowId"]=self~field(detail,"initialFlowId","")
      states=.array~new; flows=.array~new; prior=targetProject~draft("JOURNEY",id)
      if prior<>.nil then do; old=prior~spec; states=.WireUIDesignUtil~copyArray(old["states"]); flows=.WireUIDesignUtil~copyArray(self~field(old,"flows",.array~new)); spec["transitions"]=self~field(old,"transitions",.array~new); end
      fid=self~field(detail,"flowId","")~string~strip; fis=self~field(detail,"flowInitialState","")~string~strip
      if fid<>"" then do
        fr=.table~new; fr["flowId"]=fid; fr["initialState"]=fis
        fn=.array~new; ff=.false; do row over flows; if self~field(row,"flowId","")=fid then do; fn~append(fr); ff=.true; end; else fn~append(row); end; if \ff then fn~append(fr); flows=fn
      end
      spec["flows"]=flows
      sid=self~field(detail,"stateId",""); if sid="" then return .nil
      replacement=.table~new; replacement["stateId"]=sid; replacement["flowId"]=fid; replacement["ACTIVE"]=self~csv(self~field(detail,"active","")); replacement["PREFETCH"]=self~csv(self~field(detail,"prefetch","")); replacement["ON_DEMAND"]=self~csv(self~field(detail,"onDemand",""))
      next=.array~new; found=.false; do row over states; if row["stateId"]=sid then do; next~append(replacement); found=.true; end; else next~append(row); end; if \found then next~append(replacement); spec["states"]=next
      fromState=self~field(detail,"fromState","")~string~strip; toState=self~field(detail,"toState","")~string~strip
      if fromState<>"" | toState<>"" then do
        if fromState="" | toState="" then return .nil
        transitions=.WireUIDesignUtil~copyArray(self~field(spec,"transitions",.array~new))
        tr=.table~new; tr["fromState"]=fromState; tr["toState"]=toState; tr["trigger"]=self~field(detail,"trigger","")~string~strip; tr["purpose"]=self~field(detail,"purpose","")~string~strip
        tr["whenMode"]=self~field(detail,"transitionWhenMode","ALL")~string~strip~translate; tr["whenConditionIds"]=self~csv(self~field(detail,"transitionWhenConditionIds","")); tr["suppressConditionIds"]=self~csv(self~field(detail,"transitionSuppressConditionIds",""))
        tn=.array~new; tf=.false
        do oldtr over transitions
          same=self~field(oldtr,"fromState","")=fromState & self~field(oldtr,"toState","")=toState & self~field(oldtr,"trigger","")=tr["trigger"]
          if same then do; tn~append(tr); tf=.true; end; else tn~append(oldtr)
        end
        if \tf then tn~append(tr)
        spec["transitions"]=tn
      end
    end
    when action="DESIGN.CONDITION.DRAFT" then do
      do k over .array~of("sourceKind","sourceRef","operator","authorityRef"); spec[k]=self~field(detail,k,""); end
      if self~field(detail,"expectedValue","")<>"" then spec["expectedValue"]=self~field(detail,"expectedValue","")
    end
    when action="DESIGN.PRESENTATION_POLICY.DRAFT" then do
      prior=targetProject~draft("PRESENTATION_POLICY",id); precedence=.array~new; capacities=.table~new
      if prior<>.nil then do; precedence=.WireUIDesignUtil~copyArray(self~field(prior~spec,"precedence",.array~new)); capacities=.WireUIDesignUtil~copyTable(self~field(prior~spec,"capacities",.table~new)); end
      if self~field(detail,"precedence","")<>"" then precedence=self~csv(self~field(detail,"precedence",""))
      region=self~field(detail,"region","")~string~strip; if region<>"" then capacities[region]=self~numberOr(self~field(detail,"capacity",""),1)
      spec["precedence"]=precedence; spec["capacities"]=capacities
    end
    when action="DESIGN.COMPOSITION.DRAFT" then do
      do k over .array~of("journeyId","profile","stateId","layoutModel","presentationPolicyId","presentationPolicyVersion"); spec[k]=self~field(detail,k,""); end
      placements=.array~new; prior=targetProject~draft("COMPOSITION",id)
      if prior<>.nil then placements=.WireUIDesignUtil~copyArray(prior~spec["placements"])
      replacement=.table~new
      replacement["elementId"]=self~field(detail,"elementId",""); if replacement["elementId"]="" then return .nil
      replacement["projectionId"]=self~field(detail,"projectionId","")
      replacement["region"]=self~field(detail,"region","main"); replacement["order"]=self~numberOr(self~field(detail,"order",""),0)
      replacement["span"]=self~numberOr(self~field(detail,"span",""),12); replacement["rowSpan"]=self~numberOr(self~field(detail,"rowSpan",""),1)
      replacement["align"]=self~field(detail,"align","STRETCH"); replacement["viewportClass"]=self~field(detail,"viewportClass","DEFAULT"); replacement["whenMode"]=self~field(detail,"whenMode","ALL"); replacement["whenConditionIds"]=self~csv(self~field(detail,"whenConditionIds","")); replacement["suppressConditionIds"]=self~csv(self~field(detail,"suppressConditionIds","")); replacement["presentationClass"]=self~field(detail,"presentationClass","STANDARD")
      next=.array~new; found=.false
      do row over placements
        same=row["elementId"]=replacement["elementId"] & self~field(row,"projectionId","")=replacement["projectionId"] & self~field(row,"viewportClass","DEFAULT")=replacement["viewportClass"]
        if same then do; next~append(replacement); found=.true; end; else next~append(row)
      end
      if \found then next~append(replacement)
      spec["placements"]=next
    end
    when action="DESIGN.EXPERIMENT.DRAFT" then do
      spec["targetElementId"]=self~field(detail,"targetElementId",""); vars=.array~new
      a=.table~new; a["variantId"]="A"; a["weight"]=50; a["projectionId"]=self~field(detail,"variantAProjectionId",""); vars~append(a)
      b=.table~new; b["variantId"]="B"; b["weight"]=50; b["projectionId"]=self~field(detail,"variantBProjectionId",""); vars~append(b)
      spec["variants"]=vars
    end
    otherwise return .nil
  end
  payload=.table~new; payload["artifactId"]=id; payload["spec"]=spec; return payload

::method refreshSourceWindow private
  expose sourceCatalogue sourceWorkspaceRef sourceWindowRevision sourceWindowOffset sourceWindowLimit sourceFilter sourceSortRef sourceSortDirection
  use arg requestedOffset=0, requestedLimit=25, emitPatch=.true
  paths=self~sourceWindowPaths
  total=paths~items
  requestedLimit=max(5,min(100,requestedLimit+0))
  requestedOffset=max(0,requestedOffset+0)
  if total=0 then requestedOffset=0
  else if requestedOffset>=total then requestedOffset=max(0,total-requestedLimit)
  sourceWindowOffset=requestedOffset; sourceWindowLimit=requestedLimit
  rows=.array~new
  last=min(total,requestedOffset+requestedLimit)
  if last>0 then do i=requestedOffset+1 to last
    path=paths[i]
    slots=.table~new; slots["label"]=path; slots["visible"]=.true; slots["action"]="SOURCE.OPEN"
    row=.table~new; row["instanceId"]="source-row-".WireUIDesignUtil~token(path); row["definitionKey"]="WUIB_SOURCE_ROW@1"; row["slots"]=slots
    rows~append(row)
  end
  sourceWindowRevision+=1
  anchor=""; if rows~items>0 then anchor=rows[1]["slots"]["label"]
  window=.WireUICollectionWindow~new("source-files",requestedOffset,requestedLimit,total,sourceSortRef":"sourceSortDirection,sourceFilter,sourceWindowRevision,anchor)
  if emitPatch then r=self~reconcileCollectionWindow("source-files",rows,window)
  else r=self~view~reconcileCollectionWindow("source-files",rows,window)
  if \r~ok then return r
  do row over rows; self~view~setActionAvailable(row["instanceId"],"SOURCE.OPEN",.true); end
  return .WireUIResult~success(window~asWire,"BUILDER_SOURCE_WINDOW_RECONCILED")

::method sourceWindowPaths private
  expose sourceCatalogue sourceFilter sourceSortDirection
  out=.array~new
  if sourceCatalogue==.nil then return out
  wanted=sourceFilter~string~translate
  do sourceFile over sourceCatalogue~files
    path=sourceFile~path
    if wanted<>"" & pos(wanted,path~translate)=0 then iterate
    out~append(path)
  end
  out~sort
  if sourceSortDirection="DESC" then do
    reversed=.array~new
    do i=out~items to 1 by -1; reversed~append(out[i]); end
    out=reversed
  end
  return out

::method populateArtifactEditor private
  expose targetProject
  use arg item
  kind=self~field(item,"kind",""); artifactId=self~field(item,"artifactId","")
  draft=targetProject~draft(kind,artifactId); if draft==.nil then return .false
  spec=draft~spec; pv=self~field(spec,"publishVersion","")
  select
    when kind="COMPONENT" then do
      ignore=self~setEditorValues("componentEdit",.array~of("artifactId",artifactId,"publishVersion",pv,"primitive",self~field(spec,"primitive","")))
    end
    when kind="ELEMENT" then do
      ignore=self~setEditorValues("elementEdit",.array~of("artifactId",artifactId,"publishVersion",pv,"semanticType",self~field(spec,"semanticType",""),"fields",self~join(self~field(spec,"fields",.array~new),","),"actions",self~join(self~field(spec,"actions",.array~new),","),"audiencePolicyRef",self~field(spec,"audiencePolicyRef","PUBLIC")))
    end
    when kind="PROJECTION" then do
      values=.array~of("artifactId",artifactId,"publishVersion",pv,"profile",self~field(spec,"profile",""),"elementId",self~field(spec,"elementId",""),"componentId",self~field(spec,"componentId",""),"definitionId",self~field(spec,"definitionId",""),"action",self~field(spec,"action",""),"styleRole",self~field(spec,"styleRole",""),"materialRole",self~field(spec,"materialRole",""))
      resources=self~field(spec,"resourceBindings",.array~new)
      if resources~items>0 then do
        rb=resources[1]; rr=self~field(rb,"resourceRef",.nil)
        if rr<>.nil then do
          values~append("resourceRole"); values~append(self~field(rb,"role","PRIMARY_CONTENT"))
          values~append("resourceId"); values~append(self~field(rr,"resourceId",""))
          values~append("resourceVersion"); values~append(self~field(rr,"version",""))
          values~append("resourceContentAddress"); values~append(self~field(rr,"contentAddress",""))
          values~append("resourceClass"); values~append(self~field(rr,"resourceClass",""))
          values~append("resourceLocale"); values~append(self~field(rr,"locale",""))
        end
      end
      ignore=self~setEditorValues("projectionEdit",values)
    end
    when kind="MATERIAL" then do
      tokens=self~field(spec,"tokens",.table~new); tokenName=""; tokenValue=""
      keys=tokens~allIndexes; keys~sort
      if keys~items>0 then do; tokenName=keys[1]; tokenValue=tokens[tokenName]; end
      ignore=self~setEditorValues("materialEdit",.array~of("artifactId",artifactId,"publishVersion",pv,"tokenName",tokenName,"tokenValue",tokenValue))
    end
    when kind="JOURNEY" then do
      fid=""; fis=""; sid=""; active=""; prefetch=""; onDemand=""; fromState=""; toState=""; trigger=""; purpose=""; transitionWhenMode="ALL"; transitionWhenConditionIds=""; transitionSuppressConditionIds=""
      flows=self~field(spec,"flows",.array~new); if flows~items>0 then do; fid=self~field(flows[1],"flowId",""); fis=self~field(flows[1],"initialState",""); end
      states=self~field(spec,"states",.array~new); if states~items>0 then do; st=states[1]; sid=self~field(st,"stateId",""); if fid="" then fid=self~field(st,"flowId",""); active=self~join(self~field(st,"ACTIVE",.array~new),","); prefetch=self~join(self~field(st,"PREFETCH",.array~new),","); onDemand=self~join(self~field(st,"ON_DEMAND",.array~new),","); end
      transitions=self~field(spec,"transitions",.array~new); if transitions~items>0 then do; tr=transitions[1]; fromState=self~field(tr,"fromState",""); toState=self~field(tr,"toState",""); trigger=self~field(tr,"trigger",""); purpose=self~field(tr,"purpose",""); transitionWhenMode=self~field(tr,"whenMode","ALL"); transitionWhenConditionIds=self~join(self~field(tr,"whenConditionIds",.array~new),","); transitionSuppressConditionIds=self~join(self~field(tr,"suppressConditionIds",.array~new),","); end
      ignore=self~setEditorValues("journeyEdit",.array~of("artifactId",artifactId,"publishVersion",pv,"initialState",self~field(spec,"initialState",""),"initialFlowId",self~field(spec,"initialFlowId",""),"flowId",fid,"flowInitialState",fis,"stateId",sid,"active",active,"prefetch",prefetch,"onDemand",onDemand,"fromState",fromState,"toState",toState,"trigger",trigger,"purpose",purpose,"transitionWhenMode",transitionWhenMode,"transitionWhenConditionIds",transitionWhenConditionIds,"transitionSuppressConditionIds",transitionSuppressConditionIds))
    end
    when kind="CONDITION" then do
      ignore=self~setEditorValues("conditionEdit",.array~of("artifactId",artifactId,"publishVersion",pv,"sourceKind",self~field(spec,"sourceKind",""),"sourceRef",self~field(spec,"sourceRef",""),"operator",self~field(spec,"operator",""),"expectedValue",self~field(spec,"expectedValue",""),"authorityRef",self~field(spec,"authorityRef","")))
    end
    when kind="PRESENTATION_POLICY" then do
      capacities=self~field(spec,"capacities",.table~new); region=""; capacity=""; keys=capacities~allIndexes; keys~sort; if keys~items>0 then do; region=keys[1]; capacity=capacities[region]; end
      ignore=self~setEditorValues("policyEdit",.array~of("artifactId",artifactId,"publishVersion",pv,"precedence",self~join(self~field(spec,"precedence",.array~new),","),"region",region,"capacity",capacity))
    end
    when kind="EXPERIMENT" then do
      a=""; b=""; do variant over self~field(spec,"variants",.array~new); if self~field(variant,"variantId","")="A" then a=self~field(variant,"projectionId",""); if self~field(variant,"variantId","")="B" then b=self~field(variant,"projectionId",""); end
      ignore=self~setEditorValues("experimentEdit",.array~of("artifactId",artifactId,"publishVersion",pv,"targetElementId",self~field(spec,"targetElementId",""),"variantAProjectionId",a,"variantBProjectionId",b))
    end
    otherwise nop
  end
  return .true

::method setEditorValues private
  use arg prefix,pairs
  updates=.table~new
  do i=1 to pairs~items by 2; updates[prefix"."pairs[i]]=pairs[i+1]; end
  r=self~mutateStateGroup(updates)
  return r~ok

::method artifactKindsForState private
  use arg stateId="DESIGN"
  stateId=stateId~string~translate
  select
    when stateId="COMPONENTS" then return .set~of("COMPONENT","ELEMENT","PROJECTION")
    when stateId="MATERIALS" then return .set~of("MATERIAL")
    when stateId="FLOW" then return .set~of("JOURNEY","CONDITION","PRESENTATION_POLICY","EXPERIMENT")
    otherwise return .nil
  end

::method refreshDesignCollections private
  expose targetProject studioState
  stateId=self~currentPreviewState
  updates=.table~new
  updates["projectRevision"]=targetProject~revision
  updates["projectDraftCount"]=targetProject~drafts~items
  updates["artifactLibraryItems"]=self~artifactLibraryItems(studioState)
  updates["flowMapItems"]=self~flowMapItems
  preview=self~previewStateUpdates("HUMAN_VISUAL",stateId,"DEFAULT","","")
  do key over preview~allIndexes; updates[key]=preview[key]; end
  r=self~mutateStateGroup(updates)
  return r~ok

::method artifactLibraryItems private
  expose targetProject studioState
  use arg stateId=""
  if stateId="" then stateId=studioState
  kinds=self~artifactKindsForState(stateId)
  out=.array~new
  do draft over targetProject~drafts
    if kinds<>.nil then if \kinds~hasIndex(draft~kind) then iterate
    item=.table~new; item["id"]=draft~key; item["kind"]=draft~kind; item["artifactId"]=draft~artifactId
    item["draftRevision"]=draft~draftRevision; item["publishVersion"]=self~field(draft~spec,"publishVersion","")
    out~append(item)
  end
  return out

::method artifactLibraryItem private
  use arg itemId
  do item over self~artifactLibraryItems("DESIGN")
    if item["id"]=itemId then return item
  end
  return .nil

::method flowMapItems private
  expose targetProject
  out=.array~new
  do draft over targetProject~drafts
    if draft~kind<>"JOURNEY" then iterate
    spec=draft~spec; transitions=self~field(spec,"transitions",.array~new)
    do state over self~field(spec,"states",.array~new)
      sid=self~field(state,"stateId",""); next=.array~new; branchLabels=.array~new; conditionalBranchCount=0; branchCount=0
      do tr over transitions
        if self~field(tr,"fromState","")<>sid then iterate
        branchCount+=1; target=self~field(tr,"toState",""); next~append(target)
        whenIds=self~field(tr,"whenConditionIds",.array~new); suppressIds=self~field(tr,"suppressConditionIds",.array~new)
        conditional=(whenIds~items>0 | suppressIds~items>0)
        label=self~field(tr,"trigger",""); if label="" then label="transition"
        if conditional then do
          conditionalBranchCount+=1; condText=self~join(whenIds,"+"); if condText="" then condText="conditional"
          if suppressIds~items>0 then condText ||= " / suppress:"self~join(suppressIds,"+")
          label ||= " ? "condText
        end
        label ||= " → "target; branchLabels~append(label)
      end
      conditionalPlacementCount=0; conditionalPlacementConditions=.array~new
      do placement over self~compositionCanvasItems("",sid,"DEFAULT")
        wc=self~field(placement,"whenConditionIds",""); sc=self~field(placement,"suppressConditionIds","")
        if wc<>"" | sc<>"" then do
          conditionalPlacementCount+=1; label=self~field(placement,"elementId","")
          if wc<>"" then label ||= " ? "wc
          if sc<>"" then label ||= " / suppress:"sc
          conditionalPlacementConditions~append(label)
        end
      end
      item=.table~new; item["id"]=draft~artifactId"|"sid; item["journeyId"]=draft~artifactId; item["stateId"]=sid; item["flowId"]=self~field(state,"flowId","")
      active=self~field(state,"ACTIVE",.array~new); prefetch=self~field(state,"PREFETCH",.array~new); onDemand=self~field(state,"ON_DEMAND",.array~new)
      item["activeCount"]=active~items; item["prefetchCount"]=prefetch~items; item["onDemandCount"]=onDemand~items
      item["activeElements"]=self~join(active,","); item["prefetchElements"]=self~join(prefetch,","); item["layoutSignature"]=self~flowLayoutSignature(sid)
      item["branchCount"]=branchCount; item["conditionalBranchCount"]=conditionalBranchCount; item["branches"]=self~join(branchLabels," | ")
      item["conditionalPlacementCount"]=conditionalPlacementCount; item["conditionalPlacements"]=self~join(conditionalPlacementConditions," | ")
      item["nextStates"]=self~join(next," → "); if item["nextStates"]="" then item["nextStates"]="END"
      out~append(item)
    end
  end
  return out

::method flowLayoutSignature private
  use arg stateId
  text=""
  do item over self~compositionCanvasItems("",stateId,"DEFAULT")
    part=self~field(item,"region","main")"~"self~field(item,"span",12)"~"self~field(item,"elementId","")"~"self~field(item,"align","STRETCH")
    if text<>"" then text ||= "|"
    text ||= part
  end
  return text

::method flowMapItem private
  use arg itemId
  do item over self~flowMapItems
    if item["id"]=itemId then return item
  end
  return .nil

::method placementKey private
  use arg item
  return self~field(item,"elementId","")"|"self~field(item,"projectionId","")"|"self~field(item,"viewportClass","DEFAULT")

::method compositionCanvasItems private
  expose targetProject
  use arg profile="",stateId="",viewportClass="DEFAULT"
  out=.array~new
  do draft over targetProject~drafts
    if draft~kind<>"COMPOSITION" then iterate
    spec=draft~spec
    if profile<>"" & self~field(spec,"profile","")<>profile then iterate
    if stateId<>"" & self~field(spec,"stateId","")<>stateId then iterate
    do placement over self~field(spec,"placements",.array~new)
      vp=self~field(placement,"viewportClass","DEFAULT")
      if viewportClass<>"" & vp<>"DEFAULT" & vp<>viewportClass then iterate
      item=.table~new
      item["id"]=draft~artifactId"|"self~field(spec,"stateId","")"|"vp"|"placement["elementId"]"|"self~field(placement,"projectionId","")
      item["artifactId"]=draft~artifactId; item["publishVersion"]=self~field(spec,"publishVersion",""); item["journeyId"]=self~field(spec,"journeyId","")
      item["profile"]=self~field(spec,"profile",""); item["stateId"]=self~field(spec,"stateId",""); item["layoutModel"]=self~field(spec,"layoutModel","GRID12")
      do k over .array~of("elementId","projectionId","region","order","span","rowSpan","align","viewportClass","whenMode","presentationClass"); item[k]=self~field(placement,k,""); end; item["whenConditionIds"]=self~join(self~field(placement,"whenConditionIds",.array~new),","); item["suppressConditionIds"]=self~join(self~field(placement,"suppressConditionIds",.array~new),",")
      elementDraft=targetProject~draft("ELEMENT",item["elementId"]); item["semanticType"]=""
      if elementDraft<>.nil then item["semanticType"]=self~field(elementDraft~spec,"semanticType","")
      out~append(item)
    end
  end
  return out

::method compositionCanvasItem private
  use arg itemId
  do item over self~compositionCanvasItems("","","")
    if item["id"]=itemId then return item
  end
  return .nil

::method previewStateUpdates private
  expose targetProject lastPublished
  use arg profile="HUMAN_VISUAL",stateId="",viewportClass="DEFAULT",experimentId="",variantId=""
  if profile="" then profile="HUMAN_VISUAL"
  if viewportClass="" then viewportClass="DEFAULT"
  if stateId="" then stateId=self~defaultTargetJourneyState
  mode="DRAFT"; activeText=""; variantText=variantId; count=0
  if lastPublished<>.nil then do
    pkg=lastPublished["package"]; release=lastPublished["release"]
    if stateId="" then do
      do plan over pkg~journeyPlans
        if plan["profile"]=profile then do; stateId=plan["initialState"]; leave; end
      end
    end
    if stateId<>"" then do
      scenario=.WireUIPreviewScenario~new("BUILDER_PREVIEW","1","builder-preview",.true,profile,stateId,release~ref)
      if experimentId<>"" & variantId<>"" then scenario~assignExperiment(experimentId,variantId)
      scenario~seal
      pr=.WireUICompiler~new~previewManifest(targetProject~workspace,pkg,scenario)
      if pr~ok then do
        mode="PUBLISHED"; manifest=pr~value; count=manifest["compositions"]~items
        defs=.array~new; do d over manifest["ACTIVEDefinitions"]; defs~append(d["definitionKey"]); end
        activeText=self~join(defs,", ")
        resolved=manifest["resolvedExperiments"]; if experimentId<>"" & resolved~hasIndex(experimentId) then variantText=resolved[experimentId]
      end
    end
  end
  if mode="DRAFT" then count=self~compositionCanvasItems(profile,stateId,viewportClass)~items
  updates=.table~new
  updates["previewMode"]=mode; updates["previewProfile"]=profile; updates["previewJourneyState"]=stateId
  updates["previewViewportClass"]=viewportClass; updates["previewVariant"]=variantText; updates["previewCompositionCount"]=count; updates["previewActiveDefinitions"]=activeText
  updates["compositionCanvasItems"]=self~compositionCanvasItems(profile,stateId,viewportClass)
  return updates

::method refreshPreview private
  use arg profile="HUMAN_VISUAL",stateId="",viewportClass="DEFAULT",experimentId="",variantId=""
  r=self~mutateStateGroup(self~previewStateUpdates(profile,stateId,viewportClass,experimentId,variantId))
  if \r~ok then return r
  return .WireUIResult~success(.true,"BUILDER_PREVIEW_CONFIGURED")

::method defaultTargetJourneyState private
  expose targetProject
  do draft over targetProject~drafts
    if draft~kind="JOURNEY" then return self~field(draft~spec,"initialState","")
  end
  return ""

::method currentPreviewState private
  state=self~defaultTargetJourneyState
  instance=self~view~instance("preview-summary")
  if instance<>.nil then do
    slots=self~field(instance,"slots",.nil)
    if slots<>.nil then do
      current=self~field(slots,"journeyState","")~string~strip
      if current<>"" then state=current
    end
  end
  return state

::method numberOr private
  use arg value,default
  if value==.nil | value~string~strip="" then return default
  return value+0

::method join private
  use arg values,separator=", "
  text=""; do v over values; if text<>"" then text ||= separator; text ||= v~string; end; return text

::method csv private
  use arg text
  out=.array~new; text=text~string
  do while text<>""
    parse var text item "," text
    item=item~strip; if item<>"" then out~append(item)
  end
  return out
::method detailOf private
  use arg message
  if message<>.nil & message~hasIndex("detail") & message["detail"]<>.nil then return message["detail"]
  return .directory~new
::method field private
  use arg t,k,default=.nil
  if t<>.nil & t~hasIndex(k) then return t[k]
  return default

::class WireUIBuilderStateGroupProjector public
::method call
  use arg state,changedKeys
  output=.table~new
  do key over changedKeys
    target=""; slot=""
    select
      when key="projectRevision" then do; target="project"; slot="revision"; end
      when key="projectDraftCount" then do; target="project"; slot="draftCount"; end
      when key="artifactLibraryItems" then do; target="artifact-library"; slot="items"; end
      when key="flowMapItems" then do; target="flow-map"; slot="items"; end
      when key="selectionKind" then do; target="selection-inspector"; slot="kind"; end
      when key="selectionArtifactId" then do; target="selection-inspector"; slot="artifactId"; end
      when key="selectionDraftRevision" then do; target="selection-inspector"; slot="draftRevision"; end
      when key="selectionPublishVersion" then do; target="selection-inspector"; slot="publishVersion"; end
      when key="selectionDetail" then do; target="selection-inspector"; slot="detail"; end
      when key="sourceDetailPath" then do; target="source-detail"; slot="path"; end
      when key="sourceDetailClasses" then do; target="source-detail"; slot="classes"; end
      when key="sourceDetailMethods" then do; target="source-detail"; slot="methods"; end
      when key="sourceDetailAttributes" then do; target="source-detail"; slot="attributes"; end
      when key="sourceDetailConstants" then do; target="source-detail"; slot="constants"; end
      when key="sourceDetailRequires" then do; target="source-detail"; slot="requires"; end
      when key="sourceDetailPackageOptions" then do; target="source-detail"; slot="packageOptions"; end
      when key="sourceDetailQueryRevision" then do; target="source-detail"; slot="queryRevision"; end
      when key="sourceDetailScopeRevision" then do; target="source-detail"; slot="scopeRevision"; end
      when key="sourceDetailSelectionRevision" then do; target="source-detail"; slot="selectionRevision"; end
      when key="sourceDetailVisible" then do; target="source-detail"; slot="visible"; end
      when key="compositionCanvasItems" then do; target="composition-canvas"; slot="items"; end
      when key="previewMode" then do; target="preview-summary"; slot="mode"; end
      when key="previewProfile" then do; target="preview-summary"; slot="profile"; end
      when key="previewJourneyState" then do; target="preview-summary"; slot="journeyState"; end
      when key="previewViewportClass" then do; target="preview-summary"; slot="viewportClass"; end
      when key="previewVariant" then do; target="preview-summary"; slot="variant"; end
      when key="previewCompositionCount" then do; target="preview-summary"; slot="compositionCount"; end
      when key="previewActiveDefinitions" then do; target="preview-summary"; slot="activeDefinitions"; end
      otherwise do
        dot=pos(".",key)
        if dot>1 then do
          prefix=key~left(dot-1); slot=key~substr(dot+1)
          select
            when prefix="sourceControl" then target="source-window-control"
            when prefix="compositionEdit" then target="composition-editor"
            when prefix="componentEdit" then target="component-editor"
            when prefix="elementEdit" then target="element-editor"
            when prefix="projectionEdit" then target="projection-editor"
            when prefix="materialEdit" then target="material-editor"
            when prefix="journeyEdit" then target="journey-editor"
            when prefix="conditionEdit" then target="condition-editor"
            when prefix="policyEdit" then target="presentation-policy-editor"
            when prefix="experimentEdit" then target="experiment-editor"
            otherwise do; target=""; slot=""; end
          end
        end
      end
    end
    if target<>"" & state~hasIndex(key) then do
      slots=output[target]
      if slots==.nil then do; slots=.table~new; output[target]=slots; end
      slots[slot]=state[key]
    end
  end
  return output

::class WireUIBuilderRuntimeFactory public
::method build class
  use arg targetProject, sourceCatalogue=.nil, applicationId="WIRE-UI-BUILDER", sessionId="BUILDER-SESSION", accessPointId="BUILDER-WEB", studioPackage=.nil
  if studioPackage==.nil then do
    studio=.WireUIBuilderStudioFixture~build(sourceCatalogue)
    pub=studio~publish("WIRE_UI_BUILDER_STUDIO","0.11"); if \pub~ok then return pub
    studioPackage=pub~value["package"]
  end
  else if studioPackage~isA(.String) then studioPackage=.json~fromJsonFile(studioPackage)
  catalogue=.WireUICompiledCatalogue~new(studioPackage)
  view=.WireUIView~new("WireUI.Builder.Studio","root"); projection=.WireUIProjection~new
  app=.WireUIBuilderApplication~new(applicationId,sessionId,accessPointId,view,projection,targetProject,sourceCatalogue)
  bound=app~bindCompiledRelease(catalogue,.WireUIProtocol~PROFILE_HUMAN_VISUAL,"DESIGN"); if \bound~ok then return bound
  installed=app~installInitialView; if \installed~ok then return installed
  return .WireUIResult~success(app,"WIRE_UI_BUILDER_APPLICATION_READY")

::routine must
  use arg r
  if \r~ok then raise syntax 88.900 array(r~code,r~detail)
  return r
::requires "json.cls"
::requires "WireUIAll.cls"
::requires "WireUICompiledCatalogue.cls"
::requires "WireUIBuilderStudioFixture.cls"
