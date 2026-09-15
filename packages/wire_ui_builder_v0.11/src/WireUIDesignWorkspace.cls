/* Mutable authoring workspace. Published artifacts remain immutable; typed operations derive new versions. */
::class WireUIDesignWorkspace subclass AlchemyObject public
::attribute workspaceId get
::attribute revision get
::attribute basedOnReleaseRef get
::attribute basedOnGraphDigest get
::method init
  expose workspaceId artifacts projectionsByProfileElement revision basedOnReleaseRef basedOnGraphDigest operationLog operationsById lineages
  use arg workspaceId, basedOnReleaseRef=.nil, basedOnGraphDigest=""
  self~init:super(.WireUIDesignAlchemy~metadata("Human/AI Wire UI authoring workspace"))
  workspaceId=workspaceId~string~strip; artifacts=.table~new; projectionsByProfileElement=.table~new
  revision=0; basedOnGraphDigest=basedOnGraphDigest~string~strip; operationLog=.array~new; operationsById=.table~new; lineages=.table~new
  if workspaceId="" then raise syntax 93.906 array("workspace")
  if basedOnReleaseRef<>.nil then if \basedOnReleaseRef~isA(.WireUIArtifactRef) then raise syntax 93.948 array("basedOnReleaseRef")
  self~registerStateVariable("workspaceId","PUBLIC","mutable authoring workspace identity")
  self~registerStateVariable("revision","PUBLIC","compare-and-swap authoring revision")
  self~registerStateVariable("basedOnGraphDigest","PUBLIC","optional immutable graph digest this workspace was forked from")

/* Import/load an already immutable artifact. This deliberately does not count as an authoring edit. */
::method register
  expose artifacts projectionsByProfileElement
  use arg artifact
  if \artifact~hasMethod("REF") then return .WireUIDesignResult~failure("NOT_VERSIONED_ARTIFACT")
  ref=artifact~ref
  if ref == .nil then return .WireUIDesignResult~failure("ARTIFACT_NOT_SEALED")
  key=ref~key
  if artifacts~hasIndex(key) then do
    prior=artifacts[key]
    if prior~ref~contentAddress \= ref~contentAddress then return .WireUIDesignResult~failure("ARTIFACT_IMMUTABILITY_CONFLICT",key)
    return .WireUIDesignResult~success(prior,"ALREADY_REGISTERED")
  end
  artifacts[key]=artifact
  if artifact~isA(.WireUIProjectionDesign) then do
    pkey=artifact~profile"|"artifact~elementRef~artifactId
    rows=projectionsByProfileElement[pkey]; if rows==.nil then do; rows=.array~new; projectionsByProfileElement[pkey]=rows; end
    rows~append(artifact)
  end
  return .WireUIDesignResult~success(artifact)

/* Apply one semantic authoring operation at exactly the revision it was based on. */
::method applyOperation
  expose revision operationLog operationsById
  use arg operation
  if \operation~isA(.WireUIDesignOperation) then return .WireUIDesignResult~failure("INVALID_DESIGN_OPERATION")
  oid=operation~operationId
  if operationsById~hasIndex(oid) then do
    prior=operationsById[oid]
    if prior~contentAddress=operation~contentAddress then return .WireUIDesignResult~success(prior,"OPERATION_ALREADY_APPLIED")
    return .WireUIDesignResult~failure("OPERATION_ID_CONFLICT",oid)
  end
  if operation~expectedRevision \= revision then return .WireUIDesignResult~failure("DESIGN_REVISION_CONFLICT",operation~expectedRevision"|"revision)
  verb=operation~verb
  select
    when verb="DESIGN.PROJECTION.SET_COMPONENT" then r=self~opProjectionSetComponent(operation)
    when verb="DESIGN.PROJECTION.SET_MATERIAL" then r=self~opProjectionSetMaterial(operation)
    when verb="DESIGN.MATERIAL.SET_TOKEN" then r=self~opMaterialSetToken(operation)
    when verb="DESIGN.JOURNEY.SET_PREFETCH" then r=self~opJourneySetPrefetch(operation)
    when verb="DESIGN.ELEMENT.SET_AUDIENCE" then r=self~opElementSetAudience(operation)
    otherwise return .WireUIDesignResult~failure("UNSUPPORTED_DESIGN_OPERATION",verb)
  end
  if \r~ok then return r
  operationLog~append(operation); operationsById[oid]=operation; revision += 1
  return .WireUIDesignResult~success(r~value,"OPERATION_APPLIED")

