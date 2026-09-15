/*
  First-party consumer-neutral Builder Studio design.
  It is itself authored through WireUIBuilderProject draft operations.
*/
::class WireUIBuilderStudioFixture public
::method build class
  use arg sourceCatalogue=.nil
  meta=.table~new
  if sourceCatalogue<>.nil then do
    if sourceCatalogue~contentAddress="" then call must sourceCatalogue~seal
    meta["sourceCatalogueContentAddress"]=sourceCatalogue~contentAddress
    meta["sourceFileCount"]=sourceCatalogue~fileCount
  end
  p=.WireUIBuilderProject~new("WIRE_UI_BUILDER_STUDIO","Wire UI Builder Studio",.nil,meta)

  /* Components are generic renderer vocabulary, not consumer application widgets. */
  call put p,"DESIGN.COMPONENT.DRAFT","FORM",self~component("1","FORM")
  call put p,"DESIGN.COMPONENT.DRAFT","TOKEN_FORM",self~component("1","TOKEN_FORM")
  call put p,"DESIGN.COMPONENT.DRAFT","COLLECTION",self~component("1","OFFER_LIST")
  call put p,"DESIGN.COMPONENT.DRAFT","SEMANTIC_RECORD",self~component("1","SEMANTIC_RECORD")
  call put p,"DESIGN.COMPONENT.DRAFT","PANEL",self~component("1","PANEL")
  call put p,"DESIGN.COMPONENT.DRAFT","ACTION_BUTTON",self~component("1","ACTION_BUTTON")

  call put p,"DESIGN.ELEMENT.DRAFT","BUILDER_SHELL",self~element("1","BUILDER_SHELL",.array~of("visible"),.array~new)
  call put p,"DESIGN.ELEMENT.DRAFT","BUILDER_PROJECT",self~element("1","BUILDER_PROJECT",.array~of("projectId","title","revision","draftCount"),.array~new)
  call put p,"DESIGN.ELEMENT.DRAFT","BUILDER_TOOL_NAV",self~element("1","STUDIO_TOOL_NAV",.array~of("items"),.array~of("STUDIO.NAVIGATE"))
  call put p,"DESIGN.ELEMENT.DRAFT","BUILDER_ARTIFACT_LIBRARY",self~element("1","ARTIFACT_LIBRARY",.array~of("items"),.array~of("ARTIFACT.SELECT"))
  call put p,"DESIGN.ELEMENT.DRAFT","BUILDER_SELECTION_INSPECTOR",self~element("1","SELECTION_INSPECTOR",.array~of("kind","artifactId","draftRevision","publishVersion","detail"),.array~new)
  call put p,"DESIGN.ELEMENT.DRAFT","BUILDER_FLOW_MAP",self~element("1","FLOW_MAP",.array~of("items"),.array~of("FLOW.SELECT"))
  call put p,"DESIGN.ELEMENT.DRAFT","BUILDER_SOURCE_FILES",self~element("1","SOURCE_WINDOW",.array~of("collectionRef","windowOffset","windowLimit","windowTotalCount","windowRevision","sortRef","filterRef","anchorRef"),.array~new)
  call put p,"DESIGN.ELEMENT.DRAFT","BUILDER_SOURCE_WINDOW_CONTROL",self~element("1","SOURCE_WINDOW_CONTROL",.array~of("filter","sortRef","direction","offset","limit"),.array~of("SOURCE.WINDOW"))
  call put p,"DESIGN.ELEMENT.DRAFT","BUILDER_SOURCE_ROW",self~element("1","SOURCE_ROW",.array~of("label"),.array~of("SOURCE.OPEN"))
  call put p,"DESIGN.ELEMENT.DRAFT","BUILDER_SOURCE_DETAIL",self~element("1","SOURCE_DETAIL",.array~of("path","classes","methods","attributes","constants","requires","packageOptions","queryRevision","scopeRevision","selectionRevision"),.array~new)
  call put p,"DESIGN.ELEMENT.DRAFT","BUILDER_COMPONENT_EDITOR",self~element("1","COMPONENT_EDITOR",.array~of("artifactId","publishVersion","primitive"),.array~of("DESIGN.COMPONENT.DRAFT"))
  call put p,"DESIGN.ELEMENT.DRAFT","BUILDER_ELEMENT_EDITOR",self~element("1","ELEMENT_EDITOR",.array~of("artifactId","publishVersion","semanticType","fields","actions","audiencePolicyRef"),.array~of("DESIGN.ELEMENT.DRAFT"))
  call put p,"DESIGN.ELEMENT.DRAFT","BUILDER_PROJECTION_EDITOR",self~element("1","PROJECTION_EDITOR",.array~of("artifactId","publishVersion","profile","elementId","componentId","definitionId","action","styleRole","materialRole","resourceRole","resourceId","resourceVersion","resourceContentAddress","resourceClass","resourceLocale"),.array~of("DESIGN.PROJECTION.DRAFT"))
  call put p,"DESIGN.ELEMENT.DRAFT","BUILDER_MATERIAL_EDITOR",self~element("1","MATERIAL_EDITOR",.array~of("artifactId","publishVersion","tokenName","tokenValue"),.array~of("DESIGN.MATERIAL.DRAFT"))
  call put p,"DESIGN.ELEMENT.DRAFT","BUILDER_JOURNEY_EDITOR",self~element("1","JOURNEY_EDITOR",.array~of("artifactId","publishVersion","initialState","initialFlowId","flowId","flowInitialState","stateId","active","prefetch","onDemand","fromState","toState","trigger","purpose","transitionWhenMode","transitionWhenConditionIds","transitionSuppressConditionIds"),.array~of("DESIGN.JOURNEY.DRAFT"))
  call put p,"DESIGN.ELEMENT.DRAFT","BUILDER_CONDITION_EDITOR",self~element("1","CONDITION_EDITOR",.array~of("artifactId","publishVersion","sourceKind","sourceRef","operator","expectedValue","authorityRef"),.array~of("DESIGN.CONDITION.DRAFT"))
  call put p,"DESIGN.ELEMENT.DRAFT","BUILDER_PRESENTATION_POLICY_EDITOR",self~element("1","PRESENTATION_POLICY_EDITOR",.array~of("artifactId","publishVersion","precedence","region","capacity"),.array~of("DESIGN.PRESENTATION_POLICY.DRAFT"))
  call put p,"DESIGN.ELEMENT.DRAFT","BUILDER_EXPERIMENT_EDITOR",self~element("1","EXPERIMENT_EDITOR",.array~of("artifactId","publishVersion","targetElementId","variantAProjectionId","variantBProjectionId"),.array~of("DESIGN.EXPERIMENT.DRAFT"))
  call put p,"DESIGN.ELEMENT.DRAFT","BUILDER_COMPOSITION_CANVAS",self~element("1","COMPOSITION_CANVAS",.array~of("items"),.array~of("COMPOSITION.SELECT","DESIGN.COMPOSITION.MOVE","DESIGN.COMPOSITION.RESIZE","DESIGN.COMPOSITION.RELOCATE","DESIGN.COMPOSITION.ALIGN"))
  call put p,"DESIGN.ELEMENT.DRAFT","BUILDER_COMPOSITION_EDITOR",self~element("1","COMPOSITION_EDITOR",.array~of("artifactId","publishVersion","journeyId","profile","stateId","layoutModel","presentationPolicyId","presentationPolicyVersion","elementId","projectionId","region","order","span","rowSpan","align","viewportClass","whenMode","whenConditionIds","suppressConditionIds","presentationClass"),.array~of("DESIGN.COMPOSITION.DRAFT"))
  call put p,"DESIGN.ELEMENT.DRAFT","BUILDER_PREVIEW_CONTROL",self~element("1","PREVIEW_CONTROL",.array~of("profile","journeyState","viewportClass","experimentId","variantId"),.array~of("PREVIEW.CONFIGURE"))
  call put p,"DESIGN.ELEMENT.DRAFT","BUILDER_PREVIEW_SUMMARY",self~element("1","PREVIEW_SUMMARY",.array~of("mode","profile","journeyState","viewportClass","variant","compositionCount","activeDefinitions"),.array~new)
  call put p,"DESIGN.ELEMENT.DRAFT","BUILDER_PUBLISH",self~element("1","PUBLISH",.array~of("releaseId","releaseVersion"),.array~of("DESIGN.PUBLISH"))

  tokens=.table~new; tokens["brand.ink"]="#172033"; tokens["brand.accent"]="#4f46e5"; tokens["surface"]="#ffffff"; tokens["space.unit"]="8"; tokens["radius.control"]="8"
  recipes=.table~new; recipes["builder.panel"]="surface/panel"; recipes["builder.editor"]="surface/form"; recipes["builder.source"]="surface/list"
  ms=.table~new; ms["publishVersion"]="1"; ms["tokens"]=tokens; ms["recipes"]=recipes
  call put p,"DESIGN.MATERIAL.DRAFT","WIRE_UI_BUILDER_MATERIAL",ms

  call put p,"DESIGN.PROJECTION.DRAFT","BUILDER_SHELL_VIEW",self~projection("1","HUMAN_VISUAL","BUILDER_SHELL","PANEL","WUIB_SHELL","","builder.panel","builder.panel",.nil)
  call put p,"DESIGN.PROJECTION.DRAFT","BUILDER_PROJECT_VIEW",self~projection("1","HUMAN_VISUAL","BUILDER_PROJECT","SEMANTIC_RECORD","WUIB_PROJECT","","builder.panel","builder.panel",self~bindings(.array~of("projectId","title","revision","draftCount")))
  call put p,"DESIGN.PROJECTION.DRAFT","BUILDER_TOOL_NAV_VIEW",self~projection("1","HUMAN_VISUAL","BUILDER_TOOL_NAV","COLLECTION","WUIB_TOOL_NAV","STUDIO.NAVIGATE","builder.tool.nav","builder.tool.nav",.nil)
  call put p,"DESIGN.PROJECTION.DRAFT","BUILDER_ARTIFACT_LIBRARY_VIEW",self~projection("1","HUMAN_VISUAL","BUILDER_ARTIFACT_LIBRARY","COLLECTION","WUIB_ARTIFACT_LIBRARY","ARTIFACT.SELECT","builder.library","builder.library",.nil)
  call put p,"DESIGN.PROJECTION.DRAFT","BUILDER_SELECTION_INSPECTOR_VIEW",self~projection("1","HUMAN_VISUAL","BUILDER_SELECTION_INSPECTOR","SEMANTIC_RECORD","WUIB_SELECTION_INSPECTOR","","builder.inspector","builder.panel",self~bindings(.array~of("kind","artifactId","draftRevision","publishVersion","detail")))
  call put p,"DESIGN.PROJECTION.DRAFT","BUILDER_FLOW_MAP_VIEW",self~projection("1","HUMAN_VISUAL","BUILDER_FLOW_MAP","COLLECTION","WUIB_FLOW_MAP","FLOW.SELECT","builder.flow.map","builder.panel",.nil)
  call put p,"DESIGN.PROJECTION.DRAFT","BUILDER_SOURCE_FILES_VIEW",self~projection("1","HUMAN_VISUAL","BUILDER_SOURCE_FILES","SEMANTIC_RECORD","WUIB_SOURCE_FILES","","builder.source","builder.source",self~bindings(.array~of("collectionRef","windowOffset","windowLimit","windowTotalCount","windowRevision","sortRef","filterRef","anchorRef")))
  call put p,"DESIGN.PROJECTION.DRAFT","BUILDER_SOURCE_WINDOW_CONTROL_VIEW",self~projection("1","HUMAN_VISUAL","BUILDER_SOURCE_WINDOW_CONTROL","FORM","WUIB_SOURCE_WINDOW_CONTROL","SOURCE.WINDOW","builder.source.control","builder.editor",self~bindings(.array~of("filter","sortRef","direction","offset","limit")))
  call put p,"DESIGN.PROJECTION.DRAFT","BUILDER_SOURCE_ROW_VIEW",self~projection("1","HUMAN_VISUAL","BUILDER_SOURCE_ROW","ACTION_BUTTON","WUIB_SOURCE_ROW","SOURCE.OPEN","builder.source.row","builder.source",self~bindings(.array~of("label")))
  call put p,"DESIGN.PROJECTION.DRAFT","BUILDER_SOURCE_DETAIL_VIEW",self~projection("1","HUMAN_VISUAL","BUILDER_SOURCE_DETAIL","SEMANTIC_RECORD","WUIB_SOURCE_DETAIL","","builder.panel","builder.panel",self~bindings(.array~of("path","classes","methods","attributes","constants","requires","packageOptions","queryRevision","scopeRevision","selectionRevision")))
  call put p,"DESIGN.PROJECTION.DRAFT","BUILDER_COMPONENT_EDITOR_VIEW",self~projection("1","HUMAN_VISUAL","BUILDER_COMPONENT_EDITOR","FORM","WUIB_COMPONENT_EDITOR","DESIGN.COMPONENT.DRAFT","builder.editor","builder.editor",self~bindings(.array~of("artifactId","publishVersion","primitive")))
  call put p,"DESIGN.PROJECTION.DRAFT","BUILDER_ELEMENT_EDITOR_VIEW",self~projection("1","HUMAN_VISUAL","BUILDER_ELEMENT_EDITOR","FORM","WUIB_ELEMENT_EDITOR","DESIGN.ELEMENT.DRAFT","builder.editor","builder.editor",self~bindings(.array~of("artifactId","publishVersion","semanticType","fields","actions","audiencePolicyRef")))
  call put p,"DESIGN.PROJECTION.DRAFT","BUILDER_PROJECTION_EDITOR_VIEW",self~projection("1","HUMAN_VISUAL","BUILDER_PROJECTION_EDITOR","FORM","WUIB_PROJECTION_EDITOR","DESIGN.PROJECTION.DRAFT","builder.editor","builder.editor",self~bindings(.array~of("artifactId","publishVersion","profile","elementId","componentId","definitionId","action","styleRole","materialRole","resourceRole","resourceId","resourceVersion","resourceContentAddress","resourceClass","resourceLocale")))
  call put p,"DESIGN.PROJECTION.DRAFT","BUILDER_MATERIAL_EDITOR_VIEW",self~projection("1","HUMAN_VISUAL","BUILDER_MATERIAL_EDITOR","TOKEN_FORM","WUIB_MATERIAL_EDITOR","DESIGN.MATERIAL.DRAFT","builder.editor","builder.editor",self~bindings(.array~of("artifactId","publishVersion","tokenName","tokenValue")))
  call put p,"DESIGN.PROJECTION.DRAFT","BUILDER_JOURNEY_EDITOR_VIEW",self~projection("1","HUMAN_VISUAL","BUILDER_JOURNEY_EDITOR","FORM","WUIB_JOURNEY_EDITOR","DESIGN.JOURNEY.DRAFT","builder.editor","builder.editor",self~bindings(.array~of("artifactId","publishVersion","initialState","initialFlowId","flowId","flowInitialState","stateId","active","prefetch","onDemand","fromState","toState","trigger","purpose","transitionWhenMode","transitionWhenConditionIds","transitionSuppressConditionIds")))
  call put p,"DESIGN.PROJECTION.DRAFT","BUILDER_CONDITION_EDITOR_VIEW",self~projection("1","HUMAN_VISUAL","BUILDER_CONDITION_EDITOR","FORM","WUIB_CONDITION_EDITOR","DESIGN.CONDITION.DRAFT","builder.editor","builder.editor",self~bindings(.array~of("artifactId","publishVersion","sourceKind","sourceRef","operator","expectedValue","authorityRef")))
  call put p,"DESIGN.PROJECTION.DRAFT","BUILDER_PRESENTATION_POLICY_EDITOR_VIEW",self~projection("1","HUMAN_VISUAL","BUILDER_PRESENTATION_POLICY_EDITOR","FORM","WUIB_PRESENTATION_POLICY_EDITOR","DESIGN.PRESENTATION_POLICY.DRAFT","builder.editor","builder.editor",self~bindings(.array~of("artifactId","publishVersion","precedence","region","capacity")))
  call put p,"DESIGN.PROJECTION.DRAFT","BUILDER_EXPERIMENT_EDITOR_VIEW",self~projection("1","HUMAN_VISUAL","BUILDER_EXPERIMENT_EDITOR","FORM","WUIB_EXPERIMENT_EDITOR","DESIGN.EXPERIMENT.DRAFT","builder.editor","builder.editor",self~bindings(.array~of("artifactId","publishVersion","targetElementId","variantAProjectionId","variantBProjectionId")))
  call put p,"DESIGN.PROJECTION.DRAFT","BUILDER_COMPOSITION_CANVAS_VIEW",self~projection("1","HUMAN_VISUAL","BUILDER_COMPOSITION_CANVAS","COLLECTION","WUIB_COMPOSITION_CANVAS","COMPOSITION.SELECT","builder.canvas","builder.canvas",.nil)
  call put p,"DESIGN.PROJECTION.DRAFT","BUILDER_COMPOSITION_EDITOR_VIEW",self~projection("1","HUMAN_VISUAL","BUILDER_COMPOSITION_EDITOR","FORM","WUIB_COMPOSITION_EDITOR","DESIGN.COMPOSITION.DRAFT","builder.editor","builder.editor",self~bindings(.array~of("artifactId","publishVersion","journeyId","profile","stateId","layoutModel","presentationPolicyId","presentationPolicyVersion","elementId","projectionId","region","order","span","rowSpan","align","viewportClass","whenMode","whenConditionIds","suppressConditionIds","presentationClass")))
  call put p,"DESIGN.PROJECTION.DRAFT","BUILDER_PREVIEW_CONTROL_VIEW",self~projection("1","HUMAN_VISUAL","BUILDER_PREVIEW_CONTROL","FORM","WUIB_PREVIEW_CONTROL","PREVIEW.CONFIGURE","builder.preview.control","builder.panel",self~bindings(.array~of("profile","journeyState","viewportClass","experimentId","variantId")))
  call put p,"DESIGN.PROJECTION.DRAFT","BUILDER_PREVIEW_SUMMARY_VIEW",self~projection("1","HUMAN_VISUAL","BUILDER_PREVIEW_SUMMARY","SEMANTIC_RECORD","WUIB_PREVIEW_SUMMARY","","builder.preview.summary","builder.panel",self~bindings(.array~of("mode","profile","journeyState","viewportClass","variant","compositionCount","activeDefinitions")))
  call put p,"DESIGN.PROJECTION.DRAFT","BUILDER_PUBLISH_VIEW",self~projection("1","HUMAN_VISUAL","BUILDER_PUBLISH","FORM","WUIB_PUBLISH","DESIGN.PUBLISH","builder.editor","builder.editor",self~bindings(.array~of("releaseId","releaseVersion")))

  states=.array~new
  s=.table~new; s["stateId"]="DESIGN"; s["ACTIVE"]=.array~of("BUILDER_SHELL","BUILDER_PROJECT","BUILDER_TOOL_NAV","BUILDER_ARTIFACT_LIBRARY","BUILDER_COMPOSITION_CANVAS","BUILDER_SELECTION_INSPECTOR","BUILDER_COMPOSITION_EDITOR","BUILDER_PREVIEW_CONTROL","BUILDER_PREVIEW_SUMMARY","BUILDER_FLOW_MAP"); s["PREFETCH"]=.array~of("BUILDER_SOURCE_FILES","BUILDER_SOURCE_WINDOW_CONTROL","BUILDER_SOURCE_ROW","BUILDER_SOURCE_DETAIL","BUILDER_COMPONENT_EDITOR","BUILDER_ELEMENT_EDITOR","BUILDER_PROJECTION_EDITOR","BUILDER_MATERIAL_EDITOR","BUILDER_JOURNEY_EDITOR","BUILDER_CONDITION_EDITOR","BUILDER_PRESENTATION_POLICY_EDITOR","BUILDER_EXPERIMENT_EDITOR","BUILDER_PUBLISH"); s["ON_DEMAND"]=.array~new; states~append(s)
  s=.table~new; s["stateId"]="SOURCE"; s["ACTIVE"]=.array~of("BUILDER_SHELL","BUILDER_PROJECT","BUILDER_TOOL_NAV","BUILDER_SOURCE_FILES","BUILDER_SOURCE_WINDOW_CONTROL","BUILDER_SOURCE_ROW","BUILDER_SOURCE_DETAIL"); s["PREFETCH"]=.array~new; s["ON_DEMAND"]=.array~new; states~append(s)
  s=.table~new; s["stateId"]="COMPONENTS"; s["ACTIVE"]=.array~of("BUILDER_SHELL","BUILDER_PROJECT","BUILDER_TOOL_NAV","BUILDER_ARTIFACT_LIBRARY","BUILDER_COMPONENT_EDITOR","BUILDER_ELEMENT_EDITOR","BUILDER_PROJECTION_EDITOR"); s["PREFETCH"]=.array~new; s["ON_DEMAND"]=.array~new; states~append(s)
  s=.table~new; s["stateId"]="MATERIALS"; s["ACTIVE"]=.array~of("BUILDER_SHELL","BUILDER_PROJECT","BUILDER_TOOL_NAV","BUILDER_ARTIFACT_LIBRARY","BUILDER_MATERIAL_EDITOR","BUILDER_PREVIEW_SUMMARY"); s["PREFETCH"]=.array~new; s["ON_DEMAND"]=.array~new; states~append(s)
  s=.table~new; s["stateId"]="FLOW"; s["ACTIVE"]=.array~of("BUILDER_SHELL","BUILDER_PROJECT","BUILDER_TOOL_NAV","BUILDER_ARTIFACT_LIBRARY","BUILDER_FLOW_MAP","BUILDER_JOURNEY_EDITOR","BUILDER_CONDITION_EDITOR","BUILDER_PRESENTATION_POLICY_EDITOR","BUILDER_EXPERIMENT_EDITOR","BUILDER_PREVIEW_SUMMARY"); s["PREFETCH"]=.array~new; s["ON_DEMAND"]=.array~new; states~append(s)
  s=.table~new; s["stateId"]="PUBLISH"; s["ACTIVE"]=.array~of("BUILDER_SHELL","BUILDER_PROJECT","BUILDER_TOOL_NAV","BUILDER_ARTIFACT_LIBRARY","BUILDER_PREVIEW_SUMMARY","BUILDER_PUBLISH"); s["PREFETCH"]=.array~new; s["ON_DEMAND"]=.array~new; states~append(s)
  transitions=.array~new
  js=.table~new; js["publishVersion"]="1"; js["initialState"]="DESIGN"; js["states"]=states; js["transitions"]=transitions
  call put p,"DESIGN.JOURNEY.DRAFT","BUILDER_STUDIO",js

  /* The Builder Studio itself dogfoods semantic composition. */
  call put p,"DESIGN.COMPOSITION.DRAFT","BUILDER_DESIGN_LAYOUT",self~composition("1","BUILDER_STUDIO","HUMAN_VISUAL","DESIGN",self~designPlacements)
  call put p,"DESIGN.COMPOSITION.DRAFT","BUILDER_SOURCE_LAYOUT",self~composition("1","BUILDER_STUDIO","HUMAN_VISUAL","SOURCE",self~sourcePlacements)
  call put p,"DESIGN.COMPOSITION.DRAFT","BUILDER_COMPONENTS_LAYOUT",self~composition("1","BUILDER_STUDIO","HUMAN_VISUAL","COMPONENTS",self~componentsPlacements)
  call put p,"DESIGN.COMPOSITION.DRAFT","BUILDER_MATERIALS_LAYOUT",self~composition("1","BUILDER_STUDIO","HUMAN_VISUAL","MATERIALS",self~materialsPlacements)
  call put p,"DESIGN.COMPOSITION.DRAFT","BUILDER_FLOW_LAYOUT",self~composition("1","BUILDER_STUDIO","HUMAN_VISUAL","FLOW",self~flowPlacements)
  call put p,"DESIGN.COMPOSITION.DRAFT","BUILDER_PUBLISH_LAYOUT",self~composition("1","BUILDER_STUDIO","HUMAN_VISUAL","PUBLISH",self~publishPlacements)
  return p

