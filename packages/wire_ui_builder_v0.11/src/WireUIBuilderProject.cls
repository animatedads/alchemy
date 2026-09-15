/*
  Consumer-neutral Builder project.
  Many draft edits advance project revision only. Publication materialises one
  explicit immutable artifact version per draft into WireUIDesignWorkspace.
*/
::class WireUIBuilderProject subclass AlchemyObject public
::attribute projectId get
::attribute title get
::attribute revision get
::attribute workspace get
::method init
  expose projectId title revision workspace drafts operationLog operationsById metadata
  use arg projectId, title="", workspace=.nil, metadata=.nil
  self~init:super(.WireUIDesignAlchemy~metadata("Consumer-neutral Wire UI Builder project"))
  projectId=projectId~string~strip; title=title~string~strip
  if projectId="" then raise syntax 93.906 array("builder project")
  if workspace==.nil then workspace=.WireUIDesignWorkspace~new(projectId".workspace")
  if \workspace~isA(.WireUIDesignWorkspace) then raise syntax 93.948 array("workspace")
  revision=0; drafts=.table~new; operationLog=.array~new; operationsById=.table~new; metadata=.WireUIDesignUtil~copyTable(metadata)
  self~registerStateVariable("projectId","PUBLIC","stable Builder project identity")
  self~registerStateVariable("revision","PUBLIC","mutable draft project compare-and-swap revision")

::method applyOperation
  expose revision drafts operationLog operationsById
  use arg operation
  if \operation~isA(.WireUIDesignOperation) then return .WireUIDesignResult~failure("INVALID_DESIGN_OPERATION")
  oid=operation~operationId
  if operationsById~hasIndex(oid) then do
    prior=operationsById[oid]
    if prior~contentAddress=operation~contentAddress then return .WireUIDesignResult~success(prior,"OPERATION_ALREADY_APPLIED")
    return .WireUIDesignResult~failure("OPERATION_ID_CONFLICT",oid)
  end
  if operation~expectedRevision<>revision then return .WireUIDesignResult~failure("DESIGN_REVISION_CONFLICT",operation~expectedRevision"|"revision)
  verb=operation~verb
  select
    when verb="DESIGN.COMPONENT.DRAFT" then r=self~putDraft("COMPONENT",operation)
    when verb="DESIGN.ELEMENT.DRAFT" then r=self~putDraft("ELEMENT",operation)
    when verb="DESIGN.MATERIAL.DRAFT" then r=self~putDraft("MATERIAL",operation)
    when verb="DESIGN.CONDITION.DRAFT" then r=self~putDraft("CONDITION",operation)
    when verb="DESIGN.PRESENTATION_POLICY.DRAFT" then r=self~putDraft("PRESENTATION_POLICY",operation)
    when verb="DESIGN.PROJECTION.DRAFT" then r=self~putDraft("PROJECTION",operation)
    when verb="DESIGN.JOURNEY.DRAFT" then r=self~putDraft("JOURNEY",operation)
    when verb="DESIGN.COMPOSITION.DRAFT" then r=self~putDraft("COMPOSITION",operation)
    when verb="DESIGN.COMPOSITION.MOVE" then r=self~moveComposition(operation)
    when verb="DESIGN.COMPOSITION.RESIZE" then r=self~resizeComposition(operation)
    when verb="DESIGN.COMPOSITION.RELOCATE" then r=self~relocateComposition(operation)
    when verb="DESIGN.COMPOSITION.ALIGN" then r=self~alignComposition(operation)
    when verb="DESIGN.EXPERIMENT.DRAFT" then r=self~putDraft("EXPERIMENT",operation)
    otherwise return .WireUIDesignResult~failure("UNSUPPORTED_PROJECT_OPERATION",verb)
  end
  if \r~ok then return r
  revision += 1
  /* Re-stamp the draft with the accepted project revision. */
  candidate=r~value
  final=.WireUIBuilderDraft~new(candidate~kind,candidate~artifactId,revision,candidate~spec,candidate~baseRef)
  drafts[final~key]=final
  operationLog~append(operation); operationsById[oid]=operation
  return .WireUIDesignResult~success(final,"PROJECT_DRAFT_APPLIED")