::method operations
  expose operationLog
  return .WireUIDesignUtil~copyArray(operationLog)
::method operation
  expose operationsById
  use arg operationId
  if operationsById~hasIndex(operationId) then return operationsById[operationId]
  return .nil
::method lineageFor
  expose lineages
  use arg artifactRef
  if artifactRef==.nil then return .nil
  if lineages~hasIndex(artifactRef~key) then return lineages[artifactRef~key]
  return .nil

::method artifact
  expose artifacts
  use arg kind,id,version
  key=kind~string~translate":"id"@"version
  if artifacts~hasIndex(key) then return artifacts[key]
  return .nil
::method projectionFor
  expose projectionsByProfileElement
  use arg profile, elementId, requestedVersion=""
  key=profile~string~translate"|"elementId
  rows=projectionsByProfileElement[key]
  if rows==.nil then return .nil
  if requestedVersion="" then do
    if rows~items=1 then return rows[1]
    return .nil /* ambiguous is safer than silently selecting latest */
  end
  do p over rows; if p~version=requestedVersion then return p; end
  return .nil
::method allArtifacts
  expose artifacts
  a=.array~new; keys=artifacts~allIndexes; keys~sort; do k over keys; a~append(artifacts[k]); end; return a
::method lineages
  expose lineages
  a=.array~new; keys=lineages~allIndexes; keys~sort; do k over keys; a~append(lineages[k]); end; return a
::method asWire
  expose workspaceId revision basedOnReleaseRef basedOnGraphDigest
  d=.table~new; d["workspaceId"]=workspaceId; d["revision"]=revision; d["basedOnGraphDigest"]=basedOnGraphDigest
  if basedOnReleaseRef==.nil then d["basedOnReleaseRef"]=.nil; else d["basedOnReleaseRef"]=basedOnReleaseRef~asWire
  ar=.array~new; do a over self~allArtifacts; ar~append(a~ref~asWire); end; d["artifactRefs"]=ar
  oo=.array~new; do o over self~operations; oo~append(o~asWire); end; d["operations"]=oo
  ll=.array~new; do l over self~lineages; ll~append(l~asWire); end; d["lineages"]=ll
  return d

::method opProjectionSetComponent private
  use arg operation
  prior=self~targetArtifact(operation,"PROJECTION"); if prior==.nil then return .WireUIDesignResult~failure("DESIGN_TARGET_NOT_FOUND")
  p=operation~payload; nv=self~field(p,"newVersion","")~string~strip; cr=self~field(p,"componentRef",.nil)
  if nv="" | nv=prior~version then return .WireUIDesignResult~failure("NEW_VERSION_REQUIRED")
  if cr==.nil | \cr~isA(.WireUIArtifactRef) | cr~kind<>"COMPONENT" then return .WireUIDesignResult~failure("COMPONENT_REF_REQUIRED")
  if self~artifact(cr~kind,cr~artifactId,cr~version)==.nil then return .WireUIDesignResult~failure("COMPONENT_NOT_REGISTERED",cr~key)
  w=prior~asWire
  derived=.WireUIProjectionDesign~new(prior~projectionId,nv,prior~profile,prior~elementRef,cr,prior~definitionId,w["action"],prior~styleRole,prior~materialRole,w["bindings"],w["metadata"],w["resourceBindings"])
  return self~registerDerived(derived,prior~ref,operation)

::method opProjectionSetMaterial private
  use arg operation
  prior=self~targetArtifact(operation,"PROJECTION"); if prior==.nil then return .WireUIDesignResult~failure("DESIGN_TARGET_NOT_FOUND")
  p=operation~payload; nv=self~field(p,"newVersion","")~string~strip
  if nv="" | nv=prior~version then return .WireUIDesignResult~failure("NEW_VERSION_REQUIRED")
  style=self~field(p,"styleRole",prior~styleRole); material=self~field(p,"materialRole",prior~materialRole); w=prior~asWire
  derived=.WireUIProjectionDesign~new(prior~projectionId,nv,prior~profile,prior~elementRef,prior~componentRef,prior~definitionId,w["action"],style,material,w["bindings"],w["metadata"],w["resourceBindings"])
  return self~registerDerived(derived,prior~ref,operation)