::method component class

  use arg version,primitive
  s=.table~new; s["publishVersion"]=version; s["primitive"]=primitive; return s
::method element class
  use arg version,semanticType,fields,actions
  s=.table~new; s["publishVersion"]=version; s["semanticType"]=semanticType; s["fields"]=fields; s["actions"]=actions; s["audiencePolicyRef"]="PUBLIC"; return s
::method projection class
  use arg version,profile,elementId,componentId,definitionId,action,styleRole,materialRole,bindings
  s=.table~new; s["publishVersion"]=version; s["profile"]=profile; s["elementId"]=elementId; s["componentId"]=componentId; s["definitionId"]=definitionId; s["action"]=action; s["styleRole"]=styleRole; s["materialRole"]=materialRole; s["bindings"]=bindings; return s
::method composition class
  use arg version,journeyId,profile,stateId,placements
  s=.table~new; s["publishVersion"]=version; s["journeyId"]=journeyId; s["profile"]=profile; s["stateId"]=stateId; s["layoutModel"]="GRID12"; s["placements"]=placements; return s
::method placement class
  use arg elementId,region,order,span,align="STRETCH",viewportClass="DEFAULT"
  p=.table~new; p["elementId"]=elementId; p["region"]=region; p["order"]=order; p["span"]=span; p["rowSpan"]=1; p["align"]=align; p["viewportClass"]=viewportClass; p["projectionId"]=""; return p