::method putDraft private
  expose drafts revision
  use arg kind, operation
  p=operation~payload
  artifactId=self~field(p,"artifactId","")~string~strip
  spec=self~field(p,"spec",.nil)
  if artifactId="" then return .WireUIDesignResult~failure(kind"_DRAFT_ID_REQUIRED")
  if spec==.nil | \(spec~isA(.Table) | spec~isA(.Directory)) then return .WireUIDesignResult~failure(kind"_DRAFT_SPEC_REQUIRED")
  vr=self~validateSpec(kind,spec); if \vr~ok then return vr
  baseRef=.nil; key=kind":"artifactId
  if drafts~hasIndex(key) then baseRef=drafts[key]~baseRef
  if p~hasIndex("baseRef") then do
    b=p["baseRef"]
    if b<>.nil & \b~isA(.WireUIArtifactRef) then return .WireUIDesignResult~failure("DRAFT_BASE_REF_INVALID")
    baseRef=b
  end
  return .WireUIDesignResult~success(.WireUIBuilderDraft~new(kind,artifactId,revision+1,spec,baseRef),"DRAFT_READY")

::method moveComposition private
  expose drafts revision
  use arg operation
  p=operation~payload; artifactId=self~field(p,"artifactId","")~string~strip
  if artifactId="" then return .WireUIDesignResult~failure("COMPOSITION_DRAFT_ID_REQUIRED")
  key="COMPOSITION:"artifactId
  if \drafts~hasIndex(key) then return .WireUIDesignResult~failure("COMPOSITION_DRAFT_NOT_FOUND",artifactId)
  sourceKey=self~field(p,"sourcePlacementKey",""); targetKey=self~field(p,"targetPlacementKey","")
  if sourceKey="" | targetKey="" | sourceKey=targetKey then return .WireUIDesignResult~failure("COMPOSITION_MOVE_INVALID")
  prior=drafts[key]; spec=prior~spec; rows=self~field(spec,"placements",.array~new)
  sourceIndex=0; targetIndex=0; i=0
  do row over rows
    i+=1; rk=self~placementKey(row)
    if rk=sourceKey then sourceIndex=i
    if rk=targetKey then targetIndex=i
  end
  if sourceIndex=0 | targetIndex=0 then return .WireUIDesignResult~failure("COMPOSITION_MOVE_PLACEMENT_NOT_FOUND",sourceKey"|"targetKey)
  ordered=.array~new; moving=rows[sourceIndex]
  do i=1 to rows~items
    if i=sourceIndex then iterate
    if i=targetIndex then ordered~append(moving)
    ordered~append(rows[i])
  end
  if sourceIndex>targetIndex then nop
  else if targetIndex=rows~items then do
    /* Moving forward to the last row needs append-after, not insert-before. */
    ordered=.array~new
    do i=1 to rows~items
      if i=sourceIndex then iterate
      ordered~append(rows[i])
    end
    ordered~append(moving)
  end
  normal=.array~new; n=0
  do row over ordered
    n+=1; copy=.WireUIDesignUtil~copyTable(row); copy["order"]=n*10; normal~append(copy)
  end
  spec["placements"]=normal
  return .WireUIDesignResult~success(.WireUIBuilderDraft~new("COMPOSITION",artifactId,revision+1,spec,prior~baseRef),"COMPOSITION_MOVED")

::method resizeComposition private
  expose drafts revision
  use arg operation
  p=operation~payload; artifactId=self~field(p,"artifactId","")~string~strip
  if artifactId="" then return .WireUIDesignResult~failure("COMPOSITION_DRAFT_ID_REQUIRED")
  key="COMPOSITION:"artifactId
  if \drafts~hasIndex(key) then return .WireUIDesignResult~failure("COMPOSITION_DRAFT_NOT_FOUND",artifactId)
  placementKey=self~field(p,"placementKey",""); if placementKey="" then return .WireUIDesignResult~failure("COMPOSITION_RESIZE_PLACEMENT_REQUIRED")
  prior=drafts[key]; spec=prior~spec; rows=self~field(spec,"placements",.array~new)
  next=.array~new; found=.false
  do row over rows
    copy=.WireUIDesignUtil~copyTable(row)
    if self~placementKey(row)=placementKey then do
      span=self~field(p,"span",self~field(row,"span",12))+0
      rowSpan=self~field(p,"rowSpan",self~field(row,"rowSpan",1))+0
      if span<1 | span>12 | span<>span~trunc then return .WireUIDesignResult~failure("COMPOSITION_SPAN_INVALID",span)
      if rowSpan<1 | rowSpan<>rowSpan~trunc then return .WireUIDesignResult~failure("COMPOSITION_ROW_SPAN_INVALID",rowSpan)
      copy["span"]=span; copy["rowSpan"]=rowSpan; found=.true
    end
    next~append(copy)
  end
  if \found then return .WireUIDesignResult~failure("COMPOSITION_RESIZE_PLACEMENT_NOT_FOUND",placementKey)
  spec["placements"]=next
  return .WireUIDesignResult~success(.WireUIBuilderDraft~new("COMPOSITION",artifactId,revision+1,spec,prior~baseRef),"COMPOSITION_RESIZED")