::method opMaterialSetToken private
  use arg operation
  prior=self~targetArtifact(operation,"MATERIAL"); if prior==.nil then return .WireUIDesignResult~failure("DESIGN_TARGET_NOT_FOUND")
  p=operation~payload; nv=self~field(p,"newVersion","")~string~strip; name=self~field(p,"tokenName","")~string~strip
  if nv="" | nv=prior~version then return .WireUIDesignResult~failure("NEW_VERSION_REQUIRED")
  if name="" | \p~hasIndex("tokenValue") then return .WireUIDesignResult~failure("MATERIAL_TOKEN_REQUIRED")
  w=prior~asWire; tokens=.WireUIDesignUtil~copyTable(w["tokens"]); tokens[name]=p["tokenValue"]
  derived=.WireUIMaterialSet~new(prior~materialId,nv,tokens,w["recipes"])
  return self~registerDerived(derived,prior~ref,operation)

::method opJourneySetPrefetch private
  use arg operation
  prior=self~targetArtifact(operation,"JOURNEY"); if prior==.nil then return .WireUIDesignResult~failure("DESIGN_TARGET_NOT_FOUND")
  p=operation~payload; nv=self~field(p,"newVersion","")~string~strip; stateId=self~field(p,"stateId","")~string~strip; elements=self~field(p,"elements",.nil)
  if nv="" | nv=prior~version then return .WireUIDesignResult~failure("NEW_VERSION_REQUIRED")
  if stateId="" | prior~state(stateId)==.nil | elements==.nil | \elements~isA(.Array) then return .WireUIDesignResult~failure("JOURNEY_PREFETCH_INPUT_INVALID")
  derived=.WireUIJourneyDesign~new(prior~journeyId,nv,prior~initialState)
  do sid over prior~stateIds
    s=prior~state(sid); pref=s["PREFETCH"]; if sid=stateId then pref=elements
    rr=derived~defineState(sid,s["ACTIVE"],pref,s["ON_DEMAND"]); if \rr~ok then return rr
  end
  do t over prior~transitions
    rr=derived~allowTransition(t["fromState"],t["toState"],t["trigger"],t["purpose"]); if \rr~ok then return rr
  end
  rr=derived~seal; if \rr~ok then return rr
  return self~registerDerived(derived,prior~ref,operation)

::method opElementSetAudience private
  use arg operation
  prior=self~targetArtifact(operation,"ELEMENT"); if prior==.nil then return .WireUIDesignResult~failure("DESIGN_TARGET_NOT_FOUND")
  p=operation~payload; nv=self~field(p,"newVersion","")~string~strip; audience=self~field(p,"audiencePolicyRef","")~string~strip
  if nv="" | nv=prior~version then return .WireUIDesignResult~failure("NEW_VERSION_REQUIRED")
  if audience="" then return .WireUIDesignResult~failure("AUDIENCE_POLICY_REQUIRED")
  w=prior~asWire
  derived=.WireUISemanticElement~new(prior~elementId,nv,prior~semanticType,w["fields"],w["actions"],audience,w["metadata"])
  return self~registerDerived(derived,prior~ref,operation)

::method targetArtifact private
  use arg operation, expectedKind
  r=operation~targetRef
  if r==.nil | r~kind<>expectedKind then return .nil
  return self~artifact(r~kind,r~artifactId,r~version)
::method registerDerived private
  expose lineages
  use arg derived, predecessorRef, operation
  rr=self~register(derived); if \rr~ok then return rr
  lineage=.WireUIDesignLineage~new(derived~ref,predecessorRef,operation~ref,operation~evidenceRefs)
  lineages[derived~ref~key]=lineage
  return .WireUIDesignResult~success(derived,"DERIVED_ARTIFACT_REGISTERED")
::method field private
  use arg t,k,default=.nil
  if t==.nil then return default
  if t~hasIndex(k) then return t[k]
  return default

::requires "WireUIProjectionDesign.cls"
::requires "WireUIMaterialSet.cls"
::requires "WireUIJourneyDesign.cls"
::requires "WireUISemanticElement.cls"
::requires "WireUIDesignOperation.cls"
::requires "WireUIDesignLineage.cls"
::requires "WireUIDesignSupport.cls"