::method commonPlacements class
  a=.array~new
  a~append(self~placement("BUILDER_PROJECT","header",0,12))
  a~append(self~placement("BUILDER_TOOL_NAV","nav",5,12))
  return a
::method designPlacements class
  a=self~commonPlacements
  a~append(self~placement("BUILDER_ARTIFACT_LIBRARY","library",10,3))
  a~append(self~placement("BUILDER_COMPOSITION_CANVAS","canvas",20,6))
  a~append(self~placement("BUILDER_SELECTION_INSPECTOR","inspector",30,3))
  a~append(self~placement("BUILDER_PREVIEW_CONTROL","inspector",31,3))
  a~append(self~placement("BUILDER_COMPOSITION_EDITOR","inspector",32,3))
  a~append(self~placement("BUILDER_PREVIEW_SUMMARY","canvas",40,6))
  a~append(self~placement("BUILDER_FLOW_MAP","flow",50,12))
  return a
::method sourcePlacements class
  a=self~commonPlacements
  a~append(self~placement("BUILDER_SOURCE_WINDOW_CONTROL","source-list",9,4))
  a~append(self~placement("BUILDER_SOURCE_FILES","source-list",10,4))
  a~append(self~placement("BUILDER_SOURCE_DETAIL","source-detail",11,8))
  return a