::method relocateComposition private
  expose drafts revision
  use arg operation
  p=operation~payload; artifactId=self~field(p,"artifactId","")~string~strip
  if artifactId="" then return .WireUIDesignResult~failure("COMPOSITION_DRAFT_ID_REQUIRED")
  key="COMPOSITION:"artifactId
  if \drafts~hasIndex(key) then return .WireUIDesignResult~failure("COMPOSITION_DRAFT_NOT_FOUND",artifactId)
  placementKey=self~field(p,"placementKey",""); region=self~field(p,"region","")~string~strip
  if placementKey="" then return .WireUIDesignResult~failure("COMPOSITION_RELOCATE_PLACEMENT_REQUIRED")
  if region="" then return .WireUIDesignResult~failure("COMPOSITION_REGION_REQUIRED")
  prior=drafts[key]; spec=prior~spec; rows=self~field(spec,"placements",.array~new)
  next=.array~new; found=.false
  do row over rows
    copy=.WireUIDesignUtil~copyTable(row)
    if self~placementKey(row)=placementKey then do; copy["region"]=region; found=.true; end
    next~append(copy)
  end
  if \found then return .WireUIDesignResult~failure("COMPOSITION_RELOCATE_PLACEMENT_NOT_FOUND",placementKey)
  spec["placements"]=next
  return .WireUIDesignResult~success(.WireUIBuilderDraft~new("COMPOSITION",artifactId,revision+1,spec,prior~baseRef),"COMPOSITION_RELOCATED")

::method alignComposition private
  expose drafts revision
  use arg operation
  p=operation~payload; artifactId=self~field(p,"artifactId","")~string~strip
  if artifactId="" then return .WireUIDesignResult~failure("COMPOSITION_DRAFT_ID_REQUIRED")
  key="COMPOSITION:"artifactId
  if \drafts~hasIndex(key) then return .WireUIDesignResult~failure("COMPOSITION_DRAFT_NOT_FOUND",artifactId)
  placementKey=self~field(p,"placementKey",""); align=self~field(p,"align","")~string~strip~translate
  if placementKey="" then return .WireUIDesignResult~failure("COMPOSITION_ALIGN_PLACEMENT_REQUIRED")
  if align<>"START" & align<>"CENTER" & align<>"END" & align<>"STRETCH" then return .WireUIDesignResult~failure("COMPOSITION_ALIGN_INVALID",align)
  prior=drafts[key]; spec=prior~spec; rows=self~field(spec,"placements",.array~new)
  next=.array~new; found=.false
  do row over rows
    copy=.WireUIDesignUtil~copyTable(row)
    if self~placementKey(row)=placementKey then do; copy["align"]=align; found=.true; end
    next~append(copy)
  end
  if \found then return .WireUIDesignResult~failure("COMPOSITION_ALIGN_PLACEMENT_NOT_FOUND",placementKey)
  spec["placements"]=next
  return .WireUIDesignResult~success(.WireUIBuilderDraft~new("COMPOSITION",artifactId,revision+1,spec,prior~baseRef),"COMPOSITION_ALIGNED")

::method placementKey private
  use arg row
  return self~field(row,"elementId","")"|"self~field(row,"projectionId","")"|"self~field(row,"viewportClass","DEFAULT")

::method validateSpec private
  use arg kind, spec
  pv=self~field(spec,"publishVersion","")~string~strip
  if pv="" then return .WireUIDesignResult~failure("PUBLISH_VERSION_REQUIRED",kind)
  if kind<>"MATERIAL" then do
    inline=self~inlineDisplayContentKey(spec)
    if inline<>"" then return .WireUIDesignResult~failure("INLINE_DISPLAY_CONTENT_FORBIDDEN",inline)
  end
  select
    when kind="COMPONENT" then do
      if self~field(spec,"primitive","")~string~strip="" then return .WireUIDesignResult~failure("COMPONENT_PRIMITIVE_REQUIRED")
    end
    when kind="ELEMENT" then do
      if self~field(spec,"semanticType","")~string~strip="" then return .WireUIDesignResult~failure("ELEMENT_SEMANTIC_TYPE_REQUIRED")
    end
    when kind="MATERIAL" then nop
    when kind="CONDITION" then do
      do key over .array~of("sourceKind","sourceRef","operator","authorityRef")
        if self~field(spec,key,"")~string~strip="" then return .WireUIDesignResult~failure("CONDITION_"key~translate"_REQUIRED")
      end
      sk=self~field(spec,"sourceKind","")~string~strip~translate; if sk<>"FACT" & sk<>"DECISION" then return .WireUIDesignResult~failure("CONDITION_SOURCE_KIND_INVALID",sk)
      op=self~field(spec,"operator","")~string~strip~translate; if \(.set~of("EQ","NE","PRESENT","ABSENT","TRUE","FALSE")~hasIndex(op)) then return .WireUIDesignResult~failure("CONDITION_OPERATOR_INVALID",op)
      if (op="EQ" | op="NE") & \spec~hasIndex("expectedValue") then return .WireUIDesignResult~failure("CONDITION_EXPECTED_VALUE_REQUIRED")
    end
    when kind="PRESENTATION_POLICY" then do
      prec=self~field(spec,"precedence",.nil); caps=self~field(spec,"capacities",.nil)
      if prec==.nil | \prec~isA(.Array) then return .WireUIDesignResult~failure("PRESENTATION_POLICY_PRECEDENCE_REQUIRED")
      if caps==.nil | \(caps~isA(.Table) | caps~isA(.Directory)) then return .WireUIDesignResult~failure("PRESENTATION_POLICY_CAPACITIES_REQUIRED")
    end
    when kind="PROJECTION" then do
      do key over .array~of("profile","elementId","componentId","definitionId")
        if self~field(spec,key,"")~string~strip="" then return .WireUIDesignResult~failure("PROJECTION_"key~translate"_REQUIRED")
      end
      resources=self~field(spec,"resourceBindings",.array~new)
      if \resources~isA(.Array) then return .WireUIDesignResult~failure("PROJECTION_RESOURCE_BINDINGS_INVALID")
      do rb over resources
        if rb==.nil | \(rb~isA(.Table) | rb~isA(.Directory)) then return .WireUIDesignResult~failure("PROJECTION_RESOURCE_BINDING_INVALID")
        if self~field(rb,"role","")~string~strip="" then return .WireUIDesignResult~failure("PROJECTION_RESOURCE_ROLE_REQUIRED")
        rr=self~field(rb,"resourceRef",.nil); if rr==.nil | \(rr~isA(.Table) | rr~isA(.Directory)) then return .WireUIDesignResult~failure("PROJECTION_RESOURCE_REF_REQUIRED")
        do rk over .array~of("resourceId","version","contentAddress","resourceClass")
          if self~field(rr,rk,"")~string~strip="" then return .WireUIDesignResult~failure("PROJECTION_RESOURCE_"rk~translate"_REQUIRED")
        end
      end
    end
    when kind="JOURNEY" then do
      if self~field(spec,"initialState","")~string~strip="" then return .WireUIDesignResult~failure("JOURNEY_INITIAL_STATE_REQUIRED")
      states=self~field(spec,"states",.nil)
      if states==.nil | \states~isA(.Array) | states~items=0 then return .WireUIDesignResult~failure("JOURNEY_STATES_REQUIRED")
      flows=self~field(spec,"flows",.array~new)
      if flows~items>0 then do
        if self~field(spec,"initialFlowId","")~string~strip="" then return .WireUIDesignResult~failure("JOURNEY_INITIAL_FLOW_REQUIRED")
        do f over flows
          if self~field(f,"flowId","")~string~strip="" | self~field(f,"initialState","")~string~strip="" then return .WireUIDesignResult~failure("JOURNEY_FLOW_INVALID")
        end
        do st over states; if self~field(st,"flowId","")~string~strip="" then return .WireUIDesignResult~failure("JOURNEY_STATE_FLOW_REQUIRED",self~field(st,"stateId","")); end
      end
      transitions=self~field(spec,"transitions",.array~new)
      if \transitions~isA(.Array) then return .WireUIDesignResult~failure("JOURNEY_TRANSITIONS_INVALID")
      do tr over transitions
        if tr==.nil | \(tr~isA(.Table) | tr~isA(.Directory)) then return .WireUIDesignResult~failure("JOURNEY_TRANSITION_INVALID")
        if self~field(tr,"fromState","")~string~strip="" | self~field(tr,"toState","")~string~strip="" then return .WireUIDesignResult~failure("JOURNEY_TRANSITION_STATES_REQUIRED")
        mode=self~field(tr,"whenMode","ALL")~string~strip~translate
        if mode<>"ALL" & mode<>"ANY" then return .WireUIDesignResult~failure("JOURNEY_TRANSITION_WHEN_MODE_INVALID",mode)
        do ck over .array~of("whenConditionIds","suppressConditionIds")
          ca=self~field(tr,ck,.array~new); if \ca~isA(.Array) then return .WireUIDesignResult~failure("JOURNEY_TRANSITION_CONDITION_IDS_INVALID",ck)
        end
      end
    end
    when kind="COMPOSITION" then do
      do key over .array~of("journeyId","profile","stateId","layoutModel")
        if self~field(spec,key,"")~string~strip="" then return .WireUIDesignResult~failure("COMPOSITION_"key~translate"_REQUIRED")
      end
      rows=self~field(spec,"placements",.nil)
      if rows==.nil | \rows~isA(.Array) | rows~items=0 then return .WireUIDesignResult~failure("COMPOSITION_PLACEMENTS_REQUIRED")
      do row over rows
        if row==.nil | \(row~isA(.Table) | row~isA(.Directory)) then return .WireUIDesignResult~failure("COMPOSITION_PLACEMENT_INVALID")
        if self~field(row,"elementId","")~string~strip="" then return .WireUIDesignResult~failure("COMPOSITION_PLACEMENT_ELEMENT_REQUIRED")
        span=self~field(row,"span",12)+0; if span<1 | span>12 | span<>span~trunc then return .WireUIDesignResult~failure("COMPOSITION_SPAN_INVALID",span)
        rowSpan=self~field(row,"rowSpan",1)+0; if rowSpan<1 | rowSpan<>rowSpan~trunc then return .WireUIDesignResult~failure("COMPOSITION_ROW_SPAN_INVALID",rowSpan)
        mode=self~field(row,"whenMode","ALL")~string~strip~translate; if mode<>"ALL" & mode<>"ANY" then return .WireUIDesignResult~failure("COMPOSITION_WHEN_MODE_INVALID",mode)
        do ck over .array~of("whenConditionIds","suppressConditionIds")
          ca=self~field(row,ck,.array~new); if \ca~isA(.Array) then return .WireUIDesignResult~failure("COMPOSITION_CONDITION_IDS_INVALID",ck)
        end
      end
    end
    when kind="EXPERIMENT" then do
      if self~field(spec,"targetElementId","")~string~strip="" then return .WireUIDesignResult~failure("EXPERIMENT_TARGET_REQUIRED")
      vars=self~field(spec,"variants",.nil)
      if vars==.nil | \vars~isA(.Array) | vars~items<2 then return .WireUIDesignResult~failure("EXPERIMENT_VARIANTS_REQUIRED")
    end
    otherwise return .WireUIDesignResult~failure("UNKNOWN_DRAFT_KIND",kind)
  end
  return .WireUIDesignResult~success(.true)