::method componentsPlacements class
  a=self~commonPlacements
  a~append(self~placement("BUILDER_ARTIFACT_LIBRARY","catalogue",9,3))
  a~append(self~placement("BUILDER_COMPONENT_EDITOR","component-editor",10,3))
  a~append(self~placement("BUILDER_ELEMENT_EDITOR","element-editor",11,3))
  a~append(self~placement("BUILDER_PROJECTION_EDITOR","projection-editor",12,3))
  return a
::method materialsPlacements class
  a=self~commonPlacements
  a~append(self~placement("BUILDER_ARTIFACT_LIBRARY","catalogue",9,4))
  a~append(self~placement("BUILDER_MATERIAL_EDITOR","material-editor",10,4))
  a~append(self~placement("BUILDER_PREVIEW_SUMMARY","preview",11,4))
  return a
::method flowPlacements class
  a=self~commonPlacements
  a~append(self~placement("BUILDER_ARTIFACT_LIBRARY","catalogue",9,3))
  a~append(self~placement("BUILDER_FLOW_MAP","flow",10,9))
  a~append(self~placement("BUILDER_JOURNEY_EDITOR","journey-editor",20,4))
  a~append(self~placement("BUILDER_CONDITION_EDITOR","condition-editor",21,4))
  a~append(self~placement("BUILDER_PRESENTATION_POLICY_EDITOR","policy-editor",22,4))
  a~append(self~placement("BUILDER_EXPERIMENT_EDITOR","experiment-editor",23,6))
  a~append(self~placement("BUILDER_PREVIEW_SUMMARY","preview",30,6))
  return a
::method publishPlacements class
  a=self~commonPlacements
  a~append(self~placement("BUILDER_ARTIFACT_LIBRARY","catalogue",9,4))
  a~append(self~placement("BUILDER_PREVIEW_SUMMARY","preview",10,5))
  a~append(self~placement("BUILDER_PUBLISH","publish",11,3))
  return a

::method bindings class
  use arg names
  b=.table~new; do name over names; b[name]=name; end; return b

::routine put
  use arg project,verb,id,spec
  payload=.table~new; payload["artifactId"]=id; payload["spec"]=spec
  op=.WireUIDesignOperation~new("studio-"project~revision"-"id,verb,project~revision,.nil,payload,"BUILDER:SELF","first-party Builder Studio design")
  r=project~applyOperation(op); call must r
  return r
::routine must
  use arg r
  if r~isA(.WireUIDesignResult) then if \r~ok then raise syntax 88.900 array(r~code,r~detail)
  return r
::requires "WireUIBuilderAll.cls"