::method draft
  expose drafts
  use arg kind, artifactId
  key=kind~string~translate":"artifactId
  if drafts~hasIndex(key) then return drafts[key]
  return .nil
::method drafts
  expose drafts
  out=.array~new; keys=drafts~allIndexes; keys~sort; do k over keys; out~append(drafts[k]); end; return out
::method operations
  expose operationLog
  return .WireUIDesignUtil~copyArray(operationLog)

::method publish
  expose workspace projectId title metadata
  use arg releaseId, releaseVersion, releaseMetadata=.nil
  releaseId=releaseId~string~strip; releaseVersion=releaseVersion~string~strip
  if releaseId="" | releaseVersion="" then return .WireUIDesignResult~failure("RELEASE_ID_VERSION_REQUIRED")
  published=.table~new
  do kind over .array~of("COMPONENT","ELEMENT","MATERIAL","CONDITION","PRESENTATION_POLICY","PROJECTION","JOURNEY","COMPOSITION","EXPERIMENT")
    do d over self~drafts
      if d~kind<>kind then iterate
      r=self~materialize(d,published)
      if \r~ok then return r
      artifact=r~value; rr=workspace~register(artifact); if \rr~ok then return rr
      published[d~key]=artifact
    end
  end
  releaseInfo=.WireUIDesignUtil~copyTable(releaseMetadata)
  releaseInfo["builderProjectId"]=projectId; releaseInfo["builderProjectRevision"]=self~revision; releaseInfo["builderProjectMetadata"]=.WireUIDesignUtil~copyTable(metadata)
  ledger=""; do operation over self~operations; ledger ||= "|"operation~contentAddress; end
  releaseInfo["builderOperationLedgerFingerprint"]="ledger-" || .WireUIDesignUtil~token(ledger)
  release=.WireUISiteRelease~new(releaseId,releaseVersion,releaseInfo)
  keys=published~allIndexes; keys~sort
  do k over keys; r=release~pin(published[k]~ref); if \r~ok then return r; end
  r=release~seal; if \r~ok then return r
  r=workspace~register(release); if \r~ok then return r
  cr=.WireUICompiler~new~compile(workspace,release); if \cr~ok then return cr
  publishedResult=.directory~new; publishedResult["project"]=self; publishedResult["workspace"]=workspace; publishedResult["release"]=release; publishedResult["package"]=cr~value; publishedResult["published"]=published
  return .WireUIDesignResult~success(publishedResult,"PROJECT_PUBLISHED")

::method materialize private
  expose workspace
  use arg draft, published
  s=draft~spec; id=draft~artifactId; v=s["publishVersion"]~string
  kind=draft~kind
  select
    when kind="COMPONENT" then return .WireUIDesignResult~success(.WireUIVisualComponent~new(id,v,s["primitive"],self~field(s,"slotSchema",.nil),self~field(s,"styleHooks",.nil),self~field(s,"capabilities",.nil)))
    when kind="ELEMENT" then return .WireUIDesignResult~success(.WireUISemanticElement~new(id,v,s["semanticType"],self~field(s,"fields",.nil),self~field(s,"actions",.nil),self~field(s,"audiencePolicyRef","PUBLIC"),self~field(s,"metadata",.nil)))
    when kind="MATERIAL" then return .WireUIDesignResult~success(.WireUIMaterialSet~new(id,v,self~field(s,"tokens",.nil),self~field(s,"recipes",.nil)))
    when kind="CONDITION" then return .WireUIDesignResult~success(.WireUIConditionDesign~new(id,v,s["sourceKind"],s["sourceRef"],s["operator"],self~field(s,"expectedValue",.nil),s["authorityRef"],self~field(s,"metadata",.nil)))
    when kind="PRESENTATION_POLICY" then return .WireUIDesignResult~success(.WireUIPresentationPolicy~new(id,v,self~field(s,"precedence",.nil),self~field(s,"capacities",.nil),self~field(s,"metadata",.nil)))
    when kind="PROJECTION" then do
      er=self~resolveRef("ELEMENT",s["elementId"],self~field(s,"elementVersion",""),published); if er==.nil then return .WireUIDesignResult~failure("PROJECTION_ELEMENT_UNRESOLVED",id)
      cr=self~resolveRef("COMPONENT",s["componentId"],self~field(s,"componentVersion",""),published); if cr==.nil then return .WireUIDesignResult~failure("PROJECTION_COMPONENT_UNRESOLVED",id)
      return .WireUIDesignResult~success(.WireUIProjectionDesign~new(id,v,s["profile"],er,cr,s["definitionId"],self~field(s,"action",""),self~field(s,"styleRole",""),self~field(s,"materialRole",""),self~field(s,"bindings",.nil),self~field(s,"metadata",.nil),self~field(s,"resourceBindings",.nil)))
    end
    when kind="JOURNEY" then do
      j=.WireUIJourneyDesign~new(id,v,s["initialState"],self~field(s,"initialFlowId",""))
      do flow over self~field(s,"flows",.array~new)
        r=j~defineFlow(self~field(flow,"flowId",""),self~field(flow,"initialState",""),self~field(flow,"metadata",.nil)); if \r~ok then return r
      end
      do row over s["states"]
        sid=self~field(row,"stateId",""); if sid="" then return .WireUIDesignResult~failure("JOURNEY_STATE_ID_REQUIRED",id)
        r=j~defineState(sid,self~field(row,"ACTIVE",.nil),self~field(row,"PREFETCH",.nil),self~field(row,"ON_DEMAND",.nil),self~field(row,"flowId","")); if \r~ok then return r
      end
      ts=self~field(s,"transitions",.nil)
      if ts<>.nil then do t over ts
        r=j~allowTransition(self~field(t,"fromState",""),self~field(t,"toState",""),self~field(t,"trigger",""),self~field(t,"purpose",""),self~field(t,"whenConditionIds",.nil),self~field(t,"suppressConditionIds",.nil),self~field(t,"whenMode","ALL")); if \r~ok then return r
      end
      r=j~seal; if \r~ok then return r
      return .WireUIDesignResult~success(j)
    end
    when kind="COMPOSITION" then do
      jr=self~resolveRef("JOURNEY",s["journeyId"],self~field(s,"journeyVersion",""),published)
      if jr==.nil then return .WireUIDesignResult~failure("COMPOSITION_JOURNEY_UNRESOLVED",id)
      pref=.nil
      if self~field(s,"presentationPolicyId","")<>"" then do
        pref=self~resolveRef("PRESENTATION_POLICY",s["presentationPolicyId"],self~field(s,"presentationPolicyVersion",""),published)
        if pref==.nil then return .WireUIDesignResult~failure("COMPOSITION_PRESENTATION_POLICY_UNRESOLVED",id)
      end
      c=.WireUICompositionDesign~new(id,v,jr,s["profile"],s["stateId"],self~field(s,"layoutModel","GRID12"),s["placements"],self~field(s,"metadata",.nil),pref)
      return .WireUIDesignResult~success(c)
    end
    when kind="EXPERIMENT" then do
      e=.WireUIExperiment~new(id,v,s["targetElementId"],self~field(s,"assignmentUnit","USER"))
      do row over s["variants"]
        pr=self~resolveRef("PROJECTION",self~field(row,"projectionId",""),self~field(row,"projectionVersion",""),published)
        if pr==.nil then return .WireUIDesignResult~failure("EXPERIMENT_PROJECTION_UNRESOLVED",id)
        r=e~addVariant(self~field(row,"variantId",""),self~field(row,"weight",0),pr); if \r~ok then return r
      end
      r=e~seal; if \r~ok then return r
      return .WireUIDesignResult~success(e)
    end
  end
  return .WireUIDesignResult~failure("UNKNOWN_DRAFT_KIND",kind)

::method resolveRef private
  expose workspace
  use arg kind,id,version,published
  key=kind":"id
  if published~hasIndex(key) then return published[key]~ref
  if version="" then return .nil
  a=workspace~artifact(kind,id,version); if a==.nil then return .nil
  return a~ref

::method asWire
  expose projectId title revision metadata
  d=.directory~new; d["schema"]="wire-ui-builder-project-v0.7"; d["projectId"]=projectId; d["title"]=title; d["revision"]=revision; d["metadata"]=.WireUIDesignUtil~copyTable(metadata)
  aa=.array~new; do draft over self~drafts; aa~append(draft~asWire); end; d["drafts"]=aa
  oo=.array~new; do operation over self~operations; oo~append(operation~projectWire); end; d["operations"]=oo
  d["contentAddress"]="project-" || .WireUIDesignUtil~token(projectId"|"title"|"revision"|".WireUIDesignUtil~canonicalArray(aa)"|".WireUIDesignUtil~canonicalArray(oo))
  return d

::method save
  use arg path
  .json~toJsonFile(path,self~asWire,.true)
  return .WireUIDesignResult~success(path,"PROJECT_SAVED")

::method load class
  use arg path
  wire=.json~fromJsonFile(path)
  if wire==.nil then return .WireUIDesignResult~failure("PROJECT_FILE_INVALID",path)
  if wire["schema"]<>"wire-ui-builder-project-v0.7" & wire["schema"]<>"wire-ui-builder-project-v0.6" & wire["schema"]<>"wire-ui-builder-project-v0.5" & wire["schema"]<>"wire-ui-builder-project-v0.4" & wire["schema"]<>"wire-ui-builder-project-v0.3" then return .WireUIDesignResult~failure("PROJECT_SCHEMA_UNSUPPORTED",wire["schema"])
  p=.WireUIBuilderProject~new(wire["projectId"],wire["title"],.nil,wire["metadata"])
  r=p~restoreSnapshot(wire); if \r~ok then return r
  if wire~hasIndex("contentAddress") & wire["contentAddress"]<>"" then if p~asWire["contentAddress"]<>wire["contentAddress"] then return .WireUIDesignResult~failure("PROJECT_CONTENT_MISMATCH",path)
  return .WireUIDesignResult~success(p,"PROJECT_LOADED")

::method restoreSnapshot
  expose revision drafts operationLog operationsById
  use arg wire
  drafts=.table~new; operationLog=.array~new; operationsById=.table~new
  rev=wire["revision"]+0
  if wire~hasIndex("operations") & wire["operations"]<>.nil then do row over wire["operations"]
    rr=.WireUIDesignOperation~fromProjectWire(row); if \rr~ok then return rr
    op=rr~value
    if operationsById~hasIndex(op~operationId) then return .WireUIDesignResult~failure("PROJECT_OPERATION_DUPLICATE",op~operationId)
    operationLog~append(op); operationsById[op~operationId]=op
  end
  if operationLog~items<>rev then return .WireUIDesignResult~failure("PROJECT_OPERATION_LEDGER_INCOMPLETE",operationLog~items"|"rev)
  do row over wire["drafts"]
    base=.nil
    if row["baseRef"]<>.nil then do
      b=row["baseRef"]; base=.WireUIArtifactRef~new(b["kind"],b["id"],b["version"],b["contentAddress"])
    end
    d=.WireUIBuilderDraft~new(row["kind"],row["artifactId"],row["draftRevision"]+0,row["spec"],base)
    if d~contentAddress<>row["contentAddress"] then return .WireUIDesignResult~failure("PROJECT_DRAFT_CONTENT_MISMATCH",d~key)
    drafts[d~key]=d
  end
  revision=rev
  return .WireUIDesignResult~success(self,"PROJECT_RESTORED")

::method inlineDisplayContentKey private
  use arg value, path="spec"
  if value==.nil then return ""
  if value~isA(.Table) | value~isA(.Directory) then do
    forbidden=.set~of("TEXT","LABEL","COPY","CAPTION","HEADLINE","BODY","HTML","MARKDOWN","IMAGE","IMAGEURL","IMAGESRC","SRC","ALTTEXT","DESCRIPTION","LITERALTEXT","DISPLAYTEXT")
    safeSubtrees=.set~of("BINDINGS","SLOTSCHEMA","STYLEHOOKS","CAPABILITIES")
    do k over value~allIndexes
      ku=k~string~translate
      if safeSubtrees~hasIndex(ku) then iterate
      if forbidden~hasIndex(ku) then return path"."k
      r=self~inlineDisplayContentKey(value[k],path"."k); if r<>"" then return r
    end
  end
  else if value~isA(.Array) then do
    i=0; do item over value; i+=1; r=self~inlineDisplayContentKey(item,path"["i"]"); if r<>"" then return r; end
  end
  return ""

::method field private
  use arg t,k,default=.nil
  if t==.nil then return default
  if t~hasIndex(k) then return t[k]
  return default

::requires "json.cls"
::requires "WireUIBuilderDraft.cls"
::requires "WireUIDesignWorkspace.cls"
::requires "WireUIDesignOperation.cls"
::requires "WireUICompiler.cls"
::requires "WireUISiteRelease.cls"
::requires "WireUIVisualComponent.cls"
::requires "WireUISemanticElement.cls"
::requires "WireUIMaterialSet.cls"
::requires "WireUIConditionDesign.cls"
::requires "WireUIPresentationPolicy.cls"
::requires "WireUIResourceRef.cls"
::requires "WireUIProjectionDesign.cls"
::requires "WireUIJourneyDesign.cls"
::requires "WireUIExperiment.cls"

::requires "WireUICompositionDesign.cls"
